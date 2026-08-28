import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import QtCore
import "../components"
import "../memorylake"
import "../components/TagPalette.js" as TagPalette
import "../../shared/I18n.js" as I18n
import "../components/PlatformCursor.js" as Cursor

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
    property string languageMode: "zh"

    function tr(source) { return I18n.t(languageMode, source) }
    function sentence(key, params) { return I18n.sentence(languageMode, key, params) }

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
    property var fixedTags: ["Study", "Work", "Exercise", "Entertainment", "Reading", "Social", "Life", "Other"]
    // 备忘黑板覆盖层引用（Shell 在 pageLoader.onLoaded 注入）：议程上「便签待办行」的勾选/删除回写到便签。
    property var memoOverlayRef: null
    property int projectRefreshKey: 0
    // 专注记录·本周 7 天专注时长缓存（避免每帧 7×DB 扫描）：由 refreshWeekFocus() 重建。
    property var weekFocusModel: []
    property int weekMaxFocusSeconds: 1
    property string sidePanelMode: "tasks"
    // 左栏视图 tab：month/week/today/focus 四视图均已实装（§2.5）。
    property string activeView: "month"

    // 安排事项表单状态（自绘下拉 + 时间选择器，避开原生 Controls 白边/白底弹窗）。
    property string todoTag: fixedTags[0]
    property string annType: "Anniversary"            // 纪念日 / 倒计时日
    property bool createOpen: false              // 创建弹出界面（独立浮层）开合
    property string createTime: ""               // 创建时选定的时间 HH:MM（空=未选）
    property bool timePickerOpen: false          // 时间选择浮层开合
    property int pickHour: 9
    property int pickMinute: 0

    // 记忆湖统一色板（接 AppShell.applyThemeToLoadedPage 注入的主题契约）。
    MemoryLakeStyle {
        id: ml
        night: root.nightMode
        accentSeed: root.themeAccentColor
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

    function displayTime(raw) {
        if (!raw || raw === "")
            return ""
        var parts = raw.split(":")
        if (parts.length < 2)
            return raw
        var h = parseInt(parts[0])
        var m = parseInt(parts[1])
        if (isNaN(h) || isNaN(m))
            return raw
        var fmt = settingsRepository ? settingsRepository.getValue("time_format", "24") : "24"
        return fmt === "12" ? Qt.formatTime(new Date(2000, 0, 1, h, m), "h:mm AP") : raw
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
        var weeks = I18n.weekdaysAbbr(languageMode)
        return I18n.langKey(languageMode) === "en"
               ? (I18n.monthDay(languageMode, value) + ", " + weeks[value.getDay()])
               : (I18n.monthDay(languageMode, value) + " " + weeks[value.getDay()])
    }

    function monthTitle() {
        return I18n.yearMonth(languageMode, viewedMonth)
    }

    function monthShortLabel(monthIndex) {
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return months[Math.max(0, Math.min(11, monthIndex))]
    }

    function monthDayLabel(dateValue) {
        return I18n.monthDay(languageMode, dateValue)
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
        var raw = (calendarManager && calendarManager.dayPhotos) ? calendarManager.dayPhotos : ""
        if (raw === "")
            return {}
        if (raw === root._photoRaw)
            return root._photoParsed
        var parsed = {}
        try {
            parsed = JSON.parse(raw)
        } catch (e) {
            parsed = {}
        }
        root._photoRaw = raw
        root._photoParsed = parsed
        return parsed
    }

    // 聊天图片按日索引，整段 JSON 只解析一次。原先每问一天就把**整个聊天记录**读一次 KV
    // 再整块解析一遍，只为挑出那一天的图。
    function chatImageIndex() {
        var raw = settingsRepository ? settingsRepository.getValue("local_memo_chat_messages", "") : ""
        if (!raw || raw === "")
            return {}
        if (raw === root._chatRaw)
            return root._chatByDate
        var index = {}
        try {
            var chats = JSON.parse(raw)
            for (var i = 0; i < chats.length; i++) {
                var item = chats[i]
                if (item.imagePath && item.imagePath !== "" && item.timeText) {
                    var k = item.timeText.substring(0, 10)
                    if (!index[k])
                        index[k] = []
                    index[k].push(item.imagePath)
                }
            }
        } catch (e) {
            index = {}
        }
        root._chatRaw = raw
        root._chatByDate = index
        return index
    }

    function chatImagesForDate(key) {
        var hit = chatImageIndex()[key]
        return hit ? hit : []
    }

    function normalizedImageSource(path) {
        var s = path ? ("" + path).trim() : ""
        if (s === "")
            return ""
        if (s.indexOf("file:") === 0 || s.indexOf("qrc:") === 0 || s.indexOf("image:") === 0)
            return s
        s = s.replace(/\\/g, "/")
        if (/^[A-Za-z]:\//.test(s))
            return "file:///" + encodeURI(s)
        return s
    }

    function backgroundForDate(key) {
        var manual = manualPhotoMap()
        if (manual[key] && manual[key] !== "")
            return normalizedImageSource(manual[key])

        var images = chatImagesForDate(key)
        return images.length > 0 ? normalizedImageSource(images[0]) : ""
    }

    function selectedPhotoSource() {
        return backgroundForDate(selectedDateKey)
    }

    function setManualPhotoForSelectedDate(path) {
        var map = manualPhotoMap()
        map[selectedDateKey] = normalizedImageSource(path)
        if (calendarManager)
            calendarManager.setDayPhotos(JSON.stringify(map))
        refreshCalendar()
        showCalToast("Photo updated")
    }

    // —— JSON 解析记忆化 ——
    // 下面几个存储都是「一大块 JSON 字符串」，而助手函数是按天调用的：一次选中日变化就会
    // 经 weekViewTaskCount → weekDays、model: weekDays(...)、model: dayAgenda(...) 至少把
    // 待办整块解析 3 遍，纪念日整块 1 遍。缓存键取**原始字符串本身**——存储没变就不重解析，
    // 变了（字符串不等）自动失效，无需任何手动作废。
    property var _todosRaw: null
    property var _todosParsed: ({})
    property var _annRaw: null
    property var _annParsed: []
    property var _photoRaw: null
    property var _photoParsed: ({})
    property var _chatRaw: null
    property var _chatByDate: ({})

    function allTodosMap() {
        var raw = (calendarManager && calendarManager.savedTodos) ? calendarManager.savedTodos : ""
        if (raw === "")
            return {}
        if (raw === root._todosRaw)
            return root._todosParsed
        var parsed = {}
        try {
            parsed = JSON.parse(raw)
        } catch (e) {
            parsed = {}
        }
        root._todosRaw = raw
        root._todosParsed = parsed
        return parsed
    }

    function todosForDate(key) {
        var map = allTodosMap()
        return map[key] ? map[key] : []
    }

    // 写路径专用：拿一份**可改**的浅拷贝。allTodosMap() 现在返回的是缓存里那一个对象，
    // 就地改它会污染缓存——旧实现每次都重新解析，所以改了无所谓；加了缓存就有所谓了。
    // 浅拷贝够用：写路径只整天替换 map[key]，不会就地改某天的数组。
    function todosMapForEdit() {
        var src = allTodosMap()
        var copy = {}
        for (var k in src)
            copy[k] = src[k]
        return copy
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
        var raw = anniversarySettings.savedAnniversaries ? anniversarySettings.savedAnniversaries : ""
        if (raw === "")
            return []
        if (raw === root._annRaw)
            return root._annParsed
        var arr = []
        try {
            var parsed = JSON.parse(raw)
            arr = parsed ? parsed : []
        } catch (e) {
            arr = []
        }
        root._annRaw = raw
        root._annParsed = arr
        return arr
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
    function typeLabel(type) {
        return type === "event" ? tr("Event") : type === "focus" ? tr("Focus") : tr("Todos")
    }

    // 左栏统计芯片（§2.7）：今日事项 / 完成率 / 专注块(今日 focus 数) / 本周任务(本周周一起事项总数) 均为真值。
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

    // 底中变更反馈胶囊（v88 §1.11 showCalendarToast）。净增反馈，低风险。
    function showCalToast(msg) {
        calToast.message = tr(msg)
        calToast.shown = true
        toastTimer.restart()
    }


    // 跳到任意日期（切月 + 选中 + 重渲染），供时间选择器「安排到他日」用。
    function goToDate(key) {
        var d = dateFromKey(key)
        viewedMonth = new Date(d.getFullYear(), d.getMonth(), 1)
        selectDate(key)
        refreshCalendar()
    }

    // 一次性构建 dateKey→照片路径 查找表（手动优先，回退当天首张 chat 图）。
    // 取代 buildCalendarCells 内每格重新解析整段 chat JSON（42× 解析 → 1×）。
    function buildPhotoLookup() {
        var result = {}
        // 复用按日索引（同一份缓存），不再在这里单独解析一遍整段 chat JSON。
        var index = chatImageIndex()
        for (var k in index)
            if (index[k].length > 0)
                result[k] = index[k][0]   // 同旧行为：取当天第一张
        var manual = manualPhotoMap()
        for (var key in manual)
            if (manual[key] && manual[key] !== "")
                result[key] = manual[key]
        return result
    }

    function anniversaryTypeFromText(text) {
        return text.indexOf("Countdown") >= 0 ? "countdown" : "since"
    }

    function anniversaryKind(item) {
        return item.type === "countdown" || item.type === "yearly" ? "countdown" : "since"
    }

    // 创建纪念日已并入创建弹层（见 addAnniversaryFromPopup / submitCreate）。

    function removeAnniversaryById(id) {
        var list = allAnniversaries()
        var result = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== id)
                result.push(list[i])
        }
        saveAnniversaries(result)
        showCalToast("Deleted")
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
                return sentence("countdownDaysLeft", {count: left})
            if (left === 0)
                return "Today"
            return sentence("countdownDaysPast", {count: Math.abs(left)})
        }

        var passed = daysBetween(dateFromKey(item.dateKey), todayDate)
        if (passed >= 0)
            return sentence("anniversaryDaysSince", {count: passed})
        return sentence("anniversaryDaysUntil", {count: Math.abs(passed)})
    }

    function anniversarySubtitle(item) {
        if (anniversaryKind(item) === "countdown")
            return sentence("targetDay", {date: item.dateKey})
        return sentence("anniversarySince", {date: item.dateKey})
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
        var map = todosMapForEdit()   // 要改它，所以取可写副本（见 todosMapForEdit）
        var arr = []
        for (var i = 0; i < todoModel.count; i++) {
            var item = todoModel.get(i)
            arr.push({
                text: item.text,
                done: item.done,
                tag: item.tag ? item.tag : fixedTags[0],
                linkedProject: item.linkedProject ? item.linkedProject : "",
                time: item.time ? item.time : "",
                type: item.type ? item.type : "todo",
                desc: item.desc ? item.desc : "",
                // 便签投影行的来源标记 + nid：原样回写，使「同日原生编辑」不把便签行抹掉/转为原生（投影桥唯一权威仍是便签）。
                src: item.src ? item.src : "",
                nid: item.nid ? item.nid : ""
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
                type: arr[i].type ? arr[i].type : "todo",
                desc: arr[i].desc ? arr[i].desc : "",
                src: arr[i].src ? arr[i].src : "",      // "memo" = 由便签投影；"" = 原生待办
                nid: arr[i].nid ? arr[i].nid : ""
            })
        }
    }

    function projectChoicesForTag(tag) {
        projectRefreshKey
        var choices = ["Not linked"]
        if (!projectManager)
            return choices

        var list = projectManager.projectsForTag(tag, "all")
        for (var i = 0; i < list.length; i++)
            choices.push(list[i].name)
        return choices
    }

    function linkedProjectFromChoice(choice) {
        return choice === "Not linked" ? "" : choice
    }

    // 调色板与图标统一委托到 TagPalette.js（单一来源，杜绝多页色表漂移）。
    function tagColor(tag) { return TagPalette.tagColor(tag) }
    function tagIcon(tag) { return TagPalette.tagIcon(tag) }

    // 创建从独立弹出界面提交（参考时间选择浮层）。本日 = 当前选中日，无需选日期。
    function addTodo() {
        var text = createTitleInput.text.trim()
        if (text.length === 0)
            return
        todoModel.append({
            text: text,
            done: false,
            tag: root.todoTag,
            linkedProject: "",
            time: root.createTime,
            type: "todo",
            desc: createDescEdit.text.trim(),
            src: "",                         // 原生待办（非便签投影）：补齐 src/nid 角色，满足 delegate required 属性
            nid: ""
        })
        saveTodosForSelectedDate()
        showCalToast(tr("Todo created"))
    }

    function addAnniversaryFromPopup() {
        var title = createTitleInput.text.trim()
        if (title.length === 0)
            return
        var list = allAnniversaries().slice()   // 要 push，先脱离缓存数组
        list.push({
            id: selectedDateKey + "-" + Date.now() + "-" + Math.floor(Math.random() * 10000),
            title: title,
            dateKey: selectedDateKey,
            type: anniversaryTypeFromText(root.annType),
            desc: createDescEdit.text.trim()
        })
        saveAnniversaries(list)
        showCalToast(tr("Anniversary created"))
    }

    function openCreate() {
        createTitleInput.text = ""
        root.createTime = ""
        createDescEdit.text = ""
        root.createOpen = true
        createTitleInput.forceActiveFocus()
    }
    function closeCreate() {
        root.createOpen = false
    }
    function submitCreate() {
        if (sidePanelMode === "anniversaries")
            addAnniversaryFromPopup()
        else
            addTodo()
        closeCreate()
    }

    // 时间选择浮层：点时间格 → 时:分步进选择（无需手打）。
    function openTimePicker() {
        var t = root.createTime
        if (t && t.indexOf(":") > 0) {
            root.pickHour = Math.max(0, Math.min(23, parseInt(t.split(":")[0]) || 0))
            root.pickMinute = Math.max(0, Math.min(59, parseInt(t.split(":")[1]) || 0))
        } else {
            root.pickHour = 9
            root.pickMinute = 0
        }
        root.timePickerOpen = true
    }
    function commitTimePick() {
        root.createTime = pad2(root.pickHour) + ":" + pad2(root.pickMinute)
        root.timePickerOpen = false
    }

    // 议程项操作走 root 函数：在 delegate 被 remove 销毁的同一帧里，后续 save 仍在 root 作用域执行，
    // 不会因 delegate 析构而断流（曾导致「删不掉」）。
    function removeTodoAt(idx) {
        if (idx < 0 || idx >= todoModel.count)
            return
        todoModel.remove(idx)
        saveTodosForSelectedDate()
        showCalToast("Deleted")
    }
    function toggleTodoDoneAt(idx) {
        if (idx < 0 || idx >= todoModel.count)
            return
        todoModel.setProperty(idx, "done", !todoModel.get(idx).done)
        saveTodosForSelectedDate()
    }

    function dayProjects() {
        return dayProjectsFor(selectedDateKey)
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

    // ===== 三视图（周计划 / 今日议程 / 专注记录）数据助手 —— 全部复用既有数据，零新增 C++ =====

    // 任意日的 calendar_todo 计时条（dayProjects 的按 key 版本；dayProjects 锁定 selectedDateKey）。
    function dayProjectsFor(key) {
        projectRefreshKey
        if (!projectManager)
            return []
        var list = projectManager.timeEntriesForDate(key)
        var filtered = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].source === "calendar_todo" && (list[i].seconds ? list[i].seconds : 0) > 0)
                filtered.push(list[i])
        }
        filtered.sort(function (a, b) { return (b.seconds ? b.seconds : 0) - (a.seconds ? a.seconds : 0) })
        return filtered
    }

    // 选中日所在周的周一（周一起始：偏移 (getDay()+6)%7，与月视图/MemoDatePicker 一致）。
    function weekStartDate(key) {
        var d = dateFromKey(key)
        d.setDate(d.getDate() - ((d.getDay() + 6) % 7))
        return new Date(d.getFullYear(), d.getMonth(), d.getDate())
    }

    // 周计划：选中周 7 天（一→日），每天带当天待办/事件。一次性解析 savedTodos（不逐格重析）。
    function weekDays(key) {
        var labels = I18n.weekdaysNarrow(languageMode)
        var map = allTodosMap()
        var todayKey = dateKey(todayDate)
        var start = weekStartDate(key)
        var out = []
        for (var i = 0; i < 7; i++) {
            var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            var k = dateKey(d)
            var evs = map[k] ? map[k] : []
            var done = 0
            for (var j = 0; j < evs.length; j++)
                if (evs[j].done) done += 1
            out.push({ dateKey: k, day: d.getDate(), weekdayLabel: labels[i],
                       isToday: k === todayKey, isSelected: k === selectedDateKey,
                       events: evs, doneCount: done, total: evs.length })
        }
        return out
    }

    function weekRangeLabel(key) {
        var s = weekStartDate(key)
        var e = new Date(s.getFullYear(), s.getMonth(), s.getDate() + 6)
        return monthDayLabel(s) + " – " + monthDayLabel(e)
    }

    function weekViewTaskCount(key) {
        var days = weekDays(key)
        var n = 0
        for (var i = 0; i < days.length; i++)
            n += days[i].total
        return n
    }

    // 今日议程：'HH:mm' → 自零点分钟数（排序用）；空/非法 → 大哨兵（排到最后）。
    function minutesOf(hhmm) {
        if (!hhmm || hhmm.indexOf(":") < 0)
            return 100000
        var p = hhmm.split(":")
        var h = parseInt(p[0]), m = parseInt(p[1])
        if (isNaN(h) || isNaN(m))
            return 100000
        return h * 60 + m
    }

    // 今日议程：选中日「纪念(全天置顶) + 定时待办 + 未定待办 + 专注记录」按时间合并排序的只读时间线。
    function dayAgenda(key) {
        var rows = []
        var anns = anniversariesForDate(key)
        for (var a = 0; a < anns.length; a++)
            rows.push({ sort: -1, time: "", label: anns[a].title, type: "event",
                        tag: "", done: false, subtitle: anniversarySubtitle(anns[a]), seconds: 0 })
        var todos = todosForDate(key)
        for (var t = 0; t < todos.length; t++) {
            var it = todos[t]
            var timed = it.time && it.time !== ""
            rows.push({ sort: timed ? minutesOf(it.time) : 90000, time: timed ? it.time : "",
                        label: it.text, type: (it.type ? it.type : "todo"),
                        tag: it.tag ? it.tag : "", done: it.done === true,
                        subtitle: it.desc ? it.desc : "", seconds: 0 })
        }
        var foc = dayProjectsFor(key)
        for (var f = 0; f < foc.length; f++)
            rows.push({ sort: 99000, time: "", label: foc[f].name ? foc[f].name : "Focus",
                        type: "focus", tag: foc[f].tag ? foc[f].tag : "", done: false,
                        subtitle: "", seconds: foc[f].seconds ? foc[f].seconds : 0 })
        rows.sort(function (x, y) {
            if (x.sort !== y.sort) return x.sort - y.sort
            return x.time < y.time ? -1 : (x.time > y.time ? 1 : 0)
        })
        return rows
    }

    // 专注记录：任意日专注总秒数（按 key）。
    function dayFocusSeconds(key) {
        var list = dayProjectsFor(key)
        var total = 0
        for (var i = 0; i < list.length; i++)
            total += list[i].seconds ? list[i].seconds : 0
        return total
    }

    // 专注记录：重建本周 7 柱缓存（7×timeEntriesForDate，仅在选中日/数据变更时算一次）。
    function refreshWeekFocus() {
        var days = weekDays(selectedDateKey)
        var model = []
        var mx = 1
        for (var i = 0; i < days.length; i++) {
            var s = dayFocusSeconds(days[i].dateKey)
            if (s > mx) mx = s
            model.push({ dateKey: days[i].dateKey, weekdayLabel: days[i].weekdayLabel,
                         seconds: s, isSelected: days[i].isSelected, isToday: days[i].isToday })
        }
        weekFocusModel = model
        weekMaxFocusSeconds = mx
    }

    // 专注记录：选中日按标签聚合专注时长（降序）。
    function dayTagSummary(key) {
        var list = dayProjectsFor(key)
        var sums = {}
        var order = []
        for (var i = 0; i < list.length; i++) {
            var tg = list[i].tag && list[i].tag !== "" ? list[i].tag : "Other"
            if (sums[tg] === undefined) { sums[tg] = 0; order.push(tg) }
            sums[tg] += list[i].seconds ? list[i].seconds : 0
        }
        var out = []
        for (var j = 0; j < order.length; j++)
            out.push({ tag: order[j], seconds: sums[order[j]] })
        out.sort(function (a, b) { return b.seconds - a.seconds })
        return out
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
        refreshWeekFocus()
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
            color: ml.panelBg
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
                        font.letterSpacing: 0
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.tr("Organize todos, photos, and timer records by date")
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
                                cursorShape: Cursor.button(); onClicked: previousMonth() }
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
                    Text { anchors.centerIn: parent; text: root.tr("Today"); color: ml.calBtnInk
                           font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Cursor.button()
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
                                cursorShape: Cursor.button(); onClicked: nextMonth() }
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
                color: ml.panelBg
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
                            Text { text: root.tr("Calendar"); color: ml.textPrimary; font.pixelSize: 26
                                   font.weight: Font.Bold; font.letterSpacing: 0 }
                            Text { text: root.tr("Organize time context by date"); color: ml.textTertiary; font.pixelSize: 11 }
                        }
                    }

                    // 4 视图 Tab：month/week/today/focus 均真渲染（点击切 activeView）。
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [
                                { key: "month", label: "Month",   glyph: "▦" },
                                { key: "week",  label: "Week Plan",   glyph: "▤" },
                                { key: "today", label: "Agenda", glyph: "▣" },
                                { key: "focus", label: "Focus Records", glyph: "◴" }
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
                                        text: root.tr(modelData.label)
                                        color: activeView === modelData.key ? ml.textPrimary : ml.textSecondary
                                        font.pixelSize: 13
                                        font.weight: activeView === modelData.key ? Font.DemiBold : Font.Normal
                                        width: 160
                                        elide: Text.ElideRight
                                    }
                                }
                                MouseArea {
                                    id: tabMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Cursor.button()
                                    onClicked: {
                                        activeView = modelData.key
                                        showCalToast(root.sentence("switchedRangeView", {range: root.tr(modelData.label)}))
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // 2×2 统计芯片（今日事项/完成率/专注块/本周任务，均为真值）
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10
                        Repeater {
                            model: [
                                { label: "Today's Items", key: "items", real: true },
                                { label: "Completion",   key: "rate",  real: true },
                                { label: "Focus Blocks",   key: "focus", real: true },
                                { label: "Week Tasks", key: "week",  real: true }
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
                        Text { text: root.tr(modelData.label); color: ml.textTertiary; font.pixelSize: 10 }
                                    Text { text: statValue(modelData.key); color: ml.textPrimary
                                           font.pixelSize: 21; font.weight: Font.Bold }
                                }
                            }
                        }
                    }
                }
            }

            // ===== 中栏：月视图（仅 activeView==="month" 真渲染）=====
            // v88 月视图（M-B2，§1.8）：玻璃底 + 周一表头 + 发丝账本栅格。
            // 用圆角 Rectangle（非 RoundedFrame）承载：RoundedFrame 把内容合成进 FBO（holder
            // visible:false）会吞掉 cell 的鼠标点选、并使栅格相对表头有微位移；圆角处「不画最外圈
            // 发丝线」即可避免方角外露（见 cell delegate 的 visible 条件）。
            Rectangle {
                id: monthView
                visible: activeView === "month"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 22
                color: ml.panelBg
                border.width: 1
                border.color: ml.panelBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 1
                    spacing: 0

                    // 周一表头（一..日）— 用 GridLayout(7 列) 与下方格栅同一套列分配，保证逐列对齐。
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        columns: 7
                        columnSpacing: 0
                        rowSpacing: 0

                        Repeater {
                            model: I18n.weekdaysNarrow(root.languageMode)

                            delegate: Item {
                                required property string modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.centerIn: parent
                                    text: root.tr(modelData)
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
                                required property int index

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 84
                                opacity: modelData.inMonth ? 1.0 : 0.35

                                // 右/下发丝线（最右列/最底行不画 → 圆角处无方角发丝外露）
                                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: ml.cellHair; visible: (index % 7) !== 6 }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: ml.cellHair; visible: index < 35 }

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
                            text: modelData.countdownCount > 0 ? root.tr("D") : root.tr("A")
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
                                                text: (ev.time && ev.time !== "" ? displayTime(ev.time) + " " : "") + ev.text
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
                                    cursorShape: Cursor.button()
                                    onClicked: selectCellDate(modelData)
                                }
                            }
                        }
                    }
                }
            }

            // ===== 中栏：周计划（activeView==="week"）=====
            // 选中周 7 列；复用月视图栅格配方（纯 Rectangle 承载——RoundedFrame 的 FBO holder
            // visible:false 会吞列点击/微移栅格，故此处禁用 RoundedFrame）。点列头/列即选当天。
            Rectangle {
                id: weekView
                visible: activeView === "week"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 22
                color: ml.panelBg
                border.width: 1
                border.color: ml.panelBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 1
                    spacing: 0

                    // 表头：本周区间 + 本周任务数（跟随选中日，区别于左栏锚定今日的统计芯片）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: weekRangeLabel(selectedDateKey)
                                color: ml.textPrimary
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text { text: root.tr("This Week"); color: ml.textTertiary; font.pixelSize: 10 }
                        }
                        Text {
                            text: root.sentence("itemCount", {count: weekViewTaskCount(selectedDateKey)})
                            color: ml.textTertiary
                            font.pixelSize: 11
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: ml.cellHair }

                    // 7 列（周一→周日）
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        columnSpacing: 0
                        rowSpacing: 0

                        Repeater {
                            model: weekDays(selectedDateKey)

                            delegate: Item {
                                id: weekCol
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 84

                                // 右发丝线（最后一列不画）
                                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: ml.cellHair; visible: weekCol.index !== 6 }

                                // 今日底洗 + 角晕
                                Rectangle { anchors.fill: parent; visible: weekCol.modelData.isToday; color: ml.todayWash }
                                GlowCircle {
                                    visible: weekCol.modelData.isToday
                                    width: 130; height: 130
                                    x: parent.width * 0.8 - width / 2
                                    y: parent.height * 0.12 - height / 2
                                    glowColor: ml.aqua
                                    glowOpacity: 0.16 * ml.glowStrength
                                }
                                // hover 洗（非选中态）
                                Rectangle {
                                    anchors.fill: parent
                                    visible: weekColMouse.containsMouse && weekCol.modelData.dateKey !== selectedDateKey
                                    color: ml.cellHover
                                }
                                // 选中 2px 内环
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    visible: weekCol.modelData.dateKey === selectedDateKey
                                    color: "transparent"
                                    border.width: 2
                                    border.color: ml.selectedRing
                                }

                                // 列头：星期 + 日号 + 完成数
                                Column {
                                    id: weekColHead
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.topMargin: 8
                                    spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: weekCol.modelData.weekdayLabel
                                        color: ml.textTertiary
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.letterSpacing: 1
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: weekCol.modelData.day
                                        color: weekCol.modelData.isToday ? ml.aqua : ml.cellDateText
                                        font.pixelSize: 15
                                        font.weight: (weekCol.modelData.isToday || weekCol.modelData.isSelected) ? Font.Bold : Font.DemiBold
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: weekCol.modelData.total > 0
                                        text: weekCol.modelData.doneCount + "/" + weekCol.modelData.total
                                        color: ml.textTertiary
                                        font.pixelSize: 10
                                    }
                                }

                                // 空日占位
                                Text {
                                    visible: weekCol.modelData.events.length === 0
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: weekColHead.bottom
                                    anchors.topMargin: 18
                                    text: "—"
                                    color: ml.textTertiary
                                    font.pixelSize: 14
                                }

                                // 事件 chips（展示态，裁切溢出；whole-column 点选交给上面的 MouseArea）
                                Item {
                                    anchors.top: weekColHead.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.topMargin: 6
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    anchors.bottomMargin: 6
                                    clip: true
                                    Column {
                                        width: parent.width
                                        spacing: 3
                                        Repeater {
                                            model: weekCol.modelData.events
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: parent.width
                                                height: 16
                                                radius: 8
                                                color: eventChipBg(modelData.type)
                                                border.width: 1
                                                border.color: eventChipBd(modelData.type)
                                                Text {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 6
                                                    anchors.rightMargin: 6
                                                    verticalAlignment: Text.AlignVCenter
                                                    elide: Text.ElideRight
                                                    text: (modelData.time && modelData.time !== "" ? displayTime(modelData.time) + " " : "") + modelData.text
                                                    color: ml.chipText
                                                    font.pixelSize: 9
                                                }
                                            }
                                        }
                                    }
                                }

                                // 整列点选（在最上层；chips 为展示态、无自身命中）
                                MouseArea {
                                    id: weekColMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Cursor.button()
                                    onClicked: selectCellDate({ dateKey: weekCol.modelData.dateKey,
                                                                inMonth: dateFromKey(weekCol.modelData.dateKey).getMonth() === viewedMonth.getMonth() })
                                }
                            }
                        }
                    }
                }
            }

            // ===== 中栏：今日议程（activeView==="today"）=====
            // 选中日的「纪念(全天置顶) + 定时待办 + 未定待办 + 专注记录」按时间合并的只读时间线。
            // 只读（无勾选/开始/删除）：保持唯一写路径在右栏 + 创建弹层，与右栏列表区分为「时间线视角」。
            Rectangle {
                id: todayView
                visible: activeView === "today"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 22
                color: ml.panelBg
                border.width: 1
                border.color: ml.panelBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: selectedDateLabel()
                            color: ml.textPrimary
                            font.pixelSize: 16
                            font.weight: Font.Bold
                        }
                        Text {
                            text: root.sentence("focusDuration", {time: secondsToDisplay(selectedDateTotalSeconds())})
                            color: ml.accentText
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: ml.cellHair }

                    SilkyFlickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        style: ml

                        Column {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                id: agendaRepeater
                                model: dayAgenda(selectedDateKey)
                                delegate: Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 50
                                    radius: 13
                                    color: ml.calSunkBg
                                    border.width: 1
                                    border.color: ml.cardBorder

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        // 左：时间轨（脊柱色 + 时间/标记）
                                        RowLayout {
                                            Layout.preferredWidth: 52
                                            Layout.fillHeight: true
                                            spacing: 6
                                            Rectangle {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredWidth: 3
                                                Layout.preferredHeight: 28
                                                radius: 1.5
                                                color: eventSpine(modelData.type)
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                text: modelData.type === "event" ? root.tr("All day")
                                                      : (modelData.time && modelData.time !== "" ? displayTime(modelData.time)
                                                      : (modelData.type === "focus" ? root.tr("Focus") : root.tr("Unscheduled")))
                                                color: (modelData.time && modelData.time !== "") ? ml.glowCyan : ml.textTertiary
                                                font.pixelSize: (modelData.time && modelData.time !== "") ? 11 : 10
                                                font.bold: (modelData.time && modelData.time !== "")
                                            }
                                        }

                                        // 中：标题 + 副行
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                Layout.fillWidth: true
                                            text: root.tr(modelData.label)
                                                color: modelData.done ? ml.textSecondary : ml.textPrimary
                                                font.pixelSize: 13
                                                font.bold: true
                                                font.strikeout: modelData.done
                                                elide: Text.ElideRight
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                TagChip {
                                                    visible: modelData.type !== "event" && modelData.type !== "focus" && modelData.tag !== ""
                                                    tag: modelData.tag
                                                    style: ml
                                                    languageMode: root.languageMode
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    visible: text !== ""
                                                    text: modelData.type === "focus" ? secondsToDisplay(modelData.seconds)
                                                          : (modelData.subtitle ? modelData.subtitle : "")
                                                    color: modelData.type === "focus" ? ml.accentText : ml.textTertiary
                                                    font.pixelSize: 10
                                                    font.bold: modelData.type === "focus"
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        // 右：类型 pill
                                        Rectangle {
                                            Layout.preferredWidth: typeMk.implicitWidth + 14
                                            Layout.preferredHeight: 18
                                            radius: 9
                                            color: eventChipBg(modelData.type)
                                            border.width: 1
                                            border.color: eventChipBd(modelData.type)
                                            Text {
                                                id: typeMk
                                                anchors.centerIn: parent
                                                text: typeLabel(modelData.type)
                                                color: ml.chipText
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 120
                                visible: agendaRepeater.count === 0
                                Text {
                                    anchors.centerIn: parent
                                    text: root.tr("Nothing scheduled for this day")
                                    color: ml.textTertiary
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }
            }

            // ===== 中栏：专注记录（activeView==="focus"）=====
            // 本周 7 柱（跟随选中日） + 选中日总计 + 逐项目计时条 + 按标签聚合。右栏「记录」仅单日条，
            // 此处多了「跨天对比」与「按标签」两条轴。本周柱可点选当天。
            Rectangle {
                id: focusView
                visible: activeView === "focus"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 22
                color: ml.panelBg
                border.width: 1
                border.color: ml.panelBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    Text { text: root.tr("This Week's Focus"); color: ml.textPrimary; font.pixelSize: 13; font.bold: true }

                    // 本周 7 柱
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        spacing: 8
                        Repeater {
                            model: weekFocusModel
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 4
                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 90
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: ml.trackBg
                                        border.width: modelData.isSelected ? 1 : 0
                                        border.color: ml.selectedRing
                                    }
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width
                                        height: parent.height * (modelData.seconds / Math.max(1, weekMaxFocusSeconds))
                                        radius: 6
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: ml.aqua }
                                            GradientStop { position: 1; color: ml.violet }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Cursor.button()
                                        onClicked: selectCellDate({ dateKey: modelData.dateKey,
                                                                    inMonth: dateFromKey(modelData.dateKey).getMonth() === viewedMonth.getMonth() })
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.weekdayLabel
                                    color: modelData.isToday ? ml.aqua : ml.textTertiary
                                    font.pixelSize: 10
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: secondsToDisplay(modelData.seconds)
                                    color: ml.accentText
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }

                    // 选中日总计
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: selectedDateLabel(); color: ml.textPrimary; font.pixelSize: 13; font.bold: true }
                        Text { text: secondsToDisplay(selectedDateTotalSeconds()); color: ml.accentText; font.pixelSize: 18; font.bold: true }
                        Text { Layout.fillWidth: true; text: root.sentence("projectCount", {count: dayProjects().length}); color: ml.textTertiary; font.pixelSize: 11 }
                    }

                    // 逐项目计时条 + 按标签（同一滚动列）
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
                                height: 80
                                visible: dayProjects().length === 0
                                Text {
                                    anchors.centerIn: parent
                                    text: root.tr("No focus records for this day")
                                    color: ml.textTertiary
                                    font.pixelSize: 13
                                }
                            }

                            Text {
                                visible: dayTagSummary(selectedDateKey).length > 0
                                text: root.tr("By Tag")
                                color: ml.textTertiary
                                font.pixelSize: 11
                                topPadding: 4
                            }
                            Flow {
                                width: parent.width
                                spacing: 8
                                Repeater {
                                    model: dayTagSummary(selectedDateKey)
                                    delegate: Row {
                                        required property var modelData
                                        spacing: 5
                                        TagChip { tag: modelData.tag; style: ml; languageMode: root.languageMode }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: secondsToDisplay(modelData.seconds)
                                            color: ml.textSecondary
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ===== 右栏：选中日卡 + 模式（待办/记录/纪念）=====
            GlassPanel {
                Layout.preferredWidth: 310
                Layout.fillHeight: true
                style: ml
                color: ml.panelBg
                dropShadow: false
                radius: 22

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    // v88 选中日卡（§1.10）：外层 Item 承载（让「加照片」按钮可点）；内层 RoundedFrame
                    // 只裁视觉（底/角晕/照片/压暗，无 MouseArea，G7 不漏方角）；内容(含按钮)放其外、在上。
                    Item {
                        id: selDayCard
                        property string selPhoto: selectedPhotoSource()
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150

                        RoundedFrame {
                            anchors.fill: parent
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
                                cache: false
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
                                        text: selDayCard.selPhoto === "" ? "+ " + root.tr("Add Photo") : "+ " + root.tr("Change Photo")
                                        color: ml.calGlyph
                                        font.pixelSize: 13
                                    }
                                    MouseArea {
                                        id: photoMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Cursor.button()
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
                                    { key: "tasks", label: "Todos" },
                                    { key: "records", label: "Records" },
                                    { key: "anniversaries", label: "Anniversaries" }
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
                                        text: root.tr(modelData.label)
                                        color: sidePanelMode === modelData.key ? ml.calBtnInk : ml.textSecondary
                                        font.pixelSize: 13
                                        font.weight: sidePanelMode === modelData.key ? Font.Bold : Font.DemiBold
                                    }

                                    MouseArea {
                                        id: segMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Cursor.button()
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
                                        required property string desc
                                        required property string src     // "memo" = 便签投影行
                                        required property string nid     // 便签 id（反向回写定位）

                                        width: parent.width
                                        height: 60
                                        radius: 13
                                        color: ml.calSunkBg
                                        border.width: 1
                                        border.color: ml.cardBorder

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            // 完成切换（aqua→violet 渐变勾选框 + ✓，与首页今日事项一致）
                                            Rectangle {
                                                Layout.preferredWidth: 22
                                                Layout.preferredHeight: 22
                                                radius: 8
                                                color: Qt.rgba(1, 1, 1, 0.06)
                                                border.width: agendaItem.done ? 0 : 1
                                                border.color: Qt.rgba(ml.glowCyan.r, ml.glowCyan.g, ml.glowCyan.b, 0.22)
                                                gradient: agendaItem.done ? agDoneGrad : null
                                                Gradient {
                                                    id: agDoneGrad
                                                    GradientStop { position: 0; color: Qt.rgba(ml.glowCyan.r, ml.glowCyan.g, ml.glowCyan.b, 0.86) }
                                                    GradientStop { position: 1; color: Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0.82) }
                                                }
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
                                                    cursorShape: Cursor.button()
                                                    preventStealing: true
                                                    // 便签投影行：完成态回写到便签（单一来源 odone）；原生行走 todoModel。
                                                    onClicked: {
                                                        if (agendaItem.src === "memo") {
                                                            if (memoOverlayRef)
                                                                memoOverlayRef.setNoteDoneByNid(agendaItem.nid, !agendaItem.done)
                                                        } else {
                                                            toggleTodoDoneAt(agendaItem.index)
                                                        }
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: agendaItem.text
                                                    color: agendaItem.done ? ml.textSecondary : ml.textPrimary
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                    font.strikeout: agendaItem.done
                                                    elide: Text.ElideRight
                                                }

                                                // 副标：tag 小标 + 时间(aqua) + 详情（对齐 v88/首页 .todo-copy small）
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6

                                                    TagChip {
                                                        tag: agendaItem.tag
                                                        style: ml
                                                        languageMode: root.languageMode
                                                    }

                                                    // 便签来源标记（紫，呼应便签上的「待办」勾色）：提示该行来自备忘黑板便签。
                                                    Rectangle {
                                                        visible: agendaItem.src === "memo"
                                                        Layout.preferredWidth: memoMk.implicitWidth + 12
                                                        Layout.preferredHeight: 16
                                                        radius: 8
                                                        color: Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0.16)
                                                        border.width: 1
                                                        border.color: Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0.40)
                                                        Text {
                                                            id: memoMk
                                                            anchors.centerIn: parent
                                                            text: root.tr("Note")
                                                            color: ml.violet
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                        }
                                                    }

                                                    Text {
                                                        visible: agendaItem.time && agendaItem.time !== ""
                                                        text: displayTime(agendaItem.time)
                                                        color: Qt.rgba(ml.glowCyan.r, ml.glowCyan.g, ml.glowCyan.b, 0.85)
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: agendaItem.desc !== "" ? agendaItem.desc
                                                              : (agendaItem.linkedProject !== "" ? agendaItem.linkedProject : "")
                                                        color: ml.textTertiary
                                                        font.pixelSize: 10
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }

                                            // 开始（计时）—— 便签投影行隐藏（completeTodo 按文本匹配会被下次投影覆盖）。
                                            Rectangle {
                                                Layout.preferredWidth: 50
                                                Layout.preferredHeight: 30
                                                visible: !agendaItem.done && agendaItem.src !== "memo"
                                                radius: 10
                                                color: startMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                                                border.width: 1
                                                border.color: ml.calGhostBorder
                                                Text { anchors.centerIn: parent; text: root.tr("Start"); color: ml.calGlyph; font.pixelSize: 12 }
                                                MouseArea {
                                                    id: startMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Cursor.button()
                                                    preventStealing: true
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
                                                    cursorShape: Cursor.button()
                                                    preventStealing: true
                                                    // 便签投影行：删除=把便签降级（便签本身保留，不会被下次编辑复活）；原生行才真删。
                                                    onClicked: {
                                                        if (agendaItem.src === "memo") {
                                                            if (memoOverlayRef)
                                                                memoOverlayRef.demoteNoteByNid(agendaItem.nid)
                                                        } else {
                                                            removeTodoAt(agendaItem.index)
                                                        }
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
                                        text: root.tr("No agenda")
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
                                        text: root.tr("No timer records for this day")
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
                                            cursorShape: Cursor.button()
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
                                                    text: anniversaryKind(modelData) === "countdown" ? "D" : "A"
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
                                                          + ((modelData.desc && modelData.desc !== "") ? "  ·  " + modelData.desc : "")
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
                                                    cursorShape: Cursor.button()
                                                    preventStealing: true
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
                                        text: root.tr("No anniversaries or countdowns yet")
                                        color: ml.textTertiary
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }

                    // 底部「新建」bar：独立创建入口。待办/纪念可见；记录（自动计时）隐藏。
                    Rectangle {
                        visible: sidePanelMode !== "records"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 14
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: ml.aqua }
                            GradientStop { position: 1; color: ml.violet }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: sidePanelMode === "anniversaries" ? "＋ " + root.tr("New Anniversary") : "＋ " + root.tr("New Todo")
                            color: ml.calBtnInk
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Cursor.button()
                            onClicked: openCreate()
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



    // 创建弹出界面（参考时间选择浮层）：把「创建待办 / 纪念日」从主面板移进独立浮层。
    // 字段：标题 + tag（待办，固定色小标）/ 类型（纪念）+ 时间（待办，可选）+ 详情。本日 = 当前选中日。
    Item {
        id: createPopup
        anchors.fill: parent
        visible: root.createOpen
        z: 5000

        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5) }
        MouseArea { anchors.fill: parent; onClicked: closeCreate() }

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: createCol.implicitHeight + 32
            radius: 18
            gradient: Gradient {
                GradientStop { position: 0; color: ml.calPageTop }
                GradientStop { position: 1; color: ml.calPageBottom }
            }
            border.width: 1
            border.color: ml.chipEventBd
            antialiasing: true
            MouseArea { anchors.fill: parent }   // 吞卡内点击，不穿到遮罩关闭

            Column {
                id: createCol
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: 18; rightMargin: 18; topMargin: 16 }
                spacing: 12

                // 头部：标题 + 本日 + 关闭
                Item {
                    width: parent.width
                    height: 40
                    Column {
                        anchors.left: parent.left
                        anchors.right: createClose.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text { text: sidePanelMode === "anniversaries" ? root.tr("New Anniversary") : root.tr("New Todo")
                               color: ml.textPrimary; font.pixelSize: 17; font.weight: Font.Bold }
                        Text { text: root.sentence("thisDayLabel", {date: selectedDateLabel()}); color: ml.textTertiary; font.pixelSize: 11 }
                    }
                    Rectangle {
                        id: createClose
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28; radius: 9
                        color: closeMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                        border.width: 1; border.color: ml.calGhostBorder
                        Text { anchors.centerIn: parent; text: "×"; color: ml.calGlyph; font.pixelSize: 16; font.bold: true }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Cursor.button(); onClicked: closeCreate() }
                    }
                }

                // 标题
                Rectangle {
                    width: parent.width; height: 40; radius: 12
                    color: ml.calSunkBg; border.width: 1
                    border.color: createTitleInput.activeFocus ? ml.chipEventBd : ml.calInputBorder
                    TextInput {
                        id: createTitleInput
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        color: ml.textPrimary; font.pixelSize: 14; selectByMouse: true; clip: true
                        Keys.onReturnPressed: submitCreate()
                    }
                    Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                           visible: createTitleInput.text === ""
                           text: sidePanelMode === "anniversaries" ? root.tr("Anniversary Name") : root.tr("Title")
                           color: ml.textTertiary; font.pixelSize: 14 }
                }

                // 标签（待办）：真·标签 chip 选择器（选中=语义色，未选=中性灰）
                Flow {
                    width: parent.width
                    spacing: 6
                    visible: sidePanelMode !== "anniversaries"
                    Repeater {
                        model: fixedTags
                        delegate: TagChip {
                            required property string modelData
                            tag: modelData
                            style: ml
                            languageMode: root.languageMode
                            big: true
                            selected: root.todoTag === modelData
                            MouseArea { anchors.fill: parent; cursorShape: Cursor.button()
                                        onClicked: root.todoTag = modelData }
                        }
                    }
                }

                // 类型（纪念）：纪念日 / 倒计时日
                Row {
                    width: parent.width
                    spacing: 8
                    visible: sidePanelMode === "anniversaries"
                    Repeater {
                        model: ["Anniversary", "Countdown"]
                        delegate: Rectangle {
                            required property string modelData
                            width: (parent.width - 8) / 2; height: 36; radius: 12
                            gradient: root.annType === modelData ? annTypeGrad : null
                            color: root.annType === modelData ? "transparent" : ml.calGhostBg
                            border.width: 1
                            border.color: root.annType === modelData ? "transparent" : ml.calGhostBorder
                            Gradient { id: annTypeGrad; orientation: Gradient.Horizontal
                                       GradientStop { position: 0; color: ml.aqua }
                                       GradientStop { position: 1; color: ml.violet } }
                            Text { anchors.centerIn: parent; text: root.tr(modelData)
                                   color: root.annType === modelData ? ml.calBtnInk : ml.textSecondary
                                   font.pixelSize: 13; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Cursor.button()
                                        onClicked: root.annType = modelData }
                        }
                    }
                }

                // 时间（待办，可选）：点开时间选择浮层（时:分步进），不用手打。
                Rectangle {
                    width: parent.width; height: 38; radius: 12
                    visible: sidePanelMode !== "anniversaries"
                    color: ml.calSunkBg; border.width: 1
                    border.color: root.timePickerOpen ? ml.chipEventBd : ml.calInputBorder
                    Text { id: createTimeGlyph; anchors.left: parent.left; anchors.leftMargin: 12
                           anchors.verticalCenter: parent.verticalCenter; text: "⧗"; color: ml.aqua; font.pixelSize: 13 }
                    Text {
                        anchors.left: createTimeGlyph.right; anchors.right: timePickChev.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8; anchors.rightMargin: 6
                        text: root.createTime !== "" ? displayTime(root.createTime) : root.tr("Choose time (optional)")
                        color: root.createTime !== "" ? ml.textPrimary : ml.textTertiary
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Text { id: timePickChev; anchors.right: parent.right; anchors.rightMargin: 12
                           anchors.verticalCenter: parent.verticalCenter; text: "▾"; color: ml.textTertiary; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; cursorShape: Cursor.button(); onClicked: openTimePicker() }
                }

                // 详情（多行，可选）
                Rectangle {
                    width: parent.width; height: 84; radius: 12
                    color: ml.calSunkBg; border.width: 1
                    border.color: createDescEdit.activeFocus ? ml.chipEventBd : ml.calInputBorder
                    clip: true
                    Flickable {
                        anchors.fill: parent; anchors.margins: 10
                        contentHeight: createDescEdit.implicitHeight; clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        TextEdit {
                            id: createDescEdit
                            width: parent.width
                            color: ml.textPrimary; font.pixelSize: 13
                            wrapMode: TextEdit.Wrap; selectByMouse: true
                        }
                    }
                    Text { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 11
                           visible: createDescEdit.text === ""
                           text: root.tr("Details (optional)"); color: ml.textTertiary; font.pixelSize: 13 }
                }

                // 底部：取消 / 创建
                Row {
                    width: parent.width
                    spacing: 10
                    Rectangle {
                        width: (parent.width - 10) / 2; height: 40; radius: 12
                        color: createCancelMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                        border.width: 1; border.color: ml.calGhostBorder
                        Text { anchors.centerIn: parent; text: root.tr("Cancel"); color: ml.textSecondary; font.pixelSize: 14 }
                        MouseArea { id: createCancelMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Cursor.button(); onClicked: closeCreate() }
                    }
                    Rectangle {
                        width: (parent.width - 10) / 2; height: 40; radius: 12
                        gradient: Gradient { orientation: Gradient.Horizontal
                                             GradientStop { position: 0; color: ml.aqua }
                                             GradientStop { position: 1; color: ml.violet } }
                        Text { anchors.centerIn: parent; text: root.tr("Create"); color: ml.calBtnInk
                               font.pixelSize: 14; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; cursorShape: Cursor.button()
                                    onClicked: submitCreate() }
                    }
                }
            }
        }
    }

    // 时间选择浮层（时:分步进）：点创建弹层的时间格打开；确定回填 createTime。
    Item {
        id: timePicker
        anchors.fill: parent
        visible: root.timePickerOpen
        z: 5200

        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5) }
        MouseArea { anchors.fill: parent; onClicked: root.timePickerOpen = false }

        Rectangle {
            anchors.centerIn: parent
            width: 260
            height: tpCol.implicitHeight + 32
            radius: 18
            gradient: Gradient {
                GradientStop { position: 0; color: ml.calPageTop }
                GradientStop { position: 1; color: ml.calPageBottom }
            }
            border.width: 1
            border.color: ml.chipEventBd
            antialiasing: true
            MouseArea { anchors.fill: parent }

            Column {
                id: tpCol
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: 18; rightMargin: 18; topMargin: 16 }
                spacing: 14

                Text { text: root.tr("Choose Time"); color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.Bold }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    // 时
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 64; height: 30; radius: 9
                            color: hUpMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                            border.width: 1; border.color: ml.calGhostBorder
                            Text { anchors.centerIn: parent; text: "▲"; color: ml.aqua; font.pixelSize: 12 }
                            MouseArea { id: hUpMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Cursor.button(); onClicked: root.pickHour = (root.pickHour + 1) % 24 }
                        }
                        Rectangle {
                            width: 64; height: 48; radius: 12
                            color: ml.calSunkBg; border.width: 1; border.color: ml.calInputBorder
                            Text { anchors.centerIn: parent; text: pad2(root.pickHour); color: ml.textPrimary
                                   font.pixelSize: 22; font.weight: Font.Bold }
                        }
                        Rectangle {
                            width: 64; height: 30; radius: 9
                            color: hDnMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                            border.width: 1; border.color: ml.calGhostBorder
                            Text { anchors.centerIn: parent; text: "▼"; color: ml.aqua; font.pixelSize: 12 }
                            MouseArea { id: hDnMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Cursor.button(); onClicked: root.pickHour = (root.pickHour + 23) % 24 }
                        }
                    }

                    Text { anchors.verticalCenter: parent.verticalCenter; text: ":"; color: ml.textPrimary
                           font.pixelSize: 22; font.bold: true }

                    // 分（步进 5）
                    Column {
                        spacing: 6
                        Rectangle {
                            width: 64; height: 30; radius: 9
                            color: mUpMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                            border.width: 1; border.color: ml.calGhostBorder
                            Text { anchors.centerIn: parent; text: "▲"; color: ml.aqua; font.pixelSize: 12 }
                            MouseArea { id: mUpMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Cursor.button(); onClicked: root.pickMinute = (root.pickMinute + 5) % 60 }
                        }
                        Rectangle {
                            width: 64; height: 48; radius: 12
                            color: ml.calSunkBg; border.width: 1; border.color: ml.calInputBorder
                            Text { anchors.centerIn: parent; text: pad2(root.pickMinute); color: ml.textPrimary
                                   font.pixelSize: 22; font.weight: Font.Bold }
                        }
                        Rectangle {
                            width: 64; height: 30; radius: 9
                            color: mDnMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                            border.width: 1; border.color: ml.calGhostBorder
                            Text { anchors.centerIn: parent; text: "▼"; color: ml.aqua; font.pixelSize: 12 }
                            MouseArea { id: mDnMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Cursor.button(); onClicked: root.pickMinute = (root.pickMinute + 55) % 60 }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10
                    Rectangle {
                        width: (parent.width - 10) / 2; height: 38; radius: 12
                        color: tpClearMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                        border.width: 1; border.color: ml.calGhostBorder
                        Text { anchors.centerIn: parent; text: root.tr("Clear"); color: ml.textSecondary; font.pixelSize: 13 }
                        MouseArea { id: tpClearMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Cursor.button()
                                    onClicked: { root.createTime = ""; root.timePickerOpen = false } }
                    }
                    Rectangle {
                        width: (parent.width - 10) / 2; height: 38; radius: 12
                        gradient: Gradient { orientation: Gradient.Horizontal
                                             GradientStop { position: 0; color: ml.aqua }
                                             GradientStop { position: 1; color: ml.violet } }
                        Text { anchors.centerIn: parent; text: root.tr("OK"); color: ml.calBtnInk
                               font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; cursorShape: Cursor.button(); onClicked: commitTimePick() }
                    }
                }
            }
        }
    }

    FileDialog {
        id: dayPhotoDialog
        title: root.tr("Choose a background photo for this day")
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
            refreshWeekFocus()
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
        refreshWeekFocus()
        openAnim.start()
    }
}
