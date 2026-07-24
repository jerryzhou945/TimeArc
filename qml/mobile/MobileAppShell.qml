import QtQuick
import "components"
import "pages"

Rectangle {
    id: root

    color: mobileTheme.bg

    property string currentTab: "home"
    property int topReserve: 0
    property url wallpaperSource: ""
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
    }

    function setDarkMode(enabled) {
        mobileTheme.isDark = enabled
        if (typeof settingsRepository !== "undefined" && settingsRepository)
            settingsRepository.setValue("mobile_theme_mode",
                                        enabled ? "dark" : "light")
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
        anchors.topMargin: root.topReserve
        anchors.bottom: tabBar.top

        MobileHomePage {
            anchors.fill: parent
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
            visible: root.currentTab === "stats"
            enabled: visible
            theme: mobileTheme
            wallpaperActive: root.wallpaperActive
            wallpaperSource: root.wallpaperSource
        }

        MobileHistoryPage {
            anchors.fill: parent
            visible: root.currentTab === "history"
            enabled: visible
            theme: mobileTheme
            wallpaperActive: root.wallpaperActive
        }

        MobileSettingsPage {
            id: settingsPage
            anchors.fill: parent
            visible: root.currentTab === "settings"
            enabled: visible
            theme: mobileTheme
            wallpaperActive: root.wallpaperActive
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
        height: 74
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
            anchors.fill: parent
            anchors.topMargin: 3

            Repeater {
                model: [
                    { "key": "home", "label": "首页", "icon": "home" },
                    { "key": "stats", "label": "统计", "icon": "stats" },
                    { "key": "history", "label": "记忆湖", "icon": "history" },
                    { "key": "settings", "label": "我的", "icon": "settings" }
                ]

                MobileTabButton {
                    required property var modelData
                    width: tabBar.width / 4
                    theme: mobileTheme
                    label: modelData.label
                    iconName: modelData.icon
                    active: root.currentTab === modelData.key
                    wallpaperActive: root.wallpaperActive
                    onClicked: root.currentTab = modelData.key
                }
            }
        }
    }

    Component.onCompleted: {
        refreshWallpaper()
        loadThemePreference()
        ensureUsageAccessOnboarding()
    }
}
