import QtQuick
import "../components"
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    required property var theme
    property bool wallpaperActive: false
    property url wallpaperSource: ""
    property bool anonymousShare: false
    property var totalDashboard: emptyDashboard()
    property int selectedCardIndex: 0
    property var flippedApps: ({})
    signal wallpaperRequested()
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
            "displayName": "Waiting for the first record",
            "durationText": "0s",
            "sharePct": 0,
            "relativePct": 0,
            "recordedDays": 0,
            "spanDays": 0,
            "initial": "h",
            "storyText": "Turn on usage access and sync, and app time cards will appear here.",
            "conversionText": "Every shared phrase is generated from real durations.",
            "empty": true
        }
    }

    function previewDashboard() {
        return {
            "totalSec": 2923200,
            "totalText": "812h",
            "activeDays": 168,
            "appCount": 6,
            "firstDateLocal": "2025.03.13",
            "rangeText": "2025.03.13 to today",
            "empty": false,
            "topApps": [
                {
                    "appIdentifier": "preview:chrome",
                    "displayName": "Google Chrome",
                    "appIconPath": "image://appicon/C:/Program Files/Google/Chrome/Application/chrome.exe",
                    "durationText": "71h 30m",
                    "sharePct": 31,
                    "relativePct": 100,
                    "recordedDays": 44,
                    "spanDays": 441,
                    "firstDateLocal": "2025.04.27",
                    "initial": "Ch",
                    "storyText": "71 hours of browsing and searching, quietly happening on screen.",
                    "conversionText": "In 25-minute reading blocks, that is about 172 of them."
                },
                {
                    "appIdentifier": "preview:vscode",
                    "displayName": "Visual Studio Code",
                    "appIconPath": "image://appicon/C:/Users/Lenovo/AppData/Local/Programs/Microsoft VS Code/Code.exe",
                    "durationText": "64h 36m",
                    "sharePct": 28,
                    "relativePct": 90,
                    "recordedDays": 37,
                    "spanDays": 386,
                    "firstDateLocal": "2025.06.21",
                    "initial": "VS",
                    "storyText": "Many unbroken lines, extending slowly through one focused stretch after another.",
                    "conversionText": "In 25-minute focus blocks, that is about 155 of them."
                },
                {
                    "appIdentifier": "preview:netease",
                    "displayName": "NetEase Cloud Music",
                    "appIconPath": "image://appicon/C:/Program Files (x86)/NetEase/CloudMusic/cloudmusic.exe",
                    "durationText": "42h 18m",
                    "sharePct": 18,
                    "relativePct": 59,
                    "recordedDays": 29,
                    "spanDays": 322,
                    "firstDateLocal": "2025.08.24",
                    "initial": "Mu",
                    "storyText": "Sound kept the light on for this stretch of time.",
                    "conversionText": "Played as four-minute songs, that is about 634 of them."
                }
            ]
        }
    }

    function hasService() {
        return typeof mobileUsageService !== "undefined" && mobileUsageService
    }

    function isPreviewMode() {
        return Qt.application.arguments.indexOf("--mobile-preview") >= 0
    }

    function reload() {
        var dashboard = hasService()
                ? mobileUsageService.getDashboardForRange("all")
                : emptyDashboard()
        totalDashboard = isPreviewMode() && dashboard.empty
                ? previewDashboard() : dashboard
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

            languageMode: root.languageMode
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
                width: root.wallpaperActive ? 220 : 158
                height: parent.height
                z: 2
                text: "TimeArc · time card"
                color: root.wallpaperActive
                       ? root.theme.wallpaperInk : root.theme.textPrimary
                font.family: root.theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.Bold
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                id: wallpaperPrompt
                anchors.right: parent.right
                anchors.rightMargin: 66
                anchors.verticalCenter: parent.verticalCenter
                width: 132
                height: 36
                radius: root.theme.controlRadius
                visible: !root.wallpaperActive
                color: root.theme.withAlpha(root.theme.surface, 0.52)
                border.width: 1
                border.color: root.theme.withAlpha(root.theme.accentBright,
                                                   0.28)

                Text {
                    anchors.centerIn: parent
                    text: "Add a custom wallpaper"
                    color: root.theme.textSecondary
                    font.family: root.theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.wallpaperRequested()
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 22
                color: root.wallpaperActive
                       ? root.theme.contentWash
                       : root.theme.surfaceRaised

                Text {
                    anchors.centerIn: parent
                    text: "↻"
                    color: root.wallpaperActive
                           ? root.theme.wallpaperInk : root.theme.textPrimary
                    font.pixelSize: 20
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.requestSync()
                }
            }
        }

        MobileGlassPanel {

            languageMode: root.languageMode
            id: archiveStrip
            width: parent.width - 32
            height: 78
            anchors.horizontalCenter: parent.horizontalCenter
            theme: root.theme
            wallpaperActive: root.wallpaperActive
            strong: false

            Row {
                anchors.fill: parent
                anchors.margins: 12

                ArchiveFact {
                    width: (parent.width - 2) / 3
                    height: parent.height
                    value: root.totalDashboard.firstDateLocal || "Not started yet"
                    label: "Start recording"
                }

                Rectangle {
                    width: 1
                    height: 34
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.wallpaperActive
                           ? root.theme.timelineLine : root.theme.line
                }

                ArchiveFact {
                    width: (parent.width - 2) / 3
                    height: parent.height
                    value: root.totalDashboard.totalText || "0s"
                    label: "Total time"
                }

                Rectangle {
                    width: 1
                    height: 34
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.wallpaperActive
                           ? root.theme.timelineLine : root.theme.line
                }

                ArchiveFact {
                    width: (parent.width - 2) / 3
                    height: parent.height
                    value: I18n.sentence(root.languageMode, "dayCount", {count: root.totalDashboard.activeDays || 0})
                    label: "Days recorded"
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

                    languageMode: root.languageMode
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
                    onFlippedRequested: function(flipped) {
                        var next = Object.assign({}, root.flippedApps)
                        next[modelData.appIdentifier
                             || modelData.packageName
                             || modelData.displayName] = flipped
                        root.flippedApps = next
                    }
                    onShareRequested: function(appModel) {
                        shareOverlay.openFor(
                                    appModel,
                                    I18n.reportRange(root.languageMode, root.totalDashboard) || root.tr("All records"))
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

        languageMode: root.languageMode
        id: shareOverlay
        theme: root.theme
        anonymous: root.anonymousShare
        wallpaperSource: root.wallpaperSource
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
                color: root.wallpaperActive
                       ? root.theme.wallpaperInk : root.theme.textPrimary
                font.family: root.theme.numberFontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: label
                color: root.wallpaperActive
                       ? root.theme.wallpaperMuted : root.theme.textMuted
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
