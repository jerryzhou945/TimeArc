import QtQuick
import QtQuick.Window
import "monthly"
import "MobileMonthProfiles.js" as MonthProfiles
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    required property var theme
    property var model: ({})
    property bool opened: false
    property int currentPage: 0
    property string errorText: ""
    property string feedbackText: ""

    signal closed()

    anchors.fill: parent
    parent: root.Window.window ? root.Window.window.contentItem : undefined
    visible: opened
    enabled: visible
    z: 90

    readonly property var report: model && model.report ? model.report : ({})
    readonly property int pageCount: 6
    readonly property int reportMonth: {
        var key = (report.monthKey || "").toString()
        if (key.length >= 7)
            return Math.max(1, Math.min(12, parseInt(key.slice(5, 7), 10)))
        return new Date().getMonth() + 1
    }
    readonly property var profile: MonthProfiles.forMonth(reportMonth)

    function open() {
        currentPage = 0
        errorText = ""
        feedbackText = ""
        opened = true
    }

    function close() {
        opened = false
        closed()
    }

    function next() {
        currentPage = Math.min(pageCount - 1, currentPage + 1)
    }

    function previous() {
        currentPage = Math.max(0, currentPage - 1)
    }

    function exportReport(channel, previewItem) {
        errorText = ""
        feedbackText = "Building the monthly card…"
        var captureItem = previewItem || reportSurface
        captureItem.grabToImage(function(result) {
            if (typeof mobileUiService === "undefined" || !mobileUiService) {
                errorText = "Images cannot be saved in this environment."
                feedbackText = ""
                return
            }
            var path = mobileUiService.createShareImagePath(
                        I18n.reportMonthLabel(root.languageMode, report) || "monthly-report")
            if (!path || !result.saveToFile(path)) {
                errorText = "Could not save the monthly image. Try again."
                feedbackText = ""
                return
            }
            if (!mobileUiService.shareImageToChannel(
                        path, channel || "system", "Share monthly time report")) {
                errorText = mobileUiService.lastError
                feedbackText = ""
                return
            }
            feedbackText = Qt.platform.os === "android"
                    ? "System share sheet opened" : "Monthly image saved"
        }, Qt.size(1080, 1920))
    }

    Rectangle {
        id: reportSurface
        anchors.fill: parent
        color: "#111719"
        clip: true

        MobileSeasonScene {

            languageMode: root.languageMode
            anchors.fill: parent
            profile: root.profile
            pageIndex: root.currentPage
            reducedMotion: root.theme.reducedMotion
        }

        Item {
            anchors.fill: parent

            MonthlyCoverPage {
                anchors.fill: parent
                theme: root.theme
                report: root.report
                profile: root.profile
                languageMode: root.languageMode
                visible: root.currentPage === 0
                opacity: visible ? 1 : 0
                transform: Translate {
                    x: (0 - root.currentPage) * 22
                }
            }

            MonthlyOverviewPage {
                anchors.fill: parent
                theme: root.theme
                report: root.report
                profile: root.profile
                languageMode: root.languageMode
                visible: root.currentPage === 1
            }

            MonthlyHighlightPage {
                anchors.fill: parent
                theme: root.theme
                report: root.report
                profile: root.profile
                languageMode: root.languageMode
                visible: root.currentPage === 2
            }

            MonthlyCompanionPage {
                anchors.fill: parent
                theme: root.theme
                report: root.report
                profile: root.profile
                languageMode: root.languageMode
                visible: root.currentPage === 3
            }

            MonthlyRankingPage {
                anchors.fill: parent
                theme: root.theme
                report: root.report
                profile: root.profile
                languageMode: root.languageMode
                visible: root.currentPage === 4
            }

            MonthlySharePage {
                anchors.fill: parent
                theme: root.theme
                report: root.report
                profile: root.profile
                languageMode: root.languageMode
                visible: root.currentPage === 5
                onShareRequested: function(channel, previewItem) {
                    root.exportReport(channel, previewItem)
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 20
            anchors.rightMargin: 68
            anchors.topMargin: SafeArea.margins.top + 18
            height: 36
            spacing: 5

            Repeater {
                model: root.pageCount

                Rectangle {
                    required property int index
                    width: (parent.width - 25) / root.pageCount
                    height: 3
                    radius: 2
                    color: index <= root.currentPage
                           ? "#F4FFFFFF" : "#45FFFFFF"
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 14
            anchors.topMargin: SafeArea.margins.top + 8
            width: 44
            height: 44
            radius: 22
            color: "#4A101719"
            border.width: 1
            border.color: "#35FFFFFF"

            MobileSymbolIcon {

                languageMode: root.languageMode
                anchors.centerIn: parent
                name: "close"
                color: "white"
                iconSize: 22
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 24
            anchors.bottomMargin: SafeArea.margins.bottom + 18
            text: root.currentPage === root.pageCount - 1
                  ? "Tap the button to take this stretch of time with you"
                  : "Tap the sides or swipe left and right"
            color: "#BFFFFFFF"
            font.family: root.theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 24
            anchors.bottomMargin: SafeArea.margins.bottom + 13
            text: (root.currentPage + 1) + " / " + root.pageCount
            color: "#AFFFFFFF"
            font.family: root.theme.numberFontFamily
            font.pixelSize: 11
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: SafeArea.margins.bottom + 20
            width: parent.width - 120
            visible: root.errorText.length > 0 || root.feedbackText.length > 0
            text: root.errorText.length > 0 ? root.errorText : root.feedbackText
            color: root.errorText.length > 0 ? "#FFB4AB" : "#DFFFFFFF"
            font.family: root.theme.fontFamily
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 96
            anchors.bottomMargin: 72
            width: parent.width * 0.24
            z: 10
            onClicked: root.previous()
        }

        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 96
            anchors.bottomMargin: 72
            width: parent.width * 0.24
            z: 10
            onClicked: root.next()
        }

        DragHandler {
            id: storySwipe
            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            onActiveChanged: {
                if (!active) {
                    if (translation.x < -54)
                        root.next()
                    else if (translation.x > 54)
                        root.previous()
                }
            }
        }
    }
}
