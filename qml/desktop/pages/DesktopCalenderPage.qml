import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import QtCore
import "../components"
import "../memorylake"

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

    // 颜色全部走 memory-lake token（G1 单源）。夜=暗玻璃霓虹，昼=浅瓷，由 ml.night 切换。
    // 旧布局（Soft* 卡）在 F-B1 仍在，但已被 token 染成暗霓虹（可跑切片）；F-B2+ 重构结构。
    property color textPrimary: ml.textPrimary
    property color textSecondary: ml.textSecondary
    property color cardColor: ml.faceBg
    property color cardSoft: ml.bg2
    property color panelColor: ml.panelBg
    property color mint: ml.aqua
    property color lightMint: ml.accentSoft
    property color cream: ml.shareGold
    property color blush: ml.sharePink
    property color lavender: ml.violet
    property color borderColor: ml.panelBorder
    property color softBorder: ml.cardBorder
    property color shadowColor: ml.shadowColor
    property color fieldColor: ml.calSunkBg
    property color primaryButton: ml.violet
    property color primaryButtonHover: ml.aqua
    property color accentText: ml.accentText

    property date todayDate: new Date()
    property date viewedMonth: new Date(todayDate.getFullYear(), todayDate.getMonth(), 1)
    property string selectedDateKey: initialSelectedDateKey()
    property var calendarCells: []
    property var fixedTags: ["学习", "工作", "运动", "娱乐", "阅读", "社交", "生活", "其他"]
    property int projectRefreshKey: 0
    property string sidePanelMode: "tasks"

    // 记忆湖统一色板（接 AppShell.applyThemeToLoadedPage 注入的主题契约）。
    MemoryLakeStyle {
        id: ml
        night: root.nightMode
        injectedTextPrimary: root.themeTextPrimary
        injectedTextSecondary: root.themeTextSecondary
    }

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
        // 周一为每周起始列（与 v88 + MemoDatePicker 一致）：偏移 (getDay()+6)%7。
        start.setDate(first.getDate() - ((first.getDay() + 6) % 7))

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

    // 点 cell：跨月（上/下月溢出格）则先切到该月再选中并重渲染。
    function selectCellDate(cell) {
        if (!cell.inMonth) {
            var d = dateFromKey(cell.dateKey)
            viewedMonth = new Date(d.getFullYear(), d.getMonth(), 1)
        }
        selectDate(cell.dateKey)
        refreshCalendar()
    }

    onNightModeChanged: refreshCalendar()

    // v88 暗玻璃整页基底（M-B1）：竖直近黑渐变（不透明替代 backdrop-filter）+ 42px 蓝图栅格
    // + 双角晕（aqua 左上 / violet 右上，圆心近角顶）。圆角 r26 由 RoundedFrame 的 FBO+mask 裁剪，
    // 内部栅格/角晕不漏方角（G7：禁 clip:true 当圆角裁剪）。
    RoundedFrame {
        id: pageBase
        anchors.fill: parent
        radius: 26
        border { width: 1; color: ml.panelBorder }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: ml.calPageTop }
                GradientStop { position: 1.0; color: ml.calPageBottom }
            }
        }

        GridTexture {
            anchors.fill: parent
            cell: 42
            lineColor: ml.gridLine
            textureOpacity: 0.24
        }

        GlowCircle {
            width: 520; height: 520
            x: pageBase.width * 0.15 - width / 2
            y: -height / 2
            glowColor: ml.aqua
            glowOpacity: 0.10 * ml.glowStrength
        }

        GlowCircle {
            width: 520; height: 520
            x: pageBase.width * 0.88 - width / 2
            y: pageBase.height * 0.18 - height / 2
            glowColor: ml.violet
            glowOpacity: 0.12 * ml.glowStrength
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 16

        // v88 中栏顶栏（M-B2，§1.7）：玻璃面板（无投影，仅 inset 缝）+ 月标题 + ‹/今天/› 导航。
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            style: ml
            color: ml.calPanelBg
            dropShadow: false
            radius: 22

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Text {
                        text: "日历 · CALENDAR"
                        color: ml.glowCyan
                        font.pixelSize: 11
                        font.weight: Font.Black
                        font.letterSpacing: 0.6
                    }

                    Text {
                        text: monthTitle()
                        color: textPrimary
                        font.pixelSize: 23
                        font.weight: Font.Bold
                        font.letterSpacing: -0.4
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "按日期整理待办、照片与计时记录"
                        color: textSecondary
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                // ‹ 上一月
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    radius: 13
                    color: prevMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                    border.width: 1; border.color: ml.calGhostBorder
                    Text { anchors.centerIn: parent; text: "‹"; color: ml.calGlyph
                           font.pixelSize: 19; font.weight: Font.DemiBold }
                    MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: previousMonth() }
                }

                // 今天（aqua→violet 主键）
                Rectangle {
                    Layout.preferredWidth: 72; Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    radius: 13
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: ml.aqua }
                        GradientStop { position: 1; color: ml.violet }
                    }
                    Text { anchors.centerIn: parent; text: "今天"; color: ml.calBtnInk
                           font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    viewedMonth = new Date(todayDate.getFullYear(), todayDate.getMonth(), 1)
                                    selectDate(dateKey(todayDate))
                                    refreshCalendar()
                                } }
                }

                // › 下一月
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    radius: 13
                    color: nextMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                    border.width: 1; border.color: ml.calGhostBorder
                    Text { anchors.centerIn: parent; text: "›"; color: ml.calGlyph
                           font.pixelSize: 19; font.weight: Font.DemiBold }
                    MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: nextMonth() }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // v88 月视图（M-B2，§1.8）：玻璃底 + 周一表头 + 发丝账本栅格。
            // RoundedFrame 裁圆角（G7：内部满铺栅格在圆角处不漏方角）。
            RoundedFrame {
                id: monthView
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 780
                radius: 22
                border { width: 1; color: ml.panelBorder }

                Rectangle { anchors.fill: parent; color: ml.calPanelBg }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // 周一表头（一..日）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        spacing: 0

                        Repeater {
                            model: ["一", "二", "三", "四", "五", "六", "日"]

                            delegate: Item {
                                required property string modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: ml.textTertiary
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: ml.cellHair }

                    // 42 格发丝账本（无间距 → 右/下 1px 发丝线连成账本网；仅光态，无填充块）
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        columnSpacing: 0
                        rowSpacing: 0

                        Repeater {
                            model: calendarCells

                            delegate: Item {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 84
                                opacity: modelData.inMonth ? 1.0 : 0.35

                                // 右/下发丝线
                                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: ml.cellHair }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: ml.cellHair }

                                // 今日底洗 + 角晕
                                Rectangle { anchors.fill: parent; visible: modelData.isToday; color: ml.todayWash }
                                GlowCircle {
                                    visible: modelData.isToday
                                    width: 130; height: 130
                                    x: parent.width * 0.8 - width / 2
                                    y: parent.height * 0.12 - height / 2
                                    glowColor: ml.aqua
                                    glowOpacity: 0.16 * ml.glowStrength
                                }

                                // hover 洗（选中态不叠）
                                Rectangle {
                                    anchors.fill: parent
                                    visible: cellMouse.containsMouse && modelData.dateKey !== selectedDateKey
                                    color: ml.cellHover
                                }

                                // 选中 2px 内描边环（outline-offset:-2）
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    visible: modelData.dateKey === selectedDateKey
                                    color: "transparent"
                                    border.width: 2
                                    border.color: ml.selectedRing
                                }

                                // 日号
                                Text {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.leftMargin: 10
                                    anchors.topMargin: 8
                                    text: modelData.day
                                    color: modelData.isToday ? ml.aqua : ml.cellDateText
                                    font.pixelSize: 13
                                    font.weight: (modelData.isToday || modelData.dateKey === selectedDateKey)
                                                 ? Font.Bold : Font.DemiBold
                                }

                                // 保留徽标（待办计数 + 倒/纪 + 照片点）。事件胶囊在 F-B3 接入。
                                Row {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: 8
                                    anchors.bottomMargin: 8
                                    spacing: 5

                                    Rectangle {
                                        visible: modelData.todoCount > 0
                                        width: 18; height: 18; radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: modelData.doneCount === modelData.todoCount ? ml.accentSoft : ml.chipTodoBg
                                        border.width: 1
                                        border.color: modelData.doneCount === modelData.todoCount ? ml.accentSoftBorder : ml.chipTodoBd
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.todoCount
                                            color: ml.chipText
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        visible: modelData.anniversaryCount > 0
                                        width: 22; height: 18; radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: modelData.countdownCount > 0 ? ml.chipFocusBg : ml.chipTodoBg
                                        border.width: 1
                                        border.color: modelData.countdownCount > 0 ? ml.chipFocusBd : ml.chipTodoBd
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.countdownCount > 0 ? "倒" : "纪"
                                            color: ml.chipText
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        visible: modelData.hasPhoto
                                        width: 7; height: 7; radius: 3.5
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: ml.glowCyan
                                    }
                                }

                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: selectCellDate(modelData)
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
