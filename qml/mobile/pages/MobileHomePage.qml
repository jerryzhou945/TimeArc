import QtQuick
import QtQuick.Effects
import "../components"
import "../../desktop/components/AppVisual.js" as AppVisual

Rectangle {
    id: root

    required property var theme

    color: theme.bg

    property var dashboard: emptyDashboard()
    property var totalDashboard: emptyDashboard()
    readonly property var todayApps: dashboard.topApps || []
    readonly property var totalApps: totalDashboard.topApps || []
    readonly property var displayApps: todayApps.length > 0 ? todayApps : (totalApps.length > 0 ? totalApps : [placeholderApp()])
    readonly property bool usingTotalFallback: todayApps.length === 0 && totalApps.length > 0
    readonly property int totalSeconds: totalDashboard.totalSec || dashboard.totalSec || 0
    readonly property int activeDays: totalDashboard.activeDays || dashboard.activeDays || 0
    readonly property int totalHours: Math.floor(totalSeconds / 3600)
    readonly property string cardRangeLabel: todayApps.length > 0 ? "今日" : (totalApps.length > 0 ? "累计" : "待同步")

    function emptyDashboard() {
        return {
            "totalSec": 0,
            "totalText": "0s",
            "averageDailyText": "0s",
            "activeDays": 0,
            "appCount": 0,
            "topApps": [],
            "empty": true,
            "syncStatusText": "等待 Android 使用数据同步"
        }
    }

    function placeholderApp() {
        return {
            "displayName": "等待安卓数据",
            "packageName": "授权后回到 TimeArc 同步",
            "durationText": "0s",
            "foregroundSec": 0,
            "sharePct": 0,
            "initial": "T",
            "empty": true
        }
    }

    function hasMobileUsageService() {
        return typeof mobileUsageService !== "undefined" && mobileUsageService
    }

    function reloadDashboard() {
        if (!hasMobileUsageService()) {
            dashboard = emptyDashboard()
            totalDashboard = emptyDashboard()
            return
        }
        dashboard = mobileUsageService.getDashboardForRange("day")
        totalDashboard = mobileUsageService.getDashboardForRange("all")
    }

    function requestSync() {
        if (hasMobileUsageService())
            mobileUsageService.requestImmediateSync()
    }

    function openUsageAccess() {
        if (hasMobileUsageService())
            mobileUsageService.openUsageAccessSettings()
    }

    function iconSource(path) {
        var value = (path || "").toString().trim()
        if (value.length === 0)
            return ""
        if (value.indexOf("file://") === 0 || value.indexOf("qrc:/") === 0 || value.indexOf("image://") === 0)
            return value
        value = value.replace(/\\/g, "/")
        if (value.charAt(0) === "/")
            return "file://" + value
        return "file:///" + value
    }

    function rankText(index) {
        var n = index + 1
        return n < 10 ? "0" + n : "" + n
    }

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function appIdentity(app) {
        var value = app || ({})
        return value.appIdentifier || value.packageName || value.displayName || value.appIconPath || "android:timearc"
    }

    function appDisplayName(app) {
        var value = app || ({})
        return value.displayName || value.packageName || "未知应用"
    }

    function appPath(app) {
        var value = app || ({})
        return value.appIconPath || value.packageName || ""
    }

    function appBaseColor(app) {
        if ((app || ({})).empty === true)
            return theme.accent
        return AppVisual.appColor(appIdentity(app), appDisplayName(app), appPath(app))
    }

    function appAmbientColor(app) {
        return AppVisual.ambientTone(appBaseColor(app), theme.isDark)
    }

    function appCoverColor(app) {
        return AppVisual.coverTone(appBaseColor(app), theme.isDark)
    }

    Component.onCompleted: reloadDashboard()

    Connections {
        target: root.hasMobileUsageService() ? mobileUsageService : null

        function onDataChanged() {
            root.reloadDashboard()
        }

        function onStatusChanged() {
            root.reloadDashboard()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.theme.bg
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: content.implicitHeight + 22

        Column {
            id: content
            width: flick.width
            spacing: 0

            Item {
                width: parent.width
                height: Math.max(690, flick.height - 6)

                MobileStatusBar {
                    id: statusBar
                    width: parent.width
                    theme: root.theme
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: statusBar.bottom
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22
                    anchors.topMargin: 10
                    height: 38

                    Text {
                        width: 42
                        height: parent.height
                        text: "☰"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 28
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: parent.width - 84
                        height: parent.height
                        text: "TimeArc"
                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: 42
                        height: parent.height
                        text: "↻"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 23
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.requestSync()
                        }
                    }
                }

                Column {
                    id: profileStrip
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: statusBar.bottom
                    anchors.topMargin: 48
                    width: parent.width - 42
                    height: 138
                    spacing: 5

                    Rectangle {
                        width: 62
                        height: 62
                        radius: 31
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: root.theme.card
                        border.color: root.withAlpha(root.theme.textPrimary, root.theme.isDark ? 0.78 : 0.88)
                        border.width: 3

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: width / 2
                            color: root.theme.isDark ? "#DDEAF3" : "#FFFFFF"
                        }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            x: parent.width - width + 1
                            y: parent.height - height + 1
                            color: root.theme.card
                            border.color: root.theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "T"
                                color: root.theme.accentText
                                font.family: root.theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Arc"
                            color: root.theme.isDark ? "#102235" : "#174E72"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        width: parent.width
                        text: "TimeArc Mobile"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: "已使用 TimeArc " + root.activeDays + " 天 · 总共 " + root.totalHours + " 小时"
                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: badgeText.implicitWidth + 22
                        height: 22
                        radius: 11
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: root.withAlpha(root.theme.card, root.theme.isDark ? 0.58 : 0.78)
                        border.color: root.withAlpha(root.theme.accent, 0.30)
                        border.width: 1

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: "TimeArc 记录徽章"
                            color: root.theme.textSecondary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                Row {
                    id: metricRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: profileStrip.bottom
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    anchors.topMargin: 4
                    height: 44
                    spacing: 0

                    ProfileMetric {
                        width: parent.width / 3
                        value: root.activeDays + " 天"
                        label: "使用"
                    }

                    ProfileMetric {
                        width: parent.width / 3
                        value: root.totalHours + " 小时"
                        label: "累计"
                    }

                    ProfileMetric {
                        width: parent.width / 3
                        value: "" + (root.totalDashboard.appCount || root.dashboard.appCount || 0)
                        label: "应用"
                    }
                }

                ListView {
                    id: cardList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: metricRow.bottom
                    anchors.topMargin: 12
                    height: Math.min(420, parent.height - y - 66)
                    orientation: ListView.Horizontal
                    clip: false
                    boundsBehavior: Flickable.StopAtBounds
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: Math.round((width - cardWidth) / 2)
                    preferredHighlightEnd: preferredHighlightBegin + cardWidth
                    spacing: 16
                    model: root.displayApps
                    interactive: count > 1

                    readonly property int cardWidth: Math.min(318, Math.round(width * 0.80))
                    readonly property int sideInset: Math.max(24, Math.round((width - cardWidth) / 2))

                    header: Item { width: cardList.sideInset; height: 1 }
                    footer: Item { width: cardList.sideInset; height: 1 }

                    onMovementEnded: syncCurrentIndex()
                    onFlickEnded: syncCurrentIndex()
                    onCountChanged: currentIndex = Math.min(currentIndex, Math.max(0, count - 1))

                    function syncCurrentIndex() {
                        var step = cardWidth + spacing
                        var idx = Math.round(Math.max(0, contentX - sideInset) / step)
                        currentIndex = Math.max(0, Math.min(count - 1, idx))
                    }

                    delegate: AppUsageCard {
                        required property var modelData
                        required property int index

                        width: cardList.cardWidth
                        height: cardList.height
                        theme: root.theme
                        app: modelData
                        cardIndex: index
                        selected: index === cardList.currentIndex
                        iconUrl: root.iconSource(modelData.appIconPath)
                        rangeLabel: root.cardRangeLabel
                        onClicked: {
                            cardList.currentIndex = index
                            cardList.positionViewAtIndex(index, ListView.Center)
                        }
                        onOpenUsageAccess: root.openUsageAccess()
                        onRequestSync: root.requestSync()
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: cardList.bottom
                    anchors.topMargin: 10
                    height: 12
                    spacing: 6

                    Repeater {
                        model: Math.min(root.displayApps.length, 8)

                        Rectangle {
                            width: index === cardList.currentIndex ? 26 : 7
                            height: 7
                            radius: 4
                            color: index === cardList.currentIndex ? root.theme.accent : root.withAlpha(root.theme.textMuted, 0.45)

                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    text: root.usingTotalFallback ? "今日暂无记录，当前展示累计卡牌" : "下滑查看应用排行"
                    color: root.theme.textMuted
                    font.pixelSize: 12
                }
            }

            Column {
                width: parent.width - 40
                x: 20
                spacing: 14

                Row {
                    width: parent.width
                    height: 36

                    Text {
                        width: parent.width - 94
                        text: "使用排行"
                        color: root.theme.textPrimary
                        font.pixelSize: 25
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: 94
                        text: root.cardRangeLabel
                        color: root.theme.textSecondary
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    width: parent.width
                    visible: root.todayApps.length === 0 && root.totalApps.length === 0
                    text: "还没有安卓使用数据。开启 Usage Access 后，TimeArc 会在你打开 App 时读取系统使用时长并写入数据库。"
                    color: root.theme.textSecondary
                    wrapMode: Text.WordWrap
                    font.pixelSize: 14
                    lineHeight: 1.35
                }

                Repeater {
                    model: root.todayApps.length > 0 ? root.todayApps : root.totalApps

                    RankRow {
                        required property var modelData
                        required property int index

                        width: parent.width
                        app: modelData
                        rank: root.rankText(index)
                        theme: root.theme
                        iconUrl: root.iconSource(modelData.appIconPath)
                    }
                }
            }
        }
    }

    component ProfileMetric: Column {
        property string value: ""
        property string label: ""

        spacing: 4

        Text {
            width: parent.width
            text: value
            color: root.theme.textPrimary
            font.family: root.theme.numberFontFamily
            font.pixelSize: 18
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: label
            color: root.theme.textMuted
            font.family: root.theme.fontFamily
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
    }

    component AppUsageCard: Item {
        id: card

        required property var theme
        property var app: ({})
        property string iconUrl: ""
        property string rangeLabel: "今日"
        property int cardIndex: 0
        property bool selected: false
        property bool flipped: false
        readonly property int faceRadius: 28
        readonly property int faceMargin: selected ? 0 : 8

        signal clicked()
        signal openUsageAccess()
        signal requestSync()

        property real flipAngle: flipped ? 180 : 0

        function safeApp() {
            return app || ({})
        }

        function isEmptyApp() {
            return safeApp().empty === true
        }

        function appName() {
            var value = safeApp()
            return value.displayName || value.packageName || "未知应用"
        }

        function packageText() {
            var value = safeApp()
            return value.packageName || value.appIdentifier || "Android UsageStats"
        }

        function shareText() {
            var value = safeApp()
            return Math.max(0, Math.min(100, value.sharePct || 0)) + "%"
        }

        function coverColor() {
            return root.appCoverColor(safeApp())
        }

        function ambientColor() {
            return root.appAmbientColor(safeApp())
        }

        function edgeColor() {
            return root.withAlpha(coverColor(), card.theme.isDark ? 0.72 : 0.92)
        }

        scale: selected ? 1.0 : 0.92
        opacity: selected ? 1.0 : 0.58

        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on flipAngle { NumberAnimation { duration: 620; easing.type: Easing.InOutCubic } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: card.faceMargin + 4
            radius: card.faceRadius
            color: root.withAlpha(card.coverColor(), selected ? (card.theme.isDark ? 0.16 : 0.28) : 0.0)
            border.width: 0

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: card.faceRadius + 3
                color: "transparent"
                border.width: 0
                opacity: 0
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                card.clicked()
                card.flipped = !card.flipped
            }
        }

        Flipable {
            anchors.fill: parent
            anchors.margins: card.faceMargin

            transform: Rotation {
                origin.x: card.width / 2
                origin.y: card.height / 2
                axis.x: 0
                axis.y: 1
                axis.z: 0
                angle: card.flipAngle
            }

            front: Item {
                anchors.fill: parent

                Item {
                    id: frontFaceSource
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    layer.samples: 4
                    layer.smooth: true

                Rectangle {
                    anchors.fill: parent
                    radius: card.faceRadius
                    color: card.theme.card

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: Math.round(parent.height * 0.47)
                        color: card.coverColor()
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Math.round(parent.height * 0.12)
                        width: 104
                        height: 104
                        radius: 24
                        color: root.withAlpha(card.ambientColor(), card.theme.isDark ? 0.84 : 0.92)
                        border.color: root.withAlpha(card.theme.textPrimary, card.theme.isDark ? 0.14 : 0.20)
                        border.width: 1
                        clip: true

                        Image {
                            id: cardIcon
                            anchors.fill: parent
                            anchors.margins: 14
                            source: card.iconUrl
                            visible: card.iconUrl.length > 0 && status !== Image.Error
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !cardIcon.visible
                            text: card.safeApp().initial || "T"
                            color: card.theme.textPrimary
                            font.family: card.theme.fontFamily
                            font.pixelSize: 34
                            font.weight: Font.Bold
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 20
                        spacing: 9

                        Text {
                            width: parent.width
                            text: card.appName()
                            color: card.theme.textPrimary
                            font.family: card.theme.fontFamily
                            font.pixelSize: 25
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: card.isEmptyApp() ? "等待授权或同步" : "Android 应用 · " + card.rangeLabel
                            color: card.theme.textMuted
                            font.family: card.theme.fontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: timeLabel.implicitWidth + 24
                            height: 42
                            radius: 15
                            color: root.withAlpha(card.ambientColor(), card.theme.isDark ? 0.58 : 0.76)
                            border.color: root.withAlpha(card.edgeColor(), card.theme.isDark ? 0.58 : 0.72)
                            border.width: 1

                            Text {
                                id: timeLabel
                                anchors.centerIn: parent
                                text: card.safeApp().durationText || "0s"
                                color: card.theme.accentText
                                font.family: card.theme.numberFontFamily
                                font.pixelSize: 19
                                font.weight: Font.Bold
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 7
                            radius: 4
                            color: card.theme.rankTrack

                            Rectangle {
                                width: parent.width * Math.max(0.03, Math.min(1, (card.safeApp().sharePct || 0) / 100))
                                height: parent.height
                                radius: parent.radius
                                color: card.edgeColor()
                            }
                        }

                        Text {
                            width: parent.width
                            text: card.isEmptyApp() ? "点击翻面查看授权操作" : "点击翻面查看记录细节"
                            color: card.theme.textMuted
                            font.family: card.theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: card.faceRadius
                        color: "transparent"
                        border.color: card.selected ? card.edgeColor() : card.theme.borderSoft
                        border.width: card.selected ? 2 : 1
                    }
                }
                }

                Rectangle {
                    id: frontFaceMask
                    anchors.fill: parent
                    radius: card.faceRadius
                    color: "white"
                    antialiasing: true
                    visible: false
                    layer.enabled: true
                    layer.samples: 4
                    layer.smooth: true
                }

                MultiEffect {
                    anchors.fill: parent
                    source: frontFaceSource
                    maskEnabled: true
                    maskSource: frontFaceMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 0.24
                }
            }

            back: Item {
                anchors.fill: parent

                Item {
                    id: backFaceSource
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    layer.samples: 4
                    layer.smooth: true

                Rectangle {
                    anchors.fill: parent
                    radius: card.faceRadius
                    color: card.theme.card
                    border.color: card.theme.border
                    border.width: 0

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: card.ambientColor()
                        opacity: card.theme.isDark ? 0.20 : 0.68
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 14

                        Text {
                            width: parent.width
                            text: card.isEmptyApp() ? "需要使用情况访问权限" : card.appName()
                            color: card.theme.textPrimary
                            font.family: card.theme.fontFamily
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: card.isEmptyApp()
                                  ? "TimeArc 会读取 Android 系统已记录的应用前台使用时长，然后写入本地 SQLite。"
                                  : "来源 Android UsageStats，已按应用合并后进入 TimeArc 数据库。"
                            color: card.theme.textSecondary
                            font.family: card.theme.fontFamily
                            font.pixelSize: 13
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                        }

                        DetailLine { width: parent.width; label: "时长"; value: card.safeApp().durationText || "0s"; theme: card.theme }
                        DetailLine { width: parent.width; label: "占比"; value: card.shareText(); theme: card.theme }
                        DetailLine { width: parent.width; label: "排行"; value: card.isEmptyApp() ? "待同步" : root.rankText(card.cardIndex); theme: card.theme }
                        DetailLine { width: parent.width; label: "包名"; value: card.packageText(); theme: card.theme }

                        Row {
                            width: parent.width
                            height: 42
                            spacing: 10
                            visible: card.isEmptyApp()

                            ActionButton {
                                width: (parent.width - 10) / 2
                                label: "去授权"
                                theme: card.theme
                                primary: true
                                onClicked: card.openUsageAccess()
                            }

                            ActionButton {
                                width: (parent.width - 10) / 2
                                label: "同步"
                                theme: card.theme
                                primary: false
                                onClicked: card.requestSync()
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: card.faceRadius
                        color: "transparent"
                        border.color: card.selected ? card.edgeColor() : card.theme.borderSoft
                        border.width: card.selected ? 2 : 1
                    }
                }
                }

                Rectangle {
                    id: backFaceMask
                    anchors.fill: parent
                    radius: card.faceRadius
                    color: "white"
                    antialiasing: true
                    visible: false
                    layer.enabled: true
                    layer.samples: 4
                    layer.smooth: true
                }

                MultiEffect {
                    anchors.fill: parent
                    source: backFaceSource
                    maskEnabled: true
                    maskSource: backFaceMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 0.24
                }
            }
        }
    }

    component DetailLine: Row {
        required property var theme
        property string label: ""
        property string value: ""

        height: 24
        spacing: 10

        Text {
            width: 44
            text: label
            color: theme.textMuted
            font.family: theme.fontFamily
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            width: parent.width - 54
            text: value
            color: theme.textPrimary
            font.family: (label === "时长" || label === "占比" || label === "排行") ? theme.numberFontFamily : theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    component ActionButton: Rectangle {
        required property var theme
        property string label: ""
        property bool primary: false
        signal clicked()

        radius: 14
        color: primary ? theme.accent : theme.card
        border.color: primary ? theme.accent : theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: label
            color: primary ? (theme.isDark ? "#06101A" : "#FFFFFF") : theme.textPrimary
            font.family: theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }

    component RankRow: Rectangle {
        required property var theme
        property var app: ({})
        property string rank: "01"
        property string iconUrl: ""

        height: 74
        radius: 18
        color: theme.card
        border.color: theme.borderSoft
        border.width: 1

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Rectangle {
                width: 48
                height: 48
                radius: 13
                anchors.verticalCenter: parent.verticalCenter
                color: theme.cardElevated
                clip: true

                Image {
                    id: appImage
                    anchors.fill: parent
                    anchors.margins: 5
                    source: iconUrl
                    visible: iconUrl.length > 0 && status !== Image.Error
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !appImage.visible
                    text: app.initial || "?"
                    color: theme.accentText
                    font.family: theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }

            Column {
                width: parent.width - 148
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Text {
                    width: parent.width
                    text: app.displayName || app.packageName || "未知应用"
                    color: theme.textPrimary
                    font.family: theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: parent.width
                    height: 5
                    radius: 3
                    color: theme.rankTrack

                    Rectangle {
                        width: parent.width * Math.max(0.04, Math.min(1, (app.sharePct || 0) / 100))
                        height: parent.height
                        radius: parent.radius
                        color: theme.accent
                    }
                }
            }

            Column {
                width: 64
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    width: parent.width
                    text: app.durationText || "0s"
                    color: theme.textPrimary
                    font.family: theme.numberFontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: rank
                    color: theme.textMuted
                    font.family: theme.numberFontFamily
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
