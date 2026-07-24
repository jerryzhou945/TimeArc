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
    wechat_adapter_path = ROOT / (
        "android/src/main/java/com/timearc/mobile/ui/"
        "WeChatMomentsAdapter.java"
    )
    qq_adapter_path = ROOT / (
        "android/src/main/java/com/timearc/mobile/ui/QqZoneAdapter.java"
    )
    if not wechat_adapter_path.exists() or not qq_adapter_path.exists():
        raise AssertionError("missing direct social share adapters")
    wechat_adapter = wechat_adapter_path.read_text(encoding="utf-8")
    qq_adapter = qq_adapter_path.read_text(encoding="utf-8")
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
    share_bar_path = ROOT / "qml/mobile/components/MobileShareActionBar.qml"
    if not share_bar_path.exists():
        raise AssertionError("missing unified mobile share action bar")
    share_bar = share_bar_path.read_text(encoding="utf-8")
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
    require(ui_header, "Q_INVOKABLE bool saveImageToGallery",
            "gallery save API")
    require(ui_header, "Q_INVOKABLE bool shareImageToChannel",
            "social channel share API")
    require(ui_header, "Q_INVOKABLE QVariantMap socialShareStatus",
            "social authorization status API")
    require(ui_header, "Q_PROPERTY(QString wechatAppId",
            "WeChat AppID property")
    require(ui_header, "Q_PROPERTY(QString qqAppId",
            "QQ AppID property")
    require(ui_header, "Q_INVOKABLE bool setSocialAppId",
            "social AppID persistence API")
    require(ui_service, "mobile_share_wechat_app_id",
            "WeChat AppID settings key")
    require(ui_service, "mobile_share_qq_app_id",
            "QQ AppID settings key")
    require(android_bridge, "FileProvider.getUriForFile",
            "Android FileProvider share")
    require(android_bridge, "Intent.ACTION_SEND", "Android share intent")
    require(android_bridge, "MediaStore.Images.Media.EXTERNAL_CONTENT_URI",
            "Android MediaStore gallery collection")
    require(android_bridge, "MediaStore.MediaColumns.RELATIVE_PATH",
            "Android gallery relative path")
    require(android_bridge, 'Environment.DIRECTORY_PICTURES + "/TimeArc"',
            "TimeArc gallery album")
    require(android_bridge, "MediaStore.MediaColumns.IS_PENDING",
            "atomic Android gallery write")
    require(android_bridge, "saveImageToGallery",
            "Android gallery export")
    require(android_bridge, "shareImageToChannel",
            "Android social channel routing")
    for status_code in (
        "ready",
        "waiting_authorization",
        "client_missing",
        "sdk_missing",
        "launch_failed",
        "saved",
    ):
        combined_social = android_bridge + wechat_adapter + qq_adapter
        require(combined_social, status_code,
                f"social status code {status_code}")
    require(wechat_adapter, "WXSceneTimeline",
            "WeChat Moments timeline scene")
    require(wechat_adapter, "com.tencent.mm.opensdk",
            "WeChat OpenSDK boundary")
    require(qq_adapter, "publishToQzone",
            "QQ Zone publish boundary")
    require(qq_adapter, "com.tencent.tauth",
            "QQ Connect SDK boundary")
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
        if "mobileUiService.wallpaperUrl" in page:
            raise AssertionError(
                f"{page_name} must not instantiate or load its own wallpaper"
            )
    for label in ("社交平台授权", "微信 AppID", "QQ AppID", "等待平台授权"):
        require(settings, label, f"social authorization UI: {label}")
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
    require(history, 'import "../components/MobileMonthProfiles.js" as MonthProfiles',
            "Memory Lake monthly profile import")
    require(history, "Image.PreserveAspectCrop",
            "seasonal monthly entry image crop")
    require(history, "coverProfile.sceneSource",
            "seasonal monthly entry scene")
    report_cover = history.split("id: reportCover", 1)[1].split(
        "最近被记住", 1
    )[0]
    if "Canvas {" in report_cover:
        raise AssertionError("monthly entry must not use the old Canvas cover")
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
    for channel, label in (
        ("gallery", "保存到图库"),
        ("moments", "朋友圈"),
        ("qzone", "QQ动态"),
        ("system", "更多"),
    ):
        require(share_bar, f'channel: "{channel}"',
                f"share action channel {channel}")
        require(share_bar, label, f"share action label {label}")
    require(share, "MobileShareActionBar",
            "app share action bar")
    qml_cmake = read("qml/CMakeLists.txt")
    require(qml_cmake, "MobileShareActionBar.qml",
            "share action bar QML registration")
    if profiles.count("sceneSource:") != 12:
        raise AssertionError("month profiles must define twelve scene sources")
    require(season_scene, "Image.PreserveAspectCrop",
            "season scene preserves portrait crop")
    require(season_scene, "reducedMotion",
            "season scene reduced-motion mode")
    require(season_scene, "rainDrop",
            "independent seasonal rain particles")
    monthly_pages = (
        "MonthlyCoverPage.qml",
        "MonthlyOverviewPage.qml",
        "MonthlyHighlightPage.qml",
        "MonthlyCompanionPage.qml",
        "MonthlyRankingPage.qml",
        "MonthlySharePage.qml",
    )
    for page_name in monthly_pages:
        page_path = ROOT / "qml/mobile/components/monthly" / page_name
        if not page_path.exists():
            raise AssertionError(f"missing monthly story page: {page_name}")
    monthly_story = read("qml/mobile/components/MobileMonthlyStory.qml")
    require(monthly_story, "readonly property int pageCount: 6",
            "six-page monthly story")
    require(monthly_story, "MobileSeasonScene",
            "monthly story seasonal scene")
    require(monthly_story, "DragHandler",
            "monthly story swipe gesture")
    require(monthly_story, "Qt.size(1080, 1920)",
            "portrait monthly share export")
    require(monthly_story, '(root.currentPage + 1) + " / " + root.pageCount',
            "neutral monthly story progress marker")
    if '? "完成"' in monthly_story:
        raise AssertionError("monthly story must not show abrupt completion copy")
    ranking_share_path = (
        ROOT / "qml/mobile/components/MobileRankingShareOverlay.qml"
    )
    if not ranking_share_path.exists():
        raise AssertionError("missing ranking share overlay")
    ranking_share = ranking_share_path.read_text(encoding="utf-8")
    require(ranking_share, "MobileShareActionBar",
            "ranking share action bar")
    require(monthly_story, "shareImageToChannel",
            "monthly channel share handoff")
    require(ranking_share, "function openForRanking",
            "range ranking share entry point")
    require(ranking_share, "MobileAppIcon",
            "ranking share uses actual app icons")
    require(ranking_share, "grabToImage",
            "ranking share image export")
    require(stats, "rankingShare.openForRanking",
            "Statistics ranking share action")
    story_block = share.split("function storyForShare()", 1)[1].split(
        "function exportAndShare(channel)", 1
    )[0]
    if "displayName" in story_block:
        raise AssertionError(
            "anonymous-safe share story must not read the application name"
        )

    print("Mobile UI static checks passed")


if __name__ == "__main__":
    main()
