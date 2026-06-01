import QtQuick
import "../components"

Rectangle {
    id: root

    required property var theme

    color: theme.bg

    property int selectedDayIndex: 0
    property bool datePickerOpen: false
    property var selectedDate: new Date()
    property int displayYear: selectedDate.getFullYear()
    property int displayMonth: selectedDate.getMonth()
    property var weekNames: ["日", "一", "二", "三", "四", "五", "六"]

    property var previewCards: ["今日主线卡", "娱乐卡", "音乐卡"]
    property var timeline: [
        { "start": "09:20", "end": "11:05", "app": "VSCode", "category": "项目开发", "colorKey": "accent", "duration": "1h45m", "privacy": false },
        { "start": "11:10", "end": "11:45", "app": "Chrome", "category": "文档查阅", "colorKey": "textMuted", "duration": "35m", "privacy": false },
        { "start": "14:20", "end": "16:10", "app": "VSCode", "category": "项目开发", "colorKey": "accent", "duration": "1h50m", "privacy": false },
        { "start": "20:30", "end": "21:40", "app": "Steam", "category": "娱乐", "colorKey": "amber", "duration": "1h10m", "privacy": false },
        { "start": "23:10", "end": "00:30", "app": "Spotify", "category": "音乐陪伴", "colorKey": "green", "duration": "1h20m", "privacy": true }
    ]

    property var dateOptions: [
        {
            "label": "今天",
            "date": "5月31日 周日",
            "previewCards": previewCards,
            "timeline": timeline
        },
        {
            "label": "昨天",
            "date": "5月30日 周六",
            "previewCards": ["开发卡", "阅读卡", "休息卡"],
            "timeline": [
                { "start": "10:10", "end": "11:30", "app": "Qt Creator", "category": "界面调试", "colorKey": "accent", "duration": "1h20m", "privacy": false },
                { "start": "13:40", "end": "14:20", "app": "Chrome", "category": "资料查阅", "colorKey": "textMuted", "duration": "40m", "privacy": false },
                { "start": "21:00", "end": "22:15", "app": "Bilibili", "category": "放松", "colorKey": "amber", "duration": "1h15m", "privacy": false }
            ]
        },
        {
            "label": "前天",
            "date": "5月29日 周五",
            "previewCards": ["整理卡", "音乐卡"],
            "timeline": [
                { "start": "09:35", "end": "10:25", "app": "Notion", "category": "计划整理", "colorKey": "green", "duration": "50m", "privacy": false },
                { "start": "15:10", "end": "16:45", "app": "VSCode", "category": "项目开发", "colorKey": "accent", "duration": "1h35m", "privacy": false },
                { "start": "22:20", "end": "23:05", "app": "Spotify", "category": "音乐陪伴", "colorKey": "green", "duration": "45m", "privacy": true }
            ]
        },
        {
            "label": "周四",
            "date": "5月28日 周四",
            "previewCards": ["学习卡", "社交卡"],
            "timeline": [
                { "start": "08:50", "end": "09:40", "app": "Chrome", "category": "学习资料", "colorKey": "accent", "duration": "50m", "privacy": false },
                { "start": "12:30", "end": "13:05", "app": "WeChat", "category": "社交沟通", "colorKey": "textMuted", "duration": "35m", "privacy": true },
                { "start": "19:45", "end": "20:30", "app": "Steam", "category": "娱乐", "colorKey": "amber", "duration": "45m", "privacy": false }
            ]
        }
    ]
    property var selectedDay: buildDayData(selectedDate)

    function formatDate(date) {
        return (date.getMonth() + 1) + "月" + date.getDate() + "日 周" + weekNames[date.getDay()]
    }

    function monthTitle() {
        return displayYear + "年 " + (displayMonth + 1) + "月"
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    function firstWeekday(year, month) {
        return new Date(year, month, 1).getDay()
    }

    function dayForCell(cellIndex) {
        var day = cellIndex - firstWeekday(displayYear, displayMonth) + 1
        return day > 0 && day <= daysInMonth(displayYear, displayMonth) ? day : 0
    }

    function isSelectedDay(day) {
        return day > 0
            && selectedDate.getFullYear() === displayYear
            && selectedDate.getMonth() === displayMonth
            && selectedDate.getDate() === day
    }

    function buildDayData(date) {
        var variant = date.getDate() % 3
        if (variant === 1) {
            return {
                "date": formatDate(date),
                "previewCards": ["开发卡", "阅读卡", "音乐卡"],
                "timeline": [
                    { "start": "10:10", "end": "11:30", "app": "Qt Creator", "category": "界面调试", "colorKey": "accent", "duration": "1h20m", "privacy": false },
                    { "start": "13:40", "end": "14:20", "app": "Chrome", "category": "资料查阅", "colorKey": "textMuted", "duration": "40m", "privacy": false },
                    { "start": "21:00", "end": "22:15", "app": "Bilibili", "category": "放松", "colorKey": "amber", "duration": "1h15m", "privacy": false }
                ]
            }
        }
        if (variant === 2) {
            return {
                "date": formatDate(date),
                "previewCards": ["整理卡", "音乐卡"],
                "timeline": [
                    { "start": "09:35", "end": "10:25", "app": "Notion", "category": "计划整理", "colorKey": "green", "duration": "50m", "privacy": false },
                    { "start": "15:10", "end": "16:45", "app": "VSCode", "category": "项目开发", "colorKey": "accent", "duration": "1h35m", "privacy": false },
                    { "start": "22:20", "end": "23:05", "app": "Spotify", "category": "音乐陪伴", "colorKey": "green", "duration": "45m", "privacy": true }
                ]
            }
        }
        return {
            "date": formatDate(date),
            "previewCards": previewCards,
            "timeline": timeline
        }
    }

    function selectCalendarDay(day) {
        if (day <= 0)
            return
        selectedDate = new Date(displayYear, displayMonth, day)
        selectedDay = buildDayData(selectedDate)
        datePickerOpen = false
    }

    function shiftSelectedDate(days) {
        selectedDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate() + days)
        displayYear = selectedDate.getFullYear()
        displayMonth = selectedDate.getMonth()
        selectedDay = buildDayData(selectedDate)
    }

    function changeMonth(delta) {
        var d = new Date(displayYear, displayMonth + delta, 1)
        displayYear = d.getFullYear()
        displayMonth = d.getMonth()
    }

    function changeYear(delta) {
        displayYear += delta
    }

    function goToday() {
        selectedDate = new Date()
        displayYear = selectedDate.getFullYear()
        displayMonth = selectedDate.getMonth()
        selectedDay = buildDayData(selectedDate)
        datePickerOpen = false
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
            contentHeight: content.implicitHeight + 20

            Column {
                id: content
                width: flick.width - 40
                x: 20
                spacing: 16

                MobileSectionTitle {
                    width: parent.width
                    theme: root.theme
                    title: "历史"
                    subtitle: "按日期回看一天"
                }

                Row {
                    width: parent.width
                    height: 32
                    spacing: 10

                    ArrowButton {
                        theme: root.theme
                        direction: -1
                        onClicked: root.shiftSelectedDate(-1)
                    }

                    Rectangle {
                        width: parent.width - 84
                        height: 32
                        radius: 12
                        color: root.theme.card
                        border.color: root.theme.border
                        border.width: 1

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: parent.radius + 2
                            color: "transparent"
                            border.color: root.theme.glowColor
                            border.width: 1
                            opacity: root.theme.isDark ? 0.32 : 0.20
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "5月31日 周日"
                            color: root.theme.textPrimary
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            Component.onCompleted: text = Qt.binding(function() { return root.selectedDay.date })
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.datePickerOpen = !root.datePickerOpen
                        }
                    }

                    ArrowButton {
                        theme: root.theme
                        direction: 1
                        onClicked: root.shiftSelectedDate(1)
                    }
                }

                Rectangle {
                    width: parent.width
                    height: root.datePickerOpen ? calendarPanelContent.implicitHeight + 28 : 0
                    radius: 16
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: root.datePickerOpen ? 1 : 0
                    visible: height > 0

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: parent.radius + 3
                        color: "transparent"
                        border.color: root.theme.glowColor
                        border.width: 1
                        opacity: root.theme.isDark ? 0.45 : 0.30
                    }

                    Column {
                        id: calendarPanelContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14
                        spacing: 10

                        Row {
                            width: parent.width
                            height: 30
                            spacing: 8

                            CalendarTextButton {
                                theme: root.theme
                                label: "‹ 年"
                                onClicked: root.changeYear(-1)
                            }

                            CalendarTextButton {
                                theme: root.theme
                                label: "‹ 月"
                                onClicked: root.changeMonth(-1)
                            }

                            Text {
                                width: parent.width - 192
                                height: parent.height
                                text: root.monthTitle()
                                color: root.theme.textPrimary
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            CalendarTextButton {
                                theme: root.theme
                                label: "月 ›"
                                onClicked: root.changeMonth(1)
                            }

                            CalendarTextButton {
                                theme: root.theme
                                label: "年 ›"
                                onClicked: root.changeYear(1)
                            }
                        }

                        Row {
                            width: parent.width
                            height: 20

                            Repeater {
                                model: root.weekNames

                                Text {
                                    width: parent.width / 7
                                    height: parent.height
                                    text: modelData
                                    color: root.theme.textMuted
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        Grid {
                            width: parent.width
                            columns: 7
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: 42

                                Rectangle {
                                    property int dayNumber: root.dayForCell(index)

                                    width: (calendarPanelContent.width - 36) / 7
                                    height: width
                                    radius: width / 2
                                    color: root.isSelectedDay(dayNumber) ? root.theme.accent
                                          : dayNumber > 0 ? root.theme.cardElevated : "transparent"
                                    border.color: root.isSelectedDay(dayNumber) ? root.theme.accent
                                                  : dayNumber > 0 ? root.theme.border : "transparent"
                                    border.width: dayNumber > 0 ? 1 : 0
                                    opacity: dayNumber > 0 ? 1 : 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.dayNumber > 0 ? parent.dayNumber : ""
                                        color: root.isSelectedDay(parent.dayNumber) ? root.theme.bg : root.theme.textSecondary
                                        font.pixelSize: 12
                                        font.weight: root.isSelectedDay(parent.dayNumber) ? Font.DemiBold : Font.Normal
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: parent.dayNumber > 0
                                        onClicked: root.selectCalendarDay(parent.dayNumber)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 12
                            color: root.theme.cardElevated
                            border.color: root.theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "回到今天"
                                color: root.theme.accent
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.goToday()
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: recapColumn.implicitHeight + 32
                    radius: 18
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: parent.radius + 3
                        color: "transparent"
                        border.color: root.theme.glowColor
                        border.width: 1
                        opacity: root.theme.isDark ? 0.34 : 0.22
                    }

                    Column {
                        id: recapColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        Text {
                            text: "今日卡片回顾"
                            color: root.theme.textMuted
                            font.pixelSize: 12
                        }

                        Flow {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: root.selectedDay.previewCards

                                Rectangle {
                                    width: chipText.implicitWidth + 20
                                    height: 26
                                    radius: 8
                                    color: root.theme.cardElevated
                                    border.color: root.theme.border
                                    border.width: 1

                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: root.theme.textSecondary
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            Rectangle {
                                width: plusText.implicitWidth + 20
                                height: 26
                                radius: 8
                                color: root.theme.cardElevated
                                border.color: root.theme.border
                                border.width: 1

                                Text {
                                    id: plusText
                                    anchors.centerIn: parent
                                    text: "+2 张"
                                    color: root.theme.accent
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: timelineColumn.implicitHeight + 32
                    radius: 18
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: parent.radius + 3
                        color: "transparent"
                        border.color: root.theme.glowColor
                        border.width: 1
                        opacity: root.theme.isDark ? 0.34 : 0.22
                    }

                    Column {
                        id: timelineColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 0

                        Text {
                            width: parent.width
                            height: 28
                            text: "时间线"
                            color: root.theme.textMuted
                            font.pixelSize: 12
                        }

                        Repeater {
                            model: root.selectedDay.timeline

                            Item {
                                width: parent.width
                                height: 56

                                Row {
                                    anchors.fill: parent
                                    spacing: 12

                                    Rectangle {
                                        width: 3
                                        height: 36
                                        radius: 2
                                        color: root.theme.colorFor(modelData.colorKey)
                                        anchors.top: parent.top
                                        anchors.topMargin: 3
                                    }

                                    Column {
                                        width: parent.width - 15
                                        spacing: 2

                                        Row {
                                            width: parent.width

                                            Column {
                                                width: parent.width - durationColumn.width
                                                spacing: 2

                                                Row {
                                                    spacing: 6

                                                    Text {
                                                        text: modelData.app
                                                        color: root.theme.textPrimary
                                                        font.pixelSize: 14
                                                        font.weight: Font.Medium
                                                    }

                                                    Rectangle {
                                                        width: hiddenText.implicitWidth + 12
                                                        height: 18
                                                        radius: 4
                                                        visible: modelData.privacy
                                                        color: root.theme.cardElevated
                                                        border.color: root.theme.border
                                                        border.width: 1

                                                        Text {
                                                            id: hiddenText
                                                            anchors.centerIn: parent
                                                            text: "标题已隐藏"
                                                            color: root.theme.textMuted
                                                            font.pixelSize: 10
                                                        }
                                                    }
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: modelData.category
                                                    color: root.theme.textMuted
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Column {
                                                id: durationColumn
                                                width: 58
                                                spacing: 2

                                                Text {
                                                    width: parent.width
                                                    text: modelData.duration
                                                    color: root.theme.textPrimary
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                    horizontalAlignment: Text.AlignRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: modelData.start + "–" + modelData.end
                                                    color: root.theme.textMuted
                                                    font.pixelSize: 11
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 20
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: root.theme.border
                                    opacity: index < root.selectedDay.timeline.length - 1 ? 0.5 : 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component CalendarTextButton: Rectangle {
        required property var theme
        property string label: ""
        signal clicked()

        width: 40
        height: 30
        radius: 10
        color: theme.cardElevated
        border.color: theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: label
            color: theme.textSecondary
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }

    component ArrowButton: Rectangle {
        required property var theme
        property int direction: -1
        signal clicked()

        width: 32
        height: 32
        radius: 16
        color: theme.card
        border.color: theme.border
        border.width: 1

        Canvas {
            anchors.centerIn: parent
            width: 16
            height: 16
            property color strokeColor: theme.textSecondary

            onStrokeColorChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = strokeColor
                ctx.lineWidth = 1.7
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                if (direction < 0) {
                    ctx.moveTo(10, 4)
                    ctx.lineTo(6, 8)
                    ctx.lineTo(10, 12)
                } else {
                    ctx.moveTo(6, 4)
                    ctx.lineTo(10, 8)
                    ctx.lineTo(6, 12)
                }
                ctx.stroke()
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            onClicked: parent.clicked()
        }
    }
}
