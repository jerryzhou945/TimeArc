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
    mac_status_bar_cpp = read(
        "src/services/macos/macos_status_bar_icon.cpp")
    app_cmake = read("src/CMakeLists.txt")
    cmake_root = read("CMakeLists.txt")
    android_gradle = read("android/build.gradle") if (ROOT / "android/build.gradle").exists() else ""
    android_manifest = read("android/AndroidManifest.xml")
    android_activity = read("android/src/main/java/com/timearc/mobile/ui/TimeArcActivity.java")
    main_qml = read("qml/main.qml")
    shell_qml = read("qml/desktop/DesktopAppShell.qml")
    mac_menu_qml = read("qml/desktop/MacMenuBar.qml")
    mobile_shell_qml = read("qml/mobile/MobileAppShell.qml")
    tray_qml = read("qml/desktop/memorylake/NotifierTray.qml")
    toolbar_qml = read("qml/desktop/memorylake/MemoToolbar.qml")
    memo_qml = read("qml/desktop/memorylake/MemoOverlay.qml")
    memory_style_qml = read("qml/desktop/memorylake/MemoryLakeStyle.qml")
    memory_card_qml = read("qml/desktop/memorylake/MemoryCard.qml")
    memory_page_qml = read("qml/desktop/pages/DesktopMemoryLakePage.qml")
    stats_qml = read("qml/desktop/pages/DesktopStatsPage.qml")
    mobile_stats_qml = read("qml/mobile/pages/MobileStatsPage.qml")
    mobile_settings_qml = read("qml/mobile/pages/MobileSettingsPage.qml")
    calendar_qml = read("qml/desktop/pages/DesktopCalenderPage.qml")
    settings_qml = read("qml/desktop/pages/DesktopProfilePage.qml")
    app_visual_js = read("qml/desktop/components/AppVisual.js")
    settings_cpp = read("src/services/settings_repository.cpp")
    usage_cpp = read("src/services/usage_stat_manager.cpp")
    all_apps_cpp = usage_cpp.split("QVariantList UsageStatManager::allApps() const", 1)[1]
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
    require(cmake_root, "QT_ANDROID_PACKAGE_SOURCE_DIR", "Android package source dir")
    require(android_gradle, "androidx.work:work-runtime", "Android WorkManager dependency")
    require(android_gradle, "src/main/java", "Android Java source directory")
    require(android_manifest, "android.permission.PACKAGE_USAGE_STATS",
            "Android usage stats permission")
    require(android_manifest, "com.timearc.mobile.ui.TimeArcActivity",
            "TimeArc Android activity")
    require(android_activity, "extends org.qtproject.qt.android.bindings.QtActivity",
            "TimeArc activity inherits the Qt Android activity")
    require(android_manifest, "android.app.lib_name", "Qt Android lib metadata")

    require(main_qml, "hideToTrayOnClose", "close-to-tray gate")
    require(main_qml, "close.accepted = false", "close event cancellation")
    require(main_qml, "visible: !startInTray", "autostart launches hidden to tray")
    require(shell_qml, "trayShowRequested", "tray show bridge")
    require(shell_qml, "trayQuitRequested", "tray quit bridge")
    require(tray_qml, "Platform.Menu", "tray context menu")
    require(tray_qml, "showRequested", "tray show action")
    require(tray_qml, "quitRequested", "tray quit action")
    require(tray_qml, "icon.source: notifier.iconSource",
            "original tray SVG on non-macOS platforms")
    require(shell_qml, "pomodoroManager ? pomodoroManager.timeText",
            "tray binding tolerates context teardown")
    require(shell_qml, "pomodoroManager ? pomodoroManager.running : false",
            "tray running binding tolerates context teardown")
    require(tray_qml, "usesNativeMacOsStatusItem",
            "macOS native status-item selection")
    reject(main_cpp, "makeInputSourceTIcon",
           "macOS status-bar implementation in main")
    require(main_cpp, "MacStatusBarIcon macStatusBarIcon",
            "macOS status-bar integration")
    require(main_cpp, "QApplication app(argc, argv)",
            "QMenu-compatible macOS application")
    require(main_cpp, "QGuiApplication app(argc, argv)",
            "non-macOS GUI application")
    require(mac_status_bar_cpp, "makeInputSourceTIcon",
            "macOS status-bar icon factory")
    require(mac_status_bar_cpp, "logicalWidth = 22.0",
            "input-source icon width")
    require(mac_status_bar_cpp, "logicalHeight = 18.0",
            "input-source icon height")
    require(mac_status_bar_cpp, "std::array{1.0, 2.0, 3.0}",
            "explicit Retina icon representations")
    require(mac_status_bar_cpp, "icon.setIsMask(true)",
            "macOS template icon mask")
    require(mac_status_bar_cpp, 'invokeRoot("restoreFromTray")',
            "native macOS status-item restore action")
    require(app_cmake, "services/macos/macos_status_bar_icon.cpp",
            "macOS status-bar source list")
    require(main_cpp, "#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)",
            "macOS-only native status-item implementation")

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
    require(shell_qml, "property bool memoryRecapEnabled: false",
            "desktop release memory recap gate defaults off")
    require(shell_qml,
            'it.page !== "recap" || root.memoryRecapEnabled',
            "desktop recap navigation is filtered by the release gate")
    require(shell_qml,
            'if (key === "recap" && !memoryRecapEnabled)',
            "direct desktop recap navigation is rejected")
    require(shell_qml,
            'memoryRecapEnabled ? Qt.resolvedUrl("pages/DesktopMonthlyRecapPage.qml")',
            "disabled recap route falls back without deleting its page")
    require(mac_menu_qml,
            "visible: bar.hasShell && bar.hostShell.memoryRecapEnabled",
            "macOS recap menu entry follows the desktop release gate")
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
    reject(stats_qml, "Cursor.text()", "undefined platform text cursor helper")
    require(memory_page_qml, "accentSeed: root.themeAccentColor", "home uses injected accent")
    require(calendar_qml, "accentSeed: root.themeAccentColor", "calendar uses injected accent")

    require(usage_cpp, "app:codex", "Codex has its own activity group")
    require(usage_cpp, "app:uu-accelerator", "UU accelerator has its own activity group")
    reject(usage_cpp, 'containsAny(text, {"cloudmusic", "netease"})',
           "generic NetEase app matching")
    require(usage_cpp, 'item["lastUsedUnixSec"]', "application aggregate recent record time")
    require(all_apps_cpp, "if (!m_autoClassify)", "all-app library auto-classify gating")
    require(all_apps_cpp, "!m_gameClassify", "all-app library game-classify gating")

    require(stats_qml, "component StatsAggregateSummary", "shared aggregate summary")
    require(stats_qml, "radius: aggregateSummary.radius", "aggregate summary overlay has a concrete radius")
    require(stats_qml, "component StatsCategoryDistribution", "shared category distribution")
    require(stats_qml, "// ====== 周/月/年共用聚合视图 ======", "shared period layout")
    require(stats_qml, 'barCount: root.vmTrendBars.length', "period-specific trend density")
    require(stats_qml, 'text: root.tr("最近记录")', "application library recent record column")
    reject(stats_qml, 'title: "月度日历"', "retired standalone monthly calendar")
    reject(stats_qml, "StatsYearRhythm {", "retired standalone yearly rhythm")

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

    require(mobile_shell_qml, "mobileUsageService.refreshUsageAccessState",
            "mobile shell refreshes Android usage access")
    require(mobile_shell_qml, "mobileUsageService.requestImmediateSync",
            "mobile shell queues Android usage sync")
    require(mobile_settings_qml, "mobileUsageService.openUsageAccessSettings",
            "mobile settings opens Usage Access")
    require(mobile_settings_qml, "mobileUsageService.requestImmediateSync",
            "mobile settings triggers usage sync")
    require(mobile_settings_qml, "mobileUsageService.syncStatusText",
            "mobile settings shows usage sync status")

    print("desktop UX static checks passed")


if __name__ == "__main__":
    main()
