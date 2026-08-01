from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def forbid(text, needle, label):
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


def main():
    layer = (ROOT / "qml/desktop/PomodoroLayer.qml").read_text(encoding="utf-8")
    memo = (
        ROOT / "qml/desktop/memorylake/MemoOverlay.qml"
    ).read_text(encoding="utf-8")
    shell = (
        ROOT / "qml/desktop/DesktopAppShell.qml"
    ).read_text(encoding="utf-8")
    tray = (
        ROOT / "qml/desktop/memorylake/NotifierTray.qml"
    ).read_text(encoding="utf-8")
    menu_bar = (ROOT / "qml/desktop/MacMenuBar.qml").read_text(encoding="utf-8")
    qml_cmake = (ROOT / "qml/CMakeLists.txt").read_text(encoding="utf-8")
    i18n_js = (
        ROOT / "qml/desktop/components/I18n.js"
    ).read_text(encoding="utf-8")

    # The layer owns the widget, the celebration overlay, and the toggle API.
    require(layer, "PomodoroWidget {", "widget owned by the layer")
    require(layer, "PomodoroCompleteOverlay {", "celebration owned by the layer")
    require(layer, "function toggle()", "toggle entry point")
    require(layer, "signal finished(string title)", "completion signal")
    require(layer, "pomodoro_celebrate", "celebration setting still honored")

    # The memo blackboard no longer hosts the pomodoro. The old togglePomodoro()
    # had to open the board to make the widget visible; that is the coupling
    # this whole split exists to remove, so it must not come back.
    for banned in ("PomodoroWidget", "PomodoroCompleteOverlay",
                   "togglePomodoro", "pomodoroFinished"):
        forbid(memo, banned, "pomodoro left inside the memo overlay")
    require(memo, "signal pomodoroRequested()",
            "toolbar button forwards out of the overlay")
    require(memo, "onPomodoroRequested: memo.pomodoroRequested()",
            "toolbar button wired to the forward signal")

    # Shell hosts the layer and reaches it directly from hotkey and menu.
    require(shell, "PomodoroLayer {", "layer instantiated in the shell")
    require(shell, "onPomodoroRequested: pomodoroLayer.toggle()",
            "memo toolbar button routed to the layer")
    require(shell, "onActivated: pomodoroLayer.toggle()",
            "global hotkey opens the widget directly")
    require(shell, "target: pomodoroLayer",
            "completion notification listens to the layer")

    # The non-macOS tray exposes the same engine-backed timer controls as the
    # native macOS status item, without creating another clock in QML.
    for fragment in (
        "pomodoroTimeText",
        "pomodoroRunning",
        "pomodoroPaused",
        "pomodoroShowRequested",
        "pomodoroPrimaryRequested",
        "pomodoroResetRequested",
    ):
        require(tray, fragment, "Windows tray Pomodoro parity")
    for fragment in (
        "pomodoroManager.startTimer()",
        "pomodoroManager.pauseTimer()",
        "pomodoroManager.resetTimer()",
    ):
        require(shell, fragment, "tray action uses shared Pomodoro manager")

    # Declared after MemoOverlay: same z, later sibling paints on top, so the
    # widget stays visible while the blackboard is open.
    if shell.index("PomodoroLayer {") < shell.index("MemoOverlay {"):
        raise AssertionError(
            "PomodoroLayer must be declared after MemoOverlay so it stacks above it")

    # memoLocked is the memory-card flip lock. It gates the blackboard, and
    # must no longer gate focus timing anywhere.
    hotkey_block = shell[shell.index("sequences: root.pomodoroHotkeyKey"):]
    hotkey_block = hotkey_block[:hotkey_block.index("}")]
    forbid(hotkey_block, "memoLocked", "memo lock gating the pomodoro hotkey")
    menu_fn = shell[shell.index("function menuTogglePomodoro()"):]
    menu_fn = menu_fn[:menu_fn.index("\n    }")]
    forbid(menu_fn, "memoLocked", "memo lock gating the pomodoro menu command")
    require(menu_bar, "readonly property bool canTogglePomodoro: "
                      "hasWindow && hasShell && !capturing",
            "menu row enabled independently of the memo lock")
    require(menu_bar, "enabled: bar.canTogglePomodoro",
            "pomodoro menu row uses its own gate")

    # Esc dismisses the pomodoro on every platform (a QML Shortcut, not a macOS
    # menu key equivalent). It outranks the memo blackboard's own Esc handler
    # only while the widget is up: MemoOverlay holds focus when open and closes
    # on Esc via Keys.onPressed, but Qt offers the shortcut first and the
    # overlay never accepts a ShortcutOverride — so "pomodoro first, board
    # second" falls out of the gate below, and neither side knows about the
    # other. Once the widget is hidden the shortcut is disabled and Esc falls
    # back through to the board untouched.
    require(layer, 'sequences: ["Esc"]', "escape shortcut")
    require(layer, "enabled: layer.escapeEnabled && "
                   "(pomodoro.shown || pomodoroComplete.shown)",
            "escape only armed while the pomodoro is up")
    require(layer, "function dismiss()", "escape target")
    require(layer, "if (pomodoroComplete.shown) { pomodoroComplete.shown = false; return; }",
            "celebration dismissed before the widget")
    forbid(layer, "pomodoro.pauseTimer()",
            "escape must not stop a running session, only hide it")
    require(shell, "escapeEnabled: !root.hotkeyCapturing",
            "settings key-cap capture keeps its own Esc")
    require(memo, "if (memo.selActive) memo._clearSelection();",
            "memo overlay keeps its own escape ladder")

    # The timing engine lives in C++. The QML widget is a view: it may read
    # state and forward gestures, but must not keep its own copy — two clocks
    # that can disagree is exactly what the port removed.
    widget = (
        ROOT / "qml/desktop/memorylake/PomodoroWidget.qml"
    ).read_text(encoding="utf-8")
    require(widget, "readonly property var engine: pomodoroManager",
            "widget reads the C++ engine")
    # `readonly property int total: engine.total` is a mirror of the engine and
    # is fine; a writable one would be a second source of truth.
    for decl in ("property int total", "property int remain",
                 "property bool running", "property string title"):
        for line in widget.splitlines():
            stripped = line.strip()
            if stripped.startswith(decl):
                raise AssertionError(
                    f"writable timing state left in the QML view: {stripped}")
    for banned in ("JSON.parse", "JSON.stringify", "_save", "_load",
                   "_recordCompletion", "memoryLakeMemoPomodoro"):
        forbid(widget, banned, "timing state left in the QML view")
    # Only the collapse animation timer survives; the 1 Hz counting timer is gone.
    if widget.count("Timer {") != 1:
        raise AssertionError(
            "PomodoroWidget should keep exactly one Timer (the 180ms collapse)")

    manager_h = (
        ROOT / "src/services/pomodoro_manager.h"
    ).read_text(encoding="utf-8")
    manager_cpp = (
        ROOT / "src/services/pomodoro_manager.cpp"
    ).read_text(encoding="utf-8")
    timer_cpp = (ROOT / "src/services/timer_manager.cpp").read_text(encoding="utf-8")

    # Both clocks measure elapsed wall time instead of counting ticks. A tick
    # that never arrives (blocked event loop, coalesced timer, machine asleep)
    # must not become a lost second — and the loss only ever runs one way.
    for name, text in (("pomodoro", manager_cpp), ("manual timer", timer_cpp)):
        require(text, "currentMs()", f"{name} reads a clock")
        require(text, "refreshFromClock", f"{name} recomputes from the anchor")
        forbid(text, "++m_elapsedSeconds", f"{name} still counts ticks")
        forbid(text, "--m_remain", f"{name} still counts ticks")
    require(manager_cpp, "QDateTime::currentMSecsSinceEpoch",
            "wall clock, not a monotonic clock that stops during sleep")
    require(timer_cpp, "QDateTime::currentMSecsSinceEpoch",
            "wall clock, not a monotonic clock that stops during sleep")
    require(manager_cpp, "now < m_anchorMs", "backward clock jump handled")
    require(timer_cpp, "now < m_anchorMs", "backward clock jump handled")
    require(manager_h, "virtual qint64 currentMs()", "clock is injectable for tests")

    # Storage key and field names are unchanged, or upgrading discards whatever
    # session the user had in flight.
    require(manager_cpp, 'kStoreKey[] = "memoryLakeMemoPomodoro"',
            "storage key kept for upgrade compatibility")
    for field in ('"total"', '"remain"', '"title"'):
        require(manager_cpp, f"QStringLiteral({field})", f"archive field {field}")

    # New QML file is in the module, and the celebration's close button no
    # longer promises a trip back to the blackboard.
    require(qml_cmake, "qml/desktop/PomodoroLayer.qml", "layer in the qml module")
    complete = (
        ROOT / "qml/desktop/memorylake/PomodoroCompleteOverlay.qml"
    ).read_text(encoding="utf-8")
    forbid(complete, "回到备忘录", "memo-specific label on the close button")
    require(complete, 'I18n.t(comp.languageMode, "知道了")',
            "neutral close label")
    if i18n_js.count('"知道了"') < 2:
        raise AssertionError("知道了 must be translated for en and ja")

    print("pomodoro_global_static_test: ok")


if __name__ == "__main__":
    main()
