import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import QtCore
import "../components"

Item {
    id: root
    anchors.fill: parent
    clip: true

    signal startTodoProject(string projectName, string tagName, string dateKey, string linkedProjectName)

    property bool nightMode: false
    property color themeTextPrimary: "#2D2724"
    property color themeTextSecondary: "#7C746D"
    property color themePanelColor: "#FBF8F4"
    property color themeBorderColor: "#E8E0D8"
    property color themeAccentColor: "#CFE8D8"

    property color textPrimary: themeTextPrimary
    property color textSecondary: themeTextSecondary
    property color cardColor: nightMode ? "#3E465F" : "#FFFDF9"
    property color cardSoft: nightMode ? "#454D68" : "#F7F3EE"
    property color panelColor: nightMode ? "#353C55" : "#FBF8F4"
    property color mint: nightMode ? "#7780B5" : "#CFE8D8"
    property color lightMint: nightMode ? "#596184" : "#DDF1E5"
    property color cream: nightMode ? "#555A78" : "#F4E8C8"
    property color blush: nightMode ? "#65536A" : "#EBC9CF"
    property color lavender: nightMode ? "#60668C" : "#D9D0F2"
    property color borderColor: nightMode ? "#626A90" : "#E8E0D8"
    property color softBorder: nightMode ? "#737BA4" : "#EFE7DE"
    property color shadowColor: nightMode ? "#05070D" : "#BFAE9D"
    property color fieldColor: nightMode ? "#4A526F" : "#FFFDF9"
    property color primaryButton: nightMode ? "#8E93D8" : "#1F1A17"
    property color primaryButtonHover: nightMode ? "#9AA0E7" : "#332C27"
    property color accentText: nightMode ? "#DADDFD" : "#2F7A5B"

    property date todayDate: new Date()
    property date viewedMonth: new Date(todayDate.getFullYear(), todayDate.getMonth(), 1)
    property string selectedDateKey: initialSelectedDateKey()
    property var calendarCells: []
    property var fixedTags: ["学习", "工作", "运动", "娱乐", "阅读", "社交", "生活", "其他"]
    property int projectRefreshKey: 0
    property string sidePanelMode: "tasks"

    Settings {
        id: anniversarySettings
        category: "DesktopCalendarAnniversaryData"
        property string savedAnniversaries: ""
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
                hasPhoto: backgroundForDate(key) !== "",
                todoCount: todoCountForDate(key),
                doneCount: doneCountForDate(key),
                anniversaryCount: anniversaryCountForDate(key),
                countdownCount: countdownCountForDate(key)
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
        var savedChats = settingsRepository ? settingsRepository.getValue("local_memo_chat_messages", "") : ""
        if (!savedChats || savedChats === "")
            return []
        try {
            var chats = JSON.parse(savedChats)
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

    function selectedPhotoSource() {
        return backgroundForDate(selectedDateKey)
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

    function todosForDate(key) {
        var map = allTodosMap()
        return map[key] ? map[key] : []
    }

    function todoCountForDate(key) {
        return todosForDate(key).length
    }

    function doneCountForDate(key) {
        var arr = todosForDate(key)
        var done = 0
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].done)
                done += 1
        }
        return done
    }

    function allAnniversaries() {
        if (!anniversarySettings.savedAnniversaries || anniversarySettings.savedAnniversaries === "")
            return []
        try {
            var arr = JSON.parse(anniversarySettings.savedAnniversaries)
            return arr ? arr : []
        } catch (e) {
            return []
        }
    }

    function saveAnniversaries(list) {
        anniversarySettings.savedAnniversaries = JSON.stringify(list)
        refreshCalendar()
    }

    function anniversariesForDate(key) {
        var list = allAnniversaries()
        var result = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].dateKey === key)
                result.push(list[i])
        }
        return result
    }

    function anniversaryCountForDate(key) {
        return anniversariesForDate(key).length
    }

    function countdownCountForDate(key) {
        var list = anniversariesForDate(key)
        var count = 0
        for (var i = 0; i < list.length; i++) {
            if (anniversaryKind(list[i]) === "countdown")
                count += 1
        }
        return count
    }

    function anniversaryTypeFromText(text) {
        return text.indexOf("倒计时") >= 0 ? "countdown" : "since"
    }

    function anniversaryKind(item) {
        return item.type === "countdown" || item.type === "yearly" ? "countdown" : "since"
    }

    function addAnniversary() {
        var title = anniversaryTitleInput.text.trim()
        if (title.length === 0)
            return

        var list = allAnniversaries()
        list.push({
            id: selectedDateKey + "-" + Date.now() + "-" + Math.floor(Math.random() * 10000),
            title: title,
            dateKey: selectedDateKey,
            type: anniversaryTypeFromText(anniversaryTypeBox.currentText)
        })
        anniversaryTitleInput.text = ""
        saveAnniversaries(list)
    }

    function removeAnniversaryById(id) {
        var list = allAnniversaries()
        var result = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== id)
                result.push(list[i])
        }
        saveAnniversaries(result)
    }

    function normalizedDate(value) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate())
    }

    function daysBetween(start, end) {
        var a = normalizedDate(start)
        var b = normalizedDate(end)
        return Math.round((b.getTime() - a.getTime()) / 86400000)
    }

    function anniversaryStatus(item) {
        if (anniversaryKind(item) === "countdown") {
            var left = daysBetween(todayDate, dateFromKey(item.dateKey))
            if (left > 0)
                return "还有 " + left + " 天"
            if (left === 0)
                return "今天"
            return "已过去 " + Math.abs(left) + " 天"
        }

        var passed = daysBetween(dateFromKey(item.dateKey), todayDate)
        if (passed >= 0)
            return "已经 " + passed + " 天"
        return "还有 " + Math.abs(passed) + " 天开始"
    }

    function anniversarySubtitle(item) {
        if (anniversaryKind(item) === "countdown")
            return "目标日 · " + item.dateKey
        return "从 " + item.dateKey + " 开始"
    }

    function anniversaryColor(type) {
        return anniversaryKind({ type: type }) === "countdown" ? lavender : blush
    }

    function anniversarySortValue(item) {
        if (anniversaryKind(item) === "countdown") {
            var left = daysBetween(todayDate, dateFromKey(item.dateKey))
            return left >= 0 ? left : 100000 + Math.abs(left)
        }

        return 200000 + Math.abs(daysBetween(dateFromKey(item.dateKey), todayDate))
    }

    function sortedAnniversaries() {
        var list = allAnniversaries().slice()
        list.sort(function(a, b) {
            return anniversarySortValue(a) - anniversarySortValue(b)
        })
        return list
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
        refreshCalendar()
    }

    function loadTodosForSelectedDate() {
        todoModel.clear()
        var arr = todosForDate(selectedDateKey)
        for (var i = 0; i < arr.length; i++) {
            todoModel.append({
                text: arr[i].text,
                done: arr[i].done ? true : false,
                tag: arr[i].tag ? arr[i].tag : fixedTags[0],
                linkedProject: arr[i].linkedProject ? arr[i].linkedProject : ""
            })
        }
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
        if (tag === "学习") return "#D9D0F2"
        if (tag === "工作") return "#EFDCC3"
        if (tag === "运动") return "#CFE8D8"
        if (tag === "娱乐") return "#EBC9CF"
        if (tag === "阅读") return "#BFD7EA"
        if (tag === "社交") return "#E7D4EA"
        if (tag === "生活") return "#DDF1E5"
        return "#D8D1CA"
    }

    function tagIcon(tag) {
        if (tag === "学习") return "✦"
        if (tag === "工作") return "▣"
        if (tag === "运动") return "●"
        if (tag === "娱乐") return "★"
        if (tag === "阅读") return "✎"
        if (tag === "社交") return "♥"
        if (tag === "生活") return "☀"
        return "•"
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
        projectRefreshKey
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

    function secondsToDisplay(seconds) {
        var total = Math.max(0, Math.floor(seconds ? seconds : 0))
        if (total <= 0)
            return "0m"
        if (total < 60)
            return "<1m"
        var h = Math.floor(total / 3600)
        var m = Math.floor((total % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    function selectedDateTotalSeconds() {
        var list = dayProjects()
        var total = 0
        for (var i = 0; i < list.length; i++)
            total += list[i].seconds ? list[i].seconds : 0
        return total
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

    Rectangle {
        anchors.fill: parent
        radius: 28
        gradient: Gradient {
            GradientStop { position: 0.0; color: nightMode ? "#30364D" : "#E8F4EC" }
            GradientStop { position: 0.58; color: nightMode ? "#353C55" : "#F7F3EE" }
            GradientStop { position: 1.0; color: nightMode ? "#3E465F" : "#F4E8C8" }
        }
        opacity: nightMode ? 0.24 : 0.44
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 112
            radius: 32
            color: "transparent"
            border.width: 1
            border.color: nightMode ? "#697195" : "#D8E7DC"

            Rectangle {
                x: 0
                y: 9
                width: parent.width
                height: parent.height
                radius: parent.radius
                color: shadowColor
                opacity: nightMode ? 0.16 : 0.08
                z: -2
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 31
                gradient: Gradient {
                    GradientStop { position: 0.0; color: nightMode ? "#495170" : "#CFE8D8" }
                    GradientStop { position: 1.0; color: nightMode ? "#383E57" : "#F4E8C8" }
                }
                opacity: nightMode ? 0.88 : 0.96
                z: -1
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "日历"
                        color: textPrimary
                        font.pixelSize: 34
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "按日期整理待办、照片和计时记录"
                        color: textSecondary
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }

                SoftButton {
                    text: "‹"
                    implicitWidth: 44
                    implicitHeight: 42
                    radius: 16
                    fillColor: nightMode ? "#4A526F" : "#FFFDF9"
                    hoverColor: nightMode ? "#596184" : "#F7F3EE"
                    strokeColor: softBorder
                    strokeWidth: 1
                    textColor: textPrimary
                    fontSize: 20
                    onClicked: previousMonth()
                }

                Text {
                    Layout.preferredWidth: 158
                    horizontalAlignment: Text.AlignHCenter
                    text: monthTitle()
                    color: textPrimary
                    font.pixelSize: 20
                    font.bold: true
                }

                SoftButton {
                    text: "›"
                    implicitWidth: 44
                    implicitHeight: 42
                    radius: 16
                    fillColor: nightMode ? "#4A526F" : "#FFFDF9"
                    hoverColor: nightMode ? "#596184" : "#F7F3EE"
                    strokeColor: softBorder
                    strokeWidth: 1
                    textColor: textPrimary
                    fontSize: 20
                    onClicked: nextMonth()
                }

                SoftButton {
                    text: "今天"
                    implicitWidth: 74
                    implicitHeight: 42
                    radius: 16
                    fillColor: primaryButton
                    hoverColor: primaryButtonHover
                    textColor: "#FFFDF9"
                    fontSize: 14
                    onClicked: {
                        viewedMonth = new Date(todayDate.getFullYear(), todayDate.getMonth(), 1)
                        selectDate(dateKey(todayDate))
                        refreshCalendar()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            SoftCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 780
                radius: 30
                padding: 20
                fillColor: cardColor
                fillOpacity: nightMode ? 0.74 : 0.86
                strokeColor: borderColor
                shadowColor: shadowColor
                shadowOpacity: nightMode ? 0.16 : 0.08

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: ["日", "一", "二", "三", "四", "五", "六"]

                            delegate: Text {
                                required property string modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                text: modelData
                                color: textSecondary
                                font.pixelSize: 13
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: calendarCells

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 62
                                radius: 18
                                color: modelData.hasPhoto
                                       ? cardSoft
                                       : (modelData.dateKey === selectedDateKey
                                          ? lightMint
                                          : (modelData.isToday ? cream : cardSoft))
                                opacity: modelData.inMonth ? 1.0 : 0.42
                                border.width: modelData.dateKey === selectedDateKey || modelData.isToday ? 1 : 0
                                border.color: modelData.dateKey === selectedDateKey ? "#BFDCCB" : softBorder
                                clip: true

                                Image {
                                    id: dayPhotoSource
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
                                    radius: parent.radius
                                    visible: false
                                    layer.enabled: true
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: dayPhotoSource
                                    visible: modelData.hasPhoto
                                    maskEnabled: true
                                    maskSource: dayPhotoMask
                                    opacity: nightMode ? 0.82 : 0.96
                                }

                                Rectangle {
                                    visible: modelData.hasPhoto
                                    anchors.fill: parent
                                    radius: parent.radius
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.0
                                            color: nightMode ? "#2230364D" : "#12FFFDF9"
                                        }
                                        GradientStop {
                                            position: 0.48
                                            color: modelData.dateKey === selectedDateKey
                                                   ? (nightMode ? "#334A526F" : "#26DDF1E5")
                                                   : (nightMode ? "#2A3E465F" : "#22FBF8F4")
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: nightMode ? "#5530364D" : "#3AF7F3EE"
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: modelData.hasPhoto && (modelData.dateKey === selectedDateKey || modelData.isToday)
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: parent.radius - 1
                                    color: "transparent"
                                    border.width: 1
                                    border.color: modelData.dateKey === selectedDateKey ? "#99BFDCCB" : "#99F4E8C8"
                                }

                                Rectangle {
                                    visible: dayMouse.containsMouse
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "#FFFFFF"
                                    opacity: nightMode ? 0.05 : 0.24
                                }

                                Rectangle {
                                    anchors.left: dayNumber.left
                                    anchors.right: dayNumber.right
                                    anchors.top: dayNumber.top
                                    anchors.bottom: dayNumber.bottom
                                    anchors.margins: -5
                                    radius: 9
                                    color: modelData.hasPhoto ? (nightMode ? "#AA30364D" : "#CCFFFDF9") : "transparent"
                                    border.width: modelData.hasPhoto ? 1 : 0
                                    border.color: nightMode ? "#33596084" : "#66E8E0D8"
                                }

                                Text {
                                    id: dayNumber
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.leftMargin: 11
                                    anchors.topMargin: 9
                                    text: modelData.day
                                    color: textPrimary
                                    font.pixelSize: 17
                                    font.bold: modelData.dateKey === selectedDateKey || modelData.isToday
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: 9
                                    anchors.bottomMargin: 9
                                    spacing: 5

                                    Rectangle {
                                        visible: modelData.todoCount > 0
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: modelData.doneCount === modelData.todoCount ? mint : blush

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.todoCount
                                            color: textPrimary
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        visible: modelData.anniversaryCount > 0
                                        width: 22
                                        height: 18
                                        radius: 9
                                        color: modelData.countdownCount > 0 ? lavender : blush
                                        border.width: 1
                                        border.color: nightMode ? "#668E93D8" : "#99FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.countdownCount > 0 ? "倒" : "纪"
                                            color: textPrimary
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        visible: modelData.hasPhoto
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: nightMode ? "#AA596184" : "#CCFFFDF9"
                                        border.width: 1
                                        border.color: nightMode ? "#809AA0E7" : "#D8E8E0D8"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
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

            SoftCard {
                Layout.preferredWidth: 372
                Layout.fillHeight: true
                radius: 30
                padding: 20
                fillColor: cardColor
                fillOpacity: nightMode ? 0.76 : 0.88
                strokeColor: borderColor
                shadowColor: shadowColor
                shadowOpacity: nightMode ? 0.16 : 0.08

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 154
                        radius: 24
                        color: cardSoft
                        border.width: 1
                        border.color: softBorder
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: selectedPhotoSource()
                            fillMode: Image.PreserveAspectCrop
                            visible: selectedPhotoSource() !== ""
                            opacity: nightMode ? 0.56 : 0.48
                            smooth: true
                            asynchronous: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: nightMode ? "#66454D68" : "#22FFFFFF" }
                                GradientStop { position: 1.0; color: nightMode ? "#DD30364D" : "#EEFFFDF9" }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: selectedDateLabel()
                                        color: textPrimary
                                        font.pixelSize: 24
                                        font.bold: true
                                    }

                                    Text {
                                        text: selectedDateKey
                                        color: textSecondary
                                        font.pixelSize: 12
                                    }
                                }

                                SoftPill {
                                    compact: true
                                    title: ""
                                    value: secondsToDisplay(selectedDateTotalSeconds())
                                    iconText: "T"
                                    fillColor: nightMode ? "#4A526F" : "#FFFDF9"
                                    strokeColor: softBorder
                                    accentColor: mint
                                    valueColor: textPrimary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SoftButton {
                                    Layout.fillWidth: true
                                    text: selectedPhotoSource() === "" ? "添加照片" : "更换照片"
                                    iconText: "+"
                                    implicitHeight: 38
                                    radius: 15
                                    fillColor: nightMode ? "#4A526F" : "#FFFDF9"
                                    hoverColor: nightMode ? "#596184" : "#F7F3EE"
                                    strokeColor: softBorder
                                    strokeWidth: 1
                                    textColor: textPrimary
                                    fontSize: 13
                                    onClicked: dayPhotoDialog.open()
                                }

                                SoftPill {
                                    compact: true
                                    title: "待办"
                                    value: doneCountForDate(selectedDateKey) + "/" + todoModel.count
                                    iconText: "✓"
                                    fillColor: nightMode ? "#4A526F" : "#FFFDF9"
                                    strokeColor: softBorder
                                    accentColor: lightMint
                                    titleColor: textSecondary
                                    valueColor: textPrimary
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 18
                        color: cardSoft
                        border.width: 1
                        border.color: softBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 5

                            Repeater {
                                model: [
                                    { key: "tasks", label: "待办" },
                                    { key: "records", label: "记录" },
                                    { key: "anniversaries", label: "纪念" }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: sidePanelMode === modelData.key ? primaryButton : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: sidePanelMode === modelData.key ? "#FFFDF9" : textSecondary
                                        font.pixelSize: 14
                                        font.bold: sidePanelMode === modelData.key
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: sidePanelMode = modelData.key
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        visible: sidePanelMode === "tasks"

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 136
                            radius: 22
                            color: cardSoft
                            border.width: 1
                            border.color: softBorder

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                TextField {
                                    id: todoInput
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    placeholderText: "添加这一天的待办"
                                    placeholderTextColor: textSecondary
                                    color: textPrimary
                                    font.pixelSize: 14
                                    selectByMouse: true
                                    background: Rectangle {
                                        radius: 15
                                        color: fieldColor
                                        border.width: 1
                                        border.color: softBorder
                                    }
                                    Keys.onReturnPressed: addTodo()
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    ComboBox {
                                        id: todoTagBox
                                        Layout.preferredWidth: 88
                                        Layout.preferredHeight: 38
                                        model: fixedTags
                                        currentIndex: 0
                                        onCurrentTextChanged: todoProjectBox.currentIndex = 0

                                        contentItem: Text {
                                            leftPadding: 12
                                            rightPadding: 26
                                            text: todoTagBox.displayText
                                            color: textPrimary
                                            font.pixelSize: 13
                                            font.bold: true
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        background: Rectangle {
                                            radius: 15
                                            color: fieldColor
                                            border.width: 1
                                            border.color: softBorder
                                        }
                                    }

                                    ComboBox {
                                        id: todoProjectBox
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        model: projectChoicesForTag(todoTagBox.currentText)

                                        contentItem: Text {
                                            leftPadding: 12
                                            rightPadding: 26
                                            text: todoProjectBox.displayText
                                            color: textPrimary
                                            font.pixelSize: 13
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        background: Rectangle {
                                            radius: 15
                                            color: fieldColor
                                            border.width: 1
                                            border.color: softBorder
                                        }
                                    }

                                    SoftButton {
                                        text: "添加"
                                        implicitWidth: 70
                                        implicitHeight: 38
                                        radius: 15
                                        fillColor: primaryButton
                                        hoverColor: primaryButtonHover
                                        textColor: "#FFFDF9"
                                        fontSize: 13
                                        onClicked: addTodo()
                                    }
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 9
                            model: todoModel

                            delegate: Rectangle {
                                id: todoDelegate

                                required property int index
                                required property string text
                                required property bool done
                                required property string tag
                                required property string linkedProject

                                width: ListView.view.width
                                height: 64
                                radius: 20
                                color: cardSoft
                                border.width: 1
                                border.color: softBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    CheckBox {
                                        checked: todoDelegate.done
                                        onToggled: {
                                            todoModel.setProperty(todoDelegate.index, "done", checked)
                                            saveTodosForSelectedDate()
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 15
                                        color: tagColor(todoDelegate.tag)

                                        Text {
                                            anchors.centerIn: parent
                                            text: tagIcon(todoDelegate.tag)
                                            color: textPrimary
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: todoDelegate.text
                                            color: todoDelegate.done ? textSecondary : textPrimary
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                            font.strikeout: todoDelegate.done
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: todoDelegate.tag + (todoDelegate.linkedProject !== "" ? " · " + todoDelegate.linkedProject : "")
                                            color: textSecondary
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    SoftButton {
                                        visible: !todoDelegate.done
                                        text: "开始"
                                        implicitWidth: 58
                                        implicitHeight: 32
                                        radius: 13
                                        fillColor: primaryButton
                                        hoverColor: primaryButtonHover
                                        textColor: "#FFFDF9"
                                        fontSize: 12
                                        onClicked: startTodoProject(todoDelegate.text, todoDelegate.tag, selectedDateKey, todoDelegate.linkedProject)
                                    }

                                    Text {
                                        text: "×"
                                        color: textSecondary
                                        font.pixelSize: 18
                                        font.bold: true

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                todoModel.remove(todoDelegate.index)
                                                saveTodosForSelectedDate()
                                            }
                                        }
                                    }
                                }
                            }

                            footer: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: todoModel.count === 0 ? 96 : 0

                                Text {
                                    anchors.centerIn: parent
                                    visible: todoModel.count === 0
                                    text: "还没有待办"
                                    color: textSecondary
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        visible: sidePanelMode === "records"

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 10
                            model: dayProjects()

                            delegate: Rectangle {
                                required property var modelData

                                width: ListView.view.width
                                height: 76
                                radius: 20
                                color: cardSoft
                                border.width: 1
                                border.color: softBorder

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 13
                                    spacing: 7

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title ? modelData.title : modelData.name
                                            color: textPrimary
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: secondsToDisplay(modelData.seconds)
                                            color: accentText
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 7
                                        radius: 4
                                        color: nightMode ? "#596184" : "#EFE7DE"
                                        clip: true

                                        Rectangle {
                                            width: parent.width * ((modelData.seconds ? modelData.seconds : 0) / Math.max(1, maxDaySeconds()))
                                            height: parent.height
                                            radius: 4
                                            color: tagColor(modelData.tag)
                                        }
                                    }
                                }
                            }

                            footer: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: dayProjects().length === 0 ? 120 : 0

                                Text {
                                    anchors.centerIn: parent
                                    visible: dayProjects().length === 0
                                    text: "这一天还没有计时记录"
                                    color: textSecondary
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        visible: sidePanelMode === "anniversaries"

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 112
                            radius: 22
                            color: cardSoft
                            border.width: 1
                            border.color: softBorder

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                TextField {
                                    id: anniversaryTitleInput
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    placeholderText: "添加纪念日名称"
                                    placeholderTextColor: textSecondary
                                    color: textPrimary
                                    font.pixelSize: 14
                                    selectByMouse: true
                                    background: Rectangle {
                                        radius: 15
                                        color: fieldColor
                                        border.width: 1
                                        border.color: softBorder
                                    }
                                    Keys.onReturnPressed: addAnniversary()
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    ComboBox {
                                        id: anniversaryTypeBox
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        model: ["纪念日", "倒计时日"]

                                        contentItem: Text {
                                            leftPadding: 12
                                            rightPadding: 26
                                            text: anniversaryTypeBox.displayText
                                            color: textPrimary
                                            font.pixelSize: 13
                                            font.bold: true
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        background: Rectangle {
                                            radius: 15
                                            color: fieldColor
                                            border.width: 1
                                            border.color: softBorder
                                        }
                                    }

                                    SoftButton {
                                        text: "保存"
                                        implicitWidth: 70
                                        implicitHeight: 38
                                        radius: 15
                                        fillColor: primaryButton
                                        hoverColor: primaryButtonHover
                                        textColor: "#FFFDF9"
                                        fontSize: 13
                                        onClicked: addAnniversary()
                                    }
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 10
                            model: sortedAnniversaries()

                            delegate: Rectangle {
                                required property var modelData

                                width: ListView.view.width
                                height: 78
                                radius: 20
                                color: cardSoft
                                border.width: 1
                                border.color: softBorder

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var targetDate = dateFromKey(modelData.dateKey)
                                        viewedMonth = new Date(targetDate.getFullYear(), targetDate.getMonth(), 1)
                                        selectDate(modelData.dateKey)
                                        refreshCalendar()
                                    }
                                }

                                RowLayout {
                                    z: 1
                                    anchors.fill: parent
                                    anchors.margins: 13
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        radius: 20
                                        color: anniversaryColor(modelData.type)

                                        Text {
                                            anchors.centerIn: parent
                                            text: anniversaryKind(modelData) === "countdown" ? "倒" : "纪"
                                            color: textPrimary
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            color: textPrimary
                                            font.pixelSize: 15
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: anniversarySubtitle(modelData)
                                            color: textSecondary
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: anniversaryStatus(modelData)
                                        color: accentText
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        text: "×"
                                        color: textSecondary
                                        font.pixelSize: 18
                                        font.bold: true

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: removeAnniversaryById(modelData.id)
                                        }
                                    }
                                }

                            }

                            footer: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: sortedAnniversaries().length === 0 ? 120 : 0

                                Text {
                                    anchors.centerIn: parent
                                    visible: sortedAnniversaries().length === 0
                                    text: "还没有纪念日或倒计时"
                                    color: textSecondary
                                    font.pixelSize: 14
                                }
                            }
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
