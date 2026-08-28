import QtQuick
import QtQuick.Window
import "components"
import "pages"
import "../shared/I18n.js" as I18n

Rectangle {
    id: root


    // One resolver owns the UI language (SettingsRepository::languageMode),
    // so a fresh install adopts the system language and every surface agrees.
    property string languageMode: (typeof settingsRepository !== "undefined" && settingsRepository)
                                  ? settingsRepository.languageMode() : "en"
    function tr(source) { return I18n.t(languageMode, source) }
    color: mobileTheme.bg

    property string currentTab: "home"
    property int topReserve: 0
    property url wallpaperSource: ""
    property bool reportUnread: false
    property bool launchOverlayVisible: true
    property string currentReportReleaseToken: ""
    readonly property int safeTopInset: Qt.platform.os === "android"
                                         ? SafeArea.margins.top : 0
    readonly property int safeBottomInset: Qt.platform.os === "android"
                                            ? SafeArea.margins.bottom : 0
    readonly property bool wallpaperActive:
        wallpaperSource.toString().length > 0

    function refreshWallpaper() {
        if (typeof mobileUiService === "undefined" || !mobileUiService) {
            root.wallpaperSource = ""
            return
        }
        root.wallpaperSource = mobileUiService.wallpaperUrl
    }

    function loadThemePreference() {
        if (typeof settingsRepository === "undefined" || !settingsRepository)
            return
        var mode = settingsRepository.getValue("mobile_theme_mode", "dark")
        mobileTheme.isDark = mode !== "light"
        mobileTheme.reducedMotion =
            settingsRepository.getBool("mobile_reduced_motion", false)
        if (typeof mobileUiService !== "undefined" && mobileUiService)
            mobileUiService.setSystemBarsLight(!mobileTheme.isDark)
    }

    function setDarkMode(enabled) {
        mobileTheme.isDark = enabled
        if (typeof mobileUiService !== "undefined" && mobileUiService)
            mobileUiService.setSystemBarsLight(!enabled)
        if (typeof settingsRepository !== "undefined" && settingsRepository)
            settingsRepository.setValue("mobile_theme_mode",
                                        enabled ? "dark" : "light")
    }

    function refreshReportNotification() {
        if (typeof mobileUsageService === "undefined"
                || !mobileUsageService
                || typeof settingsRepository === "undefined"
                || !settingsRepository) {
            root.reportUnread = false
            return
        }
        var status = mobileUsageService.getReportReleaseStatus()
        root.currentReportReleaseToken = status.releaseToken || ""
        var seen = settingsRepository.getValue(
                    "mobile_seen_report_release_token", "")
        root.reportUnread = root.currentReportReleaseToken.length > 0
                && seen !== root.currentReportReleaseToken
    }

    function markReportsSeen() {
        if (root.currentReportReleaseToken.length === 0
                || typeof settingsRepository === "undefined"
                || !settingsRepository)
            return
        settingsRepository.setValue("mobile_seen_report_release_token",
                                    root.currentReportReleaseToken)
        root.reportUnread = false
    }

    function ensureUsageAccessOnboarding() {
        if (typeof mobileUsageService === "undefined" || !mobileUsageService)
            return
        var granted = mobileUsageService.refreshUsageAccessState()
        if (granted) {
            mobileUsageService.requestImmediateSync()
            return
        }
        if (typeof settingsRepository === "undefined" || !settingsRepository)
            return
        var prompted = settingsRepository.getValue(
                    "android_usage_access_prompted", "")
        if (prompted !== "1") {
            settingsRepository.setValue("android_usage_access_prompted", "1")
            root.currentTab = "settings"
            mobileUsageService.openUsageAccessSettings()
        }
    }

    MobileTheme {
        id: mobileTheme
    }

    Connections {
        target: typeof mobileUiService !== "undefined"
                ? mobileUiService : null

        function onWallpaperChanged() {
            root.refreshWallpaper()
        }
    }

    Connections {
        target: typeof mobileUsageService !== "undefined"
                ? mobileUsageService : null

        function onDataChanged() {
            root.refreshReportNotification()
        }
        function onStatusChanged() {
            root.refreshReportNotification()
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.refreshReportNotification()
    }

    Rectangle {
        id: defaultCanvas
        anchors.fill: parent
        visible: !root.wallpaperActive
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: mobileTheme.defaultCanvasTop
            }
            GradientStop {
                position: 0.46
                color: mobileTheme.defaultCanvasMiddle
            }
            GradientStop {
                position: 1.0
                color: mobileTheme.defaultCanvasBottom
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height * 0.42
            opacity: mobileTheme.isDark ? 0.18 : 0.24
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: mobileTheme.withAlpha(
                               mobileTheme.accentBright, 0.22)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: root.wallpaperActive && status !== Image.Error
    }

    Rectangle {
        anchors.fill: parent
        color: root.wallpaperActive
               ? (root.currentTab === "home"
                  ? mobileTheme.wallpaperVeil
                  : mobileTheme.wallpaperPageVeil)
               : "transparent"

        Behavior on color {
            ColorAnimation { duration: mobileTheme.fastDuration }
        }
    }

    Item {
        id: pageHost
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.topReserve + root.safeTopInset
        anchors.bottom: tabBar.top

        MobileHomePage {
            anchors.fill: parent
            languageMode: root.languageMode
            visible: root.currentTab === "home"
            enabled: visible
            theme: mobileTheme
            wallpaperActive: root.wallpaperActive
            wallpaperSource: root.wallpaperSource
            anonymousShare: settingsPage.anonymousShare
            onWallpaperRequested: settingsPage.openWallpaperDialog()
        }

        MobileStatsPage {
            anchors.fill: parent
            languageMode: root.languageMode
            visible: root.currentTab === "stats"
            enabled: visible
            theme: mobileTheme
            wallpaperActive: root.wallpaperActive
            wallpaperSource: root.wallpaperSource
        }

        MobileHistoryPage {
            anchors.fill: parent
            languageMode: root.languageMode
            visible: root.currentTab === "history"
            enabled: visible
            theme: mobileTheme
            wallpaperActive: root.wallpaperActive
        }

        MobileSettingsPage {
            id: settingsPage
            anchors.fill: parent
            languageMode: root.languageMode
            visible: root.currentTab === "settings"
            enabled: visible
            theme: mobileTheme
            wallpaperActive: root.wallpaperActive
            onLanguageChanged: function(mode) { root.languageMode = mode }
            onDarkModeChanged: function(enabled) {
                root.setDarkMode(enabled)
            }
        }
    }

    Rectangle {
        id: tabBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 74 + root.safeBottomInset
        color: root.wallpaperActive
               ? mobileTheme.tabBarBg
               : mobileTheme.withAlpha(mobileTheme.surface, 0.78)
        border.width: 0

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.wallpaperActive
                   ? mobileTheme.timelineLine : mobileTheme.line
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 3
            anchors.bottomMargin: root.safeBottomInset

            Repeater {
                model: [
                    { "key": "home", "label": "Home", "icon": "home" },
                    { "key": "stats", "label": "Stats", "icon": "stats" },
                    { "key": "history", "label": "Memory Lake", "icon": "history" },
                    { "key": "settings", "label": "Me", "icon": "settings" }
                ]

                MobileTabButton {

                    languageMode: root.languageMode
                    required property var modelData
                    width: tabBar.width / 4
                    theme: mobileTheme
                    label: modelData.label
                    iconName: modelData.icon
                    active: root.currentTab === modelData.key
                    wallpaperActive: root.wallpaperActive
                    badgeVisible: modelData.key === "history"
                                  && root.reportUnread
                    onClicked: {
                        root.currentTab = modelData.key
                        if (modelData.key === "history")
                            root.markReportsSeen()
                    }
                }
            }
        }
    }

    MobileLaunchOverlay {

        languageMode: root.languageMode
        id: launchOverlay
        anchors.fill: parent
        theme: mobileTheme
        reducedMotion: mobileTheme.reducedMotion
        visible: root.launchOverlayVisible
        onFinished: root.launchOverlayVisible = false
    }

    Component.onCompleted: {
        refreshWallpaper()
        loadThemePreference()
        launchOverlay.begin()
        refreshReportNotification()
        ensureUsageAccessOnboarding()
    }
}
