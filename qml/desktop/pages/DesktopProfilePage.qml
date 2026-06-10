import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import "../memorylake"

// v88「设置」页（暗玻璃全幅复刻 / 原地重皮 A-NAME）。规范：
//   docs/settings-functional-replication.md / settings-render-pipeline-replication.md /
//   settings-implementation-issues.md。
// 背景三件套（蓝黑渐变 + 42px 方格 + 双角辉光）由 DesktopAppShell 的 fullBleed 层提供
//   （已把 "settings" 加入 fullBleedPage + 栅格 visible + requestNavigate 路由）；本页只放内容。
// 契约：保留 nightMode + nightModeToggled（白天模式开关，不自写 night_mode，由 Shell 持久化）；
//   新增 requestNavigate（返回首页 / Esc）。设置项经 settingsRepository KV 即时持久化（G3）。
// 红线：对 usage jsonl/db 只读（G4/I1/I2）；无后端项（番茄/通知/真删历史）走隐藏/占位，不写死假值（G6）。
Item {
    id: root
    anchors.fill: parent
    clip: true
    focus: true

    // —— 主题契约（由 DesktopAppShell.applyThemeToLoadedPage 注入）——
    property bool nightMode: false
    property color themeTextPrimary: "#2D2724"
    property color themeTextSecondary: "#7C746D"
    property color themePanelColor: "#FBF8F4"
    property color themeBorderColor: "#E8E0D8"
    property color themeAccentColor: "#CFE8D8"

    // 白天模式开关 → Shell（Shell onLoaded 连接，写 night_mode，本页不自写，避免双写 R5）。
    signal nightModeToggled(bool enabled)
    // 顶栏「返回首页」/ Esc 切页（Shell onLoaded 连接，已含 settings）。
    signal requestNavigate(string pageKey)
    // 快捷键变更 → Shell 重读 memo/pomodoro 全局键（设置 KV 无变更信号，故显式通知，#3）。
    signal hotkeysChanged()

    // 记忆湖统一色板（单一事实源 G1）。夜=暗玻璃霓虹，昼=浅瓷；由 night 切换。
    MemoryLakeStyle {
        id: ml
        night: root.nightMode
        injectedTextPrimary: root.themeTextPrimary
        injectedTextSecondary: root.themeTextSecondary
    }

    // ============================================================
    // 状态
    // ============================================================
    property string currentTab: "general"
    property string searchQuery: ""
    readonly property bool sideCollapsed: root.width < 1100   // ≤1100 左栏折叠（设计稿 responsive）

    // —— KV 偏好（onCompleted 读入本地属性；变更即写回，重启读回 C5）——
    property string accentColor: "#9FE7EE"
    property int blurStrength: 24
    property bool restoreWindow: true
    property string landingPage: "memorylake"
    property bool showWelcome: true
    property string languageMode: "zh"
    property string timeFormat: "24"
    property bool trackRunning: true
    property bool autostartEnabled: false  // B1：开机自启实际注册态（读 --status，非 KV）
    property bool gameMode: true
    property string idleTimeout: "5"
    property bool autoClassify: true
    property bool mergeWindows: true
    property bool privacyLocalOnly: true
    property bool hideTitles: true
    property bool anonymizeExport: false
    property bool notifyEnabled: true
    property bool memoHotkeyN: true
    property bool memoAutosave: true

    // —— Phase 2 只读派生（onCompleted + usageStatsChanged 刷新；真实只读，不造假 G6）——
    property real journalBytes: 0      // usage_records.jsonl 字节
    property real cacheBytes: 0        // timearc.db 字节（UI 派生/缓存库）
    property int usageRecordCount: 0   // 已解析记录条数
    property string todaySwitchesText: "—"   // 今日前台切换次数（QML 派生）
    property string memoPagesText: "—"       // 备忘页数（从 memoryLakeMemoDoc 派生）
    property string pomodoroTodayText: "—"    // 今日番茄完成数（PomodoroWidget 写 pomodoro_today）

    // 逐项显隐（2B / G-HIDEAPP）：hiddenApps = 被隐藏的 group key 数组（持久化为 JSON）；
    // appList = usageStatManager.allApps() 去重清单（onCompleted 拉一次，供应用管理勾选）。
    property var hiddenApps: []
    property var appList: []
    // 应用管理 UI（#1 重设计）：搜索过滤 + 软上限折叠（默认显 appCap 个，可展开全部）。
    property string appSearchQuery: ""
    property bool appsExpanded: false
    readonly property int appCap: 14
    readonly property var filteredApps: {
        var q = ("" + appSearchQuery).toLowerCase()
        if (q.length === 0) return appList
        var r = []
        for (var i = 0; i < appList.length; i++) {
            var nm = ("" + (appList[i].name || appList[i].appName)).toLowerCase()
            if (nm.indexOf(q) >= 0) r.push(appList[i])
        }
        return r
    }
    readonly property var shownApps: (appSearchQuery.length > 0 || appsExpanded)
                                     ? filteredApps : filteredApps.slice(0, appCap)

    // 番茄钟（#2 接备忘番茄引擎 PomodoroWidget；写 KV，引擎在 _load/reset 时读默认时长/标题）。
    property string pomodoroDuration: "25"
    property string pomodoroTitle: "专注一会儿"
    property bool pomodoroCelebrate: true
    // 快捷键自定义（#3）：备忘 / 番茄全局键（单字母；Shell 响应式读，hotkeysChanged 通知）。
    property string memoHotkeyKey: "N"
    property string pomodoroHotkeyKey: "P"

    function _getBool(k, d) { return settingsRepository ? settingsRepository.getBool(k, d) : d }
    function _getStr(k, d) { return settingsRepository ? settingsRepository.getValue(k, d) : d }
    function _setBool(k, v) { if (settingsRepository) settingsRepository.setBool(k, v) }
    function _setStr(k, v) { if (settingsRepository) settingsRepository.setValue(k, v) }

    function reloadFromKV() {
        accentColor      = _getStr("accent_color", "#9FE7EE")
        blurStrength     = parseInt(_getStr("blur_strength", "24")) || 24
        restoreWindow    = _getBool("restore_window", true)
        landingPage      = _getStr("landing_page", "memorylake")
        showWelcome      = _getBool("show_welcome", true)
        languageMode     = _getStr("language_mode", "zh")
        timeFormat       = _getStr("time_format", "24")
        trackRunning     = _getBool("track_running", true)
        gameMode         = _getBool("game_mode", true)
        idleTimeout      = _getStr("idle_timeout", "5")
        autoClassify     = _getBool("auto_classify", true)
        mergeWindows     = _getBool("merge_windows", true)
        privacyLocalOnly = _getBool("privacy_local_only", true)
        hideTitles       = _getBool("hide_titles", true)
        anonymizeExport  = _getBool("anonymize_export", false)
        notifyEnabled    = _getBool("notify_enabled", true)
        memoHotkeyN      = _getBool("memo_hotkey_n", true)
        memoAutosave     = _getBool("memo_autosave", true)
        hiddenApps       = parseHiddenApps()
        pomodoroDuration = _getStr("pomodoro_duration", "25")
        pomodoroTitle    = _getStr("pomodoro_title", "专注一会儿")
        pomodoroCelebrate= _getBool("pomodoro_celebrate", true)
        memoHotkeyKey    = _getStr("memo_hotkey_key", "N")
        pomodoroHotkeyKey= _getStr("pomodoro_hotkey_key", "P")
    }

    // —— 读层过滤推入（2A 游戏/分类/合并 · 2B 显隐 · 2C 标题 · 3A 软暂停）——
    // 把本页开关推进 usageStatManager 读出层；只影响 UI 聚合，不写/不删 usage（G4/I1/I2）。
    function pushReadFilters() {
        if (usageStatManager && usageStatManager.setReadFilters)
            usageStatManager.setReadFilters(autoClassify, gameMode, mergeWindows,
                                            hideTitles, trackRunning, hiddenApps)
    }
    function parseHiddenApps() {
        try { var a = JSON.parse(_getStr("hidden_apps", "[]")); return Array.isArray(a) ? a : [] }
        catch (e) { return [] }
    }
    function isAppHidden(key) { return hiddenApps.indexOf(key) >= 0 }
    function setAppHidden(key, hidden) {
        var a = hiddenApps.slice()
        var idx = a.indexOf(key)
        if (hidden && idx < 0) a.push(key)
        else if (!hidden && idx >= 0) a.splice(idx, 1)
        else return
        hiddenApps = a
        _setStr("hidden_apps", JSON.stringify(a))
        pushReadFilters()
    }
    function refreshAppList() {
        appList = (usageStatManager && usageStatManager.allApps) ? usageStatManager.allApps() : []
    }

    // 存储概览（G-STORAGE）：只读文件字节 + 记录数。
    function refreshStorage() {
        if (!usageStatManager) return
        journalBytes = usageStatManager.fileSizeBytes(usageStatManager.usageRecordsPath)
        cacheBytes = (databaseManager && databaseManager.getDatabasePath)
                     ? usageStatManager.fileSizeBytes(databaseManager.getDatabasePath()) : 0
        usageRecordCount = usageStatManager.recordCount()
    }

    // 数据概览派生：今日切换次数（QML 派生，G-4）+ 备忘页数（memoryLakeMemoDoc）。
    function refreshOverview() {
        if (usageStatManager && usageStatManager.foregroundSegmentsForRange) {
            var segs = usageStatManager.foregroundSegmentsForRange("day")
            todaySwitchesText = (segs && segs.length > 0) ? (computeSwitchCount(segs) + " 次") : "—"
        }
        var doc = _getStr("memoryLakeMemoDoc", "")
        if (doc && doc.length > 0) {
            try {
                var o = JSON.parse(doc)
                if (o && o.pages && o.pages.length !== undefined) memoPagesText = o.pages.length + " 页"
            } catch (e) { /* 解析失败 → 维持「—」，不造假 */ }
        }
        // 今日番茄完成数（PomodoroWidget._recordCompletion 写 date-stamped pomodoro_today）。
        var todayKey = Qt.formatDate(new Date(), "yyyy-MM-dd")
        var praw = _getStr("pomodoro_today", "")
        if (praw && praw.length > 0) {
            try {
                var p = JSON.parse(praw)
                pomodoroTodayText = (p && p.d === todayKey && p.n > 0) ? (p.n + " 个") : "0 个"
            } catch (e) { /* 维持「—」 */ }
        }
    }

    // 切换次数（同统计页 G-4 派生）：摊平前台会话段、按起始排序、相邻 groupKey 不同计数。
    function computeSwitchCount(segments) {
        var flat = []
        for (var i = 0; i < segments.length; i++) {
            var grp = segments[i].groupKey
            var segs = segments[i].segments ? segments[i].segments : []
            for (var j = 0; j < segs.length; j++) flat.push({ key: grp, start: segs[j].startUnixSec })
        }
        flat.sort(function (a, b) { return a.start - b.start })
        var sw = 0
        for (var k = 1; k < flat.length; k++) if (flat[k].key !== flat[k - 1].key) sw++
        return sw
    }

    function bytesText(b) {
        if (!b || b <= 0) return "0 B"
        if (b < 1024) return Math.round(b) + " B"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB"
        if (b < 1073741824) return (b / 1048576).toFixed(1) + " MB"
        return (b / 1073741824).toFixed(2) + " GB"
    }

    Connections {
        target: usageStatManager
        function onUsageStatsChanged() { root.refreshStorage(); root.refreshOverview() }
    }

    // B1：读 service --status 的实际注册态（源是 OS 登录任务/Run 键，非 KV 设置）。
    function refreshAutostart() {
        if (settingsRepository && settingsRepository.autostartEnabled)
            root.autostartEnabled = settingsRepository.autostartEnabled()
    }

    Component.onCompleted: {
        reloadFromKV()
        refreshStorage()
        refreshOverview()
        refreshAppList()
        refreshAutostart()
        pushReadFilters()   // 与 Shell 启动推入一致；setReadFilters 幂等（无变化即早返回）
        root.forceActiveFocus()
    }

    // ============================================================
    // 工具：搜索 / tab 切换 / toast
    // ============================================================
    function cardMatches(text) {
        if (searchQuery.length === 0) return true
        return ("" + text).toLowerCase().indexOf(searchQuery.toLowerCase()) >= 0
    }
    function selectTab(key) {
        if (currentTab === key) return
        currentTab = key
        searchQuery = ""          // 切 tab 清搜索（C2）
        searchField.text = ""
        appSearchQuery = ""       // 应用管理搜索 / 折叠态复位（每次进 tab 全新，文本框同步清）
        appsExpanded = false
        appSearchField.text = ""
        if (key === "export") refreshOverview()   // 进数据概览前刷新（番茄今日完成数等无变更信号，主动重读）
    }
    function showToast(msg) { settingsToast.message = msg; settingsToast.shown = true; toastTimer.restart() }
    function onOff(v) { return v ? "功能已开启" : "功能已关闭" }

    // 自定义快捷键（#3）：单字母；备忘 / 番茄不能同键；写 KV + 发 hotkeysChanged 让 Shell 重读。
    function setHotkey(which, k) {
        if (which === "memo") {
            if (k === pomodoroHotkeyKey) { showToast("与番茄钟快捷键冲突"); return }
            memoHotkeyKey = k; _setStr("memo_hotkey_key", k)
        } else {
            if (k === memoHotkeyKey) { showToast("与备忘录快捷键冲突"); return }
            pomodoroHotkeyKey = k; _setStr("pomodoro_hotkey_key", k)
        }
        hotkeysChanged()
        showToast("快捷键已更新为 " + k)
    }

    // 顶栏标题/描述（settingsCopy 逐字，v88 17835–17841）
    readonly property var topCopy: ({
        "general":  { t: "通用设置",   d: "控制界面外观、启动行为和基础体验。" },
        "tracking": { t: "追踪与应用", d: "管理使用时间记录、应用分类和显示范围。" },
        "privacy":  { t: "隐私与数据", d: "控制本地保存、敏感信息隐藏和缓存清理。" },
        "memo":     { t: "备忘与番茄钟", d: "调整备忘录、便签、页面和番茄钟的默认行为。" },
        "export":   { t: "导入导出",   d: "备份设置、复制配置或恢复默认状态。" }
    })

    // 标签模型
    readonly property var tabModel: [
        { key: "general",  glyph: "✦", label: "通用" },
        { key: "tracking", glyph: "◉", label: "追踪与应用" },
        { key: "privacy",  glyph: "◆", label: "隐私与数据" },
        { key: "memo",     glyph: "◇", label: "备忘与番茄钟" },
        { key: "export",   glyph: "⇅", label: "导入导出" }
    ]

    // 强调色 4 色（picker 数据；设计稿 §7.5 渐变对）
    readonly property var accentSwatches: [
        { value: "#9FE7EE", a: "#9FE7EE", b: "#9B8BFF" },
        { value: "#FF7A9A", a: "#FF7A9A", b: "#FFB86B" },
        { value: "#7DFFB2", a: "#7DFFB2", b: "#7AD7FF" },
        { value: "#D8B4FF", a: "#D8B4FF", b: "#9B8BFF" }
    ]

    // 工作流脚注（设计稿 .workflow-map）
    readonly property var workflowMap: [
        { t: "首页", d: "看今天的结论和关键事项。" },
        { t: "日历", d: "管理未来安排和某天详情。" },
        { t: "统计", d: "观察周、月、年的长期规律。" },
        { t: "回顾", d: "把数据转成故事化总结。" }
    ]

    // 今日使用（真实只读，usageStatManager.todaySoftwareMinutes 可用）
    function todayUsageText() {
        if (!usageStatManager) return "—"
        var m = usageStatManager.todaySoftwareMinutes
        if (m === undefined || m <= 0) return "0h"
        return (Math.round(m / 6) / 10).toFixed(1) + "h"
    }

    // 导出设置 JSON（G-EXPORT）：settingsRepository.getAllSettings() 整张 settings 表 → JSON，
    // C++ exportReport 写下载/文档目录（报告文件，非契约 usage 数据）。
    function buildSettingsJson() {
        try {
            var all = settingsRepository ? settingsRepository.getAllSettings() : ({})
            return JSON.stringify({
                app: "TimeArc", reportKind: "settings", aiGenerated: false,
                theme: root.nightMode ? "dark-glass" : "day-frost",
                settings: all
            }, null, 2)
        } catch (e) { return "" }
    }
    function doExport() {
        if (!usageStatManager || !usageStatManager.exportReport) { showToast("导出暂不可用"); return }
        var json = buildSettingsJson()
        if (!json || json.length === 0) { showToast("导出失败：序列化错误"); return }
        var p = usageStatManager.exportReport("timearc-settings", json)
        if (p && p.length > 0) root.showSavedAt("设置 JSON 已导出", p)
        else showToast("导出失败")
    }
    function copySummary() {
        clipHelper.text = "TimeArc 设置摘要：" + (root.nightMode ? "暗玻璃主题" : "白天浅瓷主题")
                + " / 本地保存 / " + (memoHotkeyN ? "N 打开备忘录" : "N 快捷键关闭")
                + " / 强调色 " + accentColor
        clipHelper.selectAll(); clipHelper.copy(); clipHelper.deselect()
        showToast("配置摘要已复制")
    }
    function restoreVisualDefaults() {
        accentColor = "#9FE7EE"; _setStr("accent_color", accentColor)
        blurStrength = 24;       _setStr("blur_strength", "24")
        showWelcome = true;      _setBool("show_welcome", true)
        showToast("视觉设置已恢复默认")
    }

    // 二次确认（A-CLEAR）：危险动作前确认；动作存于 _confirmAction，确认时执行。不写死假成功（G6）。
    property var _confirmAction: null
    function askConfirm(title, msg, confirmLabel, danger, action) {
        confirmCard.titleText = title
        confirmCard.msgText = msg
        confirmCard.confirmLabel = confirmLabel
        confirmCard.danger = danger
        _confirmAction = action
        confirmCard.shown = true
    }
    function _runConfirm() {
        confirmCard.shown = false
        var a = _confirmAction; _confirmAction = null
        if (a) a()
    }
    // 仅清 UI 私有/派生缓存（窗口几何）：不动 usage 历史(D1)、设置偏好、备忘内容（A-CLEAR）。
    function clearUiCache() {
        _setStr("window_x", ""); _setStr("window_y", "")
        _setStr("window_width", ""); _setStr("window_height", "")
        showToast("已清空本地缓存（窗口位置等派生数据）")
    }

    // 导入设置（G-IMPORT）：FileDialog 选 JSON → C++ readTextFile 读 → 解析 → 逐键 setValue →
    // 重读本页属性。只读所选文件、只写 settings KV，不动 usage/契约。
    function doImport(fileUrl) {
        if (!settingsRepository) { showToast("导入暂不可用"); return }
        var txt = settingsRepository.readTextFile("" + fileUrl)
        if (!txt || txt.length === 0) { showToast("JSON 文件格式不正确"); return }
        try {
            var o = JSON.parse(txt)
            var s = (o && o.settings) ? o.settings : o
            if (!s || typeof s !== "object") { showToast("JSON 文件格式不正确"); return }
            var n = 0
            for (var k in s) { if (s.hasOwnProperty(k)) { settingsRepository.setValue("" + k, "" + s[k]); n++ } }
            reloadFromKV()
            showToast(n > 0 ? "设置文件已读取" : "JSON 文件格式不正确")
        } catch (e) { showToast("JSON 文件格式不正确") }
    }

    // 成功保存反馈：在持久确认卡里显示完整路径（toast 单行 + 1.5s 装不下长路径，用户找不到文件），
    // 并给「打开文件夹」按钮用资源管理器定位（Qt.openUrlExternally 打开所在目录）。
    function _folderUrlOf(p) {
        var s = ("" + p).replace(/\\/g, "/")
        var i = s.lastIndexOf("/")
        var dir = (i > 0) ? s.substring(0, i) : s
        return "file:///" + dir
    }
    function showSavedAt(title, p) {
        root.askConfirm(title, "已保存到：\n" + p, "打开文件夹", false,
            function () { Qt.openUrlExternally(root._folderUrlOf(p)) })
    }
    // D1 备份（整库）：C++ backupDatabase 用 VACUUM INTO 取一致快照写 下载/文档/AppData，
    // 只读、不扰 live；返回完整路径或空串（失败诚实报错 G6）。
    function doBackupDatabase() {
        if (!databaseManager || !databaseManager.backupDatabase) { showToast("备份暂不可用"); return }
        var p = databaseManager.backupDatabase()
        if (p && p.length > 0) root.showSavedAt("数据库已备份", p)
        else showToast("备份失败")
    }
    // D1 恢复（整库）：选备份 → 只读校验预览（坏文件直接拒）→ 危险二次确认 → 替换库。
    function _unixDate(s) { return (s && s > 0) ? Qt.formatDate(new Date(s * 1000), "yyyy-MM-dd") : "—" }
    function onRestoreFileChosen(fileUrl) {
        if (!databaseManager || !databaseManager.inspectBackup) { showToast("恢复暂不可用"); return }
        var info = databaseManager.inspectBackup("" + fileUrl)
        if (!info || !info.ok) {
            showToast(info && info.error ? ("无效备份：" + info.error) : "无效的备份文件")
            return
        }
        var msg = "完整性 " + info.integrity
                + "\n前台 " + info.frontmostRows + " 条 · 音频 " + info.mediaRows + " 条 · 应用 " + info.appRows + " 个"
                + "\n时间范围 " + root._unixDate(info.minUnixSec) + " ~ " + root._unixDate(info.maxUnixSec)
                + "\n\n将用所选备份覆盖当前全部记录，且需先停止后台采集。"
        root.askConfirm("恢复数据库", msg, "恢复", true, function () { root.doRestoreConfirmed("" + fileUrl) })
    }
    function doRestoreConfirmed(fileUrl) {
        if (!databaseManager || !databaseManager.restoreDatabase) { showToast("恢复暂不可用"); return }
        var ok = databaseManager.restoreDatabase("" + fileUrl)
        if (!ok) showToast("恢复失败：备份无效或数据库被后台采集占用")
        // 成功路径由 databaseManager.databaseRestored 信号触发重启提示
    }

    // D2 数据位置：选目录把整库迁到用户所选目录（更大磁盘 / 同步盘），并切换两进程共用的
    // usage_config.json db_path 指针。C++ relocateDatabaseTo 负责原子序（搬+校验新库 → 确认旧库
    // 未被占用 → 切指针 → 重开 → 任一步失败回滚），UI 只做确认 + 结果反馈（诚实失败 G6）。
    function dbLocationText() {
        return (databaseManager && databaseManager.currentDatabaseLocationDir)
            ? ("" + databaseManager.currentDatabaseLocationDir()) : "—"
    }
    function onDbFolderChosen(folderUrl) {
        if (!databaseManager || !databaseManager.relocateDatabaseTo) { showToast("迁移暂不可用"); return }
        root.askConfirm("迁移数据库位置",
            "将把整个使用数据库迁移到所选目录，并切换两进程的数据库位置指针。\n迁移前请先停止后台采集（设置 → 隐私与数据 → 开机自动在后台采集），否则会因数据库被占用而失败。",
            "迁移", true, function () { root._afterRelocate(databaseManager.relocateDatabaseTo("" + folderUrl)) })
    }
    function doRestoreDefaultLocation() {
        if (!databaseManager || !databaseManager.restoreDefaultDatabaseLocation) { showToast("迁移暂不可用"); return }
        root.askConfirm("还原默认数据库位置",
            "将把数据库迁回默认位置并清除位置指针。迁移前请先停止后台采集。",
            "还原", true, function () { root._afterRelocate(databaseManager.restoreDefaultDatabaseLocation()) })
    }
    function _afterRelocate(res) {
        if (res && res.ok) {
            root.askConfirm("迁移成功",
                "数据库已迁移到：\n" + res.newPath
                    + "\n\n需要重启应用（并重启后台采集）以让两进程加载新位置，是否立即退出？",
                "立即退出", false, function () { Qt.quit() })
        } else {
            showToast(res && res.error ? ("迁移失败：" + res.error) : "迁移失败")
        }
    }

    FileDialog {
        id: importDialog
        title: "导入设置 JSON"
        nameFilters: ["JSON 文件 (*.json)", "所有文件 (*)"]
        onAccepted: root.doImport(selectedFile)
    }

    FileDialog {
        id: restoreDialog
        title: "选择数据库备份"
        nameFilters: ["数据库备份 (*.db)", "所有文件 (*)"]
        onAccepted: root.onRestoreFileChosen(selectedFile)
    }

    FolderDialog {
        id: dbFolderDialog
        title: "选择数据库存放目录"
        onAccepted: root.onDbFolderChosen(selectedFolder)
    }

    // 恢复成功后（C++ emit databaseRestored）：引导重启以加载新数据（UI 缓存未热更）。
    Connections {
        target: databaseManager
        ignoreUnknownSignals: true
        function onDatabaseRestored() {
            root.askConfirm("恢复成功",
                "数据库已恢复。需要重启应用以加载新数据，是否立即退出？",
                "立即退出", false, function () { Qt.quit() })
        }
    }

    Keys.onEscapePressed: root.requestNavigate("memorylake")
    TextEdit { id: clipHelper; visible: false }   // 纯 QML 剪贴板助手（copy()）

    // ============================================================
    // 整页入场（对齐 stats/calendar openAnim；running:true 自启，避免整页隐形 G10）
    // ============================================================
    opacity: 0
    transform: [
        Translate { id: openT; y: 18 },
        Scale { id: openS; origin.x: root.width / 2; origin.y: root.height / 2; xScale: 0.99; yScale: 0.99 }
    ]
    ParallelAnimation {
        running: true
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
        NumberAnimation { target: openT; property: "y"; from: 18; to: 0; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
        NumberAnimation { target: openS; property: "xScale"; from: 0.99; to: 1; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
        NumberAnimation { target: openS; property: "yScale"; from: 0.99; to: 1; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
    }

    // ============================================================
    // 页面壳：左导航（238）+ 右主区（1fr）
    // ============================================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 16

        // —— 左导航 settings-nav-panel ——
        GlassPanel {
            id: navPanel
            Layout.preferredWidth: 238
            Layout.fillHeight: true
            visible: !root.sideCollapsed
            style: ml
            radius: 22

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // 标题块
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "CONTROL CENTER"
                        color: ml.aqua
                        font.pixelSize: 11; font.weight: 800; font.letterSpacing: 0.7
                        font.capitalization: Font.AllUppercase
                    }
                    Text { text: "设置"; color: ml.textPrimary; font.pixelSize: 22; font.weight: 800; font.letterSpacing: -0.4 }
                    Text {
                        Layout.fillWidth: true
                        text: "管理 TimeArc 的追踪、隐私、备忘录与视觉体验。"
                        color: ml.textSecondary; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.35
                    }
                }

                // 数据来源说明（B1：原型 localStorage 文案 → 真实本地口径）
                Rectangle {
                    Layout.fillWidth: true
                    radius: 16
                    color: ml.protoAmberBg
                    border.width: 1; border.color: ml.protoAmberBorder
                    implicitHeight: protoText.implicitHeight + 22
                    Text {
                        id: protoText
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                        text: "数据来源说明：设置项保存在本机 SQLite；使用数据来自系统采集的本地记录，全部离线、不上传。"
                        color: ml.protoAmberText; font.pixelSize: 11; wrapMode: Text.WordWrap; lineHeight: 1.35
                    }
                }

                // 标签 ×5
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.tabModel
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 15
                            color: root.currentTab === modelData.key ? ml.accentSoft
                                   : (tabMa.containsMouse ? ml.calGhostHover : "transparent")
                            border.width: 1
                            border.color: root.currentTab === modelData.key ? ml.accentSoftBorder : "transparent"
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                spacing: 10
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28; height: 28; radius: 10
                                    color: ml.calGhostBg
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.glyph
                                        color: root.currentTab === modelData.key ? ml.aqua : ml.calGlyph
                                        font.pixelSize: 14
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: root.currentTab === modelData.key ? ml.textPrimary : ml.textSecondary
                                    font.pixelSize: 13
                                    font.weight: root.currentTab === modelData.key ? Font.DemiBold : Font.Normal
                                }
                            }
                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectTab(modelData.key)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // 脚注：工作流图 + 同步点
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    FrostCard {
                        Layout.fillWidth: true
                        style: ml
                        radius: 17
                        implicitHeight: wfCol.implicitHeight + 24
                        ColumnLayout {
                            id: wfCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 8
                            Repeater {
                                model: root.workflowMap
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { text: modelData.t; color: ml.textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.d; color: ml.textTertiary; font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            width: 8; height: 8; radius: 4; color: ml.aqua
                            Layout.alignment: Qt.AlignVCenter
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: "本地数据已保护"; color: ml.textSecondary; font.pixelSize: 11; font.weight: Font.DemiBold }
                            Text { text: "离线 · 无需登录"; color: ml.textTertiary; font.pixelSize: 10 }
                        }
                    }
                }
            }
        }

        // —— 右主区 settings-main ——
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // 顶栏：标题/描述 + 搜索 + 返回
            GlassPanel {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                style: ml
                radius: 22

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: root.topCopy[root.currentTab].t
                            color: ml.textPrimary; font.pixelSize: 22; font.weight: 800; font.letterSpacing: -0.4
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.topCopy[root.currentTab].d
                            color: ml.textSecondary; font.pixelSize: 13; elide: Text.ElideRight
                        }
                    }

                    // 折叠态紧凑标签（左栏隐藏时）
                    Row {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.sideCollapsed
                        Repeater {
                            model: root.tabModel
                            delegate: Rectangle {
                                required property var modelData
                                width: 38; height: 34; radius: 11
                                color: root.currentTab === modelData.key ? ml.accentSoft : ml.calGhostBg
                                border.width: 1
                                border.color: root.currentTab === modelData.key ? ml.accentSoftBorder : ml.calGhostBorder
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.glyph
                                    color: root.currentTab === modelData.key ? ml.aqua : ml.calGlyph
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectTab(modelData.key)
                                }
                            }
                        }
                    }

                    GlassTextField {
                        id: searchField
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.sideCollapsed ? 160 : 240
                        style: ml
                        search: true
                        placeholderText: "搜索设置项..."
                        onTextEdited: function (t) { root.searchQuery = t }
                    }

                    GhostBtn { Layout.alignment: Qt.AlignVCenter; label: "返回首页"; primary: true; onTapped: root.requestNavigate("memorylake") }
                }
            }

            // 滚动卡片区
            SilkyFlickable {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                style: ml

                Item {
                    width: scroll.width
                    height: sectionStack.implicitHeight + 8   // 真实高度驱动 SilkyFlickable contentHeight

                    // 5 个分区（互斥 visible + 入场动画）
                    Item {
                        id: sectionStack
                        width: parent.width
                        height: implicitHeight
                        implicitHeight: {
                            switch (root.currentTab) {
                            case "general":  return generalSec.implicitHeight
                            case "tracking": return trackingSec.implicitHeight
                            case "privacy":  return privacySec.implicitHeight
                            case "memo":     return memoSec.implicitHeight
                            case "export":   return exportSec.implicitHeight
                            }
                            return 0
                        }

                        // ===== general 通用 =====
                        SectionGrid {
                            id: generalSec
                            tabKey: "general"

                            SettingsCard {
                                badge: "✦"; wide: true
                                cardTitle: "视觉外观"
                                cardDesc: "保持深色磨砂风格，也可以调整强调色和模糊强度。"
                                keywords: "外观 主题 透明 模糊 accent color 强调色"

                                // 强调色
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { text: "强调色"; color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Row {
                                        spacing: 12
                                        Repeater {
                                            model: root.accentSwatches
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: 34; height: 34; radius: 13
                                                border.width: 1; border.color: ml.calGhostBorder
                                                gradient: Gradient {
                                                    orientation: Gradient.Horizontal
                                                    GradientStop { position: 0; color: modelData.a }
                                                    GradientStop { position: 1; color: modelData.b }
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: root.accentColor === modelData.value
                                                    text: "✓"; color: "#FFFFFF"; font.pixelSize: 15; font.weight: 900
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.accentColor = modelData.value
                                                        root._setStr("accent_color", modelData.value)
                                                        root.showToast("强调色已更新")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        text: "强调色已保存；全局上色将在后续阶段开放。"
                                        color: ml.textTertiary; font.pixelSize: 10
                                    }
                                }

                                ThinRule {}

                                // 白天模式开关（特制 theme-switch）
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text { text: "白天模式色调"; color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "切换成日间雾面玻璃色调：亮背景、深色文字、低饱和蓝紫光效。"
                                            color: ml.textTertiary; font.pixelSize: 11; wrapMode: Text.WordWrap
                                        }
                                    }
                                    ThemeSwitch {}
                                }

                                ThinRule {}

                                SettingRow {
                                    rowTitle: "启动时恢复上次位置"
                                    rowSub: "打开应用时记住窗口与侧栏状态。"
                                    GlassSwitch {
                                        style: ml; checked: root.restoreWindow
                                        onToggled: function (c) { root.restoreWindow = c; root._setBool("restore_window", c); root.showToast(root.onOff(c)) }
                                    }
                                }

                                SettingRow {
                                    rowTitle: "背景磨砂强度"
                                    rowSub: "保存为视觉强度偏好（实时背景模糊为占位）。"
                                    GlassSlider {
                                        style: ml; from: 8; to: 36; value: root.blurStrength; stepSize: 1
                                        implicitWidth: 160
                                        onMoved: function (v) { root.blurStrength = v; root._setStr("blur_strength", "" + Math.round(v)); root.showToast("磨砂强度已保存") }
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "⌂"
                                cardTitle: "首页行为"
                                cardDesc: "选择进入应用后的默认落点。"
                                keywords: "首页 dashboard 默认页面 欢迎"

                                SettingRow {
                                    rowTitle: "默认页面"
                                    rowSub: "启动后显示哪个页面。"
                                    GlassComboBox {
                                        style: ml
                                        model: ["首页 Dashboard", "备忘录", "记忆回顾"]
                                        property var _vals: ["memorylake", "memo", "recap"]
                                        currentIndex: Math.max(0, _vals.indexOf(root.landingPage))
                                        onActivated: function (i) { root.landingPage = _vals[i]; root._setStr("landing_page", _vals[i]); root.showToast("默认页面已保存") }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "显示欢迎动画"
                                    rowSub: "短暂显示 TimeArc 启动动效。"
                                    GlassSwitch {
                                        style: ml; checked: root.showWelcome
                                        onToggled: function (c) { root.showWelcome = c; root._setBool("show_welcome", c); root.showToast(root.onOff(c)) }
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "文"
                                cardTitle: "语言与时间"
                                cardDesc: "控制界面的基础文本和时间显示方式。"
                                keywords: "语言 时间格式 单位 language time"

                                SettingRow {
                                    rowTitle: "界面语言"
                                    rowSub: "切换持久化已生效；全局译文将在后续阶段开放。"
                                    GlassComboBox {
                                        style: ml
                                        model: ["简体中文", "English", "日本語"]
                                        property var _vals: ["zh", "en", "ja"]
                                        currentIndex: Math.max(0, _vals.indexOf(root.languageMode))
                                        onActivated: function (i) { root.languageMode = _vals[i]; root._setStr("language_mode", _vals[i]); root.showToast("界面语言已保存") }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "时间格式"
                                    rowSub: "影响时间图和统计记录。"
                                    GlassComboBox {
                                        style: ml
                                        model: ["24 小时制", "12 小时制"]
                                        property var _vals: ["24", "12"]
                                        currentIndex: Math.max(0, _vals.indexOf(root.timeFormat))
                                        onActivated: function (i) { root.timeFormat = _vals[i]; root._setStr("time_format", _vals[i]); root.showToast("时间格式已保存") }
                                    }
                                }
                            }
                        }

                        // ===== tracking 追踪与应用 =====
                        SectionGrid {
                            id: trackingSec
                            tabKey: "tracking"

                            SettingsCard {
                                badge: "◉"
                                cardTitle: "追踪范围"
                                cardDesc: "决定哪些应用会进入首页、时间图和月度记忆回顾。"
                                keywords: "追踪 应用 游戏 app 使用时间 空闲"

                                SettingRow {
                                    rowTitle: "追踪正在运行的应用"
                                    rowSub: "记录窗口名称、应用名称和持续时间。真正暂停采集需后台服务支持（受限）。"
                                    GlassSwitch {
                                        style: ml; checked: root.trackRunning
                                        onToggled: function (c) {
                                            root.trackRunning = c; root._setBool("track_running", c); root.pushReadFilters()
                                            root.showToast(c ? "已恢复统计运行中的应用" : "已暂停统计（仅 UI；采集与历史保留）")
                                        }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "开机自动在后台采集"
                                    rowSub: "登录时自动在后台启动采集（在用户会话内运行，无需管理员）。关闭仅停自启，不删历史。"
                                    GlassSwitch {
                                        style: ml; checked: root.autostartEnabled
                                        onToggled: function (c) {
                                            if (!settingsRepository) return
                                            settingsRepository.setAutostartEnabled(c)
                                            root.autostartEnabled = settingsRepository.autostartEnabled()
                                            root.showToast(root.autostartEnabled ? "已设为开机自启（登录后台采集）" : "已关闭开机自启")
                                        }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "游戏模式识别"
                                    rowSub: "将 Steam / Epic / 独立游戏归入游戏类别。"
                                    GlassSwitch {
                                        style: ml; checked: root.gameMode
                                        onToggled: function (c) { root.gameMode = c; root._setBool("game_mode", c); root.pushReadFilters(); root.showToast(root.onOff(c)) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "空闲超过"
                                    rowSub: "超过指定时间后暂停记录。实际阈值由后台服务决定（受限）。"
                                    GlassComboBox {
                                        style: ml
                                        model: ["5 分钟", "10 分钟", "15 分钟", "30 分钟"]
                                        property var _vals: ["5", "10", "15", "30"]
                                        currentIndex: Math.max(0, _vals.indexOf(root.idleTimeout))
                                        onActivated: function (i) { root.idleTimeout = _vals[i]; root._setStr("idle_timeout", _vals[i]); root.showToast("空闲超时已保存") }
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "☷"
                                cardTitle: "分类规则"
                                cardDesc: "自动给软件分配游戏、创作、社交和工具等标签。"
                                keywords: "分类 规则 自动归类 合并"

                                SettingRow {
                                    rowTitle: "自动分类"
                                    rowSub: "根据应用名称和使用模式判断类别。"
                                    GlassSwitch {
                                        style: ml; checked: root.autoClassify
                                        onToggled: function (c) { root.autoClassify = c; root._setBool("auto_classify", c); root.pushReadFilters(); root.showToast(root.onOff(c)) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "合并同类窗口"
                                    rowSub: "浏览器标签页会合并为 Chrome。"
                                    GlassSwitch {
                                        style: ml; checked: root.mergeWindows
                                        onToggled: function (c) { root.mergeWindows = c; root._setBool("merge_windows", c); root.pushReadFilters(); root.showToast(root.onOff(c)) }
                                    }
                                }
                            }

                            // 应用管理（#1 重设计）：整宽卡 + 搜索 + 2 列紧凑芯片 + 计数 + 软折叠，
                            // 取代原先单列长清单（解决右栏被几十个应用撑高、栅格失衡）。
                            SettingsCard {
                                badge: "▥"; wide: true
                                cardTitle: "应用管理"
                                cardDesc: "单独控制应用是否进入首页、统计和回顾（隐藏不删历史，仅读出端排除）。"
                                keywords: "应用清单 排除 合并 显隐 隐藏 hidden 搜索"

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        GlassTextField {
                                            id: appSearchField
                                            Layout.fillWidth: true
                                            style: ml
                                            search: true
                                            placeholderText: "搜索应用…"
                                            onTextEdited: function (t) { root.appSearchQuery = t }
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "共 " + root.appList.length + " · 隐藏 " + root.hiddenApps.length
                                            color: ml.textTertiary; font.pixelSize: 11
                                        }
                                    }

                                    PlaceholderNote {
                                        visible: root.appList.length === 0
                                        text: "暂无采集到的应用记录（采集后将在此逐项显隐）。"
                                    }
                                    PlaceholderNote {
                                        visible: root.appList.length > 0 && root.shownApps.length === 0
                                        text: "没有匹配「" + root.appSearchQuery + "」的应用。"
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: root.sideCollapsed ? 1 : 2
                                        columnSpacing: 10
                                        rowSpacing: 10
                                        Repeater {
                                            model: root.shownApps
                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 52
                                                radius: 14
                                                color: ml.calSunkBg
                                                border.width: 1; border.color: ml.cellHair
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10; anchors.rightMargin: 10
                                                    spacing: 10
                                                    Rectangle {
                                                        width: 30; height: 30; radius: 9
                                                        Layout.alignment: Qt.AlignVCenter
                                                        color: ml.calGhostBg
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: { var n = "" + (modelData.name || modelData.appName); return n.length > 0 ? n.charAt(0).toUpperCase() : "?" }
                                                            color: ml.aqua; font.pixelSize: 14; font.weight: Font.DemiBold
                                                        }
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.name || modelData.appName
                                                        color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold
                                                        elide: Text.ElideRight
                                                    }
                                                    GlassSwitch {
                                                        style: ml
                                                        Layout.alignment: Qt.AlignVCenter
                                                        checked: !root.isAppHidden(modelData.groupKey)
                                                        onToggled: function (c) {
                                                            root.setAppHidden(modelData.groupKey, !c)
                                                            root.showToast(c ? "已显示该应用" : "已隐藏该应用")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    GhostBtn {
                                        visible: root.appSearchQuery.length === 0 && root.filteredApps.length > root.appCap
                                        label: root.appsExpanded ? "收起" : ("显示全部 " + root.filteredApps.length + " 个应用")
                                        onTapped: root.appsExpanded = !root.appsExpanded
                                    }
                                }
                            }
                        }

                        // ===== privacy 隐私与数据 =====
                        SectionGrid {
                            id: privacySec
                            tabKey: "privacy"

                            SettingsCard {
                                badge: "◆"; wide: true
                                cardTitle: "隐私保护"
                                cardDesc: "TimeArc 的记录默认保存在本机。你可以隐藏敏感应用和窗口标题。"
                                keywords: "隐私 本地 数据 加密 匿名"

                                SettingRow {
                                    rowTitle: "仅本地保存"
                                    rowSub: "不上传使用记录，只在本机保存。"
                                    GlassSwitch {
                                        style: ml; checked: root.privacyLocalOnly
                                        onToggled: function (c) { root.privacyLocalOnly = c; root._setBool("privacy_local_only", c); root.showToast(root.onOff(c)) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "隐藏敏感窗口标题"
                                    rowSub: "把文档名、聊天名和网页标题替换为类别（输出端脱敏，采集仍保留）。"
                                    GlassSwitch {
                                        style: ml; checked: root.hideTitles
                                        onToggled: function (c) { root.hideTitles = c; root._setBool("hide_titles", c); root.pushReadFilters(); root.showToast(root.onOff(c)) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "匿名化分享图"
                                    rowSub: "偏好已保存；分享图渲染端匿名（用类别替代应用名）将随回顾分享管线接入。"
                                    GlassSwitch {
                                        style: ml; checked: root.anonymizeExport
                                        onToggled: function (c) { root.anonymizeExport = c; root._setBool("anonymize_export", c); root.showToast(root.onOff(c)) }
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "▣"
                                cardTitle: "存储空间"
                                cardDesc: "当前缓存和历史记录占用（本机只读统计）。"
                                keywords: "存储 清理 保留周期 缓存 记录"

                                // 存储条（本地占用相对 100MB 软参考；标签显示真实大小，非硬配额）
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 12
                                    radius: 6
                                    color: ml.trackBg
                                    Rectangle {
                                        height: parent.height
                                        radius: parent.radius
                                        width: parent.width * Math.max(0.02, Math.min(1, (root.journalBytes + root.cacheBytes) / (100 * 1024 * 1024)))
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: ml.aqua }
                                            GradientStop { position: 1; color: ml.violet }
                                        }
                                    }
                                }
                                Text {
                                    text: "本地占用 " + root.bytesText(root.journalBytes + root.cacheBytes) + "（相对 100MB 参考）"
                                    color: ml.textTertiary; font.pixelSize: 10
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 10
                                    MetricTile { tileLabel: "缓存"; tileValue: root.bytesText(root.cacheBytes) }
                                    MetricTile { tileLabel: "记录"; tileValue: root.usageRecordCount > 0 ? ("" + root.usageRecordCount) : "0" }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    GhostBtn {
                                        label: "清理缓存"
                                        onTapped: root.askConfirm("清理缓存",
                                            "将清除 UI 私有的派生缓存（窗口位置等）。不影响使用历史、设置偏好与备忘内容。",
                                            "清理", false, function () { root.clearUiCache() })
                                    }
                                    GhostBtn {
                                        label: "删除历史"; danger: true
                                        onTapped: root.askConfirm("删除使用历史",
                                            "使用历史为追加-only（磁盘契约 D1），应用内不提供删除；如需清空请停止后台服务后用迁移工具处理。",
                                            "知道了", false, null)
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "✓"
                                cardTitle: "权限状态"
                                cardDesc: "用于提醒真实应用需要的系统权限。"
                                keywords: "权限 开机启动 通知"

                                SettingRow {
                                    rowTitle: "应用使用权限"
                                    rowSub: "Windows 前台采集无需额外授权。"
                                    Rectangle {
                                        radius: 11
                                        implicitWidth: permT.implicitWidth + 22; implicitHeight: 26
                                        color: ml.accentSoft; border.width: 1; border.color: ml.accentSoftBorder
                                        Text { id: permT; anchors.centerIn: parent; text: "就绪"; color: ml.aqua; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "系统通知"
                                    rowSub: "番茄钟在后台完成时发送系统通知（开启后显示系统托盘图标）。"
                                    GlassSwitch {
                                        style: ml; checked: root.notifyEnabled
                                        onToggled: function (c) { root.notifyEnabled = c; root._setBool("notify_enabled", c); root.hotkeysChanged(); root.showToast(root.onOff(c)) }
                                    }
                                }
                            }
                        }

                        // ===== memo 备忘与番茄钟 =====
                        SectionGrid {
                            id: memoSec
                            tabKey: "memo"

                            SettingsCard {
                                badge: "◇"; wide: true
                                cardTitle: "备忘录默认行为"
                                cardDesc: "控制便签、画笔、页数和快捷键体验。"
                                keywords: "备忘录 便签 画笔 页面 作者"

                                SettingRow {
                                    rowTitle: "按 N 打开备忘录"
                                    rowSub: "再次按 N 可以关闭备忘录。"
                                    GlassSwitch {
                                        style: ml; checked: root.memoHotkeyN
                                        onToggled: function (c) { root.memoHotkeyN = c; root._setBool("memo_hotkey_n", c); root.showToast(root.onOff(c)) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "自动保存笔迹和便签"
                                    rowSub: "每个页面独立保存，不互相影响。"
                                    GlassSwitch {
                                        style: ml; checked: root.memoAutosave
                                        onToggled: function (c) { root.memoAutosave = c; root._setBool("memo_autosave", c); root.showToast(root.onOff(c)) }
                                    }
                                }
                                // 「默认便签作者」已移除：便签署名 UI 在 StickyNote.qml 已停用（位置让给「成为待办」），
                                // memo_signature 无任何消费者 → 删除该死控件，避免存了没人读（审计 settings-remaining-work.md）。
                            }

                            // 番茄钟（#2 接备忘黑板真引擎 PomodoroWidget；写 KV，引擎在 _load/reset 读默认）。
                            SettingsCard {
                                badge: "●"
                                cardTitle: "番茄钟"
                                cardDesc: "设置备忘黑板里番茄钟的默认专注时长、标题与结束庆祝。"
                                keywords: "番茄钟 pomodoro 专注 时间 倒计时"

                                SettingRow {
                                    rowTitle: "默认专注时长"
                                    rowSub: "新开 / 重置番茄钟的初始分钟数（备忘内仍可临时调整）。"
                                    GlassComboBox {
                                        style: ml
                                        model: ["15 分钟", "25 分钟", "30 分钟", "45 分钟", "60 分钟"]
                                        property var _vals: ["15", "25", "30", "45", "60"]
                                        currentIndex: Math.max(0, _vals.indexOf(root.pomodoroDuration))
                                        onActivated: function (i) { root.pomodoroDuration = _vals[i]; root._setStr("pomodoro_duration", _vals[i]); root.showToast("默认专注时长已保存") }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "默认专注标题"
                                    rowSub: "番茄钟浮窗顶部显示的文字。"
                                    GlassTextField {
                                        style: ml
                                        implicitWidth: 160
                                        text: root.pomodoroTitle
                                        placeholderText: "专注一会儿"
                                        onEditingFinished: { root.pomodoroTitle = text; root._setStr("pomodoro_title", text); root.showToast("默认标题已保存") }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "结束庆祝动画"
                                    rowSub: "番茄钟完成时显示全屏庆祝。"
                                    GlassSwitch {
                                        style: ml; checked: root.pomodoroCelebrate
                                        onToggled: function (c) { root.pomodoroCelebrate = c; root._setBool("pomodoro_celebrate", c); root.showToast(root.onOff(c)) }
                                    }
                                }
                            }

                            // 快捷键（#3 自定义）：备忘 / 番茄全局键可点按重设（仅单字母）；其余为内置只读。
                            SettingsCard {
                                badge: "⌘"
                                cardTitle: "快捷键"
                                cardDesc: "自定义备忘录与番茄钟的全局快捷键（点按键重设，仅单字母；其余为内置键）。"
                                keywords: "快捷键 keyboard shortcut 自定义 备忘 番茄 N P"
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Repeater {
                                        model: [
                                            { which: "memo", d: "打开 / 关闭备忘录" },
                                            { which: "pomo", d: "打开 / 关闭番茄钟" }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: parent.width
                                            height: 40
                                            radius: 14
                                            color: ml.calSunkBg
                                            border.width: 1; border.color: ml.cellHair
                                            Row {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 10
                                                KeyCaptureChip {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    keyText: modelData.which === "memo" ? root.memoHotkeyKey : root.pomodoroHotkeyKey
                                                    onCaptured: function (k) { root.setHotkey(modelData.which, k) }
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.d; color: ml.textSecondary; font.pixelSize: 11
                                                }
                                            }
                                        }
                                    }
                                    Repeater {
                                        model: [
                                            { k: "Del", d: "删除选中便签 / 对象" },
                                            { k: "Esc", d: "关闭回顾 / 设置 / 清空选区" },
                                            { k: "Wheel", d: "切换卡牌 / 滚动列表" }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: parent.width
                                            height: 40
                                            radius: 14
                                            color: ml.calSunkBg
                                            border.width: 1; border.color: ml.cellHair
                                            Row {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 10
                                                KbdChip { style: ml; keyText: modelData.k; anchors.verticalCenter: parent.verticalCenter }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.d; color: ml.textSecondary; font.pixelSize: 11
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== export 导入导出 =====
                        SectionGrid {
                            id: exportSec
                            tabKey: "export"

                            SettingsCard {
                                badge: "⇅"; wide: true
                                cardTitle: "导入与导出"
                                cardDesc: "把当前设置导出为 JSON，或复制配置摘要。"
                                keywords: "导出 导入 json 备份 复制"

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    GhostBtn { label: "导出设置 JSON"; primary: true; onTapped: root.doExport() }
                                    GhostBtn { label: "导入设置"; onTapped: importDialog.open() }
                                    GhostBtn { label: "复制配置摘要"; onTapped: root.copySummary() }
                                }
                            }

                            SettingsCard {
                                badge: "⇩"; wide: true
                                cardTitle: "数据库备份与恢复"
                                cardDesc: "把整个使用数据库导出为单文件备份，或从备份恢复（恢复前请先停止后台采集）。"
                                keywords: "备份 恢复 数据库 sqlite db 整库 vacuum"

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    GhostBtn { label: "备份数据库"; primary: true; onTapped: root.doBackupDatabase() }
                                    GhostBtn { label: "恢复数据库"; danger: true; onTapped: restoreDialog.open() }
                                }
                            }

                            // D2：数据库位置（用户可选目录 + 安全迁移 + 还原默认）
                            SettingsCard {
                                badge: "⇧"; wide: true
                                cardTitle: "数据库位置"
                                cardDesc: "把整个使用数据库迁到所选目录（更大的磁盘 / 同步盘），并切换两进程共用的位置指针；全程安全可回滚。迁移前请先停止后台采集。"
                                keywords: "数据库 位置 迁移 路径 磁盘 db_path 重定向 relocate 移动"

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: dbLocCol.implicitHeight + 24
                                    radius: 14
                                    color: ml.calSunkBg
                                    border.width: 1; border.color: ml.cellHair
                                    Column {
                                        id: dbLocCol
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                                        spacing: 3
                                        Text { text: "当前位置"; color: ml.textTertiary; font.pixelSize: 10; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.3 }
                                        Text {
                                            text: root.dbLocationText()
                                            color: ml.textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold
                                            width: parent.width; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideMiddle
                                        }
                                    }
                                }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    GhostBtn { label: "迁移到…"; primary: true; onTapped: dbFolderDialog.open() }
                                    GhostBtn {
                                        label: "还原默认位置"
                                        opacity: enabled ? 1 : 0.45
                                        enabled: !!(databaseManager && databaseManager.isUsingCustomDatabaseLocation
                                                    && databaseManager.isUsingCustomDatabaseLocation())
                                        onTapped: root.doRestoreDefaultLocation()
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "≈"
                                cardTitle: "当前数据概览"
                                cardDesc: "今天的使用情况和本地记录规模。"
                                keywords: "状态 数据概览"

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 10
                                    MetricTile { tileLabel: "今日使用"; tileValue: root.todayUsageText() }
                                    MetricTile { tileLabel: "切换次数"; tileValue: root.todaySwitchesText }
                                    MetricTile { tileLabel: "备忘页数"; tileValue: root.memoPagesText }
                                    MetricTile { tileLabel: "番茄钟"; tileValue: root.pomodoroTodayText }   // 今日完成数（已接真引擎）
                                }
                            }

                            SettingsCard {
                                badge: "↺"
                                cardTitle: "恢复与重置"
                                cardDesc: "用于快速恢复视觉默认状态。"
                                keywords: "重置 恢复 默认 清空"

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    GhostBtn { label: "恢复视觉默认"; onTapped: root.restoreVisualDefaults() }
                                    GhostBtn {
                                        label: "清空本地缓存"; danger: true
                                        onTapped: root.askConfirm("清空本地缓存",
                                            "将清除 UI 私有的派生缓存（窗口位置等）。不影响使用历史、设置偏好与备忘内容。",
                                            "清空", true, function () { root.clearUiCache() })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // toast 胶囊（复用 calToastBg 范式）
    // ============================================================
    Rectangle {
        id: settingsToast
        property string message: ""
        property bool shown: false
        z: 300
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        implicitWidth: Math.max(200, toastLabel.implicitWidth + 36)
        height: 40
        radius: 20
        color: ml.calToastBg
        border.width: 1; border.color: ml.chipEventBd
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        transform: Translate {
            y: settingsToast.shown ? 0 : 10
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy } }
        }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Text { id: toastLabel; anchors.centerIn: parent; text: settingsToast.message; color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
        Timer { id: toastTimer; interval: 1500; onTriggered: settingsToast.shown = false }
    }

    // ============================================================
    // 二次确认弹层（A-CLEAR：危险动作前确认；玻璃卡 + 暗遮罩）
    // ============================================================
    Rectangle {
        id: confirmCard
        property bool shown: false
        property string titleText: ""
        property string msgText: ""
        property string confirmLabel: "确认"
        property bool danger: false
        anchors.fill: parent
        z: 350
        color: Qt.rgba(0, 0, 0, 0.42)
        visible: opacity > 0.01
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea { anchors.fill: parent; preventStealing: true; onClicked: confirmCard.shown = false }  // 点遮罩关闭

        GlassPanel {
            style: ml
            radius: 22
            width: Math.min(420, parent.width - 64)
            height: confirmCol.implicitHeight + 36
            anchors.centerIn: parent
            MouseArea { anchors.fill: parent }   // 吞卡内点击，避免冒泡到遮罩关闭
            ColumnLayout {
                id: confirmCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                spacing: 12
                Text {
                    text: confirmCard.titleText; color: ml.textPrimary
                    font.pixelSize: 17; font.weight: Font.DemiBold
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }
                Text {
                    text: confirmCard.msgText; color: ml.textSecondary
                    font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.Wrap; lineHeight: 1.35
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }
                    GhostBtn { label: "取消"; onTapped: confirmCard.shown = false }
                    GhostBtn {
                        label: confirmCard.confirmLabel
                        danger: confirmCard.danger
                        primary: !confirmCard.danger
                        onTapped: root._runConfirm()
                    }
                }
            }
        }
    }

    // ============================================================
    // 内联可复用组件
    // ============================================================

    // 分区栅格（2 列；wide 卡跨 2；窄屏 1 列）。互斥 visible + 入场动画。
    component SectionGrid: GridLayout {
        id: sec
        property string tabKey: ""
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        columns: root.sideCollapsed ? 1 : 2
        columnSpacing: 14
        rowSpacing: 14
        visible: root.currentTab === tabKey
        opacity: 1
        onVisibleChanged: if (visible) secAnim.restart()
        transform: Translate { id: secT; y: 0 }
        SequentialAnimation {
            id: secAnim
            ParallelAnimation {
                NumberAnimation { target: sec; property: "opacity"; from: 0.0; to: 1; duration: 300; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
                NumberAnimation { target: secT; property: "y"; from: 12; to: 0; duration: 300; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy }
            }
        }
    }

    // 设置卡（GlassPanel 头 + body 槽；自身按搜索过滤）
    component SettingsCard: GlassPanel {
        id: card
        property string badge: ""
        property string cardTitle: ""
        property string cardDesc: ""
        property string keywords: ""
        property bool wide: false
        default property alias body: bodyCol.data
        style: ml
        radius: 22
        Layout.fillWidth: true
        Layout.columnSpan: (wide && !root.sideCollapsed) ? 2 : 1
        Layout.preferredHeight: implicitHeight
        Layout.alignment: Qt.AlignTop
        visible: root.cardMatches(cardTitle + " " + cardDesc + " " + keywords)
        implicitHeight: contentCol.implicitHeight + 36

        ColumnLayout {
            id: contentCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    width: 38; height: 38; radius: 14
                    color: ml.accentSoft; border.width: 1; border.color: ml.accentSoftBorder
                    Text { anchors.centerIn: parent; text: card.badge; color: ml.aqua; font.pixelSize: 16 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: card.cardTitle; color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text {
                        visible: card.cardDesc !== ""
                        Layout.fillWidth: true
                        text: card.cardDesc; color: ml.textTertiary; font.pixelSize: 12; wrapMode: Text.WordWrap
                    }
                }
            }
            ColumnLayout { id: bodyCol; Layout.fillWidth: true; spacing: 10 }
        }
    }

    // 设置行：标题/副标题 + 右侧控件槽
    component SettingRow: RowLayout {
        id: srow
        property string rowTitle: ""
        property string rowSub: ""
        default property alias control: ctrlHost.data
        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: srow.rowTitle; color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Text {
                visible: srow.rowSub !== ""
                text: srow.rowSub; color: ml.textTertiary; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap
            }
        }
        Item {
            id: ctrlHost
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }

    // 细分隔线
    component ThinRule: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: ml.cellHair
    }

    // 诚实占位说明（无后端/下一阶段项；不放假数据 G6）
    component PlaceholderNote: Rectangle {
        property alias text: noteText.text
        Layout.fillWidth: true
        Layout.preferredHeight: noteText.implicitHeight + 24
        radius: 14
        color: ml.calSunkBg
        border.width: 1; border.color: ml.cellHair
        Text {
            id: noteText
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
            color: ml.textTertiary; font.pixelSize: 12; wrapMode: Text.WordWrap; lineHeight: 1.35
        }
    }

    // 指标格（数据概览 / 存储）
    component MetricTile: Rectangle {
        property string tileLabel: ""
        property string tileValue: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: 16
        color: ml.calSunkBg
        border.width: 1; border.color: ml.cellHair
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text { text: tileLabel; color: ml.textTertiary; font.pixelSize: 10; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.3 }
            Text { text: tileValue; color: ml.textPrimary; font.pixelSize: 21; font.weight: 900; font.letterSpacing: -0.4 }
        }
    }

    // ghost / primary / danger 按钮（复用 stats StatsGhostButton 配方）
    component GhostBtn: Rectangle {
        id: gbtn
        property string label: ""
        property bool primary: false
        property bool danger: false
        signal tapped()
        implicitWidth: gbtnLabel.implicitWidth + 28
        height: 38
        radius: 13
        color: primary ? "transparent"
               : (danger ? (gbtnMa.containsMouse ? ml.calDangerWash : ml.calGhostBg)
                         : (gbtnMa.containsMouse ? ml.calGhostHover : ml.calGhostBg))
        border.width: 1
        border.color: primary ? ml.accentSoftBorder
                      : (danger ? Qt.rgba(ml.calDangerWash.r, ml.calDangerWash.g, ml.calDangerWash.b, 0.6) : ml.calGhostBorder)
        gradient: primary ? primaryGrad : null
        Gradient {
            id: primaryGrad
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.82) }
            GradientStop { position: 1; color: Qt.rgba(ml.violet.r, ml.violet.g, ml.violet.b, 0.78) }
        }
        Text {
            id: gbtnLabel
            anchors.centerIn: parent
            text: gbtn.label
            color: gbtn.primary ? ml.calBtnInk
                   : (gbtn.danger ? ml.dangerText : ml.calGlyph)
            font.pixelSize: 13; font.weight: Font.DemiBold
        }
        MouseArea {
            id: gbtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onClicked: gbtn.tapped()
        }
    }

    // 单字母快捷键捕获键帽（#3）：点击进入捕获、按 A–Z 设定、Esc 取消。受控（不自写 keyText，
    // 父经 setHotkey 回写 → 绑定回流）。Keys.onShortcutOverride 让捕获时吃掉全局 Shortcut（否则按
    // 旧 N/P 会触发备忘/番茄而非被捕获）。
    component KeyCaptureChip: Rectangle {
        id: kc
        property string keyText: "N"
        property bool capturing: false
        signal captured(string key)
        implicitWidth: 54; implicitHeight: 30
        radius: 9
        color: capturing ? ml.accentSoft : ml.calGhostBg
        border.width: 1
        border.color: capturing ? ml.accentSoftBorder : ml.calGhostBorder
        Text {
            anchors.centerIn: parent
            text: kc.capturing ? "按键…" : kc.keyText
            color: kc.capturing ? ml.aqua : ml.textPrimary
            font.pixelSize: 12; font.weight: 900
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { kc.capturing = true; kc.forceActiveFocus() }
        }
        Keys.onShortcutOverride: function (e) { if (kc.capturing) e.accepted = true }
        Keys.onPressed: function (e) {
            if (!kc.capturing) return
            if (e.key === Qt.Key_Escape) { kc.capturing = false; e.accepted = true; return }
            if (e.key >= Qt.Key_A && e.key <= Qt.Key_Z) {
                kc.capturing = false
                kc.captured(String.fromCharCode(e.key))   // Qt.Key_A==65 → 'A'
                e.accepted = true
            }
        }
        onActiveFocusChanged: if (!activeFocus) capturing = false
    }

    // 白天/黑夜主题开关（v88 .theme-switch §7.6）：dayOn = !nightMode；点击发 nightModeToggled。
    component ThemeSwitch: Rectangle {
        id: tsw
        readonly property bool dayOn: !root.nightMode
        width: 66; height: 34; radius: 17
        color: ml.calSunkBg
        border.width: 1; border.color: ml.calInputBorder
        Layout.alignment: Qt.AlignVCenter
        Rectangle {
            width: 26; height: 26; radius: 13
            y: 4
            x: tsw.dayOn ? 36 : 4
            color: tsw.dayOn ? "#FFF3D6" : Qt.rgba(ml.aqua.r, ml.aqua.g, ml.aqua.b, 0.30)
            border.width: 1; border.color: tsw.dayOn ? Qt.rgba(0.0, 0.0, 0.0, 0.10) : ml.accentSoftBorder
            Text {
                anchors.centerIn: parent
                text: tsw.dayOn ? "☀" : "☾"
                color: tsw.dayOn ? "#3B7F9A" : ml.aqua
                font.pixelSize: 14
            }
            Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.Bezier; easing.bezierCurve: ml.easeSnappy } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onClicked: {
                // Shell 同步把 nightModeToggled→nightMode 回写本页，故 toast 必须读「目标值」而非回写后的 root.nightMode。
                var goingNight = !root.nightMode
                root.nightModeToggled(goingNight)
                root.showToast(goingNight ? "已切换到黑夜模式" : "已切换到白天模式")
            }
        }
    }
}
