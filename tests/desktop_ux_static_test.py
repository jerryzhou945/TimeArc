from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def reject(text, needle, label):
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


def main():
    main_cpp = read("src/main.cpp")
    main_qml = read("qml/main.qml")
    shell_qml = read("qml/desktop/DesktopAppShell.qml")
    tray_qml = read("qml/desktop/memorylake/NotifierTray.qml")
    toolbar_qml = read("qml/desktop/memorylake/MemoToolbar.qml")
    memo_qml = read("qml/desktop/memorylake/MemoOverlay.qml")
    settings_qml = read("qml/desktop/pages/DesktopProfilePage.qml")
    settings_cpp = read("src/services/settings_repository.cpp")
    usage_cpp = read("src/services/usage_stat_manager.cpp")

    require(main_cpp, "TimeArcUiSingleInstance", "UI single-instance mutex")
    require(main_cpp, "activateExistingTimeArcWindow", "existing-window activation")
    reject(main_cpp, "IsWindowVisible(hwnd)", "hidden tray window activation filter")
    require(main_cpp, "--start-in-tray", "UI autostart tray launch argument")
    require(main_cpp, "startInTray", "QML start-in-tray context")

    require(main_qml, "hideToTrayOnClose", "close-to-tray gate")
    require(main_qml, "close.accepted = false", "close event cancellation")
    require(main_qml, "visible: !startInTray", "autostart launches hidden to tray")
    require(shell_qml, "trayShowRequested", "tray show bridge")
    require(shell_qml, "trayQuitRequested", "tray quit bridge")
    require(tray_qml, "Platform.Menu", "tray context menu")
    require(tray_qml, "showRequested", "tray show action")
    require(tray_qml, "quitRequested", "tray quit action")

    require(toolbar_qml, "undoRequested", "visible undo signal")
    require(toolbar_qml, "redoRequested", "visible redo signal")
    require(toolbar_qml, 'kind: "undo"', "undo toolbar icon")
    require(toolbar_qml, 'kind: "redo"', "redo toolbar icon")
    require(memo_qml, "canUndo:", "undo button state binding")
    require(memo_qml, "onUndoRequested", "undo button handler")
    require(memo_qml, "onRedoRequested", "redo button handler")

    require(settings_qml, "setAutostartEnabled(c)", "autostart mutation")
    require(settings_cpp, "QCoreApplication::applicationFilePath()", "autostart registers UI executable")
    require(settings_cpp, "uiAutostartCommand", "autostart uses UI launch command")
    require(settings_cpp, "--start-in-tray", "autostart starts UI in tray")

    require(shell_qml, "pageGuideModel", "page visual guidance model")
    require(shell_qml, "guideRail", "page guide rail")
    require(shell_qml, "readonly property bool prefersLightChrome: nightMode", "day chrome uses dark glyphs")
    reject(shell_qml, "nightMode || fullBleedPage", "day full-bleed light chrome")

    require(usage_cpp, "app:codex", "Codex has its own activity group")
    require(usage_cpp, "app:uu-accelerator", "UU accelerator has its own activity group")
    reject(usage_cpp, 'containsAny(text, {"cloudmusic", "netease"})',
           "generic NetEase app matching")

    print("desktop UX static checks passed")


if __name__ == "__main__":
    main()
