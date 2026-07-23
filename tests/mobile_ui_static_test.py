from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main():
    main_cpp = read("src/main.cpp")
    ui_header = read("src/services/mobile/mobile_ui_service.h")
    ui_service = read("src/services/mobile/mobile_ui_service.cpp")
    android_bridge = read(
        "android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java"
    )
    shell = read("qml/mobile/MobileAppShell.qml")
    theme = read("qml/mobile/MobileTheme.qml")
    home = read("qml/mobile/pages/MobileHomePage.qml")
    stats = read("qml/mobile/pages/MobileStatsPage.qml")
    history = read("qml/mobile/pages/MobileHistoryPage.qml")
    settings = read("qml/mobile/pages/MobileSettingsPage.qml")
    glass = read("qml/mobile/components/MobileGlassPanel.qml")
    rank_row = read("qml/mobile/components/MobileUsageRankRow.qml")
    app_icon = read("qml/mobile/components/MobileAppIcon.qml")
    flip_card = read("qml/mobile/components/MobileFlipCard.qml")
    share = read("qml/mobile/components/MobileShareOverlay.qml")
    profiles_path = ROOT / "qml/mobile/components/MobileMonthProfiles.js"
    season_scene_path = ROOT / "qml/mobile/components/MobileSeasonScene.qml"
    if not profiles_path.exists() or not season_scene_path.exists():
        raise AssertionError("missing monthly profile or seasonal scene component")
    profiles = profiles_path.read_text(encoding="utf-8")
    season_scene = season_scene_path.read_text(encoding="utf-8")
    resources_cmake = read("resources/CMakeLists.txt")
    for month in range(1, 13):
        asset = f"resources/mobile/monthly/month-{month:02d}.jpg"
        if not (ROOT / asset).exists():
            raise AssertionError(f"missing monthly scene asset: {asset}")
        require(resources_cmake, asset, f"month {month} resource registration")

    require(main_cpp, '"mobileUiService"', "QML mobile UI service")
    require(ui_header, "Q_PROPERTY(QString wallpaperUrl",
            "wallpaper property")
    require(ui_header, "Q_INVOKABLE bool importWallpaper",
            "wallpaper import")
    require(ui_header, "Q_INVOKABLE bool shareImage", "share handoff")
    require(android_bridge, "FileProvider.getUriForFile",
            "Android FileProvider share")
    require(android_bridge, "Intent.ACTION_SEND", "Android share intent")
    require(shell, "Image.PreserveAspectCrop",
            "single shell wallpaper crop")
    require(shell, "wallpaperActive", "global wallpaper state")
    require(shell, "wallpaperSource.toString().length > 0",
            "QUrl-safe wallpaper state")
    require(shell, "function refreshWallpaper()",
            "explicit wallpaper refresh")
    require(shell, "function onWallpaperChanged()",
            "wallpaper change signal handling")
    require(ui_service, "QUuid::createUuid",
            "versioned wallpaper filename")
    require(ui_service, "const QString previous = wallpaperPath_",
            "previous wallpaper cleanup")
    require(ui_service, "removeStaleWallpaperFiles",
            "startup wallpaper orphan cleanup")
    require(ui_service, "removeWallpaperFileLater",
            "deferred wallpaper file cleanup")
    require(ui_service, "QStringLiteral(\"\")",
            "non-null empty wallpaper setting")
    require(ui_service, r'R"([^\p{L}\p{N}]+)"',
            "valid Unicode share filename sanitizer")
    if shell.count("Image.PreserveAspectCrop") != 1:
        raise AssertionError("mobile shell must own exactly one cropped wallpaper")
    for page_name, page in (
        ("Home", home),
        ("Statistics", stats),
        ("Memory Lake", history),
        ("Settings", settings),
    ):
        require(page, "property bool wallpaperActive",
                f"{page_name} global wallpaper participation")
        if "wallpaperUrl" in page or "Image.PreserveAspectCrop" in page:
            raise AssertionError(
                f"{page_name} must not instantiate or load its own wallpaper"
            )
    require(theme, "readonly property color contentClear",
            "near-clear wallpaper surface token")
    require(theme, "readonly property color contentWash",
            "light wallpaper wash token")
    require(theme, "readonly property color contentStrong",
            "strong readable wallpaper token")
    require(theme, "readonly property color timelineLine",
            "shared timeline separator token")
    require(theme, "readonly property color wallpaperInk",
            "wallpaper-adaptive primary ink")
    require(theme, "readonly property color wallpaperMuted",
            "wallpaper-adaptive secondary ink")
    require(theme, '"#78FFFFFF"',
            "readable light wallpaper glass")
    require(theme, '"#C8FFFFFF"',
            "strong light wallpaper glass")
    require(glass, "theme.contentClear",
            "glass panels pass the wallpaper through")
    require(home, "记录使用天数", "Home recorded-day semantic marker")
    require(home, "ListView.SnapOneItem", "single centered Home card paging")
    require(stats, '["week", "month", "year", "all"]',
            "four statistics ranges")
    require(stats, "previewDashboards", "desktop preview sample data")
    require(stats, '"--mobile-preview"', "preview data command-line guard")
    require(stats, "dateRailWidth", "Memory Lake-style Statistics date rail")
    require(stats, "MobileAppIcon", "icon-led Statistics rows")
    require(history, "dateRailWidth", "Memory Lake date rail")
    require(history, "theme.timelineLine", "Memory Lake transparent separators")
    require(rank_row, "theme.timelineLine",
            "flat ranking progress and separator language")
    require(app_icon, "appIconPath", "real app icon")
    require(app_icon, "visible: iconImage.status !== Image.Ready",
            "icon fallback hidden behind real icon")
    require(flip_card, "readonly property real flipDepth",
            "3D card depth cue")
    require(flip_card, "readonly property real frontFaceAngle",
            "continuous front face transform")
    require(flip_card, "readonly property real backFaceAngle",
            "continuous back face transform")
    require(flip_card, "transformOrigin: Item.Center",
            "centered depth compression")
    if flip_card.count("axis: Qt.vector3d(0, 1, 0)") != 2:
        raise AssertionError("both card faces must rotate on a pure Y axis")
    require(flip_card, "signal flippedRequested(bool flipped)",
            "one-way 3D flip state request")
    require(home, "onFlippedRequested: function(flipped)",
            "Home-owned card flip state")
    require(share, "grabToImage", "shared preview/export component")
    require(share, "anonymous", "anonymous share mode")
    require(share, "function storyForShare()",
            "anonymous-safe share story")
    require(share, "text: root.storyForShare()",
            "share poster uses privacy-filtered story")
    if profiles.count("sceneSource:") != 12:
        raise AssertionError("month profiles must define twelve scene sources")
    require(season_scene, "Image.PreserveAspectCrop",
            "season scene preserves portrait crop")
    require(season_scene, "reducedMotion",
            "season scene reduced-motion mode")
    require(season_scene, "rainDrop",
            "independent seasonal rain particles")
    story_block = share.split("function storyForShare()", 1)[1].split(
        "function exportAndShare()", 1
    )[0]
    if "displayName" in story_block:
        raise AssertionError(
            "anonymous-safe share story must not read the application name"
        )

    print("Mobile UI static checks passed")


if __name__ == "__main__":
    main()
