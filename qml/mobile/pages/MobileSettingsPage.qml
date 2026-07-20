import QtQuick
import QtQuick.Dialogs
import "../components"

Item {
    id: root

    required property var theme
    property bool wallpaperActive: false
    property bool autoSync: true
    property bool anonymousShare: false
    property bool reducedMotion: false

    signal darkModeChanged(bool enabled)

    function hasUsageService() {
        return typeof mobileUsageService !== "undefined" && mobileUsageService
    }

    function hasUiService() {
        return typeof mobileUiService !== "undefined" && mobileUiService
    }

    function hasSettings() {
        return typeof settingsRepository !== "undefined" && settingsRepository
    }

    function loadPreferences() {
        if (!hasSettings())
            return
        autoSync = settingsRepository.getBool("mobile_auto_sync", true)
        anonymousShare = settingsRepository.getBool(
                    "mobile_anonymous_share", false)
        reducedMotion = settingsRepository.getBool(
                    "mobile_reduced_motion", false)
        theme.reducedMotion = reducedMotion
    }

    function usageStatusText() {
        if (!hasUsageService())
            return "桌面预览模式"
        return mobileUsageService.syncStatusText
    }

    function usageAccessText() {
        if (!hasUsageService())
            return "仅 Android 可授权"
        return mobileUsageService.usageAccessGranted ? "已开启" : "待开启"
    }

    function wallpaperStateText() {
        if (!hasUiService())
            return "预览不可用"
        return wallpaperActive ? "正在使用自定义壁纸" : "跟随纯色主题"
    }

    function checkedFor(key) {
        if (key === "lightMode")
            return !theme.isDark
        if (key === "autoSync")
            return autoSync
        if (key === "anonymousShare")
            return anonymousShare
        if (key === "reducedMotion")
            return reducedMotion
        return false
    }

    function settingsKey(key) {
        if (key === "autoSync")
            return "mobile_auto_sync"
        if (key === "anonymousShare")
            return "mobile_anonymous_share"
        if (key === "reducedMotion")
            return "mobile_reduced_motion"
        return "mobile_" + key
    }

    function setChecked(key, value) {
        if (key === "lightMode") {
            darkModeChanged(!value)
            return
        }
        if (key === "autoSync")
            autoSync = value
        else if (key === "anonymousShare")
            anonymousShare = value
        else if (key === "reducedMotion") {
            reducedMotion = value
            theme.reducedMotion = value
        }
        if (hasSettings())
            settingsRepository.setBool(settingsKey(key), value)
    }

    function runAction(action) {
        if (action === "usageAccess" && hasUsageService()) {
            mobileUsageService.openUsageAccessSettings()
        } else if (action === "syncNow" && hasUsageService()) {
            mobileUsageService.requestImmediateSync()
        } else if (action === "wallpaper") {
            wallpaperDialog.open()
        } else if (action === "clearWallpaper" && hasUiService()) {
            mobileUiService.clearWallpaper()
        }
    }

    Component.onCompleted: loadPreferences()

    FileDialog {
        id: wallpaperDialog
        title: "选择一张壁纸"
        nameFilters: ["图片文件 (*.png *.jpg *.jpeg *.webp)"]

        onAccepted: {
            if (root.hasUiService())
                mobileUiService.importWallpaper(selectedFile)
        }
    }

    Column {
        anchors.fill: parent

        MobileStatusBar {
            width: parent.width
            theme: root.theme
        }

        Flickable {
            id: flick
            width: parent.width
            height: parent.height - y
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: content.implicitHeight + 34

            Column {
                id: content
                width: flick.width - 32
                x: 16
                spacing: 18

                Item {
                    width: parent.width
                    height: 58

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: "我的"
                            color: root.theme.textPrimary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 27
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "让记录方式更像你自己"
                            color: root.theme.textSecondary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }

                SettingsGroup {
                    width: parent.width
                    title: "记录与同步"
                    rows: [
                        {
                            "icon": "shield",
                            "label": "使用记录权限",
                            "desc": "只读取应用级时长，不读取聊天与浏览内容",
                            "value": root.usageAccessText(),
                            "action": "usageAccess"
                        },
                        {
                            "icon": "sync",
                            "label": "立即同步",
                            "desc": root.usageStatusText(),
                            "value": "同步",
                            "action": "syncNow"
                        },
                        {
                            "icon": "clock",
                            "label": "打开时自动同步",
                            "desc": "每次回到 TimeArc 时补齐最近记录",
                            "toggleKey": "autoSync"
                        }
                    ]
                }

                SettingsGroup {
                    width: parent.width
                    title: "外观"
                    rows: [
                        {
                            "icon": "image",
                            "label": "自定义壁纸",
                            "desc": root.wallpaperStateText(),
                            "value": root.wallpaperActive ? "更换" : "选择",
                            "action": "wallpaper"
                        },
                        {
                            "icon": "clear",
                            "label": "恢复纯色背景",
                            "desc": "保留数据，只移除当前壁纸",
                            "value": root.wallpaperActive ? "恢复" : "未使用",
                            "action": root.wallpaperActive
                                      ? "clearWallpaper" : ""
                        },
                        {
                            "icon": "sun",
                            "label": "浅色模式",
                            "desc": "壁纸与透明模块会同步调整可读性",
                            "toggleKey": "lightMode"
                        },
                        {
                            "icon": "motion",
                            "label": "减少动态效果",
                            "desc": "关闭翻转和页面过渡动画",
                            "toggleKey": "reducedMotion"
                        }
                    ]
                }

                SettingsGroup {
                    width: parent.width
                    title: "分享与隐私"
                    rows: [
                        {
                            "icon": "mask",
                            "label": "默认匿名分享",
                            "desc": "分享图不显示昵称，只保留应用与时间故事",
                            "toggleKey": "anonymousShare"
                        },
                        {
                            "icon": "lock",
                            "label": "数据留在本机",
                            "desc": "壁纸、时长与分享图默认保存在设备内",
                            "value": "本地优先"
                        }
                    ]
                }

                Text {
                    width: parent.width
                    topPadding: 2
                    text: root.hasUiService() && mobileUiService.lastError.length > 0
                          ? mobileUiService.lastError
                          : "TimeArc · 认真保存每一段时间"
                    color: root.hasUiService()
                           && mobileUiService.lastError.length > 0
                           ? root.theme.error : root.theme.textMuted
                    font.family: root.theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component SettingsGroup: Column {
        id: group

        property string title: ""
        property var rows: []

        spacing: 9

        Text {
            width: parent.width
            leftPadding: 2
            text: group.title
            color: root.theme.textPrimary
            font.family: root.theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        MobileGlassPanel {
            width: parent.width
            height: rowsColumn.implicitHeight
            theme: root.theme
            wallpaperActive: root.wallpaperActive
            strong: false

            Column {
                id: rowsColumn
                width: parent.width

                Repeater {
                    model: group.rows

                    SettingRow {
                        required property var modelData
                        required property int index

                        width: rowsColumn.width
                        iconName: modelData.icon || ""
                        label: modelData.label || ""
                        desc: modelData.desc || ""
                        value: modelData.value || ""
                        toggleKey: modelData.toggleKey || ""
                        action: modelData.action || ""
                        dividerVisible: index < group.rows.length - 1
                    }
                }
            }
        }
    }

    component SettingRow: Item {
        id: settingRow

        property string iconName: ""
        property string label: ""
        property string desc: ""
        property string value: ""
        property string toggleKey: ""
        property string action: ""
        property bool dividerVisible: false

        height: 74

        Rectangle {
            width: 36
            height: 36
            radius: 11
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme.withAlpha(root.theme.accent, 0.18)

            Text {
                anchors.centerIn: parent
                text: {
                    if (settingRow.iconName === "shield") return "✓"
                    if (settingRow.iconName === "sync") return "↻"
                    if (settingRow.iconName === "clock") return "◷"
                    if (settingRow.iconName === "image") return "▧"
                    if (settingRow.iconName === "clear") return "−"
                    if (settingRow.iconName === "sun") return "☼"
                    if (settingRow.iconName === "motion") return "≋"
                    if (settingRow.iconName === "mask") return "◉"
                    return "⌂"
                }
                color: root.theme.accentBright
                font.family: root.theme.numberFontFamily
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 62
            anchors.right: control.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: settingRow.label
                color: root.theme.textPrimary
                font.family: root.theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: settingRow.desc
                color: root.theme.textMuted
                font.family: root.theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Item {
            id: control
            width: settingRow.toggleKey.length > 0 ? 48 : 64
            height: parent.height
            anchors.right: parent.right
            anchors.rightMargin: 12

            MobileSwitch {
                anchors.centerIn: parent
                visible: settingRow.toggleKey.length > 0
                theme: root.theme
                checked: root.checkedFor(settingRow.toggleKey)
                onToggled: function(value) {
                    root.setChecked(settingRow.toggleKey, value)
                }
            }

            Text {
                anchors.fill: parent
                visible: settingRow.toggleKey.length === 0
                text: settingRow.value
                color: settingRow.action.length > 0
                       ? root.theme.accentBright : root.theme.textSecondary
                font.family: root.theme.fontFamily
                font.pixelSize: 12
                font.weight: settingRow.action.length > 0
                             ? Font.DemiBold : Font.Normal
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: settingRow.dividerVisible
            anchors.left: parent.left
            anchors.leftMargin: 62
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.theme.withAlpha(root.theme.line, 0.72)
        }

        MouseArea {
            anchors.fill: parent
            enabled: settingRow.action.length > 0
            onClicked: root.runAction(settingRow.action)
        }
    }
}
