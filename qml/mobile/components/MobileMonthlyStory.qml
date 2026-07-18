import QtQuick

Item {
    id: root

    required property var theme
    property var model: ({})
    property bool opened: false
    property int currentPage: 0
    property string errorText: ""
    property string feedbackText: ""

    signal closed()

    anchors.fill: parent
    visible: opened
    enabled: visible
    z: 90

    readonly property var report: model && model.report ? model.report : ({})
    readonly property var topApps: report.topApps || []
    readonly property int pageCount: 5

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

    function pageTitle() {
        if (currentPage === 0)
            return report.title || "本月时间报告"
        if (currentPage === 1)
            return "时间落在真实的日子里"
        if (currentPage === 2)
            return "这些应用最常出现"
        if (currentPage === 3)
            return "没有评价，只有记录"
        return "把这个月收进一张纪念卡"
    }

    function pageBody() {
        if (currentPage === 0)
            return report.summary || "同步后，本月故事会从真实记录中生成。"
        if (currentPage === 1)
            return "累计 " + (report.totalText || "0s") + "，分布在 "
                    + (report.activeDays || 0) + " 个有记录的日子里。"
        if (currentPage === 2) {
            if (topApps.length === 0)
                return "本月还没有可展示的应用记录。"
            var names = []
            for (var i = 0; i < Math.min(3, topApps.length); ++i)
                names.push(topApps[i].displayName)
            return names.join("、") + " 组成了本月最常出现的几段时间。"
        }
        if (currentPage === 3)
            return "TimeArc 只保存时长、日期和应用身份，不把休息或娱乐解释成失败。"
        return "分享图不会包含包名、联系人、网址、窗口标题或设备标识。"
    }

    function exportReport() {
        errorText = ""
        feedbackText = "正在生成月报图片…"
        reportSurface.grabToImage(function(result) {
            if (typeof mobileUiService === "undefined" || !mobileUiService) {
                errorText = "当前环境无法保存图片。"
                feedbackText = ""
                return
            }
            var path = mobileUiService.createShareImagePath(
                        report.monthLabel || "monthly-report")
            if (!path || !result.saveToFile(path)) {
                errorText = "月报图片保存失败，请重试。"
                feedbackText = ""
                return
            }
            if (!mobileUiService.shareImage(path, "分享月度时间报告")) {
                errorText = mobileUiService.lastError
                feedbackText = ""
                return
            }
            feedbackText = Qt.platform.os === "android"
                    ? "已打开系统分享面板" : "月报图片已保存"
        }, Qt.size(1080, 1920))
    }

    Rectangle {
        id: reportSurface
        anchors.fill: parent
        color: root.theme.isDark ? "#14262A" : "#E7F1EE"

        Canvas {
            anchors.fill: parent
            opacity: root.theme.isDark ? 0.78 : 0.62
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var month = new Date().getMonth() + 1
                var winter = month === 12 || month <= 2
                var autumn = month >= 9 && month <= 11
                var summer = month >= 6 && month <= 8
                var top = winter ? "#182D3A"
                                  : (autumn ? "#4A3025"
                                            : (summer ? "#153D32" : "#24443A"))
                var bottom = winter ? "#738897"
                                     : (autumn ? "#B77643"
                                               : (summer ? "#6EA45F" : "#93B77A"))
                var gradient = ctx.createLinearGradient(0, 0, 0, height)
                gradient.addColorStop(0, top)
                gradient.addColorStop(1, bottom)
                ctx.fillStyle = gradient
                ctx.fillRect(0, 0, width, height)

                for (var i = 0; i < 52; ++i) {
                    var x = (i * 83) % (width + 60) - 30
                    var y = (i * 137) % height
                    var size = 2 + (i % 5)
                    ctx.fillStyle = winter
                            ? "rgba(255,255,255,.55)"
                            : (summer
                               ? "rgba(210,236,149,.34)"
                               : "rgba(255,225,169,.30)")
                    ctx.beginPath()
                    ctx.arc(x, y, size, 0, Math.PI * 2)
                    ctx.fill()
                }

                ctx.strokeStyle = summer
                        ? "rgba(214,239,210,.24)"
                        : "rgba(255,255,255,.16)"
                ctx.lineWidth = 1
                for (var line = -100; line < width + 100; line += 46) {
                    ctx.beginPath()
                    ctx.moveTo(line, 0)
                    ctx.lineTo(line - 180, height)
                    ctx.stroke()
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.theme.isDark ? "#4A000000" : "#35FFFFFF"
        }

        Column {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 26
            anchors.bottomMargin: 24
            spacing: 18

            Row {
                width: parent.width
                height: 44

                Row {
                    width: parent.width - 54
                    height: parent.height
                    spacing: 5

                    Repeater {
                        model: root.pageCount

                        Rectangle {
                            width: (parent.width - 20) / root.pageCount
                            height: 3
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: index <= root.currentPage
                                   ? root.theme.textPrimary
                                   : root.theme.withAlpha(
                                         root.theme.textPrimary, 0.28)
                        }
                    }
                }

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: root.theme.withAlpha(root.theme.surface, 0.48)

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: root.theme.textPrimary
                        font.pixelSize: 24
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.close()
                    }
                }
            }

            Text {
                width: parent.width
                text: root.report.monthLabel || "月度报告"
                color: root.theme.textSecondary
                font.family: root.theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Item { width: 1; height: 34 }

            Text {
                width: parent.width
                text: root.pageTitle()
                color: root.theme.textPrimary
                font.family: root.theme.fontFamily
                font.pixelSize: 31
                font.weight: Font.Bold
                lineHeight: 1.18
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: root.pageBody()
                color: root.theme.textSecondary
                font.family: root.theme.fontFamily
                font.pixelSize: 16
                lineHeight: 1.55
                wrapMode: Text.WordWrap
            }

            Item { width: 1; height: 18 }

            Row {
                width: parent.width
                height: 70
                spacing: 10

                ReportFact {
                    width: (parent.width - 10) / 2
                    label: "记录日数"
                    value: (root.report.activeDays || 0) + " 天"
                }

                ReportFact {
                    width: (parent.width - 10) / 2
                    label: "累计时间"
                    value: root.report.totalText || "0s"
                }
            }

            Flow {
                width: parent.width
                spacing: 10
                visible: root.currentPage === 2

                Repeater {
                    model: root.topApps.slice(0, 4)

                    MobileAppIcon {
                        required property var modelData
                        theme: root.theme
                        app: modelData
                        iconSize: 52
                        cornerRadius: 13
                    }
                }
            }

            Item { width: 1; height: 24 }

            Text {
                width: parent.width
                visible: root.errorText.length > 0
                         || root.feedbackText.length > 0
                text: root.errorText.length > 0
                      ? root.errorText : root.feedbackText
                color: root.errorText.length > 0
                       ? root.theme.error : root.theme.textSecondary
                font.family: root.theme.fontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                height: 48
                spacing: 10

                Rectangle {
                    width: root.currentPage > 0 ? 80 : 0
                    height: parent.height
                    visible: root.currentPage > 0
                    radius: root.theme.controlRadius
                    color: root.theme.withAlpha(root.theme.surface, 0.62)

                    Text {
                        anchors.centerIn: parent
                        text: "上一页"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.previous()
                    }
                }

                Rectangle {
                    width: parent.width - (root.currentPage > 0 ? 90 : 0)
                    height: parent.height
                    radius: root.theme.controlRadius
                    color: root.theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: root.currentPage === root.pageCount - 1
                              ? "保存并分享月报" : "下一页"
                        color: "white"
                        font.family: root.theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.currentPage === root.pageCount - 1)
                                root.exportReport()
                            else
                                root.next()
                        }
                    }
                }
            }
        }
    }

    component ReportFact: Rectangle {
        property string label: ""
        property string value: ""

        radius: root.theme.controlRadius
        color: root.theme.withAlpha(root.theme.surface, 0.44)

        Column {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 5

            Text {
                text: label
                color: root.theme.textMuted
                font.family: root.theme.fontFamily
                font.pixelSize: 10
            }

            Text {
                width: parent.width
                text: value
                color: root.theme.textPrimary
                font.family: root.theme.numberFontFamily
                font.pixelSize: 18
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
        }
    }
}
