import QtQuick
import "../components"

Item {
    id: root

    required property var theme
    property bool wallpaperActive: false
    property bool anonymousShare: false
    property var totalDashboard: emptyDashboard()
    property int selectedCardIndex: 0
    property var flippedApps: ({})
    readonly property var apps: {
        var values = totalDashboard.topApps || []
        return values.length > 0 ? values : [placeholderApp()]
    }

    function emptyDashboard() {
        return {
            "totalSec": 0,
            "totalText": "0s",
            "activeDays": 0,
            "appCount": 0,
            "firstDateLocal": "",
            "rangeText": "",
            "topApps": [],
            "empty": true
        }
    }

    function placeholderApp() {
        return {
            "displayName": "等待第一段记录",
            "durationText": "0s",
            "sharePct": 0,
            "relativePct": 0,
            "recordedDays": 0,
            "spanDays": 0,
            "initial": "时",
            "storyText": "开启使用情况访问并同步后，应用时间卡会出现在这里。",
            "conversionText": "所有分享文案都会从真实时长生成。",
            "empty": true
        }
    }

    function hasService() {
        return typeof mobileUsageService !== "undefined" && mobileUsageService
    }

    function reload() {
        totalDashboard = hasService()
                ? mobileUsageService.getDashboardForRange("all")
                : emptyDashboard()
        selectedCardIndex = Math.min(
                    selectedCardIndex,
                    Math.max(0, (totalDashboard.topApps || []).length - 1))
    }

    function requestSync() {
        if (hasService())
            mobileUsageService.requestImmediateSync()
    }

    Component.onCompleted: reload()

    Connections {
        target: root.hasService() ? mobileUsageService : null
        function onDataChanged() { root.reload() }
        function onStatusChanged() { root.reload() }
    }

    Column {
        anchors.fill: parent

        MobileStatusBar {
            width: parent.width
            theme: root.theme
        }

        Item {
            width: parent.width
            height: 50

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: "TimeArc"
                color: root.theme.textPrimary
                font.family: root.theme.fontFamily
                font.pixelSize: 19
                font.weight: Font.Bold
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 22
                color: root.theme.panelColor(root.wallpaperActive, true)

                Text {
                    anchors.centerIn: parent
                    text: "↻"
                    color: root.theme.textPrimary
                    font.pixelSize: 20
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.requestSync()
                }
            }
        }

        MobileGlassPanel {
            id: archiveStrip
            width: parent.width - 32
            height: 78
            anchors.horizontalCenter: parent.horizontalCenter
            theme: root.theme
            wallpaperActive: root.wallpaperActive
            strong: true

            Row {
                anchors.fill: parent
                anchors.margins: 12

                ArchiveFact {
                    width: parent.width / 3
                    value: root.totalDashboard.firstDateLocal || "尚未开始"
                    label: "开始记录"
                }

                ArchiveFact {
                    width: parent.width / 3
                    value: root.totalDashboard.totalText || "0s"
                    label: "累计时间"
                }

                ArchiveFact {
                    width: parent.width / 3
                    value: (root.totalDashboard.activeDays || 0) + " 天"
                    label: "记录日数"
                }
            }
        }

        Item { width: 1; height: 14 }

        ListView {
            id: cards
            width: parent.width
            height: Math.max(390, parent.height - y - 52)
            model: root.apps
            orientation: ListView.Horizontal
            clip: true
            spacing: 40
            leftMargin: 20
            rightMargin: 20
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 20
            preferredHighlightEnd: width - 20
            currentIndex: root.selectedCardIndex
            interactive: count > 1

            onCurrentIndexChanged: root.selectedCardIndex = currentIndex

            delegate: Item {
                required property var modelData
                required property int index
                width: cards.width - 40
                height: cards.height

                MobileFlipCard {
                    id: memoryCard
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 46
                    theme: root.theme
                    app: modelData
                    wallpaperActive: root.wallpaperActive
                    selected: index === cards.currentIndex
                    flipped: !!root.flippedApps[
                                 modelData.appIdentifier
                                 || modelData.packageName
                                 || modelData.displayName]
                    onFlippedChanged: {
                        var next = Object.assign({}, root.flippedApps)
                        next[modelData.appIdentifier
                             || modelData.packageName
                             || modelData.displayName] = flipped
                        root.flippedApps = next
                    }
                    onShareRequested: function(appModel) {
                        shareOverlay.openFor(
                                    appModel,
                                    root.totalDashboard.rangeText || "全部记录")
                    }
                }
            }

            footer: Item { width: 20; height: 1 }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        height: 26
        spacing: 7

        Repeater {
            model: Math.min(9, root.apps.length)

            Rectangle {
                width: index === root.selectedCardIndex ? 18 : 6
                height: 6
                radius: 3
                color: index === root.selectedCardIndex
                       ? root.theme.accent : root.theme.textMuted
                opacity: index === root.selectedCardIndex ? 1 : 0.55
            }
        }
    }

    MobileShareOverlay {
        id: shareOverlay
        theme: root.theme
        anonymous: root.anonymousShare
    }

    component ArchiveFact: Item {
        property string value: ""
        property string label: ""

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 5

            Text {
                width: parent.width
                text: value
                color: root.theme.textPrimary
                font.family: root.theme.numberFontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: label
                color: root.theme.textMuted
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
