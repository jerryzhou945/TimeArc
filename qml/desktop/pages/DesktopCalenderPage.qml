import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import QtCore

Item {
    id: root
    anchors.fill: parent
    clip: true

    signal startTodoProject(string projectName, string tagName, string dateKey, string linkedProjectName)

    property bool nightMode: false
    property color themeTextPrimary: "#4E342E"
    property color themeTextSecondary: "#9C806C"
    property color themePanelColor: "#FFFDF9"
    property color themeBorderColor: "#D8C2AC"
    property color themeAccentColor: "#E8C6A3"

    property color textPrimary: themeTextPrimary
    property color textSecondary: themeTextSecondary
    property color panelGlass: nightMode ? "#4A506F" : "#FFFDF9"
    property color cardGlass: nightMode ? "#525878" : "#FFF9F2"
    property color softBorder: nightMode ? "#7078A5" : "#E6D6C5"
    property color warmAccent: nightMode ? "#8E93D8" : "#E8C6A3"
    property color warmAccentDeep: nightMode ? "#D8D9FF" : "#A56D46"
    property color checkedColor: nightMode ? "#78C18A" : "#DDB892"
    property color fieldColor: nightMode ? "#59608A" : "#FFFDF9"
    property color fieldBorder: nightMode ? "#757CA6" : "#E8D8C8"
    property color buttonColor: nightMode ? "#8E93D8" : "#E8C6A3"
    property color buttonBorder: nightMode ? "#757ED0" : "#D5AE86"
    property color buttonText: nightMode ? "#F8F7FF" : "#6A4C3B"

    property date todayDate: new Date()
    property date viewedMonth: new Date(todayDate.getFullYear(), todayDate.getMonth(), 1)
    property string selectedDateKey: initialSelectedDateKey()
    property var calendarCells: buildCalendarCells()
    property var fixedTags: ["学习", "工作", "运动", "娱乐", "阅读", "社交", "生活", "其他"]
    property int projectRefreshKey: 0
    property string sidePanelMode: "tasks"

    Settings {
        id: chatSettings
        category: "DesktopChatPageData"
        property string savedChats: ""
    }

    ListModel {
        id: todoModel
    }

    function pad2(value) {
        return value < 10 ? "0" + value : "" + value
    }

    function dateKey(value) {
        return value.getFullYear() + "-" + pad2(value.getMonth() + 1) + "-" + pad2(value.getDate())
    }

    function initialSelectedDateKey() {
        if (calendarManager && calendarManager.selectedDateKey && calendarManager.selectedDateKey !== "")
            return calendarManager.selectedDateKey
        return dateKey(todayDate)
    }

    function dateFromKey(key) {
        var parts = key.split("-")
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
    }

    function selectedDateLabel() {
        var value = dateFromKey(selectedDateKey)
        var weeks = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return (value.getMonth() + 1) + "月" + value.getDate() + "日 " + weeks[value.getDay()]
    }

    function monthTitle() {
        return viewedMonth.getFullYear() + "年 " + (viewedMonth.getMonth() + 1) + "月"
    }

    function buildCalendarCells() {
        var cells = []
        var first = new Date(viewedMonth.getFullYear(), viewedMonth.getMonth(), 1)
        var start = new Date(first)
        start.setDate(first.getDate() - first.getDay())

        for (var i = 0; i < 42; i++) {
            var d = new Date(start)
            d.setDate(start.getDate() + i)
            var key = dateKey(d)
            cells.push({
                dateKey: key,
                day: d.getDate(),
                inMonth: d.getMonth() === viewedMonth.getMonth(),
                isToday: key === dateKey(todayDate),
                hasPhoto: backgroundForDate(key) !== ""
            })
        }
        return cells
    }

    function refreshCalendar() {
        calendarCells = buildCalendarCells()
    }

    function manualPhotoMap() {
        if (!calendarManager || !calendarManager.dayPhotos || calendarManager.dayPhotos === "")
            return {}
        try {
            return JSON.parse(calendarManager.dayPhotos)
        } catch (e) {
            return {}
        }
    }

    function chatImagesForDate(key) {
        if (!chatSettings.savedChats || chatSettings.savedChats === "")
            return []
        try {
            var chats = JSON.parse(chatSettings.savedChats)
            var result = []
            for (var i = 0; i < chats.length; i++) {
                var item = chats[i]
                if (item.imagePath && item.imagePath !== "" && item.timeText && item.timeText.indexOf(key) === 0)
                    result.push(item.imagePath)
            }
            return result
        } catch (e) {
            return []
        }
    }

    function backgroundForDate(key) {
        var manual = manualPhotoMap()
        if (manual[key] && manual[key] !== "")
            return manual[key]

        var images = chatImagesForDate(key)
        return images.length > 0 ? images[0] : ""
    }

    function setManualPhotoForSelectedDate(path) {
        var map = manualPhotoMap()
        map[selectedDateKey] = path
        if (calendarManager)
            calendarManager.setDayPhotos(JSON.stringify(map))
        refreshCalendar()
    }

    function allTodosMap() {
        if (!calendarManager || !calendarManager.savedTodos || calendarManager.savedTodos === "")
            return {}
        try {
            return JSON.parse(calendarManager.savedTodos)
        } catch (e) {
            return {}
        }
    }

    function saveTodosForSelectedDate() {
        var map = allTodosMap()
        var arr = []
        for (var i = 0; i < todoModel.count; i++) {
            var item = todoModel.get(i)
            arr.push({
                text: item.text,
                done: item.done,
                tag: item.tag ? item.tag : fixedTags[0],
                linkedProject: item.linkedProject ? item.linkedProject : ""
            })
        }
        map[selectedDateKey] = arr
        if (calendarManager)
            calendarManager.setSavedTodos(JSON.stringify(map))
    }

    function loadTodosForSelectedDate() {
        todoModel.clear()
        var map = allTodosMap()
        var arr = map[selectedDateKey] ? map[selectedDateKey] : []
        for (var i = 0; i < arr.length; i++)
            todoModel.append({
                text: arr[i].text,
                done: arr[i].done ? true : false,
                tag: arr[i].tag ? arr[i].tag : fixedTags[0],
                linkedProject: arr[i].linkedProject ? arr[i].linkedProject : ""
            })
    }

    function projectChoicesForTag(tag) {
        projectRefreshKey
        var choices = ["不关联"]
        if (!projectManager)
            return choices

        var list = projectManager.projectsForTag(tag, "all")
        for (var i = 0; i < list.length; i++)
            choices.push(list[i].name)
        return choices
    }

    function linkedProjectFromChoice(choice) {
        return choice === "不关联" ? "" : choice
    }

    function tagColor(tag) {
        if (tag === "学习") return "#B7A6F0"
        if (tag === "工作") return "#D7B79A"
        if (tag === "运动") return "#B4C986"
        if (tag === "娱乐") return "#DFA65F"
        if (tag === "阅读") return "#A9BFE6"
        if (tag === "社交") return "#C7ADD9"
        if (tag === "生活") return "#E2B6C3"
        return "#B7AEA6"
    }

    function addTodo() {
        var text = todoInput.text.trim()
        if (text.length === 0)
            return
        todoModel.append({
            text: text,
            done: false,
            tag: todoTagBox.currentText,
            linkedProject: linkedProjectFromChoice(todoProjectBox.currentText)
        })
        todoInput.text = ""
        todoProjectBox.currentIndex = 0
        saveTodosForSelectedDate()
    }

    function dayProjects() {
        if (!projectManager)
            return []
        var list = projectManager.timeEntriesForDate(selectedDateKey)
        var filtered = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].source === "calendar_todo" && (list[i].seconds ? list[i].seconds : 0) > 0)
                filtered.push(list[i])
        }
        filtered.sort(function(a, b) {
            return (b.seconds ? b.seconds : 0) - (a.seconds ? a.seconds : 0)
        })
        return filtered
    }

    function maxDaySeconds() {
        var list = dayProjects()
        return list.length > 0 ? Math.max(1, list[0].seconds ? list[0].seconds : 1) : 1
    }

    function previousMonth() {
        viewedMonth = new Date(viewedMonth.getFullYear(), viewedMonth.getMonth() - 1, 1)
        refreshCalendar()
    }

    function nextMonth() {
        viewedMonth = new Date(viewedMonth.getFullYear(), viewedMonth.getMonth() + 1, 1)
        refreshCalendar()
    }

    function selectDate(key) {
        selectedDateKey = key
        if (calendarManager)
            calendarManager.setSelectedDateKey(key)
        loadTodosForSelectedDate()
    }

    onNightModeChanged: refreshCalendar()

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 18

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 780
            radius: 30
            color: "transparent"
            border.width: 1
            border.color: themeBorderColor
            clip: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 29
                color: panelGlass
                opacity: nightMode ? 0.68 : 0.62
                z: -1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Column {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "日历"
                            color: textPrimary
                            font.pixelSize: 38
                            font.bold: true
                        }

                        Text {
                            text: "把每天的时间、照片和待办收在同一个地方"
                            color: textSecondary
                            font.pixelSize: 15
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 42
                        radius: 16
                        color: nightMode ? "#59608A" : "#F3E5D6"
                        border.width: 1
                        border.color: softBorder

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: warmAccentDeep
                            font.pixelSize: 26
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: previousMonth()
                        }
                    }

                    Text {
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignHCenter
                        text: monthTitle()
                        color: textPrimary
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 42
                        radius: 16
                        color: nightMode ? "#59608A" : "#F3E5D6"
                        border.width: 1
                        border.color: softBorder

                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            color: warmAccentDeep
                            font.pixelSize: 26
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: nextMonth()
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: ["日", "一", "二", "三", "四", "五", "六"]

                        delegate: Text {
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            text: modelData
                            color: textSecondary
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: calendarCells

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 72
                            radius: 20
                            color: modelData.dateKey === selectedDateKey
                                   ? (nightMode ? "#656DA2" : "#F0D8BF")
                                   : (nightMode ? "#525878" : "#FFF9F2")
                            opacity: modelData.inMonth ? 1.0 : 0.48
                            border.width: modelData.dateKey === selectedDateKey || modelData.isToday ? 2 : 1
                            border.color: modelData.dateKey === selectedDateKey
                                          ? (nightMode ? "#C3C8FF" : "#D7AC83")
                                          : (modelData.isToday ? warmAccentDeep : softBorder)
                            clip: true
                            scale: dayMouse.pressed ? 0.97 : 1.0

                            Behavior on scale {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }

                            Item {
                                id: dayPhotoLayer
                                anchors.fill: parent
                                visible: backgroundForDate(modelData.dateKey) !== ""
                                opacity: modelData.dateKey === selectedDateKey ? 0.72 : 0.52

                                Image {
                                    id: dayPhotoImage
                                    anchors.fill: parent
                                    source: backgroundForDate(modelData.dateKey)
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                    smooth: true
                                    asynchronous: true
                                }

                                Rectangle {
                                    id: dayPhotoMask
                                    anchors.fill: parent
                                    radius: 20
                                    visible: false
                                    layer.enabled: true
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: dayPhotoImage
                                    maskEnabled: true
                                    maskSource: dayPhotoMask
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 20
                                    color: "transparent"
                                    border.width: 1
                                    border.color: nightMode ? "#55FFFFFF" : "#88FFF7EF"
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: modelData.hasPhoto
                                       ? (nightMode ? "#66282D40" : "#55FFF7EF")
                                       : "transparent"
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.leftMargin: 12
                                anchors.topMargin: 10
                                text: modelData.day
                                color: textPrimary
                                font.pixelSize: 18
                                font.bold: modelData.dateKey === selectedDateKey || modelData.isToday
                            }

                            Rectangle {
                                visible: modelData.hasPhoto
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: 10
                                anchors.bottomMargin: 10
                                width: 8
                                height: 8
                                radius: 4
                                color: warmAccentDeep
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: selectDate(modelData.dateKey)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 390
            Layout.fillHeight: true
            radius: 30
            color: "transparent"
            border.width: 1
            border.color: themeBorderColor
            clip: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 29
                color: panelGlass
                opacity: nightMode ? 0.70 : 0.66
                z: -1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 168
                    radius: 24
                    color: cardGlass
                    border.width: 1
                    border.color: softBorder
                    clip: true

                    Item {
                        id: selectedPhotoLayer
                        anchors.fill: parent
                        visible: backgroundForDate(selectedDateKey) !== ""

                        Image {
                            id: selectedPhotoImage
                            anchors.fill: parent
                            source: backgroundForDate(selectedDateKey)
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                            smooth: true
                            asynchronous: true
                        }

                        Rectangle {
                            id: selectedPhotoMask
                            anchors.fill: parent
                            radius: 24
                            visible: false
                            layer.enabled: true
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: selectedPhotoImage
                            maskEnabled: true
                            maskSource: selectedPhotoMask
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 24
                            color: "transparent"
                            border.width: 1
                            border.color: nightMode ? "#66FFFFFF" : "#AAFFF7EF"
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: backgroundForDate(selectedDateKey) === ""
                               ? "transparent"
                               : (nightMode ? "#992F344D" : "#77FFF7EF")
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 18
                        spacing: 6

                        Text {
                            text: selectedDateLabel()
                            color: textPrimary
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Text {
                            text: backgroundForDate(selectedDateKey) === ""
                                  ? "这一天还没有照片背景"
                                  : "背景来自聊天图片或你手动选择的照片"
                            color: textSecondary
                            font.pixelSize: 13
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: choosePhotoButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        text: "给这天换张照片"
                        onClicked: dayPhotoDialog.open()

                        contentItem: Text {
                            text: choosePhotoButton.text
                            color: buttonText
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 16
                            color: choosePhotoButton.down
                                   ? (nightMode ? "#7F85C5" : "#DAB188")
                                   : buttonColor
                            border.width: 1
                            border.color: buttonBorder

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 15
                                color: "#FFFFFF"
                                opacity: nightMode ? 0.07 : 0.18
                            }
                        }
                    }

                    Button {
                        id: todayButton
                        Layout.preferredWidth: 92
                        Layout.preferredHeight: 42
                        text: "回今天"
                        onClicked: {
                            viewedMonth = new Date(todayDate.getFullYear(), todayDate.getMonth(), 1)
                            selectedDateKey = dateKey(todayDate)
                            if (calendarManager)
                                calendarManager.setSelectedDateKey(selectedDateKey)
                            refreshCalendar()
                            loadTodosForSelectedDate()
                        }

                        contentItem: Text {
                            text: todayButton.text
                            color: warmAccentDeep
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 16
                            color: todayButton.down
                                   ? (nightMode ? "#525878" : "#EDDCCB")
                                   : (nightMode ? "#59608A" : "#FFF9F2")
                            border.width: 1
                            border.color: softBorder
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    spacing: 10

                    Repeater {
                        model: [
                            { key: "tasks", title: "当天任务记录" },
                            { key: "todos", title: "今日待办" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 16
                            color: sidePanelMode === modelData.key
                                   ? buttonColor
                                   : (nightMode ? "#59608A" : "#FFF9F2")
                            border.width: 1
                            border.color: sidePanelMode === modelData.key
                                          ? buttonBorder
                                          : softBorder
                            scale: tabMouse.pressed ? 0.98 : 1.0

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            Behavior on scale {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.title
                                color: sidePanelMode === modelData.key ? buttonText : warmAccentDeep
                                font.pixelSize: 14
                                font.bold: true
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: sidePanelMode = modelData.key
                            }
                        }
                    }
                }

                Rectangle {
                    visible: sidePanelMode === "tasks"
                    Layout.fillWidth: true
                    Layout.fillHeight: visible
                    Layout.preferredHeight: visible ? -1 : 0
                    Layout.minimumHeight: visible ? 120 : 0
                    Layout.maximumHeight: visible ? Number.POSITIVE_INFINITY : 0
                    radius: 24
                    color: cardGlass
                    border.width: 1
                    border.color: softBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: "当天任务记录"
                            color: textPrimary
                            font.pixelSize: 23
                            font.bold: true
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 10
                            model: dayProjects()

                            delegate: Column {
                                required property var modelData
                                width: ListView.view.width
                                height: 56
                                spacing: 6

                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    color: textPrimary
                                    font.pixelSize: 15
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Row {
                                    width: parent.width

                                    Text {
                                        width: parent.width - 92
                                        text: modelData.tag
                                              + (modelData.linkedProjectName && modelData.linkedProjectName !== "" ? " · 关联 " + modelData.linkedProjectName : "")
                                        color: textSecondary
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: 92
                                        horizontalAlignment: Text.AlignRight
                                        text: modelData.time
                                        color: warmAccentDeep
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 8
                                    radius: 4
                                    color: nightMode ? "#6D7297" : "#EFE1D0"

                                    Rectangle {
                                        width: parent.width * ((modelData.seconds ? modelData.seconds : 0) / maxDaySeconds())
                                        height: parent.height
                                        radius: 4
                                        color: tagColor(modelData.tag)
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: dayProjects().length === 0
                            text: "这一天还没有便笺任务计时记录。"
                            color: textSecondary
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Rectangle {
                    visible: sidePanelMode === "todos"
                    Layout.fillWidth: true
                    Layout.fillHeight: visible
                    Layout.preferredHeight: visible ? -1 : 0
                    Layout.minimumHeight: visible ? 160 : 0
                    Layout.maximumHeight: visible ? Number.POSITIVE_INFINITY : 0
                    radius: 24
                    color: cardGlass
                    border.width: 1
                    border.color: softBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        Text {
                            text: "今日待办"
                            color: textPrimary
                            font.pixelSize: 23
                            font.bold: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TextField {
                                    id: todoInput
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 42
                                    placeholderText: "添加一件今天想做的事"
                                    placeholderTextColor: textSecondary
                                    color: textPrimary
                                    font.pixelSize: 14
                                    leftPadding: 14
                                    rightPadding: 14
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    onAccepted: addTodo()

                                    background: Rectangle {
                                        radius: 15
                                        color: fieldColor
                                        border.width: 1
                                        border.color: fieldBorder

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: 14
                                            color: "#FFFFFF"
                                            opacity: nightMode ? 0.04 : 0.14
                                        }
                                    }
                                }

                                ComboBox {
                                    id: todoTagBox
                                    Layout.preferredWidth: 92
                                    Layout.preferredHeight: 42
                                    model: fixedTags
                                    currentIndex: 0
                                    onCurrentTextChanged: todoProjectBox.currentIndex = 0
                                    hoverEnabled: true
                                    scale: pressed ? 0.97 : 1.0

                                    Behavior on scale {
                                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                    }

                                    contentItem: Text {
                                        leftPadding: 14
                                        rightPadding: 30
                                        text: todoTagBox.displayText
                                        color: textPrimary
                                        font.pixelSize: 14
                                        font.bold: true
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    indicator: Text {
                                        x: todoTagBox.width - width - 12
                                        y: Math.round((todoTagBox.height - height) / 2)
                                        text: "▾"
                                        color: warmAccentDeep
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    background: Rectangle {
                                        radius: 15
                                        color: todoTagBox.pressed
                                               ? (nightMode ? "#4F567C" : "#EED8C0")
                                               : (todoTagBox.hovered || todoTagBox.popup.visible
                                                  ? (nightMode ? "#626994" : "#FFF6EC")
                                                  : fieldColor)
                                        border.width: 1
                                        border.color: todoTagBox.hovered || todoTagBox.pressed || todoTagBox.popup.visible || todoTagBox.visualFocus
                                                      ? warmAccentDeep
                                                      : fieldBorder

                                        Behavior on color {
                                            ColorAnimation { duration: 120 }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 120 }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: 14
                                            color: "#FFFFFF"
                                            opacity: nightMode ? 0.04 : 0.14
                                        }
                                    }

                                    delegate: ItemDelegate {
                                        width: todoTagBox.width
                                        height: 36

                                        contentItem: Text {
                                            text: modelData
                                            color: textPrimary
                                            font.pixelSize: 14
                                            font.bold: todoTagBox.currentText === modelData
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        background: Rectangle {
                                            radius: 10
                                            color: highlighted
                                                   ? (nightMode ? "#656DA2" : "#F0D8BF")
                                                   : "transparent"
                                        }
                                    }

                                    popup: Popup {
                                        y: todoTagBox.height + 6
                                        width: todoTagBox.width
                                        implicitHeight: Math.min(contentItem.implicitHeight + 12, 220)
                                        padding: 6

                                        background: Rectangle {
                                            radius: 16
                                            color: nightMode ? "#4A506F" : "#FFFDF9"
                                            border.width: 1
                                            border.color: softBorder
                                        }

                                        contentItem: ListView {
                                            clip: true
                                            implicitHeight: contentHeight
                                            model: todoTagBox.popup.visible ? todoTagBox.delegateModel : null
                                            currentIndex: todoTagBox.highlightedIndex
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                ComboBox {
                                    id: todoProjectBox
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    model: projectChoicesForTag(todoTagBox.currentText)
                                    hoverEnabled: true
                                    scale: pressed ? 0.98 : 1.0

                                    Behavior on scale {
                                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                    }

                                    contentItem: Text {
                                        leftPadding: 14
                                        rightPadding: 30
                                        text: todoProjectBox.displayText
                                        color: textPrimary
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    indicator: Text {
                                        x: todoProjectBox.width - width - 12
                                        y: Math.round((todoProjectBox.height - height) / 2)
                                        text: "▾"
                                        color: warmAccentDeep
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    background: Rectangle {
                                        radius: 15
                                        color: todoProjectBox.pressed
                                               ? (nightMode ? "#4F567C" : "#EED8C0")
                                               : (todoProjectBox.hovered || todoProjectBox.popup.visible
                                                  ? (nightMode ? "#626994" : "#FFF6EC")
                                                  : fieldColor)
                                        border.width: 1
                                        border.color: todoProjectBox.hovered || todoProjectBox.pressed || todoProjectBox.popup.visible || todoProjectBox.visualFocus
                                                      ? warmAccentDeep
                                                      : fieldBorder

                                        Behavior on color {
                                            ColorAnimation { duration: 120 }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 120 }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: 14
                                            color: "#FFFFFF"
                                            opacity: nightMode ? 0.04 : 0.14
                                        }
                                    }

                                    delegate: ItemDelegate {
                                        width: todoProjectBox.width
                                        height: 36

                                        contentItem: Text {
                                            text: modelData
                                            color: textPrimary
                                            font.pixelSize: 14
                                            font.bold: todoProjectBox.currentText === modelData
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        background: Rectangle {
                                            radius: 10
                                            color: highlighted
                                                   ? (nightMode ? "#656DA2" : "#F0D8BF")
                                                   : "transparent"
                                        }
                                    }

                                    popup: Popup {
                                        y: todoProjectBox.height + 6
                                        width: todoProjectBox.width
                                        implicitHeight: Math.min(contentItem.implicitHeight + 12, 220)
                                        padding: 6

                                        background: Rectangle {
                                            radius: 16
                                            color: nightMode ? "#4A506F" : "#FFFDF9"
                                            border.width: 1
                                            border.color: softBorder
                                        }

                                        contentItem: ListView {
                                            clip: true
                                            implicitHeight: contentHeight
                                            model: todoProjectBox.popup.visible ? todoProjectBox.delegateModel : null
                                            currentIndex: todoProjectBox.highlightedIndex
                                        }
                                    }
                                }

                                Button {
                                    id: addTodoButton
                                    Layout.preferredWidth: 82
                                    Layout.preferredHeight: 38
                                    text: "添加"
                                    onClicked: addTodo()

                                    contentItem: Text {
                                        text: addTodoButton.text
                                        color: buttonText
                                        font.pixelSize: 14
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    background: Rectangle {
                                        radius: 15
                                        color: addTodoButton.down
                                               ? (nightMode ? "#7F85C5" : "#DAB188")
                                               : buttonColor
                                        border.width: 1
                                        border.color: buttonBorder

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: 14
                                            color: "#FFFFFF"
                                            opacity: nightMode ? 0.07 : 0.18
                                        }
                                    }
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            model: todoModel

                            delegate: Rectangle {
                                id: todoDelegate
                                required property int index
                                required property string text
                                required property bool done
                                required property string tag
                                required property string linkedProject

                                width: ListView.view.width
                                height: 58
                                radius: 16
                                color: nightMode ? "#59608A" : "#FFFDF9"
                                border.width: 1
                                border.color: softBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 10
                                    spacing: 6

                                    CheckBox {
                                        checked: done
                                        onToggled: {
                                            todoModel.setProperty(index, "done", checked)
                                            saveTodosForSelectedDate()
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: parent.parent.text + " · " + parent.parent.tag
                                              + (parent.parent.linkedProject !== "" ? " · 关联 " + parent.parent.linkedProject : "")
                                        color: done ? textSecondary : textPrimary
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                        font.strikeout: done
                                    }

                                    Rectangle {
                                        visible: !done
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 32
                                        radius: 12
                                        color: buttonColor
                                        border.width: 1
                                        border.color: buttonBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: "开始"
                                            color: buttonText
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: startTodoProject(todoDelegate.text, todoDelegate.tag, selectedDateKey, todoDelegate.linkedProject)
                                        }
                                    }

                                    Text {
                                        text: "×"
                                        color: warmAccentDeep
                                        font.pixelSize: 18
                                        font.bold: true

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                todoModel.remove(index)
                                                saveTodosForSelectedDate()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: todoModel.count === 0
                            Layout.fillWidth: true
                            text: "还没有待办，给这一天留一张小便笺吧。"
                            color: textSecondary
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: dayPhotoDialog
        title: "选择这一天的背景照片"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp *.webp)"]

        onAccepted: {
            setManualPhotoForSelectedDate(selectedFile.toString())
        }
    }

    Connections {
        target: projectManager

        function onProjectsChanged() {
            projectRefreshKey += 1
            refreshCalendar()
        }
    }

    Connections {
        target: calendarManager

        function onCalendarDataChanged() {
            loadTodosForSelectedDate()
            refreshCalendar()
        }
    }

    Component.onCompleted: {
        var selected = dateFromKey(selectedDateKey)
        if (!isNaN(selected.getTime()))
            viewedMonth = new Date(selected.getFullYear(), selected.getMonth(), 1)
        loadTodosForSelectedDate()
        refreshCalendar()
    }
}
