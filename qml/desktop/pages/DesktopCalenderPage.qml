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

    // 路由页开合动效（M-B5，§4.4，easeSnappy）：opacity + 上移 + 微缩；Component.onCompleted 触发。
    opacity: 0
    transform: [
        Translate { id: openTranslate; y: 18 },
        Scale { id: openScale; origin.x: root.width / 2; origin.y: root.height / 2; xScale: 0.985; yScale: 0.985 }
    ]
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 240 }
        NumberAnimation { target: openTranslate; property: "y"; to: 0; duration: 300
                          easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
        NumberAnimation { target: openScale; property: "xScale"; to: 1; duration: 300
                          easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
        NumberAnimation { target: openScale; property: "yScale"; to: 1; duration: 300
                          easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
    }

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
    // 左栏视图 tab：仅 month 真渲染；week/today/focus 为诚实占位（§2.5 / B1）。
    property string activeView: "month"

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

        // 一次性取数（避免每格重新解析整段 JSON）。
        var todosMap = allTodosMap()
        var anns = allAnniversaries()
        var photoMap = buildPhotoLookup()
        var todayKey = dateKey(todayDate)

        for (var i = 0; i < 42; i++) {
            var d = new Date(start)
            d.setDate(start.getDate() + i)
            var key = dateKey(d)
            var dayTodos = todosMap[key] ? todosMap[key] : []
            var doneN = 0
            for (var t = 0; t < dayTodos.length; t++)
                if (dayTodos[t].done)
                    doneN += 1
            var annN = 0, cdN = 0
            for (var a = 0; a < anns.length; a++) {
                if (anns[a].dateKey === key) {
                    annN += 1
                    if (anniversaryKind(anns[a]) === "countdown")
                        cdN += 1
                }
            }
            cells.push({
                dateKey: key,
                day: d.getDate(),
                inMonth: d.getMonth() === viewedMonth.getMonth(),
                isToday: key === todayKey,
                hasPhoto: photoMap[key] ? true : false,
                events: dayTodos,
                todoCount: dayTodos.length,
                doneCount: doneN,
                anniversaryCount: annN,
                countdownCount: cdN
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
        showCalToast("已更新照片")
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

    // 事件类型（event/todo/focus）→ 胶囊/脊柱固定语义色（三种，v88 §1.9）。
    function eventChipBg(type) {
        return type === "event" ? ml.chipEventBg : type === "focus" ? ml.chipFocusBg : ml.chipTodoBg
    }
    function eventChipBd(type) {
        return type === "event" ? ml.chipEventBd : type === "focus" ? ml.chipFocusBd : ml.chipTodoBd
    }
    function eventSpine(type) {
        return type === "event" ? ml.aqua : type === "focus" ? ml.violet : ml.shareGold
    }
    function typeFromLabel(label) {
        return label === "事件" ? "event" : label === "专注" ? "focus" : "todo"
    }
    function typeLabel(type) {
        return type === "event" ? "事件" : type === "focus" ? "专注" : "待办"
    }

    // 左栏统计芯片（§2.7 / A5）：今日事项 / 完成率 = 真值（绑 calendarManager.savedTodos）；
    // 专注块 / 本周任务 = 诚实静态占位（待重构出最终效果后由用户选择性补真值）。
    function todayItemCount() {
        return todosForDate(dateKey(todayDate)).length
    }
    function todayDoneRate() {
        var arr = todosForDate(dateKey(todayDate))
        if (arr.length === 0)
            return "—"
        var d = 0
        for (var i = 0; i < arr.length; i++)
            if (arr[i].done)
                d += 1
        return Math.round(d / arr.length * 100) + "%"
    }
    // 本周（周一起）所有事项总数。
    function weekTaskCount() {
        var map = allTodosMap()
        var monday = new Date(todayDate)
        monday.setDate(todayDate.getDate() - ((todayDate.getDay() + 6) % 7))
        var n = 0
        for (var i = 0; i < 7; i++) {
            var day = new Date(monday)
            day.setDate(monday.getDate() + i)
            var arr = map[dateKey(day)]
            if (arr)
                n += arr.length
        }
        return n
    }
    // 今日 focus 类型事项数（专注块）。
    function focusBlockCount() {
        var arr = todosForDate(dateKey(todayDate))
        var n = 0
        for (var i = 0; i < arr.length; i++)
            if (arr[i].type === "focus")
                n += 1
        return n
    }
    function statValue(key) {
        return key === "items" ? "" + todayItemCount()
             : key === "rate" ? todayDoneRate()
             : key === "focus" ? "" + focusBlockCount()
             : key === "week" ? "" + weekTaskCount()
             : "—"
    }
    function viewLabel(key) {
        return key === "week" ? "周计划" : key === "today" ? "今日议程" : key === "focus" ? "专注记录" : "月视图"
    }

    // 底中变更反馈胶囊（v88 §1.11 showCalendarToast）。净增反馈，低风险。
    function showCalToast(msg) {
        calToast.message = msg
        calToast.shown = true
        toastTimer.restart()
    }

    // 一次性构建 dateKey→照片路径 查找表（手动优先，回退当天首张 chat 图）。
    // 取代 buildCalendarCells 内每格重新解析整段 chat JSON（42× 解析 → 1×）。
    function buildPhotoLookup() {
        var result = {}
        var savedChats = settingsRepository ? settingsRepository.getValue("local_memo_chat_messages", "") : ""
        if (savedChats && savedChats !== "") {
            try {
                var chats = JSON.parse(savedChats)
                for (var i = 0; i < chats.length; i++) {
                    var item = chats[i]
                    if (item.imagePath && item.imagePath !== "" && item.timeText) {
                        var k = item.timeText.substring(0, 10)
                        if (!result[k])
                            result[k] = item.imagePath
                    }
                }
            } catch (e) {}
        }
        var manual = manualPhotoMap()
        for (var key in manual)
            if (manual[key] && manual[key] !== "")
                result[key] = manual[key]
        return result
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
        showCalToast("已保存纪念日")
    }

    function removeAnniversaryById(id) {
        var list = allAnniversaries()
        var result = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== id)
                result.push(list[i])
        }
        saveAnniversaries(result)
        showCalToast("已删除")
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
                linkedProject: item.linkedProject ? item.linkedProject : "",
                time: item.time ? item.time : "",
                type: item.type ? item.type : "todo"
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
                linkedProject: arr[i].linkedProject ? arr[i].linkedProject : "",
                time: arr[i].time ? arr[i].time : "",
                type: arr[i].type ? arr[i].type : "todo"
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
            linkedProject: linkedProjectFromChoice(todoProjectBox.currentText),
            time: eventTimeInput.text.trim(),
            type: typeFromLabel(eventTypeBox.currentText)
        })
        todoInput.text = ""
        eventTimeInput.text = ""
        todoProjectBox.currentIndex = 0
        saveTodosForSelectedDate()
        showCalToast("已添加事项")
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

    // 沉浸式整页底完全由 Shell 的 fullBleed 层提供（DesktopAppShell `selectedPage==='calendar'`）：
    // 蓝黑深度坡 + 双角晕 + 整 App 42px 蓝图栅格纹（边缘羽化渐隐、窗口 DWM 圆角裁角）。本页只放
    // 内容，蓝黑底自然透出 —— 不再「框中框」、不外露旧背景、栅格也不在内容区内硬切方角。

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

            // ===== 左栏：品牌卡 + 4 视图 Tab + 2×2 统计芯片（M-B4，§1.4–1.6）=====
            GlassPanel {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                style: ml
                color: ml.calPanelBg
                dropShadow: false
                radius: 22

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // 品牌卡（aqua 斜染）
                    FrostCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 96
                        style: ml
                        radius: 18
                        tintTop: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.16)

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 5
                            Text { text: "CALENDAR"; color: ml.glowCyan; font.pixelSize: 11
                                   font.weight: Font.Black; font.letterSpacing: 0.7 }
                            Text { text: "日历"; color: ml.textPrimary; font.pixelSize: 26
                                   font.weight: Font.Bold; font.letterSpacing: -0.6 }
                            Text { text: "按日期整理时间上下文"; color: ml.textTertiary; font.pixelSize: 11 }
                        }
                    }

                    // 4 视图 Tab：仅 month 真渲染，其余诚实占位（点击切 active；toast 在 F-B5 接）。
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [
                                { key: "month", label: "月视图",   glyph: "▦" },
                                { key: "week",  label: "周计划",   glyph: "▤" },
                                { key: "today", label: "今日议程", glyph: "▣" },
                                { key: "focus", label: "专注记录", glyph: "◴" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 13
                                color: activeView === modelData.key ? ml.accentSoft
                                       : (tabMa.containsMouse ? ml.calGhostHover : "transparent")
                                border.width: 1
                                border.color: activeView === modelData.key ? ml.accentSoftBorder : "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    spacing: 10
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 28; height: 28; radius: 9
                                        color: ml.calGhostBg
                                        Text { anchors.centerIn: parent; text: modelData.glyph
                                               color: activeView === modelData.key ? ml.aqua : ml.calGlyph
                                               font.pixelSize: 13 }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        color: activeView === modelData.key ? ml.textPrimary : ml.textSecondary
                                        font.pixelSize: 13
                                        font.weight: activeView === modelData.key ? Font.DemiBold : Font.Normal
                                    }
                                }
                                MouseArea {
                                    id: tabMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        activeView = modelData.key
                                        showCalToast("已切换到" + modelData.label)
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // 2×2 统计芯片（今日事项/完成率 真值；专注块/本周任务 诚实占位，A5）
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10
                        Repeater {
                            model: [
                                { label: "今日事项", key: "items", real: true },
                                { label: "完成率",   key: "rate",  real: true },
                                { label: "专注块",   key: "focus", real: true },
                                { label: "本周任务", key: "week",  real: true }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 62
                                radius: 14
                                color: ml.calSunkBg
                                border.width: 1
                                border.color: ml.cardBorder

                                Column {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.leftMargin: 12
                                    anchors.topMargin: 10
                                    spacing: 6
                                    Text { text: modelData.label; color: ml.textTertiary; font.pixelSize: 10 }
                                    Text { text: statValue(modelData.key); color: ml.textPrimary
                                           font.pixelSize: 21; font.weight: Font.Bold }
                                }
                                Text {
                                    visible: !modelData.real
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.rightMargin: 8
                                    anchors.topMargin: 7
                                    text: "占位"
                                    color: ml.textTertiary
                                    font.pixelSize: 8
                                }
                            }
                        }
                    }
                }
            }

            // ===== 中栏：月视图（仅 activeView==="month" 真渲染）=====
            // v88 月视图（M-B2，§1.8）：玻璃底 + 周一表头 + 发丝账本栅格。
            // RoundedFrame 裁圆角（G7：内部满铺栅格在圆角处不漏方角）。
            RoundedFrame {
                id: monthView
                visible: activeView === "month"
                Layout.fillWidth: true
                Layout.fillHeight: true
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
                                    id: cellDayNum
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

                                // 保留徽标（倒/纪 + 照片点）右上角，与日号同排（D-KEEP）。
                                Row {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.rightMargin: 8
                                    anchors.topMargin: 8
                                    spacing: 4

                                    Rectangle {
                                        visible: modelData.anniversaryCount > 0
                                        width: 17; height: 16; radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: modelData.countdownCount > 0 ? ml.chipFocusBg : ml.chipTodoBg
                                        border.width: 1
                                        border.color: modelData.countdownCount > 0 ? ml.chipFocusBd : ml.chipTodoBd
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.countdownCount > 0 ? "倒" : "纪"
                                            color: ml.chipText
                                            font.pixelSize: 9
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

                                // 事件胶囊（前 3 条 time+title，类型色 event/todo/focus；超出 +N more，v88 §1.9）。
                                Column {
                                    id: chipCol
                                    property var evs: modelData.events
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: cellDayNum.bottom
                                    anchors.leftMargin: 7
                                    anchors.rightMargin: 7
                                    anchors.topMargin: 6
                                    spacing: 3

                                    Repeater {
                                        model: Math.min(3, chipCol.evs.length)
                                        delegate: Rectangle {
                                            required property int index
                                            property var ev: chipCol.evs[index]
                                            width: parent.width
                                            height: 16
                                            radius: 8
                                            color: eventChipBg(ev.type)
                                            border.width: 1
                                            border.color: eventChipBd(ev.type)
                                            Text {
                                                anchors.fill: parent
                                                anchors.leftMargin: 6
                                                anchors.rightMargin: 6
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                                text: (ev.time && ev.time !== "" ? ev.time + " " : "") + ev.text
                                                color: ml.chipText
                                                font.pixelSize: 9
                                            }
                                        }
                                    }

                                    Text {
                                        visible: chipCol.evs.length > 3
                                        leftPadding: 4
                                        text: "+" + (chipCol.evs.length - 3) + " more"
                                        color: ml.textTertiary
                                        font.pixelSize: 9
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

            // 非 month 视图 = 诚实占位（不伪装真实周/议程/专注视图，§2.5）。
            RoundedFrame {
                visible: activeView !== "month"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 22
                border { width: 1; color: ml.panelBorder }

                Rectangle { anchors.fill: parent; color: ml.calPanelBg }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: viewLabel(activeView)
                        color: ml.textPrimary
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "视图开发中 · 仅月视图已实现"
                        color: ml.textTertiary
                        font.pixelSize: 12
                    }
                }
            }

            // ===== 右栏：选中日卡 + 模式（待办/记录/纪念）=====
            GlassPanel {
                Layout.preferredWidth: 310
                Layout.fillHeight: true
                style: ml
                color: ml.calPanelBg
                dropShadow: false
                radius: 22

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    // v88 选中日卡（§1.10）：aqua 斜染暗玻璃 + 可选照片 hero（RoundedFrame 裁圆角，G7
                    // 不漏方角）+ 渐变压暗保可读 + 日期 / 计时 pill / 加照片 / 待办计数。
                    RoundedFrame {
                        id: selDayCard
                        property string selPhoto: selectedPhotoSource()
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        radius: 20
                        border { width: 1; color: ml.chipEventBd }

                        Rectangle { anchors.fill: parent; color: ml.calSunkBg }

                        GlowCircle {
                            visible: selDayCard.selPhoto === ""
                            width: 240; height: 240
                            x: -70; y: -100
                            glowColor: ml.aqua
                            glowOpacity: 0.16 * ml.glowStrength
                        }

                        Image {
                            anchors.fill: parent
                            source: selDayCard.selPhoto
                            fillMode: Image.PreserveAspectCrop
                            visible: selDayCard.selPhoto !== ""
                            opacity: ml.night ? 0.55 : 0.5
                            smooth: true
                            asynchronous: true
                        }

                        // 照片可读压暗（顶透 → 底实 calPageBottom）
                        Rectangle {
                            visible: selDayCard.selPhoto !== ""
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: ml.calPageBottom }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "SELECTED"
                                        color: ml.glowCyan
                                        font.pixelSize: 10
                                        font.weight: Font.Black
                                        font.letterSpacing: 0.7
                                    }
                                    Text {
                                        text: selectedDateLabel()
                                        color: ml.textPrimary
                                        font.pixelSize: 22
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: selectedDateKey
                                        color: ml.textTertiary
                                        font.pixelSize: 11
                                    }
                                }

                                // 计时 pill
                                Rectangle {
                                    Layout.alignment: Qt.AlignTop
                                    implicitWidth: timeRow.width + 18
                                    implicitHeight: 28
                                    radius: 14
                                    color: ml.calGhostBg
                                    border.width: 1
                                    border.color: ml.calGhostBorder
                                    Row {
                                        id: timeRow
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: "⧗"
                                               color: ml.aqua; font.pixelSize: 12 }
                                        Text { anchors.verticalCenter: parent.verticalCenter
                                               text: secondsToDisplay(selectedDateTotalSeconds())
                                               color: ml.textPrimary; font.pixelSize: 12; font.bold: true }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // 加 / 换照片（ghost）
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    radius: 12
                                    color: photoMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                                    border.width: 1
                                    border.color: ml.calGhostBorder
                                    Text {
                                        anchors.centerIn: parent
                                        text: selDayCard.selPhoto === "" ? "+ 添加照片" : "+ 更换照片"
                                        color: ml.calGlyph
                                        font.pixelSize: 13
                                    }
                                    MouseArea {
                                        id: photoMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dayPhotoDialog.open()
                                    }
                                }

                                // 待办计数 pill
                                Rectangle {
                                    implicitWidth: cntRow.width + 18
                                    Layout.preferredHeight: 34
                                    radius: 12
                                    color: ml.calGhostBg
                                    border.width: 1
                                    border.color: ml.calGhostBorder
                                    Row {
                                        id: cntRow
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: "✓"
                                               color: ml.aqua; font.pixelSize: 12; font.bold: true }
                                        Text { anchors.verticalCenter: parent.verticalCenter
                                               text: doneCountForDate(selectedDateKey) + "/" + todoModel.count
                                               color: ml.textPrimary; font.pixelSize: 12; font.bold: true }
                                    }
                                }
                            }
                        }
                    }

                    // 模式分段控件（待办/记录/纪念）— v88 暗霓虹（active = aqua→violet 渐变 + 近黑墨字）。
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 14
                        color: ml.calSunkBg
                        border.width: 1
                        border.color: ml.cardBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

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
                                    radius: 11
                                    gradient: sidePanelMode === modelData.key ? segGrad : null
                                    color: sidePanelMode === modelData.key
                                           ? "transparent"
                                           : (segMa.containsMouse ? ml.calGhostHover : "transparent")

                                    Gradient {
                                        id: segGrad
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: ml.aqua }
                                        GradientStop { position: 1; color: ml.violet }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: sidePanelMode === modelData.key ? ml.calBtnInk : ml.textSecondary
                                        font.pixelSize: 13
                                        font.weight: sidePanelMode === modelData.key ? Font.Bold : Font.DemiBold
                                    }

                                    MouseArea {
                                        id: segMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: sidePanelMode = modelData.key
                                    }
                                }
                            }
                        }
                    }

                    // 待办模式 = v88 加日程表单（标题 / 时间·类型 / 标签·项目·添加）+ 当天议程。
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        visible: sidePanelMode === "tasks"

                        // event-form
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 174
                            radius: 16
                            color: ml.calSunkBg
                            border.width: 1
                            border.color: ml.cardBorder

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                TextField {
                                    id: todoInput
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    placeholderText: "添加这一天的事项"
                                    placeholderTextColor: ml.textTertiary
                                    color: ml.textPrimary
                                    font.pixelSize: 14
                                    selectByMouse: true
                                    leftPadding: 12
                                    rightPadding: 12
                                    background: Rectangle {
                                        radius: 12
                                        color: ml.calSunkBg
                                        border.width: 1
                                        border.color: ml.calInputBorder
                                    }
                                    Keys.onReturnPressed: addTodo()
                                }

                                // 时间 + 类型（v88 event-form-row）
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    TextField {
                                        id: eventTimeInput
                                        Layout.preferredWidth: 92
                                        Layout.preferredHeight: 36
                                        placeholderText: "时间"
                                        placeholderTextColor: ml.textTertiary
                                        color: ml.textPrimary
                                        font.pixelSize: 13
                                        selectByMouse: true
                                        leftPadding: 12
                                        inputMethodHints: Qt.ImhPreferNumbers
                                        background: Rectangle {
                                            radius: 12
                                            color: ml.calSunkBg
                                            border.width: 1
                                            border.color: ml.calInputBorder
                                        }
                                        Keys.onReturnPressed: addTodo()
                                    }

                                    ComboBox {
                                        id: eventTypeBox
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        model: ["待办", "事件", "专注"]
                                        currentIndex: 0
                                        contentItem: Text {
                                            leftPadding: 12
                                            rightPadding: 26
                                            text: eventTypeBox.displayText
                                            color: ml.textPrimary
                                            font.pixelSize: 13
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                        background: Rectangle {
                                            radius: 12
                                            color: ml.calSunkBg
                                            border.width: 1
                                            border.color: ml.calInputBorder
                                        }
                                    }
                                }

                                // 标签 + 项目 + 添加（保留 tag/linkedProject → 计时回路）
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    ComboBox {
                                        id: todoTagBox
                                        Layout.preferredWidth: 82
                                        Layout.preferredHeight: 36
                                        model: fixedTags
                                        currentIndex: 0
                                        onCurrentTextChanged: todoProjectBox.currentIndex = 0
                                        contentItem: Text {
                                            leftPadding: 12
                                            rightPadding: 20
                                            text: todoTagBox.displayText
                                            color: ml.textPrimary
                                            font.pixelSize: 12
                                            font.bold: true
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                        background: Rectangle {
                                            radius: 12
                                            color: ml.calSunkBg
                                            border.width: 1
                                            border.color: ml.calInputBorder
                                        }
                                    }

                                    ComboBox {
                                        id: todoProjectBox
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        model: projectChoicesForTag(todoTagBox.currentText)
                                        contentItem: Text {
                                            leftPadding: 12
                                            rightPadding: 20
                                            text: todoProjectBox.displayText
                                            color: ml.textPrimary
                                            font.pixelSize: 12
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                        background: Rectangle {
                                            radius: 12
                                            color: ml.calSunkBg
                                            border.width: 1
                                            border.color: ml.calInputBorder
                                        }
                                    }

                                    // 添加（aqua→violet 主键）
                                    Rectangle {
                                        Layout.preferredWidth: 58
                                        Layout.preferredHeight: 36
                                        radius: 12
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: ml.aqua }
                                            GradientStop { position: 1; color: ml.violet }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "添加"
                                            color: ml.calBtnInk
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: addTodo()
                                        }
                                    }
                                }
                            }
                        }

                        // 当天议程（SilkyFlickable，丝滑滚动）
                        SilkyFlickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            style: ml

                            Column {
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: todoModel

                                    delegate: Rectangle {
                                        id: agendaItem
                                        required property int index
                                        required property string text
                                        required property bool done
                                        required property string tag
                                        required property string linkedProject
                                        required property string time
                                        required property string type

                                        width: parent.width
                                        height: 56
                                        radius: 13
                                        color: ml.calSunkBg
                                        border.width: 1
                                        border.color: ml.cardBorder

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            // 类型脊柱 + 完成切换（点切 done；色=类型语义色）
                                            Rectangle {
                                                Layout.preferredWidth: 22
                                                Layout.preferredHeight: 22
                                                radius: 11
                                                color: agendaItem.done ? eventSpine(agendaItem.type) : "transparent"
                                                border.width: agendaItem.done ? 0 : 1
                                                border.color: eventSpine(agendaItem.type)
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: agendaItem.done
                                                    text: "✓"
                                                    color: ml.calBtnInk
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -6
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        todoModel.setProperty(agendaItem.index, "done", !agendaItem.done)
                                                        saveTodosForSelectedDate()
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: (agendaItem.time && agendaItem.time !== "" ? agendaItem.time + "  " : "") + agendaItem.text
                                                    color: agendaItem.done ? ml.textSecondary : ml.textPrimary
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                    font.strikeout: agendaItem.done
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: typeLabel(agendaItem.type) + " · " + agendaItem.tag
                                                          + (agendaItem.linkedProject !== "" ? " · " + agendaItem.linkedProject : "")
                                                    color: ml.textTertiary
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            // 开始（计时）
                                            Rectangle {
                                                Layout.preferredWidth: 50
                                                Layout.preferredHeight: 30
                                                visible: !agendaItem.done
                                                radius: 10
                                                color: startMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                                                border.width: 1
                                                border.color: ml.calGhostBorder
                                                Text { anchors.centerIn: parent; text: "开始"; color: ml.calGlyph; font.pixelSize: 12 }
                                                MouseArea {
                                                    id: startMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: startTodoProject(agendaItem.text, agendaItem.tag, selectedDateKey, agendaItem.linkedProject)
                                                }
                                            }

                                            // 删除
                                            Rectangle {
                                                Layout.preferredWidth: 26
                                                Layout.preferredHeight: 26
                                                radius: 9
                                                color: delMa.containsMouse ? ml.calDangerWash : ml.calGhostBg
                                                border.width: 1
                                                border.color: ml.calGhostBorder
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "×"
                                                    color: delMa.containsMouse ? ml.chipText : ml.calGlyph
                                                    font.pixelSize: 16
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    id: delMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        todoModel.remove(agendaItem.index)
                                                        saveTodosForSelectedDate()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // 空态（v88 一条「暂无日程」占位）
                                Item {
                                    width: parent.width
                                    height: todoModel.count === 0 ? 90 : 0
                                    visible: todoModel.count === 0
                                    Text {
                                        anchors.centerIn: parent
                                        text: "暂无日程"
                                        color: ml.textTertiary
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }

                    // 记录模式 = calendar_todo 计时条（projectManager 拥有，与用量管线无关）。
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        visible: sidePanelMode === "records"

                        SilkyFlickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            style: ml

                            Column {
                                width: parent.width
                                spacing: 10

                                Repeater {
                                    model: dayProjects()
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 72
                                        radius: 13
                                        color: ml.calSunkBg
                                        border.width: 1
                                        border.color: ml.cardBorder

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 13
                                            spacing: 7

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.title ? modelData.title : modelData.name
                                                    color: ml.textPrimary
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: secondsToDisplay(modelData.seconds)
                                                    color: ml.accentText
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 7
                                                radius: 4
                                                color: ml.trackBg
                                                clip: true

                                                Rectangle {
                                                    width: parent.width * ((modelData.seconds ? modelData.seconds : 0) / Math.max(1, maxDaySeconds()))
                                                    height: parent.height
                                                    radius: 4
                                                    gradient: Gradient {
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0; color: ml.aqua }
                                                        GradientStop { position: 1; color: ml.violet }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: dayProjects().length === 0 ? 110 : 0
                                    visible: dayProjects().length === 0
                                    Text {
                                        anchors.centerIn: parent
                                        text: "这一天还没有计时记录"
                                        color: ml.textTertiary
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }

                    // 纪念模式 = 纪念日 / 倒数日（QtCore Settings 类目 DesktopCalendarAnniversaryData，
                    // 字节不变；v88 无对应视觉 → 按 ml 自拟暗霓虹纪念卡）。
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        visible: sidePanelMode === "anniversaries"

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 108
                            radius: 16
                            color: ml.calSunkBg
                            border.width: 1
                            border.color: ml.cardBorder

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                TextField {
                                    id: anniversaryTitleInput
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    placeholderText: "添加纪念日名称"
                                    placeholderTextColor: ml.textTertiary
                                    color: ml.textPrimary
                                    font.pixelSize: 14
                                    selectByMouse: true
                                    leftPadding: 12
                                    rightPadding: 12
                                    background: Rectangle {
                                        radius: 12
                                        color: ml.calSunkBg
                                        border.width: 1
                                        border.color: ml.calInputBorder
                                    }
                                    Keys.onReturnPressed: addAnniversary()
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    ComboBox {
                                        id: anniversaryTypeBox
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        model: ["纪念日", "倒计时日"]
                                        contentItem: Text {
                                            leftPadding: 12
                                            rightPadding: 26
                                            text: anniversaryTypeBox.displayText
                                            color: ml.textPrimary
                                            font.pixelSize: 13
                                            font.bold: true
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                        background: Rectangle {
                                            radius: 12
                                            color: ml.calSunkBg
                                            border.width: 1
                                            border.color: ml.calInputBorder
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 64
                                        Layout.preferredHeight: 36
                                        radius: 12
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: ml.aqua }
                                            GradientStop { position: 1; color: ml.violet }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "保存"
                                            color: ml.calBtnInk
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: addAnniversary()
                                        }
                                    }
                                }
                            }
                        }

                        SilkyFlickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            style: ml

                            Column {
                                width: parent.width
                                spacing: 10

                                Repeater {
                                    model: sortedAnniversaries()
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 70
                                        radius: 13
                                        color: ml.calSunkBg
                                        border.width: 1
                                        border.color: ml.cardBorder

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var t = dateFromKey(modelData.dateKey)
                                                viewedMonth = new Date(t.getFullYear(), t.getMonth(), 1)
                                                selectDate(modelData.dateKey)
                                                refreshCalendar()
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 11
                                                color: anniversaryKind(modelData) === "countdown" ? ml.chipFocusBg : ml.chipTodoBg
                                                border.width: 1
                                                border.color: anniversaryKind(modelData) === "countdown" ? ml.chipFocusBd : ml.chipTodoBd
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: anniversaryKind(modelData) === "countdown" ? "倒" : "纪"
                                                    color: anniversaryKind(modelData) === "countdown" ? ml.violet : ml.shareGold
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 3
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.title
                                                    color: ml.textPrimary
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: anniversarySubtitle(modelData)
                                                    color: ml.textTertiary
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Text {
                                                text: anniversaryStatus(modelData)
                                                color: ml.accentText
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 24
                                                Layout.preferredHeight: 24
                                                radius: 8
                                                color: annDelMa.containsMouse ? ml.calDangerWash : "transparent"
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "×"
                                                    color: annDelMa.containsMouse ? ml.chipText : ml.textTertiary
                                                    font.pixelSize: 15
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    id: annDelMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: removeAnniversaryById(modelData.id)
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: sortedAnniversaries().length === 0 ? 110 : 0
                                    visible: sortedAnniversaries().length === 0
                                    Text {
                                        anchors.centerIn: parent
                                        text: "还没有纪念日或倒计时"
                                        color: ml.textTertiary
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // v88 底中变更反馈胶囊（§1.11）。z 高于内容；showCalToast 触发，1.6s 自动隐藏。
    Rectangle {
        id: calToast
        property string message: ""
        property bool shown: false
        z: 300
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        implicitWidth: Math.max(180, toastLabel.implicitWidth + 36)
        height: 40
        radius: 20
        color: ml.calToastBg
        border.width: 1
        border.color: ml.chipEventBd
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        transform: Translate {
            y: calToast.shown ? 0 : 10
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy } }
        }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            id: toastLabel
            anchors.centerIn: parent
            text: calToast.message
            color: ml.textPrimary
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Timer { id: toastTimer; interval: 1600; onTriggered: calToast.shown = false }
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
        openAnim.start()
    }
}
