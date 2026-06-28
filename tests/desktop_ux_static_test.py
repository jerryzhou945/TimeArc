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
    memory_style_qml = read("qml/desktop/memorylake/MemoryLakeStyle.qml")
    memory_card_qml = read("qml/desktop/memorylake/MemoryCard.qml")
    memory_page_qml = read("qml/desktop/pages/DesktopMemoryLakePage.qml")
    stats_qml = read("qml/desktop/pages/DesktopStatsPage.qml")
    mobile_stats_qml = read("qml/mobile/pages/MobileStatsPage.qml")
    calendar_qml = read("qml/desktop/pages/DesktopCalenderPage.qml")
    settings_qml = read("qml/desktop/pages/DesktopProfilePage.qml")
    app_visual_js = read("qml/desktop/components/AppVisual.js")
    settings_cpp = read("src/services/settings_repository.cpp")
    usage_cpp = read("src/services/usage_stat_manager.cpp")
    icon_provider_cpp = read("src/services/app_icon_image_provider.cpp")
    adapter_registry_h = read("src/services/adapters/desktop_app_adapter_registry.h")
    activity_registry_h = read("src/services/adapters/activity_adapter_registry.h")
    codex_adapter_h = read("src/services/adapters/apps/codex_adapter.h")

    require(main_cpp, "TimeArcUiSingleInstance", "UI single-instance mutex")
    require(main_cpp, "activateExistingTimeArcWindow", "existing-window activation")
    reject(main_cpp, "IsWindowVisible(hwnd)", "hidden tray window activation filter")
    require(main_cpp, "--start-in-tray", "UI autostart tray launch argument")
    require(main_cpp, "startInTray", "QML start-in-tray context")
    require(main_cpp, "mobileUsageService", "mobile usage service context")

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

    require(memory_style_qml, "accentSeed", "shared accent seed")
    require(shell_qml, 'getValue("accent_color", "#9FE7EE")', "shell reads persisted accent")
    require(shell_qml, "item.accentChanged.connect", "settings accent signal bridge")
    require(settings_qml, "signal accentChanged", "settings accent signal")
    require(settings_qml, "root.accentChanged(modelData.value)", "accent swatch applies globally")
    require(settings_qml, "accentChanged(accentColor)", "restore defaults reapplies accent")
    reject(settings_qml, "后续阶段开放", "accent no longer deferred")
    require(stats_qml, "accentSeed: root.themeAccentColor", "stats uses injected accent")
    require(memory_page_qml, "accentSeed: root.themeAccentColor", "home uses injected accent")
    require(calendar_qml, "accentSeed: root.themeAccentColor", "calendar uses injected accent")

    require(usage_cpp, "app:codex", "Codex has its own activity group")
    require(usage_cpp, "app:uu-accelerator", "UU accelerator has its own activity group")
    reject(usage_cpp, 'containsAny(text, {"cloudmusic", "netease"})',
           "generic NetEase app matching")

    require(stats_qml, 'title: "高频应用"; sub: "本月使用排行"', "monthly ranking card")
    require(stats_qml, 'title: "活跃热力"; sub: "本月每日强度', "monthly heatmap card")
    if stats_qml.find('title: "高频应用"; sub: "本月使用排行"') > stats_qml.find('title: "活跃热力"; sub: "本月每日强度'):
        raise AssertionError("monthly ranking must render before monthly heatmap")
    require(stats_qml, "columnSpacing: heat.columnGap", "heatmap stretches columns")
    reject(stats_qml, "id: heatGridWrap\n                    anchors.centerIn: parent", "heatmap centered grid")

    require(app_visual_js, 'identity.indexOf("site:") !== 0', "app ids can resolve icons")
    require(icon_provider_cpp, "iconPixmapCache", "app icon provider cache")
    require(icon_provider_cpp, "normalizedIconPixmap", "app icon transparent-padding trim")
    require(icon_provider_cpp, "Stardew Valley.exe", "Stardew icon candidate")
    require(icon_provider_cpp, "r5apex.exe", "Apex icon candidate")
    require(codex_adapter_h, "codexAppAdapter", "Codex adapter definition")
    require(adapter_registry_h, "codexAppAdapter(), vscodeAppAdapter()", "Codex adapter before VSCode")
    require(activity_registry_h, "containsAnyLower(input.title, adapter.titleHints)", "desktop title hint matching")
    require(app_visual_js, "app:codex", "Codex visual identity")

    require(calendar_qml, "normalizedImageSource", "calendar normalizes local image paths")
    require(calendar_qml, "cache: false", "calendar selected photo bypasses stale cache")

    require(memory_page_qml, "activeSoftwareForRange(\"all\")", "home computes total duration")
    require(memory_page_qml, "copy.totalTime", "home card total duration field")
    require(memory_card_qml, "card.app.totalTime", "card back total duration")
    require(memory_card_qml, "card.app.yearTime", "card back year duration")
    require(memory_card_qml, "card.app.monthTime", "card back month duration")
    require(memory_card_qml, "card.app.dayTime", "card back day duration")

    require(mobile_stats_qml, "mobileUsageService.getDashboardForRange",
            "mobile stats reads backend dashboard")
    require(mobile_stats_qml, "dashboard.topApps",
            "mobile stats renders backend top apps")
    reject(mobile_stats_qml, 'VSCode', "mobile stats no static desktop app data")
    reject(mobile_stats_qml, 'Steam', "mobile stats no static game data")

    print("desktop UX static checks passed")


if __name__ == "__main__":
    main()
