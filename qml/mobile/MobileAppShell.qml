import QtQuick
import "components"
import "pages"
import "../desktop/components/I18n.js" as I18n

Rectangle {
    id: root

    color: mobileTheme.bg

    property string currentTab: "home"
    property string languageMode: settingsRepository ? settingsRepository.getValue("language_mode", "zh") : "zh"
    // 无边框窗口顶部预留高度（移动预览默认保留原生边框 ⇒ 0；防御性接收，便于未来移动端 chrome）。
    property int topReserve: 0

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
                label: I18n.t(root.languageMode, "首页")
                iconName: "home"
                active: root.currentTab === "home"
                onClicked: root.currentTab = "home"
            }

            MobileTabButton {
                width: parent.width / 4
                theme: mobileTheme
                label: I18n.t(root.languageMode, "统计")
                iconName: "stats"
                active: root.currentTab === "stats"
                onClicked: root.currentTab = "stats"
            }

            MobileTabButton {
                width: parent.width / 4
                theme: mobileTheme
                label: I18n.t(root.languageMode, "历史")
                iconName: "history"
                active: root.currentTab === "history"
                onClicked: root.currentTab = "history"
            }

            MobileTabButton {
                width: parent.width / 4
                theme: mobileTheme
                label: I18n.t(root.languageMode, "设置")
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
