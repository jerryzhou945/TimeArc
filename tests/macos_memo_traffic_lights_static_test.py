from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def forbid(text, needle, label):
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


def main():
    main_qml = (ROOT / "qml/main.qml").read_text(encoding="utf-8")
    shell_qml = (
        ROOT / "qml/desktop/DesktopAppShell.qml"
    ).read_text(encoding="utf-8")
    menu_qml = (
        ROOT / "qml/desktop/MacMenuBar.qml"
    ).read_text(encoding="utf-8")
    memo_qml = (
        ROOT / "qml/desktop/memorylake/MemoOverlay.qml"
    ).read_text(encoding="utf-8")

    # The AppKit buttons composite above the Qt view, so the memo board must not
    # ask the controller to hide them; they stay visible for the window's life.
    require(
        main_qml,
        "macTrafficLightsController.setVisible(true)",
        "traffic lights unconditionally visible",
    )
    forbid(
        main_qml,
        "setVisible(!memoOpen)",
        "memo-driven traffic light hiding",
    )
    forbid(
        main_qml,
        "onMemoOpenChanged",
        "memo-driven window chrome handler",
    )

    # Overlay chrome keeps clear of the button band via the shared 88px reserve.
    require(
        memo_qml,
        "readonly property int macTrafficLightInset: macSidebarChrome ? 88 : 0",
        "memo traffic light inset",
    )
    require(
        memo_qml,
        "leftMargin: 24 + memo.macTrafficLightInset",
        "save-status pill inset past the traffic lights",
    )
    require(
        shell_qml,
        "macSidebarChrome: root.macSidebarChrome",
        "shell passes macOS chrome flag into the overlay",
    )

    # Pointer handlers are offered the event ahead of the item pass, so the
    # overlay's MouseArea cannot shield the sidebar's window-drag / double-tap
    # gestures; they have to be disabled outright while the board is open or a
    # drag over the old sidebar area moves the window instead of drawing ink.
    require(
        shell_qml,
        "enabled: root.macSidebarChrome && !root.memoOpen",
        "sidebar window gestures disabled over the memo board",
    )
    forbid(
        shell_qml,
        "enabled: root.macSidebarChrome\n",
        "ungated sidebar window gesture surface",
    )

    # A reachable red button must not drop the 600ms autosave debounce.
    require(
        memo_qml,
        "function flushPendingSave()",
        "memo forced-save entry point",
    )
    require(
        memo_qml,
        "if (!_loaded) return;",
        "flush guard against overwriting an unloaded doc",
    )
    require(
        shell_qml,
        "function flushMemoDoc()",
        "shell-level memo flush hook",
    )
    require(
        main_qml,
        "shellLoader.item.flushMemoDoc()",
        "window close flushes the memo doc",
    )

    # Keyboard and mouse must agree: the red button works, so must Cmd+W.
    require(
        menu_qml,
        'text: bar.tr("关闭窗口")',
        "close window menu item",
    )
    forbid(
        menu_qml,
        "enabled: bar.hasWindow && !bar.memoOpen",
        "close window disabled over the memo board",
    )

    print("macOS memo traffic light static checks passed")


if __name__ == "__main__":
    main()
