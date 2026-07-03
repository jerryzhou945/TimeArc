import QtQuick
import "components"
import "pages"

Rectangle {
    id: root

    color: mobileTheme.bg

    property string currentTab: "home"
    property int topReserve: 0

    function ensureUsageAccessOnboarding() {
        if (typeof mobileUsageService === "undefined" || !mobileUsageService)
            return

        var granted = mobileUsageService.refreshUsageAccessState()
        if (granted) {
            mobileUsageService.requestImmediateSync()
            return
        }

        root.currentTab = "settings"
        if (typeof settingsRepository === "undefined" || !settingsRepository)
            return

        var prompted = settingsRepository.getValue("android_usage_access_prompted", "")
        if (prompted !== "1") {
            settingsRepository.setValue("android_usage_access_prompted", "1")
            mobileUsageService.openUsageAccessSettings()
        }
    }

    MobileTheme {
        id: mobileTheme
    }

    Loader {
        id: pageLoader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.topReserve
        anchors.bottom: tabBar.top
        sourceComponent: {
            if (root.currentTab === "stats")
                return statsPage
            if (root.currentTab === "history")
                return historyPage
            if (root.currentTab === "settings")
                return settingsPage
            return homePage
        }
    }

    Component.onCompleted: {
        root.ensureUsageAccessOnboarding()
    }

    Rectangle {
        id: tabBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 73
        color: mobileTheme.tabBarBg
        border.color: mobileTheme.tabBarBorder
        border.width: 1

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 52

            MobileTabButton {
                width: parent.width / 4
                theme: mobileTheme
                label: "首页"
                iconName: "home"
                active: root.currentTab === "home"
                onClicked: root.currentTab = "home"
            }

            MobileTabButton {
                width: parent.width / 4
                theme: mobileTheme
                label: "统计"
                iconName: "stats"
                active: root.currentTab === "stats"
                onClicked: root.currentTab = "stats"
            }

            MobileTabButton {
                width: parent.width / 4
                theme: mobileTheme
                label: "记忆湖"
                iconName: "history"
                active: root.currentTab === "history"
                onClicked: root.currentTab = "history"
            }

            MobileTabButton {
                width: parent.width / 4
                theme: mobileTheme
                label: "我的"
                iconName: "settings"
                active: root.currentTab === "settings"
                onClicked: root.currentTab = "settings"
            }
        }
    }

    Component {
        id: homePage
        MobileHomePage {
            theme: mobileTheme
        }
    }

    Component {
        id: statsPage
        MobileStatsPage {
            theme: mobileTheme
        }
    }

    Component {
        id: historyPage
        MobileHistoryPage {
            theme: mobileTheme
        }
    }

    Component {
        id: settingsPage
        MobileSettingsPage {
            theme: mobileTheme
            onDarkModeChanged: function(enabled) {
                mobileTheme.isDark = enabled
            }
        }
    }
}
