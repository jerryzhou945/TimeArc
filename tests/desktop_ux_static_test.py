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
    card_carousel_qml = read("qml/desktop/memorylake/CardCarousel.qml")
    generative_cover_qml = read("qml/desktop/memorylake/GenerativeCover.qml")
    usage_rank_qml = read("qml/desktop/memorylake/UsageRankList.qml")
    memory_page_qml = read("qml/desktop/pages/DesktopMemoryLakePage.qml")
    stats_qml = read("qml/desktop/pages/DesktopStatsPage.qml")
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
    ranking_pos = stats_qml.find('title: "高频应用"; sub: "本月使用排行"')
    insight_pos = stats_qml.find("keywords: root.vmKeywords")
    heat_pos = stats_qml.find('title: "活跃热力"; sub: "本月每日强度')
    if not (ranking_pos < insight_pos < heat_pos):
        raise AssertionError("monthly layout must be ranking, insight, then full-width heatmap")
    require(stats_qml, "Layout.preferredHeight: 220", "monthly heatmap uses compact GitHub-style height")
    require(stats_qml, "heatMonthLabels", "GitHub-style heatmap month labels")
    require(stats_qml, 'model: [0, 1, 2, 3, 4]', "GitHub-style heatmap legend")
    reject(stats_qml, "text: modelData.day", "heatmap cells should not show day numbers")
    require(stats_qml, "columnSpacing: heat.columnGap", "heatmap stretches columns")
    reject(stats_qml, "id: heatGridWrap\n                    anchors.centerIn: parent", "heatmap centered grid")

    require(app_visual_js, 'identity.indexOf("site:") !== 0', "app ids can resolve icons")
    require(icon_provider_cpp, "resolvedIconPathCache", "app icon path resolution cache")
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
    reject(memory_card_qml, "flipped ? 434", "card flip should not resize width")
    reject(memory_card_qml, "flipped ? 616", "card flip should not resize height")
    require(card_carousel_qml, "var selW = 340", "carousel center offset uses stable selected width")
    require(generative_cover_qml, "asynchronous: false", "home cover icons render from cache synchronously")
    require(usage_rank_qml, "asynchronous: false", "home ranking icons render from cache synchronously")
    require(stats_qml, "asynchronous: false; smooth: true", "stats ranking icons render from cache synchronously")

    print("desktop UX static checks passed")


if __name__ == "__main__":
    main()
