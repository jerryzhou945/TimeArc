import QtQuick
import "../components"

Item {
    id: root

    required property var theme
    property bool wallpaperActive: false
    property url wallpaperSource: ""
    readonly property int dateRailWidth: 52
    property var rangeKeys: ["week", "month", "year", "all"]
    property var rangeMeta: ({
        "week": {
            "label": "本周",
            "marker": "周",
            "date": "MON",
            "note": "从周一到今天"
        },
        "month": {
            "label": "本月",
            "marker": "月",
            "date": "01",
            "note": "从本月一日开始"
        },
        "year": {
            "label": "今年",
            "marker": "年",
            "date": "26",
            "note": "从一月一日开始"
        },
        "all": {
            "label": "总计",
            "marker": "全",
            "date": "∞",
            "note": "从第一条记录开始"
        }
    })
    property var dashboards: ({})
    property string selectedRange: "week"
    property bool detailOpen: false

    function emptyDashboard(key) {
        return {
            "rangeKey": key,
            "rangeLabel": rangeMeta[key].label,
            "rangeText": "",
            "totalText": "0s",
            "activeDays": 0,
            "topApps": [],
            "empty": true
        }
    }

    function previewApp(name, initial, duration, share, relative, iconPath) {
        return {
            "displayName": name,
            "initial": initial,
            "durationText": duration,
            "sharePct": share,
            "relativePct": relative,
            "appIconPath": iconPath
        }
    }

    function previewDashboards() {
        var edge = previewApp(
                    "Microsoft Edge", "E", "8h 24m", 31, 100,
                    "image://appicon/C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
        var code = previewApp(
                    "Visual Studio Code", "VS", "6h 48m", 25, 81,
                    "image://appicon/C:/Users/Lenovo/AppData/Local/Programs/Microsoft VS Code/Code.exe")
        var wechat = previewApp(
                    "微信", "微", "4h 12m", 16, 50,
                    "image://appicon/C:/Program Files/Tencent/WeChat/WeChat.exe")
        var music = previewApp(
                    "网易云音乐", "音", "3h 36m", 13, 43,
                    "image://appicon/C:/Program Files (x86)/NetEase/CloudMusic/cloudmusic.exe")
        var bilibili = previewApp(
                    "哔哩哔哩", "哔", "2h 18m", 9, 27,
                    "image://appicon/C:/Program Files/Google/Chrome/Application/chrome.exe")
        return {
            "week": {
                "rangeKey": "week",
                "rangeLabel": "本周",
                "rangeText": "07.14 — 07.20",
                "totalText": "27h 06m",
                "activeDays": 7,
                "topApps": [edge, code, wechat, music, bilibili],
                "empty": false
            },
            "month": {
                "rangeKey": "month",
                "rangeLabel": "本月",
                "rangeText": "07.01 — 07.20",
                "totalText": "96h 42m",
                "activeDays": 18,
                "topApps": [
                    previewApp("Visual Studio Code", "VS", "24h 42m", 26, 100,
                               code.appIconPath),
                    previewApp("Microsoft Edge", "E", "21h 18m", 22, 86,
                               edge.appIconPath),
                    previewApp("微信", "微", "14h 05m", 15, 57,
                               wechat.appIconPath),
                    previewApp("网易云音乐", "音", "9h 48m", 10, 40,
                               music.appIconPath)
                ],
                "empty": false
            },
            "year": {
                "rangeKey": "year",
                "rangeLabel": "今年",
                "rangeText": "2026.01.01 — 今天",
                "totalText": "568h",
                "activeDays": 142,
                "topApps": [code, edge, wechat, music],
                "empty": false
            },
            "all": {
                "rangeKey": "all",
                "rangeLabel": "总计",
                "rangeText": "2025.03.13 — 今天",
                "totalText": "812h",
                "activeDays": 168,
                "topApps": [code, edge, wechat, music, bilibili],
                "empty": false
            }
        }
    }

    function hasService() {
        return typeof mobileUsageService !== "undefined" && mobileUsageService
    }

    function isPreviewMode() {
        return Qt.application.arguments.indexOf("--mobile-preview") >= 0
    }

    function loadOverview() {
        if (root.isPreviewMode()) {
            dashboards = previewDashboards()
            return
        }
        var next = {}
        for (var i = 0; i < rangeKeys.length; ++i) {
            var key = rangeKeys[i]
            next[key] = mobileUsageService.getDashboardForRange(key)
        }
        dashboards = next
    }

    function dashboardFor(key) {
        return dashboards[key] || emptyDashboard(key)
    }

    function openRange(key) {
        selectedRange = key
        detailOpen = true
        flick.contentY = 0
    }

    function closeRange() {
        detailOpen = false
        flick.contentY = 0
    }

    Component.onCompleted: loadOverview()

    Connections {
        target: root.hasService() ? mobileUsageService : null
        function onDataChanged() { root.loadOverview() }
        function onStatusChanged() { root.loadOverview() }
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
            contentHeight: content.implicitHeight + 28

            Column {
                id: content
                width: flick.width - 32
                x: 16
                spacing: 12

                Row {
                    width: parent.width
                    height: 58
                    spacing: 8

                    Rectangle {
                        visible: root.detailOpen
                        width: 44
                        height: 44
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 22
                        color: root.wallpaperActive
                               ? root.theme.contentWash
                               : root.theme.surfaceRaised

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: root.wallpaperActive
                                   ? root.theme.wallpaperInk
                                   : root.theme.textPrimary
                            font.pixelSize: 30
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.closeRange()
                        }
                    }

                    Column {
                        width: parent.width - (root.detailOpen ? 52 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: root.detailOpen
                                  ? root.rangeMeta[root.selectedRange].label
                                  : "时间统计"
                            color: root.wallpaperActive
                                   ? root.theme.wallpaperInk
                                   : root.theme.textPrimary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            horizontalAlignment: root.detailOpen
                                                 ? Text.AlignHCenter
                                                 : Text.AlignLeft
                        }

                        Text {
                            width: parent.width
                            text: root.detailOpen
                                  ? root.dashboardFor(
                                        root.selectedRange).rangeText
                                  : "每一段时长，都有来处"
                            color: root.wallpaperActive
                                   ? root.theme.wallpaperMuted
                                   : root.theme.textSecondary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                            horizontalAlignment: root.detailOpen
                                                 ? Text.AlignHCenter
                                                 : Text.AlignLeft
                        }
                    }
                }

                Column {
                    visible: !root.detailOpen
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: root.rangeKeys

                        Item {
                            id: rangeBlock
                            required property string modelData
                            width: parent.width
                            height: 126
                            readonly property var dashboard:
                                root.dashboardFor(modelData)
                            readonly property var leadApp:
                                (dashboard.topApps || []).length > 0
                                ? dashboard.topApps[0] : ({})

                            Row {
                                anchors.fill: parent
                                anchors.topMargin: 14
                                anchors.bottomMargin: 14
                                spacing: 14

                                Column {
                                    width: root.dateRailWidth
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: root.rangeMeta[
                                                  rangeBlock.modelData].marker
                                        color: root.wallpaperActive
                                               ? root.theme.wallpaperInk
                                               : root.theme.textPrimary
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: 22
                                        font.weight: Font.Bold
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.rangeMeta[
                                                  rangeBlock.modelData].date
                                        color: root.wallpaperActive
                                               ? root.theme.wallpaperMuted
                                               : root.theme.textMuted
                                        font.family: root.theme.numberFontFamily
                                        font.pixelSize: 10
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                Column {
                                    width: parent.width - root.dateRailWidth - 14
                                    spacing: 6

                                    Row {
                                        width: parent.width
                                        height: 24

                                        Text {
                                            width: parent.width
                                                   - rangeDuration.width - 10
                                            text: root.rangeMeta[
                                                      rangeBlock.modelData].label
                                                  + "，时间停在这些应用里"
                                            color: root.wallpaperActive
                                                   ? root.theme.wallpaperInk
                                                   : root.theme.textPrimary
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: 16
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            id: rangeDuration
                                            text: rangeBlock.dashboard.totalText
                                                  || "0s"
                                            color: root.wallpaperActive
                                                   ? root.theme.wallpaperInk
                                                   : root.theme.textPrimary
                                            font.family: root.theme.numberFontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: rangeBlock.dashboard.empty
                                              ? "还没有记录，完成同步后再回来看看。"
                                              : (root.rangeMeta[
                                                     rangeBlock.modelData].note
                                                 + "，共记录 "
                                                 + rangeBlock.dashboard.activeDays
                                                 + " 天。")
                                        color: root.wallpaperActive
                                               ? root.theme.wallpaperMuted
                                               : root.theme.textSecondary
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        width: parent.width
                                        height: 40
                                        spacing: 8

                                        MobileAppIcon {
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            theme: root.theme
                                            app: rangeBlock.leadApp
                                            iconSize: 38
                                            cornerRadius: 10
                                        }

                                        Text {
                                            width: parent.width - 76
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            text: rangeBlock.dashboard.empty
                                                  ? "暂无应用"
                                                  : ((rangeBlock.leadApp.displayName
                                                      || "未知应用")
                                                     + " 留下的时间最多")
                                            color: root.wallpaperActive
                                                   ? root.theme.wallpaperMuted
                                                   : root.theme.textMuted
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: 30
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            text: "›"
                                            color: root.wallpaperActive
                                                   ? root.theme.wallpaperInk
                                                   : root.theme.textPrimary
                                            font.pixelSize: 25
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: root.dateRailWidth + 14
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: root.wallpaperActive
                                       ? root.theme.timelineLine
                                       : root.theme.line
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.openRange(rangeBlock.modelData)
                            }
                        }
                    }
                }

                Column {
                    visible: root.detailOpen
                    width: parent.width
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 98

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                width: parent.width
                                text: root.dashboardFor(
                                          root.selectedRange).totalText || "0s"
                                color: root.wallpaperActive
                                       ? root.theme.wallpaperInk
                                       : root.theme.textPrimary
                                font.family: root.theme.numberFontFamily
                                font.pixelSize: 34
                                font.weight: Font.Bold
                            }

                            Text {
                                width: parent.width
                                text: "记录 "
                                      + (root.dashboardFor(
                                             root.selectedRange).activeDays || 0)
                                      + " 天 · "
                                      + ((root.dashboardFor(
                                              root.selectedRange).topApps || []).length)
                                      + " 个应用"
                                color: root.wallpaperActive
                                       ? root.theme.wallpaperMuted
                                       : root.theme.textSecondary
                                font.family: root.theme.fontFamily
                                font.pixelSize: 12
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: root.wallpaperActive
                                   ? root.theme.timelineLine : root.theme.line
                        }
                    }

                    Text {
                        width: parent.width
                        text: "应用使用排行"
                        color: root.wallpaperActive
                               ? root.theme.wallpaperInk
                               : root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        topPadding: 6
                    }

                    Rectangle {
                        width: parent.width
                        height: 44
                        radius: 14
                        color: root.wallpaperActive
                               ? root.theme.contentWash : root.theme.accentSoft
                        border.width: 1
                        border.color: root.wallpaperActive
                                      ? root.theme.timelineLine
                                      : root.theme.accentBorder

                        Text {
                            anchors.centerIn: parent
                            text: "分享这份排行"
                            color: root.wallpaperActive
                                   ? root.theme.wallpaperInk
                                   : root.theme.accentBright
                            font.family: root.theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: rankingShare.openForRanking(
                                           root.dashboardFor(root.selectedRange))
                        }
                    }

                    Text {
                        width: parent.width
                        visible: (root.dashboardFor(
                                      root.selectedRange).topApps || []).length === 0
                        text: "这个时间范围还没有记录。开启使用情况访问并同步后，再回来看看。"
                        color: root.wallpaperActive
                               ? root.theme.wallpaperMuted
                               : root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 14
                        lineHeight: 1.45
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: root.dashboardFor(
                                   root.selectedRange).topApps || []

                        MobileUsageRankRow {
                            required property var modelData
                            required property int index
                            width: parent.width
                            theme: root.theme
                            app: modelData
                            rank: index + 1
                            wallpaperActive: root.wallpaperActive
                        }
                    }
                }
            }
        }
    }

    MobileRankingShareOverlay {
        id: rankingShare
        theme: root.theme
        wallpaperSource: root.wallpaperSource
    }
}
