from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def forbid(text, needle, label):
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


def main():
    bar = (ROOT / "qml/desktop/MacMenuBar.qml").read_text(encoding="utf-8")
    main_qml = (ROOT / "qml/main.qml").read_text(encoding="utf-8")
    shell = (
        ROOT / "qml/desktop/DesktopAppShell.qml"
    ).read_text(encoding="utf-8")
    profile = (
        ROOT / "qml/desktop/pages/DesktopProfilePage.qml"
    ).read_text(encoding="utf-8")
    i18n_js = (
        ROOT / "qml/desktop/components/I18n.js"
    ).read_text(encoding="utf-8")
    qml_cmake = (ROOT / "qml/CMakeLists.txt").read_text(encoding="utf-8")

    require(qml_cmake, "qml/desktop/MacMenuBar.qml", "menu bar in the QML module")

    # macOS only. Windows/Linux must not instantiate a MenuBar at all: they
    # keep the self-drawn WindowChrome, whose caption would collide with one.
    require(main_qml, "active: appWindow.macSidebarChrome",
            "menu bar gated on the macOS chrome flag")
    require(main_qml, "MacMenuBar {", "menu bar instantiated from the window")
    forbid(shell, "MacMenuBar {", "menu bar instantiated from the shared shell")

    # The injected properties must NOT be named after main.qml's ids. In
    # `MacMenuBar { appWindow: appWindow }` the right-hand side resolves to the
    # object's own property first, so the binding is a self-assignment that
    # stays null — and every command gated on a live window greys out.
    require(main_qml, "hostWindow: appWindow", "window injected under a distinct name")
    require(main_qml, "hostShell: shellLoader.item", "shell injected under a distinct name")
    require(bar, "property var hostWindow: null", "window property")
    require(bar, "property var hostShell: null", "shell property")
    for shadowing in ("property var appWindow", "property var shell:"):
        forbid(bar, shadowing, "property name that shadows a main.qml id")

    # Six menus: the app menu is populated by role merging (see below), the
    # other five are declared here.
    for title in ("文件", "编辑", "显示", "窗口", "帮助"):
        require(bar, f'title: bar.tr("{title}")', f"{title} menu")

    # Settings and Quit carry roles so macOS merges them into the app menu.
    # Quit must route through quitFromTray(): the default quit item bypasses
    # forceQuit and hits main.qml's "close keeps the app running" onClosing.
    require(bar, "role: Platform.MenuItem.PreferencesRole", "settings role")
    require(bar, "role: Platform.MenuItem.QuitRole", "quit role")
    require(bar, "bar.hostWindow.quitFromTray()", "quit routed through the window")

    # Commands, each bound to behavior that already exists.
    for command in (
        'shortcut: "Ctrl+,"',            # settings
        'shortcut: "Ctrl+Q"',            # quit
        'shortcut: "Ctrl+Shift+E"',      # export stats report
        'shortcut: "Ctrl+W"',            # close window
        'shortcut: "Ctrl+Z"',            # undo
        'shortcut: "Ctrl+Shift+Z"',      # redo
        'shortcut: "Ctrl+X"',            # cut
        'shortcut: "Ctrl+C"',            # copy
        'shortcut: "Ctrl+V"',            # paste
        'shortcut: "Ctrl+A"',            # select all
        'shortcut: "Ctrl+1"',            # memory lake
        'shortcut: "Ctrl+2"',            # calendar
        'shortcut: "Ctrl+3"',            # stats
        'shortcut: "Ctrl+4"',            # monthly recap
        'shortcut: "Ctrl+Shift+N"',      # memo board
        'shortcut: "Ctrl+Shift+P"',      # pomodoro
        'shortcut: "Ctrl+Alt+D"',        # night mode
        'shortcut: "Ctrl+M"',            # minimize
    ):
        require(bar, command, "menu command")

    # A single letter can never be a menu key equivalent: the menu would eat
    # the keystroke before a focused text field sees it, which is what the
    # shell's Keys.onShortcutOverride exists to prevent. The letter hotkeys
    # (N / P, user-rebindable) stay in the shell, untouched.
    for bare in ('shortcut: "N"', 'shortcut: "P"',
                 "shortcut: root.memoHotkeyKey", "shortcut: bar.host"):
        forbid(bar, bare, "bare single-letter menu shortcut")
    require(shell, "sequences: root.memoHotkeyKey.length > 0",
            "memo letter hotkey still owned by the shell")
    require(shell, "sequences: root.pomodoroHotkeyKey.length > 0",
            "pomodoro letter hotkey still owned by the shell")

    # The menu bar outlives the window (red button closes the window, the
    # process stays). Commands needing a window/shell must grey out instead of
    # silently restoring it; only the Window menu's TimeArc row brings it back.
    require(bar, "readonly property bool hasWindow: hostWindow !== null && hostWindow.visible",
            "no-window state")
    require(bar, "readonly property bool canNavigate: hasWindow && hasShell && !memoOpen",
            "navigation disabled with no window or over the memo board")
    require(bar, "bar.hostWindow.restoreFromTray()", "window restore row")
    require(bar, "enabled: bar.canNavigate && bar.onStatsPage",
            "stats export scoped to the stats page")
    require(bar, "!hostShell.memoLocked", "memo guard shared with the letter hotkey")

    # Check state is pushed on aboutToShow, never bound: Qt.labs.platform
    # writes checked on activation, which would break a binding for good.
    require(bar, "onAboutToShow: bar.syncViewChecks()", "view menu check sync")
    require(bar, "onAboutToShow: bar.syncWindowChecks()", "window menu check sync")
    forbid(bar, "checked: bar.", "bound check state that activation would break")

    # Command targets exist on the objects the menu calls into.
    for fn in ("function menuNavigateTo(", "function menuToggleMemo(",
               "function menuTogglePomodoro(", "function menuToggleNightMode(",
               "function menuSetLanguage(", "function menuRunSettingsAction(",
               "function menuExportStatsReport("):
        require(shell, fn, "shell command entry point")
    require(profile, "function openImportDialog()", "settings import entry point")
    require(profile, "function doExport()", "settings export entry point")
    require(profile, "function doBackupDatabase()", "database backup entry point")

    # All three UI languages, from the same file the window UI uses.
    require(bar, 'import "components/I18n.js" as I18n', "shared i18n source")
    require(bar, "return I18n.menu(lang, source);", "menu strings localized")
    require(i18n_js, "var menuEn = {", "English menu table")
    require(i18n_js, "var menuJa = {", "Japanese menu table")
    require(i18n_js, "function menu(lang, source)", "menu lookup")
    for label in ("文件", "编辑", "显示", "窗口", "帮助", "备忘黑板",
                  "月度记忆湖", "夜间模式", "在 Finder 中显示数据文件夹"):
        require(i18n_js, f'"{label}": "', f"{label} translated")
    # Language names stay in their own language, macOS-style — never translated.
    for literal in ('text: "中文"', 'text: "English"', 'text: "日本語"'):
        require(bar, literal, "language row")

    # No service control from the menu bar: pausing the sampler means the UI
    # signalling the service, and CHARTER §2 forbids IPC. Same rule the status
    # item follows.
    for banned in ("stopBackgroundCollection", "startBackgroundCollection",
                   "Qt.createQmlObject", "timerManager"):
        forbid(bar, banned, "service or timer control from the menu bar")


if __name__ == "__main__":
    main()
