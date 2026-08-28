import QtQuick
import "../components"
import "../components/MobileMonthProfiles.js" as MonthProfiles
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    required property var theme
    property bool wallpaperActive: false
    readonly property int dateRailWidth: 52
    property var lakeModel: ({
        "report": {},
        "moments": [],
        "topApps": [],
        "empty": true
    })
    readonly property var report: lakeModel.report || ({})
    readonly property var moments: lakeModel.moments || []
    readonly property int reportMonth: {
        var key = (report.monthKey || "").toString()
        return key.length >= 7
                ? Math.max(1, Math.min(12, parseInt(key.slice(5, 7), 10)))
                : new Date().getMonth() + 1
    }
    readonly property var coverProfile:
        report.profile && report.profile.sceneSource
        ? report.profile : MonthProfiles.forMonth(reportMonth)

    function previewApp(name, initial, iconPath) {
        return {
            "displayName": name,
            "initial": initial,
            "appIconPath": iconPath
        }
    }

    function previewLake() {
        var code = previewApp(
                    "Visual Studio Code", "VS",
                    "image://appicon/C:/Users/Lenovo/AppData/Local/Programs/Microsoft VS Code/Code.exe")
        var chrome = previewApp(
                    "Google Chrome", "Ch",
                    "image://appicon/C:/Program Files/Google/Chrome/Application/chrome.exe")
        var music = previewApp(
                    "NetEase Cloud Music", "Mu",
                    "image://appicon/C:/Program Files (x86)/NetEase/CloudMusic/cloudmusic.exe")
        var wechat = previewApp(
                    "WeChat", "We",
                    "image://appicon/C:/Program Files/Tencent/WeChat/WeChat.exe")
        return {
            "report": {
                "monthLabel": "June time report",
                "title": "Time moved like a summer night breeze across 24 remembered days",
                "summary": "168h 24m spread across different apps, most often Visual Studio Code."
            },
            "topApps": [code, chrome, music, wechat],
            "moments": [
                {
                    "dateLabel": "2026-06-28",
                    "title": "Four afternoon hours, like a line that never broke",
                    "body": "Visual Studio Code and the browser ran together for 4h 36m; Friday's work stretched from afternoon into dusk.",
                    "durationText": "4h 36m",
                    "apps": [code, chrome]
                },
                {
                    "dateLabel": "2026-06-22",
                    "title": "After midnight, sound kept a light on for the day",
                    "body": "Music carried from 23:42 into the next day, 2h 18m in all — June's longest late-night stretch of sound.",
                    "durationText": "2h 18m",
                    "apps": [music]
                },
                {
                    "dateLabel": "2026-06-11",
                    "title": "For 42 afternoon minutes, life passed through two windows",
                    "body": "Two apps alternated briefly 9 times. Only aggregated time is kept here, never what you saw.",
                    "durationText": "42m",
                    "apps": [wechat, chrome]
                }
            ],
            "empty": false
        }
    }

    function monthText(dateLabel) {
        var raw = (dateLabel || "").toString()
        if (raw.length < 7)
            return "This Month"
        var names = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        var month = parseInt(raw.slice(5, 7), 10)
        return month >= 1 && month <= 12 ? names[month - 1] : "This Month"
    }

    function archiveModels() {
        if (!root.isPreviewMode()) {
            return [{
                "code": root.report.monthLabel || "This Month",
                "title": root.report.monthLabel || "This month's time report",
                "meta": (root.report.totalText || "")
                        + ((root.report.activeDays || 0) > 0
                           ? I18n.sentence(root.languageMode, "historyRecordDays", {count: root.report.activeDays}) : "")
            }]
        }
        return [
            { "code": "06", "title": "June time report",
              "meta": "168h 24m · 24 recorded days" },
            { "code": "05", "title": "May time report",
              "meta": "152h 08m · 22 recorded days" },
            { "code": "04", "title": "April time report",
              "meta": "139h 46m · 20 recorded days" }
        ]
    }

    function hasService() {
        return typeof mobileUsageService !== "undefined" && mobileUsageService
    }

    function isPreviewMode() {
        return Qt.application.arguments.indexOf("--mobile-preview") >= 0
    }

    function reload() {
        lakeModel = isPreviewMode()
                ? previewLake()
                : (hasService()
                   ? mobileUsageService.getMemoryLakeForLatestReleasedMonth()
                   : ({ "report": {}, "moments": [],
                        "topApps": [], "empty": true }))
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

        Flickable {
            id: flick
            width: parent.width
            height: parent.height - y
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: content.implicitHeight + 30

            Column {
                id: content
                width: flick.width - 32
                x: 16
                spacing: 16

                Row {
                    width: parent.width
                    height: 54

                    Column {
                        width: parent.width - 110
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Memory Lake"
                            color: root.theme.textPrimary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 27
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Look back at the real fragments time left behind"
                            color: root.theme.textSecondary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    MobileGlassPanel {

                        languageMode: root.languageMode
                        width: 110
                        height: 40
                        anchors.verticalCenter: parent.verticalCenter
                        theme: root.theme
                        wallpaperActive: root.wallpaperActive
                        strong: false

                        Text {
                            anchors.centerIn: parent
                            text: I18n.reportMonthLabel(root.languageMode, root.report) || root.tr("This Month")
                            color: root.theme.textPrimary
                            font.family: root.theme.numberFontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Rectangle {
                    id: reportCover
                    width: parent.width
                    height: 252
                    radius: 18
                    clip: true
                    color: root.theme.bg

                    Image {
                        anchors.fill: parent
                        source: root.coverProfile.sceneSource || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#2710181A" }
                            GradientStop { position: 0.48; color: "#4710181A" }
                            GradientStop { position: 1.0; color: "#A810181A" }
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        anchors.topMargin: 20
                        spacing: 9

                        Text {
                            text: I18n.reportMonthLabel(root.languageMode, root.report) || root.tr("This month's time report")
                            color: "white"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            text: I18n.reportTitle(root.languageMode, root.report) || root.tr("Waiting for the first stretch to be remembered")
                            color: "white"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 26
                            font.weight: Font.Bold
                            lineHeight: 1.18
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.report.summary
                                  || "After syncing, the monthly story is built here from real records."
                            color: "#E7F0E5"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 13
                            lineHeight: 1.42
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        id: reportFooter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        anchors.bottomMargin: 16
                        height: root.theme.controlHeight
                        spacing: 12

                        Text {
                            width: parent.width - 146
                            height: parent.height
                            text: root.coverProfile.eyebrow || "SEASONAL STORY"
                            color: "#CFFFFFFF"
                            font.family: root.theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: 134
                            height: root.theme.controlHeight
                            radius: root.theme.controlRadius
                            color: "#E8FFFFFF"

                            Text {
                                anchors.centerIn: parent
                                text: "Open the full monthly report"
                                color: root.coverProfile.accentInk || "#17352C"
                                font.family: root.theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: monthlyStory.open()
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 38

                    Text {
                        width: parent.width - 120
                        text: "Recently remembered"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 19
                        font.weight: Font.Bold
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: 120
                        text: "Give every look back somewhere to come from"
                        color: root.theme.textMuted
                        font.family: root.theme.fontFamily
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    width: parent.width
                    visible: root.moments.length === 0
                    text: "Nothing remembered yet. Once access is granted and synced, apps and time will form sentences you can look back on."
                    color: root.theme.textSecondary
                    font.family: root.theme.fontFamily
                    font.pixelSize: 14
                    lineHeight: 1.5
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.moments

                    Item {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 132

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: root.wallpaperActive
                                   ? root.theme.timelineLine : root.theme.line
                        }

                        Row {
                            anchors.fill: parent
                            spacing: 14

                            Column {
                                width: root.dateRailWidth
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: {
                                        var raw = modelData.dateLabel || ""
                                        return raw.length >= 10
                                                ? raw.slice(8, 10) : "·"
                                    }
                                    color: root.theme.textPrimary
                                    font.family: root.theme.numberFontFamily
                                    font.pixelSize: 23
                                    font.weight: Font.Bold
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    width: parent.width
                                    text: root.monthText(modelData.dateLabel)
                                    color: root.theme.textMuted
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            Column {
                                width: parent.width
                                       - root.dateRailWidth - 14
                                spacing: 7

                                Text {
                                    width: parent.width
                                    text: modelData.title
                                    color: root.theme.textPrimary
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.body
                                    color: root.theme.textSecondary
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 12
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Row {
                                    width: parent.width
                                    height: 36
                                    spacing: 7

                                    Repeater {
                                        model: modelData.apps || []

                                        MobileAppIcon {

                                            languageMode: root.languageMode
                                            required property var modelData
                                            theme: root.theme
                                            app: modelData
                                            iconSize: 34
                                            cornerRadius: 9
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.durationText || ""
                                        color: root.theme.textMuted
                                        font.family: root.theme.numberFontFamily
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 42

                    Text {
                        width: parent.width - 100
                        text: "Monthly archive"
                        color: root.wallpaperActive
                               ? root.theme.wallpaperInk
                               : root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 19
                        font.weight: Font.Bold
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: 100
                        text: "Stored locally"
                        color: root.wallpaperActive
                               ? root.theme.wallpaperMuted
                               : root.theme.textMuted
                        font.family: root.theme.fontFamily
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Repeater {
                    model: root.archiveModels()

                    Item {
                        required property var modelData
                        width: parent.width
                        height: 82

                        Row {
                            anchors.fill: parent
                            spacing: 14

                            Rectangle {
                                width: root.dateRailWidth
                                height: 58
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 12
                                color: root.wallpaperActive
                                       ? root.theme.contentWash
                                       : root.theme.surfaceRaised

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.code
                                    color: root.wallpaperActive
                                           ? root.theme.wallpaperInk
                                           : root.theme.textPrimary
                                    font.family: root.theme.numberFontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                }
                            }

                            Column {
                                width: parent.width
                                       - root.dateRailWidth - 46
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5

                                Text {
                                    width: parent.width
                                    text: modelData.title
                                    color: root.wallpaperActive
                                           ? root.theme.wallpaperInk
                                           : root.theme.textPrimary
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.meta
                                    color: root.wallpaperActive
                                           ? root.theme.wallpaperMuted
                                           : root.theme.textMuted
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                width: 32
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: root.wallpaperActive
                                       ? root.theme.wallpaperInk
                                       : root.theme.textPrimary
                                font.pixelSize: 24
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: root.dateRailWidth + 14
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: root.wallpaperActive
                                   ? root.theme.timelineLine : root.theme.line
                        }
                    }
                }
            }
        }
    }

    MobileMonthlyStory {

        languageMode: root.languageMode
        id: monthlyStory
        theme: root.theme
        model: root.lakeModel
    }
}
