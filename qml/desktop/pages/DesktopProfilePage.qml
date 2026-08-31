import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import "../memorylake"
import "../components/AppVisual.js" as AppVisual
import "../components/Hotkeys.js" as Hotkeys
import "../../shared/I18n.js" as I18n
import "../components/PlatformCursor.js" as Cursor

// v88「设置」页（暗玻璃全幅复刻 / 原地重皮 A-NAME）。规范：
//   docs/settings-functional-replication.md / settings-render-pipeline-replication.md /
//   settings-implementation-issues.md。
// 背景三件套（蓝黑渐变 + 42px 方格 + 双角辉光）由 DesktopAppShell 的 fullBleed 层提供
//   （已把 "settings" 加入 fullBleedPage + 栅格 visible + requestNavigate 路由）；本页只放内容。
// 契约：保留 nightMode + nightModeToggled（白天模式开关，不自写 night_mode，由 Shell 持久化）；
//   新增 requestNavigate（返回首页 / Esc）。设置项经 settingsRepository KV 即时持久化（G3）。
// 红线：对 service DB 只读（G4/I1/I2）；无后端项（番茄/通知/真删历史）走隐藏/占位，不写死假值（G6）。
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
    signal languageChanged(string mode)
    signal accentChanged(string color)

    // 记忆湖统一色板（单一事实源 G1）。夜=暗玻璃霓虹，昼=浅瓷；由 night 切换。
    MemoryLakeStyle {
        id: ml
        night: root.nightMode
        accentSeed: root.accentColor
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
    // 空闲阈值以**秒**存取，与 service_config.json 的 idle_threshold_sec 同单位同量程
    // （0–86400，0=不判空闲）。旧键 idle_timeout 存的是分钟，reloadFromKV 里一次性迁移。
    property int idleTimeoutSec: 300
    readonly property int idleTimeoutSecMin: 0
    readonly property int idleTimeoutSecMax: 86400
    property bool autoClassify: true
    property bool mergeWindows: true
    property bool privacyLocalOnly: true
    property bool hideTitles: true
    property bool anonymizeExport: false
    property bool notifyEnabled: true
    property bool memoAutosave: true

    // —— Phase 2 只读派生（onCompleted + usageStatsChanged 刷新；真实只读，不造假 G6）——
    property real historyBytes: 0      // timearc_service.db 字节
    property real cacheBytes: 0        // timearc.db 字节（UI 派生/缓存库）
    property int usageRecordCount: 0   // 已解析记录条数
    property string todaySwitchesText: "—"   // 今日前台切换次数（QML 派生）
    property string memoPagesText: "—"       // 备忘页数（从 memoryLakeMemoDoc 派生）
    property string pomodoroTodayText: "—"    // 今日番茄完成数（PomodoroWidget 写 pomodoro_today）

    // 逐项显隐（2B / G-HIDEAPP）：hiddenApps = 被隐藏的 group key 数组（持久化为 JSON）；
    // appList = usageStatManager.allApps() 去重清单（onCompleted 拉一次，供应用管理勾选）。
    property var hiddenApps: []
    property var appList: []
    property var appDisplayNameOverrides: ({})
    property string editingAppKey: ""
    property string appDisplayNameDraft: ""
    property string appDisplayNameError: ""
    // 应用管理 UI（#1 重设计）：搜索过滤 + 软上限折叠（默认显 appCap 个，可展开全部）。
    property string appSearchQuery: ""
    property bool appsExpanded: false
    readonly property int appCap: 14
    readonly property var filteredApps: {
        var q = ("" + appSearchQuery).toLowerCase()
        var r = []
        for (var i = 0; i < appList.length; i++) {
            var row = appList[i]
            var searchText = [
                AppVisual.modelDisplayName(row),
                AppVisual.modelIdentity(row),
                AppVisual.modelCategory(row),
                row.appName || "",
                row.path || ""
            ].join(" ").toLowerCase()
            if (q.length === 0 || searchText.indexOf(q) >= 0) r.push(row)
        }
        r.sort(AppVisual.compareAppModels)
        return r
    }
    readonly property var shownApps: (appSearchQuery.length > 0 || appsExpanded)
                                     ? filteredApps : filteredApps.slice(0, appCap)

    // 番茄钟（#2 接备忘番茄引擎 PomodoroWidget；写 KV，引擎在 _load/reset 时读默认时长/标题）。
    property string pomodoroDuration: "25"
    property string pomodoroTitle: "Focus for a while"
    property bool pomodoroCelebrate: true
    // 快捷键自定义（#3）：备忘 / 番茄全局键（Shell 响应式读，hotkeysChanged 通知）。
    // 存的是 Qt 可移植序列文本：单字母 "N" 与组合键 "Ctrl+Shift+K" 都是合法 QKeySequence，
    // 故旧存档（默认 N / P）原样可读，无需迁移。
    // 出厂默认分平台，取自 components/Hotkeys.js —— Shell 绑 Shortcut 时读的是同一份，
    // 各写各的就会出现「这里显示 N、实际生效 ⇧⌘N」。
    property string memoHotkeyKey: Hotkeys.memoDefault()
    property string pomodoroHotkeyKey: Hotkeys.pomodoroDefault()

    // 捕获态（哪一枚键帽正在等按键）。Shell 经 pageLoader.item 读 hotkeyCapturing，
    // 在捕获期间让 macOS 菜单栏整条失效——否则 ⌘Q 等键会被 AppKit 先吃掉（⌘Q 直接退应用），
    // QML 的 Keys.onShortcutOverride 管不到 NSMenu。
    property string capturingHotkey: ""      // "" | "memo" | "pomo"
    readonly property bool hotkeyCapturing: capturingHotkey.length > 0
    // 只有自己能清自己：点第二枚键帽会抢走第一枚的焦点，两次 capturing 变化的先后不定，
    // 少了这道归属判断就可能后到的 false 把新的 true 抹掉。
    function setCapturing(which, on) {
        if (on) capturingHotkey = which
        else if (capturingHotkey === which) capturingHotkey = ""
    }


    function tr(source) { return I18n.t(languageMode, source) }
    function sentence(key, params) { return I18n.sentence(languageMode, key, params) }
    onLanguageModeChanged: refreshOverview()

    // F2「关于与开源许可」：应用版本（MVP 常量，对齐顶层 CMakeLists project(time-arc VERSION 0.1)；
    // 真值访问器须在既有类读 PROJECT_VERSION，但该宏未注入编译期→需动冻结 src/CMakeLists，故 MVP 用常量。
    // 见 docs/f2-in-app-licenses-page-kickoff.md §5）。
    readonly property string appVersion: "0.1"
    // 第三方组件清单（名称 + 版本 + 许可 + 链接方式 + 文本文件）。文本由 F1-S2 产出（resources/licenses/，
    // 随包分发 + 本页渲染，单一真相源；新增 thirdparty 组件须同步加文本 + 本数组一行，rules/06 §4(3)）。
    // 版本真相源：Qt 6.11.1（C:/Qt/6.11.1）/ SQLite 3.51.3（sqlite3.h:149）/ Parson 1.5.3（parson.h:37-39）。
    readonly property var licenseComponents: [
        { name: "TimeArc", badge: "©", version: root.appVersion,
          license: "GPL-3.0-or-later, this project itself; see repository root LICENSE",
          linkage: "—",
          texts: [ { btn: "View License Text", file: "timearc-gpl-3.0.txt" } ] },
        { name: "Qt 6", badge: "Q", version: "6.11.1",
          license: "GNU LGPL-3.0 with exceptions; some tools and add-on modules are GPL-3.0",
          linkage: "Dynamic",
          texts: [ { btn: "LGPL-3.0 Full Text", file: "qt-lgpl-3.0.txt" },
                   { btn: "GPL-3.0 Full Text", file: "qt-gpl-3.0.txt" } ] },
        { name: "SQLite", badge: "S", version: "3.51.3",
          license: "Public domain, no license text",
          linkage: "Static",
          texts: [ { btn: "View Statement", file: "sqlite-public-domain.txt" } ] },
        { name: "Parson", badge: "P", version: "1.5.3",
          license: "MIT",
          linkage: "Static",
          texts: [ { btn: "View License Text", file: "parson-mit.txt" } ] },
        { name: "Material Symbols", badge: "M", version: "2026-08 snapshot",
          license: "Apache-2.0",
          linkage: "SVG resources / qrc assets",
          texts: [ { btn: "View License Text", file: "material-symbols-apache-2.0.txt" } ] }
    ]

    // 许可全文的 Qt 资源路径。坑链（实测）：
    //   1) Qt.resolvedUrl 从 qml/desktop/pages/ 上溯三级到模块根，产出 "qrc:/qt/qml/time_arc/resources/licenses/<file>"；
    //   2) QML XMLHttpRequest 对本地/qrc 文件 GET 默认禁读（"… disabled by default … QML_XHR_ALLOW_FILE_READ"），不可用；
    //   3) settingsRepository.readTextFile() 是 QFile，认 ":/" 资源前缀但不认 "qrc:" scheme。
    // 故把 "qrc:/…" 去掉 "qrc" 前缀规整成 ":/…" 喂给 readTextFile → QFile 读内嵌资源，零 C++、无需放宽安全开关。
    // 内嵌资源无网络访问 → 天然离线（CHARTER I6 / rules/06 §4(2)）。
    function _licenseResPath(file) {
        var u = Qt.resolvedUrl("../../../resources/licenses/" + file).toString()
        return (u.indexOf("qrc:/") === 0) ? u.substring(3) : u   // "qrc:/x" → ":/x"
    }

    // 打开许可全文弹层（同步读 qrc 文本，立即填充）。
    function showLicenseText(file, titleStr, subStr) {
        licenseViewer.titleText = titleStr
        licenseViewer.subText = subStr + " · " + file
        var resPath = root._licenseResPath(file)
        var t = settingsRepository ? settingsRepository.readTextFile(resPath) : ""
        licenseViewer.bodyText = (t && t.length > 0) ? t
            : root.sentence("localLicenseEmpty", {file: file, path: resPath})
        licenseViewer.shown = true
    }

    function _getBool(k, d) { return settingsRepository ? settingsRepository.getBool(k, d) : d }
    function _getStr(k, d) { return settingsRepository ? settingsRepository.getValue(k, d) : d }
    function _setBool(k, v) { if (settingsRepository) settingsRepository.setBool(k, v) }
    function _setStr(k, v) { if (settingsRepository) settingsRepository.setValue(k, v) }

    // —— 服务侧配置（空闲超时 / 真停采集）——
    // 输入框与配置 v1 同为**秒**（v0 是毫秒，单位已改），故 UI 边界不再做换算。
    // 两进程经磁盘 service_config.json 通信（守 I1，无 IPC）：C++ writeServiceConfig
    // 原子 RMW 写入 tracking.* 叶子并保留 database.dir 键。
    // 注意 0 是合法值（不判空闲），不能用 `|| 默认值` 兜底——0 在 JS 里是 falsy。
    function _clampIdleSec(v) {
        var n = parseInt(v, 10)
        if (isNaN(n)) return root.idleTimeoutSec
        return Math.max(root.idleTimeoutSecMin, Math.min(root.idleTimeoutSecMax, n))
    }
    function _idleSec() { return _clampIdleSec(root.idleTimeoutSec) }
    // 读空闲阈值：优先秒键；仅当秒键缺失时，把旧的分钟键（"5"/"10"/…）×60 迁移一次并落盘，
    // 免得老装机的「5 分钟」被当成 5 秒。两键都缺则用默认 300 秒。
    function _readIdleTimeoutSec() {
        var stored = _getStr("idle_timeout_sec", "")
        if (String(stored).length > 0) return _clampIdleSec(stored)

        var legacyMinutes = parseInt(_getStr("idle_timeout", ""), 10)
        var seconds = isNaN(legacyMinutes) ? 300 : _clampIdleSec(legacyMinutes * 60)
        _setStr("idle_timeout_sec", String(seconds))
        return seconds
    }
    // 保存空闲阈值：落 KV + 写服务配置，返回写盘是否成功供提示用。
    function _commitIdleTimeout(raw) {
        root.idleTimeoutSec = _clampIdleSec(raw)
        root._setStr("idle_timeout_sec", String(root.idleTimeoutSec))
        return root._writeServiceConfig()
    }
    // 返回写盘是否成功：service_config.json 损坏/不可写时 patchServiceConfig 拒写并
    // 返回 false（守 database.dir 键不被覆盖）。调用方据此提示，避免「假成功」。无写入
    // 通道（如平台未绑定）视为 true，不报假失败、保持旧行为。
    function _writeServiceConfig() {
        if (databaseManager && databaseManager.writeServiceConfig)
            return databaseManager.writeServiceConfig(_idleSec(), root.trackRunning)
        return true
    }
    // 「应用并重启采集」：写最新 idle+track 后优雅停采集，再按追踪开关决定是否重启。
    // 服务是 startup-read（启动时读一次），故唯有重启采集进程新设置才即时生效。
    // 追踪关闭＝服务**真停**采集（非仅 UI 软暂停）：此时只停、不重启。
    function applyAndRestartCollection() {
        if (!_writeServiceConfig()) {
            showToast("Could not write the service config (service_config.json is unwritable or corrupt); tracking was not restarted"); return
        }
        if (!settingsRepository || !settingsRepository.stopBackgroundCollection) {
            showToast("Config written; it takes effect the next time tracking starts"); return
        }
        Qt.callLater(function () {
            settingsRepository.stopBackgroundCollection()
            if (root.trackRunning) {
                var ok = settingsRepository.startBackgroundCollection
                         ? settingsRepository.startBackgroundCollection() : false
                showToast(ok ? "Background tracking restarted with the new settings"
                             : "Tracking could not start. Check the background service.")
            } else {
                showToast("Background tracking stopped (tracking is off; no new data is recorded)")
            }
        })
    }

    function reloadFromKV() {
        accentColor      = _getStr("accent_color", "#9FE7EE")
        blurStrength     = parseInt(_getStr("blur_strength", "24")) || 24
        restoreWindow    = _getBool("restore_window", true)
        landingPage      = _getStr("landing_page", "memorylake")
        showWelcome      = _getBool("show_welcome", true)
        languageMode     = settingsRepository ? settingsRepository.languageMode() : "en"
        timeFormat       = _getStr("time_format", "24")
        trackRunning     = _getBool("track_running", true)
        gameMode         = _getBool("game_mode", true)
        idleTimeoutSec   = _readIdleTimeoutSec()
        autoClassify     = _getBool("auto_classify", true)
        mergeWindows     = _getBool("merge_windows", true)
        privacyLocalOnly = _getBool("privacy_local_only", true)
        hideTitles       = _getBool("hide_titles", true)
        anonymizeExport  = _getBool("anonymize_export", false)
        notifyEnabled    = _getBool("notify_enabled", true)
        memoAutosave     = _getBool("memo_autosave", true)
        hiddenApps       = parseHiddenApps()
        appDisplayNameOverrides = parseAppDisplayNameOverrides()
        pomodoroDuration = _getStr("pomodoro_duration", "25")
        pomodoroTitle    = _getStr("pomodoro_title", "Focus for a while")
        pomodoroCelebrate= _getBool("pomodoro_celebrate", true)
        memoHotkeyKey    = _getStr("memo_hotkey_key", Hotkeys.memoDefault())
        pomodoroHotkeyKey= _getStr("pomodoro_hotkey_key", Hotkeys.pomodoroDefault())
    }

    // —— 读层过滤推入（2A 游戏/分类/合并 · 2B 显隐 · 2C 标题）——
    // 把本页开关推进 usageStatManager 读出层；只影响 UI 聚合，不写/不删 usage（G4/I1/I2）。
    function pushReadFilters() {
        if (usageStatManager && usageStatManager.setAppDisplayNameOverrides)
            usageStatManager.setAppDisplayNameOverrides(appDisplayNameOverrides)
        if (usageStatManager && usageStatManager.setReadFilters)
            usageStatManager.setReadFilters(autoClassify, gameMode, mergeWindows,
                                            hideTitles, hiddenApps)
    }
    function parseHiddenApps() {
        // 与 Shell 同一处理：旧身份方案的键先归一，否则复选框取消不掉（读侧认别名，
        // 但删除只删得掉当前键）。canonicalHiddenKeys 幂等，重复调用无副作用。
        var a = []
        try { a = JSON.parse(_getStr("hidden_apps", "[]")); if (!Array.isArray(a)) a = [] }
        catch (e) { a = [] }
        if (usageStatManager && usageStatManager.canonicalHiddenKeys) {
            var canonical = usageStatManager.canonicalHiddenKeys(a)
            if (JSON.stringify(canonical) !== JSON.stringify(a)) {
                _setStr("hidden_apps", JSON.stringify(canonical))
                a = canonical
            }
        }
        return a
    }
    function parseAppDisplayNameOverrides() {
        // 与 parseHiddenApps 同一处理：旧身份方案的键先归一，否则改过的名字不生效
        // 而且改不回来（读侧认别名，但写入只写得进当前键）。归一是幂等的。
        try {
            var o = JSON.parse(_getStr("app_display_name_overrides", "{}"))
            if (!o || typeof o !== "object" || Array.isArray(o)) return ({})
            if (usageStatManager && usageStatManager.canonicalDisplayNameKeys) {
                var canonical = usageStatManager.canonicalDisplayNameKeys(o)
                if (JSON.stringify(canonical) !== JSON.stringify(o)) {
                    _setStr("app_display_name_overrides", JSON.stringify(canonical))
                    o = canonical
                }
            }
            return o
        } catch (e) { return ({}) }
    }
    function copyAppDisplayNameOverrides() {
        var copy = ({})
        for (var key in appDisplayNameOverrides) copy[key] = appDisplayNameOverrides[key]
        return copy
    }
    function beginEditAppDisplayName(row) {
        editingAppKey = row.originalGroupKey || row.groupKey || ""
        appDisplayNameDraft = row.customDisplayName || row.defaultDisplayName
                || AppVisual.modelDisplayName(row) || ""
        appDisplayNameError = ""
    }
    function saveAppDisplayName(rawKey, draft) {
        var displayName = ("" + draft).trim()
        if (displayName.length === 0) {
            appDisplayNameError = tr("Display name cannot be empty.")
            return
        }
        displayName = displayName.substring(0, 80)
        var next = copyAppDisplayNameOverrides()
        next[rawKey] = displayName
        if (!settingsRepository ||
                !settingsRepository.setValue("app_display_name_overrides", JSON.stringify(next))) {
            appDisplayNameError = tr("Save failed. The previous setting is unchanged.")
            return
        }
        appDisplayNameOverrides = next
        editingAppKey = ""
        appDisplayNameError = ""
        pushReadFilters()
        refreshAppList()
        showToast("App display name saved")
    }
    function restoreAppDisplayName(rawKey) {
        var next = copyAppDisplayNameOverrides()
        delete next[rawKey]
        if (!settingsRepository ||
                !settingsRepository.setValue("app_display_name_overrides", JSON.stringify(next))) {
            appDisplayNameError = tr("Save failed. The previous setting is unchanged.")
            return
        }
        appDisplayNameOverrides = next
        editingAppKey = ""
        appDisplayNameError = ""
        pushReadFilters()
        refreshAppList()
        showToast("Default display name restored")
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

    // 分类规则（docs/categorization-redesign.md）：规则表是唯一来源，UI 只读它 + 改它。
    // rulesTick 让下面这些只读属性在规则变更时重算（管理器发 rulesChanged）。
    property int rulesTick: 0
    property string titleRuleAppKey: ""        // 正在新建标题规则的应用行 key
    property var titleRuleDraft: ({})
    property string expandedRuleCategory: ""
    property bool newCategoryOpen: false
    property string newCategoryName: ""
    property bool appPickerOpen: false
    property string appPickerQuery: ""
    readonly property var appPickerResults: {
        var q = ("" + appPickerQuery).toLowerCase()
        var out = []
        for (var i = 0; i < appList.length && out.length < 14; i++) {
            var row = appList[i]
            var text = (AppVisual.modelDisplayName(row) + " " + (row.appName || "")).toLowerCase()
            if (q.length === 0 || text.indexOf(q) >= 0) out.push(row)
        }
        return out
    }
    property string editingRuleId: ""
    property bool newRuleOpen: false
    property var ruleDraft: ({})
    property string ruleDraftError: ""
    readonly property bool hasCategorization: (typeof categorizationManager !== "undefined") && !!categorizationManager
    readonly property var categoryList: {
        rulesTick
        return hasCategorization ? categorizationManager.categories() : []
    }
    readonly property var ruleGroups: {
        rulesTick
        return hasCategorization ? categorizationManager.rulesGroupedByCategory() : []
    }
    readonly property bool rulesCustomized: {
        rulesTick
        return hasCategorization ? categorizationManager.customized : false
    }
    readonly property int newDefaultsCount: {
        rulesTick
        return hasCategorization ? categorizationManager.newDefaultsCount : 0
    }
    readonly property string rulesLoadError: {
        rulesTick
        return hasCategorization ? categorizationManager.loadError() : ""
    }

    function categoryLabelOf(categoryId) {
        if (!categoryId) return ""
        return hasCategorization ? categorizationManager.categoryLabel(categoryId) : categoryId
    }
    function categoryColorOf(categoryId) {
        for (var i = 0; i < categoryList.length; i++)
            if (categoryList[i].id === categoryId && categoryList[i].color)
                return categoryList[i].color
        return AppVisual.categoryColor(categoryId, "", root.nightMode)
    }
    // 这一行改的是「这个应用」的类别。命中的规则要是还覆盖别的应用（例如共用的
    // 浏览器规则），就自动收窄成只针对本应用的规则——从应用行出发的编辑不该悄悄
    // 改动别的应用。
    function ruleBreadthFor(row) {
        if (!hasCategorization) return 0
        var info = categorizationManager.explain(row.appId || "", row.appName || "", "")
        if (!info.matched) return 0
        return categorizationManager.matchCount(info.ruleId, root.appList)
    }
    function assignAppCategory(row, categoryId) {
        if (!hasCategorization) return
        var narrow = ruleBreadthFor(row) > 1
        var ok = categorizationManager.assignCategory(row.appId || "", row.appName || "",
                                                     "", categoryId, narrow)
        if (ok) {
            root.refreshAppList()
            root.showToast(root.tr("Moved to") + " " + root.categoryLabelOf(categoryId))
        } else {
            root.showToast(root.tr("Could not save the category"))
        }
    }

    // 这个应用归哪条规则管——用户问过「规则应该出现在 App Management 里」。
    function appRuleLabel(row) {
        rulesTick
        if (!hasCategorization || !row) return root.tr("No rule yet")
        var r = categorizationManager.appRuleFor(row.appId || "", row.appName || "")
        return (r && r.label && r.label.length > 0) ? r.label : root.tr("No rule yet")
    }
    // 标题规则：绑在一个应用上，所以不需要额外的生效范围选择。
    function titleRulesFor(row) {
        rulesTick
        if (!hasCategorization || !row) return []
        return categorizationManager.titleRulesForApp(row.appId || "", row.appName || "")
    }
    function beginTitleRule(appKey, categoryId) {
        root.titleRuleDraft = { name: "", titles: "", category: categoryId ? categoryId : "other" }
        root.titleRuleAppKey = appKey
    }
    function saveTitleRule(row) {
        if (!hasCategorization) return
        var d = root.titleRuleDraft
        var titles = []
        var parts = ("" + (d.titles || "")).split(",")
        for (var i = 0; i < parts.length; i++) {
            var t = parts[i].trim()
            if (t.length > 0) titles.push(t)
        }
        if (titles.length === 0) { root.showToast(root.tr("Add at least one title match first")); return }
        var id = categorizationManager.addTitleRuleForApp(row.appId || "", row.appName || "",
                                                          d.name || "", titles, d.category)
        if (("" + id).length > 0) {
            root.titleRuleAppKey = ""
            root.refreshAppList()
            root.showToast(root.tr("Rule saved"))
        } else {
            root.showToast(root.tr("Could not save the rule"))
        }
    }
    function deleteRuleById(ruleId) {
        if (!hasCategorization) return
        if (categorizationManager.deleteRule(ruleId)) {
            root.refreshAppList()
            root.showToast(root.tr("Rule deleted"))
        }
    }
    function restoreDefaultRules() {
        if (!hasCategorization) return
        if (categorizationManager.restoreAllDefaults()) {
            root.editingRuleId = ""
            root.newRuleOpen = false
            root.refreshAppList()
            root.showToast(root.tr("Default rules restored"))
        }
    }
    // QML 只在属性**值**变化时发信号。`var d = obj; d.k = v; obj = d` 把同一个
    // 对象引用赋回去 → 不算变化 → 绑定不重算（表现为点了没反应）。所以每次改草稿
    // 都返回一个新对象。
    function withField(obj, key, value) {
        var out = {}
        for (var k in obj) out[k] = obj[k]
        out[key] = value
        return out
    }
    function beginNewCategory() {
        root.newCategoryName = ""
        root.newCategoryOpen = true
    }
    function saveNewCategory() {
        if (!hasCategorization) return
        var id = categorizationManager.addCategory(root.newCategoryName, "")
        if (("" + id).length > 0) {
            root.newCategoryOpen = false
            root.newCategoryName = ""
            root.showToast(root.tr("Category created"))
        } else {
            root.showToast(root.tr("Could not save the category"))
        }
    }
    function askDeleteCategory(categoryId, label, ruleCount) {
        root.askConfirm("Delete category",
                        root.sentence("confirmDeleteCategory", {name: label, count: ruleCount}),
                        "Delete", true,
                        function () { root.deleteCategoryById(categoryId) })
    }
    function askDeleteRule(ruleId, label) {
        root.askConfirm("Delete rule",
                        root.sentence("confirmDeleteRule", {name: label}),
                        "Delete", true,
                        function () { root.deleteRuleById(ruleId) })
    }
    function askRestoreDefaultRules() {
        root.askConfirm("Reset to defaults",
                        "This discards every change you made and rebuilds the rules from the apps tracking has recorded so far. Your history is not affected.",
                        "Restore", true,
                        function () { root.restoreDefaultRules() })
    }
    function deleteCategoryById(categoryId) {
        if (!hasCategorization) return
        if (categorizationManager.deleteCategory(categoryId)) {
            root.refreshAppList()
            root.showToast(root.tr("Category deleted"))
        } else {
            root.showToast(root.tr("This category cannot be deleted"))
        }
    }
    // GlassTextField.text 是内部 TextInput 的 alias：用户第一次输入就会摧毁父级
    // 绑定，之后再改 ruleDraft 也不会回到输入框。所以打开编辑器时**显式写入**。
    function _syncRuleFields() {
        if (typeof ruleNameField !== "undefined" && ruleNameField)
            ruleNameField.text = root.ruleDraft.name || ""
        if (typeof ruleTitleField !== "undefined" && ruleTitleField)
            ruleTitleField.text = root.ruleDraft.title || ""
    }
    function beginNewRule() {
        root.ruleDraft = { name: "", category: (categoryList.length > 0 ? categoryList[0].id : "other"),
                           appNeedle: "", appLabel: "", appIcon: "", title: "" }
        root.ruleDraftError = ""
        root.editingRuleId = ""
        root.appPickerQuery = ""
        root.newRuleOpen = true
        root._syncRuleFields()
        root.appPickerOpen = true
    }
    function beginEditRule(rule) {
        // 出厂规则的 name 是空的（只有用户改名才写），可读名字在 label 里；
        // 直接回填 label，用户看到的就是他刚点的那一行。
        var appLabel = ""
        var appIcon = ""
        if ((rule.app || []).length > 0) {
            appLabel = rule.label && rule.label.length > 0
                       ? rule.label : (rule.app || []).join(", ")
            appIcon = rule.icon || ""
        }
        root.ruleDraft = { name: rule.name && rule.name.length > 0 ? rule.name : (rule.label || ""),
                           category: rule.category,
                           appNeedle: "",            // 不重选应用就保留原有匹配
                           appLabel: appLabel,
                           appIcon: appIcon,
                           title: (rule.title || []).join(", ") }
        root.ruleDraftError = ""
        root.newRuleOpen = false
        root.appPickerOpen = false
        root.appPickerQuery = ""
        root.editingRuleId = rule.id
        root._syncRuleFields()
    }
    // 选应用而不是敲字符串：规则绑定的是一个具体应用，needle 由 C++ 归一化生成。
    function pickRuleApp(row) {
        if (!hasCategorization) return
        var next = root.withField(root.ruleDraft, "appNeedle",
                                  categorizationManager.appNeedleFor(row.appId || "", row.appName || ""))
        next = root.withField(next, "appLabel",
                              AppVisual.modelDisplayNameForLanguage(row, root.languageMode))
        next = root.withField(next, "appIcon", AppVisual.modelIconSource(row))
        root.ruleDraft = next
        root.appPickerOpen = false
    }
    function ruleDraftFields() {
        var toList = function (text) {
            var out = []
            var parts = ("" + text).split(",")
            for (var i = 0; i < parts.length; i++) {
                var t = parts[i].trim()
                if (t.length > 0) out.push(t)
            }
            return out
        }
        var fields = { name: root.ruleDraft.name, category: root.ruleDraft.category,
                       title: toList(root.ruleDraft.title) }
        // 只有重新选过应用才覆盖 app；否则保留原规则自己的匹配（出厂规则带别名列表）。
        if (("" + (root.ruleDraft.appNeedle || "")).length > 0)
            fields.app = [root.ruleDraft.appNeedle]
        return fields
    }
    // 一条规则必须绑定一个应用：标题匹配因此天然有范围，不需要额外的范围选择。
    readonly property bool ruleDraftValid: {
        rulesTick
        var f = ruleDraft
        if (!f || !f.category) return false
        var boundApp = ("" + (f.appNeedle || "")).length > 0 || ("" + (f.appLabel || "")).length > 0
        return boundApp
    }
    function saveRuleDraft() {
        if (!hasCategorization) return
        var fields = ruleDraftFields()
        var problems = categorizationManager.lintDraft(fields)
        if (problems.length > 0) { root.ruleDraftError = problems.join("；"); return }
        var ok = false
        if (root.editingRuleId.length > 0) ok = categorizationManager.updateRule(root.editingRuleId, fields)
        else ok = ("" + categorizationManager.addRule(fields)).length > 0
        if (!ok) { root.ruleDraftError = root.tr("Could not save the rule"); return }
        root.ruleDraftError = ""
        root.editingRuleId = ""
        root.newRuleOpen = false
        root.refreshAppList()
        root.showToast(root.tr("Rule saved"))
    }

    function refreshAppList() {
        appList = (usageStatManager && usageStatManager.allApps) ? usageStatManager.allApps() : []
    }

    Connections {
        target: (typeof categorizationManager !== "undefined") ? categorizationManager : null
        function onRulesChanged() { root.rulesTick++ }
    }

    // 存储概览（G-STORAGE）：只读文件字节 + 记录数。
    function refreshStorage() {
        if (!usageStatManager) return
        historyBytes = (databaseManager && databaseManager.getServiceDatabasePath)
                       ? usageStatManager.fileSizeBytes(databaseManager.getServiceDatabasePath()) : 0
        cacheBytes = (databaseManager && databaseManager.getDatabasePath)
                     ? usageStatManager.fileSizeBytes(databaseManager.getDatabasePath()) : 0
        usageRecordCount = usageStatManager.recordCount()
    }

    // 数据概览派生：今日切换次数（QML 派生，G-4）+ 备忘页数（memoryLakeMemoDoc）。
    function refreshOverview() {
        if (usageStatManager && usageStatManager.foregroundSegmentsForRange) {
            var segs = usageStatManager.foregroundSegmentsForRange("day")
            var switches = (segs && segs.length > 0) ? computeSwitchCount(segs) : 0
            todaySwitchesText = (segs && segs.length > 0)
                                ? sentence("switchCount", {count: switches})
                                : "—"
        }
        var doc = _getStr("memoryLakeMemoDoc", "")
        if (doc && doc.length > 0) {
            try {
                var o = JSON.parse(doc)
                if (o && o.pages && o.pages.length !== undefined)
                    memoPagesText = sentence("memoPagePlain", {count: o.pages.length})
            } catch (e) { /* 解析失败 → 维持「—」，不造假 */ }
        }
        // 今日番茄完成数（PomodoroWidget._recordCompletion 写 date-stamped pomodoro_today）。
        var todayKey = Qt.formatDate(new Date(), "yyyy-MM-dd")
        var praw = _getStr("pomodoro_today", "")
        if (praw && praw.length > 0) {
            try {
                var p = JSON.parse(praw)
                pomodoroTodayText = (p && p.d === todayKey && p.n > 0)
                                    ? sentence("itemCount", {count: p.n})
                                    : sentence("itemCount", {count: 0})
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

    // 读服务侧的实际注册态（真值在 launchd / OS 登录项，不是本地 KV）。
    // root.autostartEnabled 只是这一刻的快照，故凡是可能变过的时机都要重读。
    function refreshAutostart() {
        if (settingsRepository && settingsRepository.autostartEnabled)
            root.autostartEnabled = settingsRepository.autostartEnabled()
    }

    // app 内改动（状态栏菜单那两行、本页开关、启动自检）都经 SettingsRepository，
    // 由它广播；否则本页会一直显示打开页面那一刻的旧值。
    Connections {
        target: settingsRepository
        function onServiceStateChanged() { root.refreshAutostart() }
    }

    // app 外改动收不到任何信号——用户可以直接在「系统设置 → 登录项」里关掉。
    // 唯一可靠的时机是 app 重新激活（从系统设置切回来那一下）：本页在 Loader 里，
    // 换页即销毁重建，所以 visible 在其存活期间不会变，盯 visible 是抓不到的。
    Connections {
        target: Application
        function onStateChanged() {
            if (Application.state === Qt.ApplicationActive)
                root.refreshAutostart()
        }
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
    function showToast(msg) { settingsToast.message = tr(msg); settingsToast.shown = true; toastTimer.restart() }
    function onOff(v) { return v ? tr("Enabled") : tr("Disabled") }

    // —— 快捷键序列文本（#3）——
    // 修饰名一律用 Qt 的可移植写法。macOS 上 Qt 交换 Ctrl/Meta（未设
    // AA_MacDontSwapCtrlAndMeta），故 Ctrl→⌘、Meta→⌃，与 MacMenuBar.qml 里
    // 那些 "Ctrl+" 字面量同一套语义：一份文本两个平台都对。
    function _seqFromEvent(e) {
        var m = e.modifiers
        var s = ""
        if (m & Qt.ControlModifier) s += "Ctrl+"
        if (m & Qt.AltModifier)     s += "Alt+"
        if (m & Qt.ShiftModifier)   s += "Shift+"
        if (m & Qt.MetaModifier)    s += "Meta+"
        return s + String.fromCharCode(e.key)
    }

    // 归一化后再比较，别直接比字符串：QKeySequence 的修饰键次序不是这里写的次序，
    // 手写占用表也就不必操心谁在前。顺带把旧存档的小写字母抬成大写。
    function _canonSeq(text) {
        var parts = ("" + text).split("+")
        var base = parts.pop()
        var has = function (n) { return parts.indexOf(n) >= 0 }
        return (has("Ctrl") ? "Ctrl+" : "") + (has("Alt") ? "Alt+" : "")
             + (has("Shift") ? "Shift+" : "") + (has("Meta") ? "Meta+" : "")
             + base.toUpperCase()
    }

    // 展示用：非 macOS 原样显示 "Ctrl+Shift+K"；macOS 按苹果惯例的 ⌃⌥⇧⌘ 次序出符号。
    function hotkeyDisplay(seq) {
        if (!seq || seq.length === 0) return ""
        if (Qt.platform.os !== "osx") return seq
        var parts = ("" + seq).split("+")
        var base = parts.pop()
        var has = function (n) { return parts.indexOf(n) >= 0 }
        return (has("Meta") ? "⌃" : "") + (has("Alt") ? "⌥" : "")
             + (has("Shift") ? "⇧" : "") + (has("Ctrl") ? "⌘" : "") + base.toUpperCase()
    }

    // 键帽上的文字：停用（空串）时给个占位，否则空键帽看着像渲染坏了。
    function hotkeyLabel(seq) {
        return (seq && seq.length > 0) ? hotkeyDisplay(seq) : tr("Not set")
    }

    // 内置键占用表。全平台一份（Windows/Linux 没有菜单栏，这些组合其实空闲，但仍照样保留：
    // 设置导出要能在机器之间搬，卡片文案也才能只讲一条规则）。
    // 这是三处定义的镜像，没有任何机制保证同步——改动那三处时记得回来看一眼：
    //   MacMenuBar.qml（菜单项 shortcut）/ main.qml:163（⌃⌘F）/ MemoOverlay.qml:619（画布编辑键）。
    // 单字母基键出不了 ⌘, 与 ⌘1–⌘4，故表里不列；哪天基键集放宽了再补。
    // 长远方向是 docs/desktop-keyboard-navigation-design.md §4.1 的 KeyMap.js 单一真源。
    // owner 用中文菜单词，渲染时走 I18n.menu()，与菜单栏共用同一套词表。
    // cmd 是「这条内置键本来就是干这件事的」：⇧⌘N 的菜单命令正是开备忘黑板，所以把备忘
    // 设成 ⇧⌘N 不算抢键（macOS 出厂默认就是它，见 Hotkeys.js），但把「番茄」设成 ⇧⌘N 要拦。
    readonly property var reservedHotkeys: [
        { seq: "Ctrl+Q",       owner: "Quit TimeArc",  cmd: "" },
        { seq: "Ctrl+W",       owner: "Close Window",      cmd: "" },
        { seq: "Ctrl+M",       owner: "Minimize",        cmd: "" },
        { seq: "Ctrl+H",       owner: "Hide TimeArc",  cmd: "" },
        { seq: "Ctrl+Alt+H",   owner: "Hide Others",      cmd: "" },
        { seq: "Ctrl+Shift+E", owner: "Export Stats Report…", cmd: "" },
        { seq: "Ctrl+Shift+D", owner: "Night Mode",      cmd: "" },
        { seq: "Ctrl+Meta+F",  owner: "Enter Full Screen",    cmd: "" },
        { seq: "Ctrl+Shift+N", owner: "Memo Board",      cmd: "memo" },
        { seq: "Ctrl+Shift+P", owner: "Pomodoro",        cmd: "pomo" },
        { seq: "Ctrl+Z",       owner: "Undo",          cmd: "" },
        { seq: "Ctrl+Shift+Z", owner: "Redo",          cmd: "" },
        { seq: "Ctrl+Y",       owner: "Redo",          cmd: "" },
        { seq: "Ctrl+X",       owner: "Cut",          cmd: "" },
        { seq: "Ctrl+C",       owner: "Copy",          cmd: "" },
        { seq: "Ctrl+V",       owner: "Paste",          cmd: "" },
        { seq: "Ctrl+A",       owner: "Select All",          cmd: "" }
    ]
    // which 是正在设置的那一条（"memo" / "pomo"）：命中自己那条内置键时放行。
    function _reservedOwner(seq, which) {
        var c = _canonSeq(seq)
        for (var i = 0; i < reservedHotkeys.length; i++) {
            var r = reservedHotkeys[i]
            if (_canonSeq(r.seq) === c)
                return r.cmd === which ? "" : r.owner
        }
        return ""
    }

    // 自定义快捷键（#3）：单字母或组合键；备忘 / 番茄不能同键，也不能抢内置键。
    // 写 KV + 发 hotkeysChanged 让 Shell 重读。
    // 返回值就是「键帽该不该退出捕获态」：成功 true（调用方清 capturing，键帽回到显示新键位），
    // 被拒 false（留在捕获态，可直接再按一次）。捕获态本身只由键帽的 capturing 属性驱动，
    // 这里不代它写——本页拿不到那枚键帽，两处各写一半就会出现「页面以为结束了、键帽还亮着」。
    function setHotkey(which, k) {
        var seq = _canonSeq(k)

        // 键帽收到 Delete / Backspace 时送空串 = 停用。
        // macOS 停不掉（菜单行常驻同一个 key equivalent，见 Hotkeys.canDisable 的注释），
        // 那边改为恢复出厂键位；提示只报结果，原因留给注释与文档，不塞进一行 toast。
        var restored = false
        if (seq.length === 0 && !Hotkeys.canDisable()) {
            seq = _canonSeq(Hotkeys.defaultFor(which))
            restored = true
        }

        // 空串（真停用）不参与占位检查：它谁也不抢，两边同时停用也不算撞车。
        if (seq.length > 0) {
            var owner = _reservedOwner(seq, which)
            if (owner.length > 0) {
                showToast(sentence("hotkeyReserved", { owner: I18n.menu(languageMode, owner) }))
                return false
            }
            var other = which === "memo" ? pomodoroHotkeyKey : memoHotkeyKey
            if (seq === _canonSeq(other)) {
                showToast(which === "memo" ? "Conflicts with the Pomodoro hotkey" : "Conflicts with the Memo hotkey")
                return false
            }
        }

        if (which === "memo") { memoHotkeyKey = seq; _setStr("memo_hotkey_key", seq) }
        else                  { pomodoroHotkeyKey = seq; _setStr("pomodoro_hotkey_key", seq) }
        hotkeysChanged()
        if (restored)
            showToast(sentence("hotkeyRestoredDefault", { key: hotkeyDisplay(seq) }))
        else if (seq.length === 0)
            showToast("Hotkey disabled")
        else
            showToast(sentence("hotkeyUpdated", { key: hotkeyDisplay(seq) }))
        return true
    }

    // 顶栏标题/描述（settingsCopy 逐字，v88 17835–17841）
    readonly property var topCopy: ({
        "general":  { t: "General Settings",   d: "Control appearance, startup behavior, and the basic experience." },
        "tracking": { t: "Tracking & Apps", d: "Manage usage records, app categories, and visible scope." },
        "privacy":  { t: "Privacy & Data", d: "Control local storage, sensitive title hiding, and cache cleanup." },
        "memo":     { t: "Memo & Pomodoro", d: "Adjust default behavior for memo, notes, pages, and Pomodoro." },
        "export":   { t: "Import & Export",   d: "Back up settings, copy summaries, or restore defaults." },
        "about":    { t: "About & Licenses", d: "Versions and licenses for TimeArc and its third-party components. Full texts are bundled and available offline." }
    })

    // 标签模型
    readonly property var tabModel: [
        { key: "general",  glyph: "✦", label: "General" },
        { key: "tracking", glyph: "◉", label: "Tracking & Apps" },
        { key: "privacy",  glyph: "◆", label: "Privacy & Data" },
        { key: "memo",     glyph: "◇", label: "Memo & Pomodoro" },
        { key: "export",   glyph: "⇅", label: "Import & Export" },
        { key: "about",    glyph: "©", label: "About & Licenses" }
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
        { t: "Home", d: "See today's conclusion and key items." },
        { t: "Calendar", d: "Manage future plans and day details." },
        { t: "Stats", d: "Review long-term patterns by week, month, and year." },
        { t: "Recap", d: "Turn data into a story-like recap." }
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
        if (!usageStatManager || !usageStatManager.exportReport) { showToast("Export is unavailable right now"); return }
        var json = buildSettingsJson()
        if (!json || json.length === 0) { showToast("Export failed: serialization error"); return }
        var p = usageStatManager.exportReport("timearc-settings", json)
        if (p && p.length > 0) root.showSavedAt("Settings JSON Exported", p)
        else showToast("Export failed")
    }
    function copySummary() {
        clipHelper.text = sentence("settingsSummary", {
            theme: tr(root.nightMode ? "Dark glass theme" : "Light porcelain theme"),
            hotkey: memoHotkeyKey.length > 0
                    ? sentence("memoHotkeyOpens", {key: hotkeyDisplay(memoHotkeyKey)})
                    : tr("memo hotkey off"),
            accent: accentColor
        })
        clipHelper.selectAll(); clipHelper.copy(); clipHelper.deselect()
        showToast("Settings summary copied")
    }
    function restoreVisualDefaults() {
        accentColor = "#9FE7EE"; _setStr("accent_color", accentColor)
        accentChanged(accentColor)
        blurStrength = 24;       _setStr("blur_strength", "24")
        showWelcome = true;      _setBool("show_welcome", true)
        showToast("Visual settings restored to defaults")
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
        showToast("Local cache cleared (window position and other derived data)")
    }

    // 导入设置（G-IMPORT）：FileDialog 选 JSON → C++ readTextFile 读 → 解析 → 逐键 setValue →
    // 重读本页属性。只读所选文件、只写 settings KV，不动 usage/契约。
    function doImport(fileUrl) {
        if (!settingsRepository) { showToast("Import is unavailable right now"); return }
        var txt = settingsRepository.readTextFile("" + fileUrl)
        if (!txt || txt.length === 0) { showToast("That JSON file is not formatted correctly"); return }
        try {
            var o = JSON.parse(txt)
            var s = (o && o.settings) ? o.settings : o
            if (!s || typeof s !== "object") { showToast("That JSON file is not formatted correctly"); return }
            var n = 0
            for (var k in s) { if (s.hasOwnProperty(k)) { settingsRepository.setValue("" + k, "" + s[k]); n++ } }
            reloadFromKV()
            // reloadFromKV 只把值读回本页；导入的快捷键要让 Shell 重绑 Shortcut，否则得等重启
            // 才生效——键位现在可能是组合键，「按了没反应」比以前更难自己想明白。
            hotkeysChanged()
            showToast(n > 0 ? "Settings file loaded" : "That JSON file is not formatted correctly")
        } catch (e) { showToast("That JSON file is not formatted correctly") }
    }

    // 成功保存反馈：在持久确认卡里显示完整路径（toast 单行 + 1.5s 装不下长路径，用户找不到文件），
    // 并给「打开文件夹」按钮用资源管理器定位（Qt.openUrlExternally 打开所在目录）。
    // 斜杠数按平台分：Windows 盘符路径（C:/...）没有前导斜杠，要补满三道；
    // Unix（macOS/Linux）绝对路径自带前导斜杠，只补两道，否则拼出 file:////Users/...，
    // Qt 会解析成「空 authority + //Users/... 」的非本地路径，openUrlExternally 返回 false
    // 且不报错——「打开文件夹」按钮就这样静默失效。encodeURI 处理空格与非 ASCII
    // （默认服务目录 .../Library/Application Support/... 本身就带空格）。
    function _folderUrlOf(p) {
        var s = ("" + p).replace(/\\/g, "/")
        var i = s.lastIndexOf("/")
        // i === 0 是根目录下的文件（/foo.db），目录该是 "/" 而不是文件自身。
        var dir = (i > 0) ? s.substring(0, i) : (i === 0 ? "/" : s)
        return (dir.charAt(0) === "/" ? "file://" : "file:///") + encodeURI(dir)
    }
    function showSavedAt(title, p) {
        root.askConfirm(title, root.sentence("savedToPath", { path: p }), "Open Folder", false,
            function () {
                // 返回值必须看：失败时桌面环境不会有任何反馈，正是本次静默失效的原因。
                if (!Qt.openUrlExternally(root._folderUrlOf(p)))
                    root.showToast("Could not open the folder")
            })
    }
    // GUI 数据库备份：C++ backupDatabase 用 VACUUM INTO 备份 timearc.db。
    function doBackupDatabase() {
        if (!databaseManager || !databaseManager.backupDatabase) { showToast("Backup is unavailable right now"); return }
        var p = databaseManager.backupDatabase()
        if (p && p.length > 0) root.showSavedAt("Database Backed Up", p)
        else showToast("Backup failed")
    }
    // D1 恢复（整库）：选备份 → 只读校验预览（坏文件直接拒）→ 危险二次确认 → 替换库。
    function _unixDate(s) { return (s && s > 0) ? Qt.formatDate(new Date(s * 1000), "yyyy-MM-dd") : "—" }
    function onRestoreFileChosen(fileUrl) {
        if (!databaseManager || !databaseManager.inspectBackup) { showToast("Restore is unavailable right now"); return }
        var info = databaseManager.inspectBackup("" + fileUrl)
        if (!info || !info.ok) {
            showToast(info && info.error ? ("Invalid backup: " + info.error) : "Invalid backup file")
            return
        }
        var msg = root.sentence("backupPreview", {
                    integrity: info.integrity, settings: info.settingsRows,
                    projects: info.manualProjectRows, sessions: info.manualSessionRows, apps: info.appRows
                })
        root.askConfirm("Restore Database", msg, "Restore", true, function () { root.doRestoreConfirmed("" + fileUrl) })
    }
    function doRestoreConfirmed(fileUrl) {
        if (!databaseManager || !databaseManager.restoreDatabase) { showToast("Restore is unavailable right now"); return }
        var ok = databaseManager.restoreDatabase("" + fileUrl)
        if (!ok) showToast("Restore failed: the backup is invalid or the GUI database cannot be replaced")
        // 成功路径由 databaseManager.databaseRestored 信号触发重启提示
    }

    // D2 服务数据位置：选目录只更新 service_config.json database.dir 指针。GUI 不移动或写入
    // timearc_service.db；后台服务会在下次启动时写入该目录。
    function dbLocationText() {
        return (databaseManager && databaseManager.currentDatabaseLocationDir)
            ? ("" + databaseManager.currentDatabaseLocationDir()) : "—"
    }
    // 更新指针前尽量停止后台采集，让下一次启动读取新目录。
    function _stopThenMigrate(migrateFn) {
        Qt.callLater(function () {
            if (settingsRepository && settingsRepository.stopBackgroundCollection)
                settingsRepository.stopBackgroundCollection()
            root._afterRelocate(migrateFn())
        })
    }
    function onDbFolderChosen(folderUrl) {
        if (!databaseManager || !databaseManager.relocateDatabaseTo) { showToast("Migration is unavailable right now"); return }
        // 按钮文案用「设置此目录」而不是「设置」：词表以中文原文为键，"设置" 已被
        // 导航项占用（→ Settings），复用会把确认按钮翻成 "Settings"。
        root.askConfirm("Set Service Database Folder",
            "The background service database folder will be switched to the selected location. TimeArc does not move the existing database file; the background service writes to that folder after it restarts.",
            "Set This Folder", true, function () { root._stopThenMigrate(function () { return databaseManager.relocateDatabaseTo("" + folderUrl) }) })
    }
    function doRestoreDefaultLocation() {
        if (!databaseManager || !databaseManager.restoreDefaultDatabaseLocation) { showToast("Migration is unavailable right now"); return }
        root.askConfirm("Restore Default Database Location",
            "The service database folder pointer will be cleared. The background service returns to its default location the next time it starts.",
            "Restore Default", true, function () { root._stopThenMigrate(function () { return databaseManager.restoreDefaultDatabaseLocation() }) })
    }
    function _afterRelocate(res) {
        if (res && res.ok) {
            root.askConfirm("Location Updated",
                root.sentence("relocateSuccess", { path: res.newPath }),
                "Quit Now", false, function () { Qt.quit() })
        } else {
            showToast(res && res.error ? ("Migration failed: " + res.error) : "Migration failed")
        }
    }

    // macOS 菜单栏「文件 › 导入设置…」的入口：对话框 id 出不了本文件，
    // Shell 的 menuRunSettingsAction 只能按函数名调用（其余两项本就是函数）。
    function openImportDialog() {
        importDialog.open()
    }

    FileDialog {
        id: importDialog
        title: root.tr("Import Settings JSON")
        nameFilters: [root.tr("JSON files (*.json)"), root.tr("All files (*)")]
        onAccepted: root.doImport(selectedFile)
    }

    FileDialog {
        id: restoreDialog
        title: root.tr("Choose Database Backup")
        nameFilters: [root.tr("Database backups (*.db)"), root.tr("All files (*)")]
        onAccepted: root.onRestoreFileChosen(selectedFile)
    }

    FolderDialog {
        id: dbFolderDialog
        title: root.tr("Choose Database Folder")
        onAccepted: root.onDbFolderChosen(selectedFolder)
    }

    // 恢复成功后（C++ emit databaseRestored）：引导重启以加载新数据（UI 缓存未热更）。
    Connections {
        target: databaseManager
        ignoreUnknownSignals: true
        function onDatabaseRestored() {
            // 整库被换掉 → 设置读缓存指向的是旧库的值，先作废（管理器之间不直连，
            // 由 QML 转接，见 rules/04 §6）。用户若不立刻重启，读到的仍是新库。
            if (settingsRepository && settingsRepository.invalidateCache)
                settingsRepository.invalidateCache()
            root.askConfirm("Restore Complete",
                "The database has been restored. TimeArc must restart to load the new data. Quit now?",
                "Quit Now", false, function () { Qt.quit() })
        }
    }

    Keys.onEscapePressed: {
        // Esc 先收起打开的弹层（许可全文 / 二次确认），都没开才返回首页。
        if (licenseViewer.shown) licenseViewer.shown = false
        else if (root.appPickerOpen) root.appPickerOpen = false
        else if (confirmCard.shown) confirmCard.shown = false
        else root.requestNavigate("memorylake")
    }
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
                        text: root.tr("CONTROL CENTER")
                        color: ml.aqua
                        font.pixelSize: 11; font.weight: 800; font.letterSpacing: 0.7
                        font.capitalization: Font.AllUppercase
                    }
                    Text { text: root.tr("Settings"); color: ml.textPrimary; font.pixelSize: 22; font.weight: 800; font.letterSpacing: 0 }
                    Text {
                        Layout.fillWidth: true
                        text: root.tr("Manage TimeArc tracking, privacy, memo, and visual experience.")
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
                        text: root.tr("Data note: settings are stored in local SQLite; usage data comes from local system records and stays offline.")
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
                                    text: root.tr(modelData.label)
                                    color: root.currentTab === modelData.key ? ml.textPrimary : ml.textSecondary
                                    font.pixelSize: 13
                                    font.weight: root.currentTab === modelData.key ? Font.DemiBold : Font.Normal
                                    width: 150
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Cursor.button()
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
                                    Text { text: root.tr(modelData.t); color: ml.textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.tr(modelData.d); color: ml.textTertiary; font.pixelSize: 11
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
                            Text { text: root.tr("Local data protected"); color: ml.textSecondary; font.pixelSize: 11; font.weight: Font.DemiBold }
                            Text { text: root.tr("Offline · No sign-in"); color: ml.textTertiary; font.pixelSize: 10 }
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
                            text: root.tr(root.topCopy[root.currentTab].t)
                            color: ml.textPrimary; font.pixelSize: 22; font.weight: 800; font.letterSpacing: 0
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.tr(root.topCopy[root.currentTab].d)
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
                                    cursorShape: Cursor.button()
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
                        placeholderText: root.tr("Search settings...")
                        onTextEdited: function (t) { root.searchQuery = t }
                    }

                    GhostBtn { Layout.alignment: Qt.AlignVCenter; label: "Back Home"; primary: true; onTapped: root.requestNavigate("memorylake") }
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

                    // 6 个分区（互斥 visible + 入场动画）
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
                            case "about":    return aboutSec.implicitHeight
                            }
                            return 0
                        }

                        // ===== general 通用 =====
                        SectionGrid {
                            id: generalSec
                            tabKey: "general"

                            SettingsCard {
                                badge: "✦"; wide: true
                                cardTitle: "Appearance"
                                cardDesc: "Keep the dark frosted style and adjust accent color or blur."
                                keywords: "appearance theme transparency blur accent color"

                                // 强调色
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { text: root.tr("Accent Color"); color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
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
                                                    cursorShape: Cursor.button()
                                                    onClicked: {
                                                        root.accentColor = modelData.value
                                                        root._setStr("accent_color", modelData.value)
                                                        root.accentChanged(modelData.value)
                                                        root.showToast(root.tr("Accent color updated"))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        text: root.tr("The accent color now applies to highlights, navigation, heatmaps and card glows.")
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
                                        Text { text: root.tr("Day Mode Palette"); color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.tr("Switch to a daytime frosted palette: bright background, dark text, and low-saturation blue-violet glow.")
                                            color: ml.textTertiary; font.pixelSize: 11; wrapMode: Text.WordWrap
                                        }
                                    }
                                    ThemeSwitch {}
                                }

                                ThinRule {}

                                SettingRow {
                                    rowTitle: "Restore last window position"
                                    rowSub: "Remember the window and sidebar state when opening the app."
                                    GlassSwitch {
                                        style: ml; checked: root.restoreWindow
                                        onToggled: function (c) { root.restoreWindow = c; root._setBool("restore_window", c); root.showToast(root.onOff(c)) }
                                    }
                                }

                                SettingRow {
                                    rowTitle: "Background blur strength"
                                    rowSub: "Save as a visual intensity preference."
                                    GlassSlider {
                                        style: ml; from: 8; to: 36; value: root.blurStrength; stepSize: 1
                                        implicitWidth: 160
                                        onMoved: function (v) { root.blurStrength = v; root._setStr("blur_strength", "" + Math.round(v)); root.showToast("Blur strength saved") }
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "⌂"
                                cardTitle: "Home Behavior"
                                cardDesc: "Choose the default page after launch."
                                keywords: "home dashboard default page welcome"

                                SettingRow {
                                    rowTitle: "Default Page"
                                    rowSub: "Choose which page appears after launch."
                                    GlassComboBox {
                                        style: ml
                                        model: [root.tr("Home Dashboard"), root.tr("Memo"), root.tr("Memory Recap")]
                                        property var _vals: ["memorylake", "memo", "recap"]
                                        currentIndex: Math.max(0, _vals.indexOf(root.landingPage))
                                        onActivated: function (i) { root.landingPage = _vals[i]; root._setStr("landing_page", _vals[i]); root.showToast(root.tr("Default page saved")) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "Show welcome animation"
                                    rowSub: "Briefly show the TimeArc startup animation."
                                    GlassSwitch {
                                        style: ml; checked: root.showWelcome
                                        onToggled: function (c) { root.showWelcome = c; root._setBool("show_welcome", c); root.showToast(root.onOff(c)) }
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "Aa"
                                cardTitle: "Language & Time"
                                cardDesc: "Control interface language and time display."
                                keywords: "language time format units"

                                SettingRow {
                                    rowTitle: "Interface Language"
                                    rowSub: "Updates global UI copy, app names, and main tips immediately."
                                    GlassComboBox {
                                        style: ml
                                        // Language names stay in their own script: someone who cannot read the
                                        // current UI language still has to be able to find theirs.
                                        model: ["简体中文", "English", "日本語"]
                                        property var _vals: ["zh", "en", "ja"]
                                        currentIndex: Math.max(0, _vals.indexOf(root.languageMode))
                                        onActivated: function (i) {
                                            root.languageMode = _vals[i];
                                            root._setStr("language_mode", _vals[i]);
                                            root.languageChanged(_vals[i]);
                                            root.showToast(root.tr("Interface language saved"));
                                        }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "Time Format"
                                    rowSub: "Affects time charts and statistics."
                                    GlassComboBox {
                                        style: ml
                                        model: [root.tr("24-hour"), root.tr("12-hour")]
                                        property var _vals: ["24", "12"]
                                        currentIndex: Math.max(0, _vals.indexOf(root.timeFormat))
                                        onActivated: function (i) { root.timeFormat = _vals[i]; root._setStr("time_format", _vals[i]); root.showToast(root.tr("Time format saved")) }
                                    }
                                }
                            }
                        }

                        // ===== tracking 追踪与应用 =====
                        SectionGrid {
                            id: trackingSec
                            tabKey: "tracking"

                            SettingsCard {
                                badge: "◉"; wide: true
                                cardTitle: "Tracking Scope"
                                cardDesc: "Choose which apps appear on Home, charts, and monthly recaps."
                                keywords: "tracking apps games usage time idle"

                                SettingRow {
                                    rowTitle: "Track running apps"
                                    rowSub: "Records window names, app names, and duration. Turning this off stops background collection without deleting history."
                                    GlassSwitch {
                                        style: ml; checked: root.trackRunning
                                        onToggled: function (c) {
                                            root.trackRunning = c; root._setBool("track_running", c); root.pushReadFilters()
                                            root.showToast(!root._writeServiceConfig()
                                                ? "Saved on this device, but the service config could not be written (service_config.json is unwritable or corrupt)"
                                                : (c ? "Tracking on (takes effect once tracking is applied and restarted)" : "Tracking off (the service stops recording once applied and restarted)"))
                                        }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "Start TimeArc at login"
                                    rowSub: "Starts into the tray after you reach the desktop and keeps tracking. Turning this off only stops auto-start; it deletes no history."
                                    GlassSwitch {
                                        style: ml; checked: root.autostartEnabled
                                        onToggled: function (c) {
                                            if (!settingsRepository) return
                                            var ok = settingsRepository.setAutostartEnabled(c)
                                            root.autostartEnabled = settingsRepository.autostartEnabled()
                                            if (!ok || root.autostartEnabled !== c)
                                                root.showToast("Could not set start-at-login. Check this user's startup-item permissions.")
                                            else
                                                root.showToast(root.autostartEnabled ? "Start-at-login is on (launches to the tray and tracks in the background)" : "Start-at-login is off")
                                        }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "Game Mode Detection"
                                    rowSub: "Classify Steam, Epic, and standalone games as games."
                                    GlassSwitch {
                                        style: ml; checked: root.gameMode
                                        onToggled: function (c) { root.gameMode = c; root._setBool("game_mode", c); root.pushReadFilters(); root.showToast(root.onOff(c)) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "Idle After"
                                    rowSub: "Pause the current foreground timer after this many seconds without keyboard or mouse input. Any integer from 0 to 86400; 0 never treats you as idle. Takes effect after restarting collection."
                                    RowLayout {
                                        spacing: 8
                                        GlassTextField {
                                            id: idleField
                                            style: ml
                                            implicitWidth: 96
                                            // 输入层只放整数；越界值在提交时收敛到量程内。
                                            validator: IntValidator { bottom: root.idleTimeoutSecMin; top: root.idleTimeoutSecMax }
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            text: String(root.idleTimeoutSec)
                                            // 失焦或回车提交：回填收敛后的值，避免输入框与实际写入的值不一致。
                                            function commit() {
                                                var ok = root._commitIdleTimeout(text)
                                                text = String(root.idleTimeoutSec)
                                                root.showToast(ok ? "Idle timeout saved (takes effect once tracking is applied and restarted)"
                                                                  : "Saved on this device, but the service config could not be written (service_config.json is unwritable or corrupt)")
                                            }
                                            onEditingFinished: commit()
                                            onAccepted: commit()
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: root.idleTimeoutSec === 0
                                                  ? root.tr("sec (idle detection off)")
                                                  : root.tr("sec")
                                            color: ml.textTertiary; font.pixelSize: 11
                                        }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "Apply Now"
                                    rowSub: "Write idle timeout and tracking switch to the service and restart collection now."
                                    GhostBtn {
                                        label: "Apply & Restart"; primary: true
                                        // macOS 需先开「开机自启」，让 launchd 监督重启；
                                        // Windows 可随时幂等拉起当前用户会话的 collector，
                                        // 登录自启是另一项选择，不应阻止设置立即生效。
                                        enabled: !!(settingsRepository && settingsRepository.autostartSupported
                                                    && settingsRepository.autostartSupported())
                                                 && (Qt.platform.os === "windows" || root.autostartEnabled)
                                        opacity: enabled ? 1 : 0.45
                                        onTapped: root.applyAndRestartCollection()
                                    }
                                }
                            }

                            // 应用管理（#1 重设计）：整宽卡 + 搜索 + 2 列紧凑芯片 + 计数 + 软折叠，
                            // 取代原先单列长清单（解决右栏被几十个应用撑高、栅格失衡）。
                            SettingsCard {
                                badge: "▥"; wide: true
                                cardTitle: "App Management"
                                cardDesc: "Control whether each app appears in Home, Stats, and Recap. Hiding does not delete history."
                                keywords: "app list exclude merge show hide hidden search"

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
                                            placeholderText: root.tr("Search apps...")
                                            onTextEdited: function (t) { root.appSearchQuery = t }
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: root.appSearchQuery.length > 0
                                                  ? root.sentence("searchAppsCount", {shown: root.filteredApps.length, total: root.appList.length})
                                                  : root.sentence("showAppsCount", {shown: root.filteredApps.length, total: root.appList.length})
                                            color: ml.textTertiary; font.pixelSize: 11
                                        }
                                    }

                                    PlaceholderNote {
                                        visible: root.appList.length === 0
                                        text: root.tr("No collected app records yet.")
                                    }
                                    PlaceholderNote {
                                        visible: root.appList.length > 0 && root.shownApps.length === 0
                                        text: root.sentence("noMatchingApps", {query: root.appSearchQuery})
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
                                                readonly property var appRow: modelData
                                                readonly property string appIconSource: AppVisual.modelIconSource(modelData)
                                                readonly property string rawAppKey: modelData.originalGroupKey || modelData.groupKey || ""
                                                readonly property bool editing: root.editingAppKey === rawAppKey
                                                readonly property string appCategory: AppVisual.modelCategory(modelData) || "other"
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: editing ? (52 + editPanel.implicitHeight + 10) : 52
                                                radius: 8
                                                color: ml.calSunkBg
                                                border.width: 1; border.color: ml.cellHair

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    spacing: 8

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 10
                                                        Rectangle {
                                                            width: 30; height: 30; radius: 9
                                                            Layout.alignment: Qt.AlignVCenter
                                                            color: ml.calGhostBg
                                                            clip: true
                                                            Image {
                                                                id: appIconImage
                                                                anchors.fill: parent
                                                                anchors.margins: 5
                                                                visible: appIconSource.length > 0 && status === Image.Ready
                                                                source: appIconSource
                                                                fillMode: Image.PreserveAspectFit
                                                                asynchronous: true
                                                                cache: true
                                                            }
                                                            Text {
                                                                anchors.centerIn: parent
                                                                visible: appIconSource.length === 0 || appIconImage.status !== Image.Ready
                                                                text: AppVisual.modelIconLabel(modelData)
                                                                color: ml.aqua; font.pixelSize: 14; font.weight: Font.DemiBold
                                                            }
                                                        }
                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: AppVisual.modelDisplayNameForLanguage(modelData, root.languageMode)
                                                            color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold
                                                            elide: Text.ElideRight
                                                        }
                                                        Rectangle {
                                                            Layout.alignment: Qt.AlignVCenter
                                                            height: 22; width: rowCatText.implicitWidth + 24; radius: 11
                                                            color: ml.calGhostBg
                                                            Row {
                                                                anchors.centerIn: parent
                                                                spacing: 6
                                                                Rectangle {
                                                                    width: 7; height: 7; radius: 4
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    color: root.categoryColorOf(appCategory)
                                                                }
                                                                Text {
                                                                    id: rowCatText
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    text: root.categoryLabelOf(appCategory)
                                                                    color: ml.textSecondary; font.pixelSize: 11
                                                                }
                                                            }
                                                        }
                                                        GhostBtn {
                                                            label: editing ? "Done" : "Edit"
                                                            onTapped: {
                                                                if (editing) {
                                                                    root.editingAppKey = ""
                                                                    root.appDisplayNameError = ""
                                                                } else {
                                                                    root.beginEditAppDisplayName(modelData)
                                                                    root.titleRuleAppKey = ""
                                                                }
                                                            }
                                                        }
                                                        GlassSwitch {
                                                            style: ml
                                                            Layout.alignment: Qt.AlignVCenter
                                                            checked: !root.isAppHidden(modelData.groupKey)
                                                            onToggled: function (c) {
                                                                root.setAppHidden(modelData.groupKey, !c)
                                                                root.showToast(c ? "App shown" : "App hidden")
                                                            }
                                                        }
                                                    }

                                                    // 一个编辑面板同时管名称、类别和这个应用的标题规则。
                                                    ColumnLayout {
                                                        id: editPanel
                                                        visible: editing
                                                        Layout.fillWidth: true
                                                        spacing: 8

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: root.tr("Original ID") + "  " + rawAppKey
                                                            color: ml.textTertiary; font.pixelSize: 10
                                                            elide: Text.ElideMiddle
                                                        }
                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: root.tr("Rule") + "  " + root.appRuleLabel(appRow)
                                                            color: ml.textTertiary; font.pixelSize: 10
                                                            elide: Text.ElideRight
                                                        }

                                                        Text { text: root.tr("Name"); color: ml.textTertiary; font.pixelSize: 11 }
                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 7
                                                            GlassTextField {
                                                                Layout.fillWidth: true
                                                                style: ml
                                                                placeholderText: root.tr("Custom display name")
                                                                text: editing ? root.appDisplayNameDraft : ""
                                                                onTextEdited: function (t) {
                                                                    root.appDisplayNameDraft = t
                                                                    root.appDisplayNameError = ""
                                                                }
                                                            }
                                                            GhostBtn {
                                                                label: "Save"
                                                                primary: true
                                                                onTapped: root.saveAppDisplayName(rawAppKey, root.appDisplayNameDraft)
                                                            }
                                                            GhostBtn {
                                                                visible: (modelData.customDisplayName || "").length > 0
                                                                label: "Reset name"
                                                                onTapped: root.restoreAppDisplayName(rawAppKey)
                                                            }
                                                        }
                                                        Text {
                                                            visible: root.appDisplayNameError.length > 0
                                                            Layout.fillWidth: true
                                                            text: root.appDisplayNameError
                                                            color: ml.dangerText; font.pixelSize: 10
                                                            wrapMode: Text.Wrap
                                                        }

                                                        Text { text: root.tr("Category"); color: ml.textTertiary; font.pixelSize: 11 }
                                                        Flow {
                                                            Layout.fillWidth: true
                                                            spacing: 6
                                                            Repeater {
                                                                model: root.categoryList
                                                                delegate: Rectangle {
                                                                    required property var modelData
                                                                    readonly property bool active: modelData.id === appCategory
                                                                    height: 26
                                                                    width: catChipText.implicitWidth + 30
                                                                    radius: 13
                                                                    color: active ? ml.accentSoft : ml.calGhostBg
                                                                    border.width: 1
                                                                    border.color: active ? ml.aqua : ml.cellHair
                                                                    Row {
                                                                        anchors.centerIn: parent
                                                                        spacing: 6
                                                                        Rectangle {
                                                                            width: 7; height: 7; radius: 4
                                                                            anchors.verticalCenter: parent.verticalCenter
                                                                            color: root.categoryColorOf(modelData.id)
                                                                        }
                                                                        Text {
                                                                            id: catChipText
                                                                            anchors.verticalCenter: parent.verticalCenter
                                                                            text: modelData.label
                                                                            color: ml.textSecondary; font.pixelSize: 11
                                                                        }
                                                                    }
                                                                    MouseArea {
                                                                        anchors.fill: parent
                                                                        cursorShape: Cursor.button()
                                                                        onClicked: root.assignAppCategory(appRow, modelData.id)
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        // 标题规则：同一个应用里的不同内容分到不同类别（浏览器里的 YouTube 等）。
                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 8
                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: root.tr("Window title rules")
                                                                color: ml.textTertiary; font.pixelSize: 11
                                                            }
                                                            GhostBtn {
                                                                label: "New title rule"
                                                                onTapped: root.beginTitleRule(rawAppKey, appCategory)
                                                            }
                                                        }
                                                        Text {
                                                            Layout.fillWidth: true
                                                            visible: root.titleRulesFor(appRow).length === 0 && root.titleRuleAppKey !== rawAppKey
                                                            text: root.tr("Title rules split one app into different categories by what is on screen.")
                                                            color: ml.textTertiary; font.pixelSize: 10
                                                            wrapMode: Text.Wrap
                                                        }
                                                        Repeater {
                                                            model: root.titleRulesFor(appRow)
                                                            delegate: Rectangle {
                                                                required property var modelData
                                                                Layout.fillWidth: true
                                                                Layout.preferredHeight: 40
                                                                radius: 8
                                                                color: ml.calGhostBg
                                                                opacity: modelData.enabled ? 1 : 0.5
                                                                RowLayout {
                                                                    anchors.fill: parent
                                                                    anchors.margins: 9
                                                                    spacing: 8
                                                                    Rectangle {
                                                                        width: 7; height: 7; radius: 4
                                                                        Layout.alignment: Qt.AlignVCenter
                                                                        color: root.categoryColorOf(modelData.category)
                                                                    }
                                                                    ColumnLayout {
                                                                        Layout.fillWidth: true
                                                                        spacing: 0
                                                                        Text {
                                                                            Layout.fillWidth: true
                                                                            text: modelData.label
                                                                            color: ml.textPrimary; font.pixelSize: 11
                                                                            elide: Text.ElideRight
                                                                        }
                                                                        Text {
                                                                            Layout.fillWidth: true
                                                                            text: root.tr("Title contains") + " " + (modelData.title || []).join(", ")
                                                                            color: ml.textTertiary; font.pixelSize: 10
                                                                            elide: Text.ElideRight
                                                                        }
                                                                    }
                                                                    Text {
                                                                        text: root.categoryLabelOf(modelData.category)
                                                                        color: ml.textSecondary; font.pixelSize: 11
                                                                    }
                                                                    IconBtn {
                                                                        glyph: "\u2715"
                                                                        hint: "Delete rule"
                                                                        danger: true
                                                                        Layout.alignment: Qt.AlignVCenter
                                                                        onTapped: root.askDeleteRule(modelData.id, modelData.label)
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        ColumnLayout {
                                                            visible: root.titleRuleAppKey === rawAppKey
                                                            Layout.fillWidth: true
                                                            spacing: 6
                                                            GlassTextField {
                                                                Layout.fillWidth: true; style: ml
                                                                placeholderText: root.tr("Rule name")
                                                                // text 是内部 TextInput 的 alias：用户一敲键盘绑定就没了，
                                                                // 所以打开表单时显式回填，不靠绑定。
                                                                onVisibleChanged: if (visible) text = (root.titleRuleDraft.name || "")
                                                                onTextEdited: function (t) { root.titleRuleDraft = root.withField(root.titleRuleDraft, "name", t) }
                                                            }
                                                            GlassTextField {
                                                                Layout.fillWidth: true; style: ml
                                                                placeholderText: root.tr("Title contains, comma separated")
                                                                onVisibleChanged: if (visible) text = (root.titleRuleDraft.titles || "")
                                                                onTextEdited: function (t) { root.titleRuleDraft = root.withField(root.titleRuleDraft, "titles", t) }
                                                            }
                                                            Flow {
                                                                Layout.fillWidth: true
                                                                spacing: 6
                                                                Repeater {
                                                                    model: root.categoryList
                                                                    delegate: Rectangle {
                                                                        required property var modelData
                                                                        readonly property bool picked: root.titleRuleDraft.category === modelData.id
                                                                        height: 24; width: trChip.implicitWidth + 24; radius: 12
                                                                        color: picked ? ml.accentSoft : ml.calGhostBg
                                                                        border.width: 1; border.color: picked ? ml.aqua : ml.cellHair
                                                                        Text {
                                                                            id: trChip
                                                                            anchors.centerIn: parent
                                                                            text: modelData.label
                                                                            color: ml.textSecondary; font.pixelSize: 11
                                                                        }
                                                                        MouseArea {
                                                                            anchors.fill: parent
                                                                            cursorShape: Cursor.button()
                                                                            onClicked: root.titleRuleDraft = root.withField(root.titleRuleDraft, "category", modelData.id)
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                            RowLayout {
                                                                Layout.fillWidth: true
                                                                spacing: 8
                                                                Item { Layout.fillWidth: true }
                                                                GhostBtn { label: "Cancel"; onTapped: root.titleRuleAppKey = "" }
                                                                GhostBtn {
                                                                    label: "Save"; primary: true
                                                                    onTapped: root.saveTitleRule(appRow)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    GhostBtn {
                                        visible: root.appSearchQuery.length === 0 && root.filteredApps.length > root.appCap
                                        label: root.appsExpanded ? "Collapse" : root.sentence("showAllApps", {count: root.filteredApps.length})
                                        onTapped: root.appsExpanded = !root.appsExpanded
                                    }
                                }
                            }

                            // 规则表：按类别分组，因为用户真正想问的是「我的 Focus 里都算了什么」。
                            // 一条规则 = 名称 + 一个应用 + 若干标题匹配 + 一个类别。导入/导出不在这里。
                            SettingsCard {
                                badge: "▤"; wide: true
                                cardTitle: "Category Rules"
                                cardDesc: "Edit, disable or create rules and categories. Categories are computed on read, so changes apply to all history at once."
                                keywords: "rules classification category rule reset defaults"

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Rectangle {
                                        Layout.fillWidth: true
                                        visible: root.rulesLoadError.length > 0
                                        Layout.preferredHeight: 40
                                        radius: 8
                                        color: ml.calSunkBg
                                        border.width: 1; border.color: ml.cellHair
                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: 10; spacing: 8
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.tr("Could not read your rules; the default rules are in use.")
                                                color: ml.textSecondary; font.pixelSize: 11; elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.rulesCustomized
                                                  ? root.tr("Customized")
                                                  : root.tr("Built from your recorded apps")
                                            color: ml.textTertiary; font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                        GhostBtn { label: "New category"; onTapped: root.beginNewCategory() }
                                        GhostBtn { label: "New rule"; onTapped: root.beginNewRule() }
                                        GhostBtn {
                                            // 永远在：规则表始终是按采集数据推导出来的，
                                            // 没有「还没自定义所以没得恢复」这种状态。
                                            label: "Reset to defaults"
                                            danger: true
                                            onTapped: root.askRestoreDefaultRules()
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: root.newDefaultsCount > 0
                                        spacing: 8
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.sentence("newDefaultRules", {count: root.newDefaultsCount})
                                            color: ml.textSecondary; font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                        GhostBtn {
                                            label: "Merge in"
                                            onTapped: {
                                                if (categorizationManager.adoptNewDefaults([])) {
                                                    root.refreshAppList()
                                                    root.showToast(root.tr("New default rules merged in"))
                                                }
                                            }
                                        }
                                    }

                                    // 新建类别
                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: root.newCategoryOpen
                                        spacing: 7
                                        GlassTextField {
                                            Layout.fillWidth: true; style: ml
                                            placeholderText: root.tr("Category name")
                                            text: root.newCategoryName
                                            onTextEdited: function (t) { root.newCategoryName = t }
                                        }
                                        GhostBtn { label: "Cancel"; onTapped: root.newCategoryOpen = false }
                                        GhostBtn { label: "Save"; primary: true; onTapped: root.saveNewCategory() }
                                    }

                                    // 规则编辑器：名称 + 一个应用（从已采集清单里选）+ 若干标题匹配 + 类别。
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        visible: root.newRuleOpen || root.editingRuleId.length > 0
                                        spacing: 6

                                        GlassTextField {
                                            id: ruleNameField
                                            Layout.fillWidth: true; style: ml
                                            placeholderText: root.tr("Rule name")
                                            onTextEdited: function (t) { root.ruleDraft = root.withField(root.ruleDraft, "name", t) }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text {
                                                text: root.tr("App")
                                                color: ml.textTertiary; font.pixelSize: 11
                                            }
                                            // 选应用走浮层菜单：设置页是滚动容器，内联展开会被裁切也难点中。
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 34
                                                radius: 11
                                                color: appTriggerMa.containsMouse ? ml.calGhostHover : ml.calGhostBg
                                                border.width: 1
                                                border.color: (root.ruleDraft.appLabel && root.ruleDraft.appLabel.length > 0)
                                                              ? ml.cellHair : ml.accentSoftBorder
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 10
                                                    spacing: 8
                                                    Rectangle {
                                                        width: 20; height: 20; radius: 6
                                                        Layout.alignment: Qt.AlignVCenter
                                                        visible: !!(root.ruleDraft.appIcon && root.ruleDraft.appIcon.length > 0)
                                                        color: ml.calSunkBg
                                                        clip: true
                                                        Image {
                                                            anchors.fill: parent
                                                            anchors.margins: 3
                                                            source: root.ruleDraft.appIcon ? root.ruleDraft.appIcon : ""
                                                            fillMode: Image.PreserveAspectFit
                                                            asynchronous: true
                                                        }
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: (root.ruleDraft.appLabel && root.ruleDraft.appLabel.length > 0)
                                                              ? root.ruleDraft.appLabel : root.tr("Choose app")
                                                        color: (root.ruleDraft.appLabel && root.ruleDraft.appLabel.length > 0)
                                                               ? ml.textPrimary : ml.textTertiary
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                    }
                                                    Text { text: "\u25BE"; color: ml.calGlyph; font.pixelSize: 11 }
                                                }
                                                MouseArea {
                                                    id: appTriggerMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Cursor.button()
                                                    onClicked: { root.appPickerQuery = ""; root.appPickerOpen = true }
                                                }
                                            }
                                        }
                                        GlassTextField {
                                            id: ruleTitleField
                                            Layout.fillWidth: true; style: ml
                                            placeholderText: root.tr("Title contains, comma separated")
                                            onTextEdited: function (t) { root.ruleDraft = root.withField(root.ruleDraft, "title", t) }
                                        }

                                        Flow {
                                            Layout.fillWidth: true; spacing: 6
                                            Repeater {
                                                model: root.categoryList
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    readonly property bool picked: root.ruleDraft.category === modelData.id
                                                    height: 26; width: draftChip.implicitWidth + 30; radius: 13
                                                    color: picked ? ml.accentSoft : ml.calGhostBg
                                                    border.width: 1; border.color: picked ? ml.aqua : ml.cellHair
                                                    Row {
                                                        anchors.centerIn: parent
                                                        spacing: 6
                                                        Rectangle {
                                                            width: 7; height: 7; radius: 4
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            color: root.categoryColorOf(modelData.id)
                                                        }
                                                        Text {
                                                            id: draftChip
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: modelData.label
                                                            color: ml.textSecondary; font.pixelSize: 11
                                                        }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Cursor.button()
                                                        onClicked: root.ruleDraft = root.withField(root.ruleDraft, "category", modelData.id)
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: root.ruleDraftError.length > 0
                                            text: root.ruleDraftError
                                            color: ml.dangerText; font.pixelSize: 10; wrapMode: Text.WordWrap
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: 8
                                            Item { Layout.fillWidth: true }
                                            GhostBtn {
                                                label: "Cancel"
                                                onTapped: { root.newRuleOpen = false; root.editingRuleId = ""; root.ruleDraftError = ""; root.appPickerOpen = false }
                                            }
                                            GhostBtn {
                                                label: "Save"; primary: true
                                                enabled: root.ruleDraftValid
                                                opacity: enabled ? 1 : 0.45
                                                onTapped: root.saveRuleDraft()
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: root.ruleGroups
                                        delegate: ColumnLayout {
                                            required property var modelData
                                            readonly property bool open: root.expandedRuleCategory === modelData.id
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 40
                                                radius: 8
                                                color: ml.calGhostBg
                                                RowLayout {
                                                    anchors.fill: parent; anchors.margins: 9; spacing: 8
                                                    // 专门的展开钮：不再用一块盖住整行的 MouseArea，否则右侧按钮点不动。
                                                    Rectangle {
                                                        width: 22; height: 22; radius: 8
                                                        Layout.alignment: Qt.AlignVCenter
                                                        color: chevronMa.containsMouse ? ml.calGhostHover : "transparent"
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: open ? "\u25BE" : "\u25B8"
                                                            color: ml.calGlyph; font.pixelSize: 11
                                                        }
                                                        MouseArea {
                                                            id: chevronMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Cursor.button()
                                                            onClicked: root.expandedRuleCategory = open ? "" : modelData.id
                                                        }
                                                    }
                                                    Rectangle {
                                                        width: 9; height: 9; radius: 5
                                                        Layout.alignment: Qt.AlignVCenter
                                                        color: root.categoryColorOf(modelData.id)
                                                    }
                                                    Text {
                                                        text: modelData.label
                                                        color: ml.textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: root.sentence("ruleCount", {count: modelData.ruleCount})
                                                        color: ml.textTertiary; font.pixelSize: 10
                                                        elide: Text.ElideRight
                                                    }
                                                    IconBtn {
                                                        glyph: "\u2715"
                                                        hint: "Delete category"
                                                        danger: true
                                                        Layout.alignment: Qt.AlignVCenter
                                                        visible: modelData.id !== "other"
                                                        onTapped: root.askDeleteCategory(modelData.id, modelData.label, modelData.ruleCount)
                                                    }
                                                    GlassSwitch {
                                                        style: ml
                                                        Layout.alignment: Qt.AlignVCenter
                                                        checked: modelData.enabled
                                                        onToggled: function (c) {
                                                            categorizationManager.setCategoryEnabled(modelData.id, c)
                                                            root.refreshAppList()
                                                        }
                                                    }
                                                }
                                            }

                                            Repeater {
                                                model: open ? modelData.rules : []
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    Layout.leftMargin: 16
                                                    Layout.preferredHeight: 46
                                                    radius: 8
                                                    color: ml.calSunkBg
                                                    border.width: 1; border.color: ml.cellHair
                                                    opacity: modelData.enabled ? 1 : 0.45
                                                    RowLayout {
                                                        anchors.fill: parent; anchors.margins: 9; spacing: 8
                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 1
                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: modelData.label
                                                                color: ml.textPrimary; font.pixelSize: 12
                                                                elide: Text.ElideRight
                                                            }
                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: modelData.summary
                                                                color: ml.textTertiary; font.pixelSize: 10
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                        IconBtn {
                                                            glyph: "\u270E"
                                                            hint: "Edit rule"
                                                            Layout.alignment: Qt.AlignVCenter
                                                            onTapped: root.beginEditRule(modelData)
                                                        }
                                                        IconBtn {
                                                            glyph: "\u2715"
                                                            hint: "Delete rule"
                                                            danger: true
                                                            Layout.alignment: Qt.AlignVCenter
                                                            onTapped: root.askDeleteRule(modelData.id, modelData.label)
                                                        }
                                                        GlassSwitch {
                                                            style: ml
                                                            Layout.alignment: Qt.AlignVCenter
                                                            checked: modelData.enabled
                                                            onToggled: function (c) {
                                                                categorizationManager.setRuleEnabled(modelData.id, c)
                                                                root.refreshAppList()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
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
                                cardTitle: "Privacy Protection"
                                cardDesc: "TimeArc records stay local by default. You can hide sensitive apps and window titles."
                                keywords: "privacy local data encryption anonymous"

                                SettingRow {
                                    rowTitle: "Local only"
                                    rowSub: "Do not upload usage records; keep them on this device."
                                    GlassSwitch {
                                        style: ml; checked: root.privacyLocalOnly
                                        onToggled: function (c) { root.privacyLocalOnly = c; root._setBool("privacy_local_only", c); root.showToast(root.onOff(c)) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "Hide sensitive window titles"
                                    rowSub: "Replace document names, chat names, and page titles with categories at output time."
                                    GlassSwitch {
                                        style: ml; checked: root.hideTitles
                                        onToggled: function (c) { root.hideTitles = c; root._setBool("hide_titles", c); root.pushReadFilters(); root.showToast(root.onOff(c)) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "Anonymize share images"
                                    rowSub: "Preference saved. Anonymous share rendering will use categories instead of app names."
                                    GlassSwitch {
                                        style: ml; checked: root.anonymizeExport
                                        onToggled: function (c) { root.anonymizeExport = c; root._setBool("anonymize_export", c); root.showToast(root.onOff(c)) }
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "▣"
                                cardTitle: "Storage"
                                cardDesc: "Current cache and history usage, measured locally."
                                keywords: "storage cleanup retention cache records"

                                // 存储条（本地占用相对 100MB 软参考；标签显示真实大小，非硬配额）
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 12
                                    radius: 6
                                    color: ml.trackBg
                                    Rectangle {
                                        height: parent.height
                                        radius: parent.radius
                                        width: parent.width * Math.max(0.02, Math.min(1, (root.historyBytes + root.cacheBytes) / (100 * 1024 * 1024)))
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: ml.aqua }
                                            GradientStop { position: 1; color: ml.violet }
                                        }
                                    }
                                }
                                Text {
                                    text: root.sentence("localUsageSize", {size: root.bytesText(root.historyBytes + root.cacheBytes)})
                                    color: ml.textTertiary; font.pixelSize: 10
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 10
                                    MetricTile { tileLabel: "Cache"; tileValue: root.bytesText(root.cacheBytes) }
                                    MetricTile { tileLabel: "History store"; tileValue: root.bytesText(root.historyBytes) }
                                    MetricTile { tileLabel: "Records"; tileValue: root.usageRecordCount > 0 ? ("" + root.usageRecordCount) : "0" }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    GhostBtn {
                                        label: "Clear Cache"
                                        onTapped: root.askConfirm("Clear Cache",
                                            "Clears the UI's own derived cache (window position and similar). Usage history, preferences, and memo content are not affected.",
                                            "Clear", false, function () { root.clearUiCache() })
                                    }
                                    GhostBtn {
                                        label: "Delete History"; danger: true
                                        onTapped: root.askConfirm("Delete Usage History",
                                            "Usage history is append-only (disk contract D1), so TimeArc does not delete it in-app. To clear it, stop the background service and use the migration tool.",
                                            "Got It", false, null)
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "✓"
                                cardTitle: "Permission Status"
                                cardDesc: "Shows the system permissions a real app may need."
                                keywords: "permissions start-at-login notifications"

                                SettingRow {
                                    rowTitle: "App Usage Permission"
                                    rowSub: "Windows foreground collection needs no extra permission."
                                    Rectangle {
                                        radius: 11
                                        implicitWidth: permT.implicitWidth + 22; implicitHeight: 26
                                        color: ml.accentSoft; border.width: 1; border.color: ml.accentSoftBorder
                                        Text { id: permT; anchors.centerIn: parent; text: root.tr("Ready"); color: ml.aqua; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "System Notifications"
                                    rowSub: "Send system notifications when Pomodoro completes in the background."
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
                                cardTitle: "Memo Defaults"
                                cardDesc: "Control notes, ink, pages, and shortcuts."
                                keywords: "memo sticky note brush page author"

                                // 「按 N 打开备忘录」开关（memo_hotkey_n）已移除：它原本是裸字母抢打字的
                                // 逃生口，而键位如今可带修饰键、macOS 出厂即 ⇧⌘N，已无需要逃的东西。
                                // 何况 macOS 的菜单行 显示 › 备忘黑板 同样绑 ⇧⌘N 且不受该偏好管，关掉开关
                                // 快捷键照样生效——一个说了不算的开关比没有更糟。键位本身仍可在下面改。
                                SettingRow {
                                    rowTitle: "Auto-save ink and notes"
                                    rowSub: "Each page saves independently."
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
                                cardTitle: "Pomodoro"
                                cardDesc: "Set default Pomodoro duration, title, and completion celebration."
                                keywords: "pomodoro focus time countdown"

                                SettingRow {
                                    rowTitle: "Default focus length"
                                    rowSub: "Initial minutes for new or reset Pomodoro timers."
                                    GlassComboBox {
                                        style: ml
                                        model: [root.tr("15 minutes"), root.tr("25 minutes"), root.tr("30 minutes"), root.tr("45 minutes"), root.tr("60 minutes")]
                                        property var _vals: ["15", "25", "30", "45", "60"]
                                        currentIndex: Math.max(0, _vals.indexOf(root.pomodoroDuration))
                                        onActivated: function (i) { root.pomodoroDuration = _vals[i]; root._setStr("pomodoro_duration", _vals[i]); root.showToast(root.tr("Default focus length saved")) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "Default focus title"
                                    rowSub: "Text shown at the top of the Pomodoro widget."
                                    GlassTextField {
                                        style: ml
                                        implicitWidth: 160
                                        text: root.pomodoroTitle
                                        placeholderText: root.tr("Focus for a while")
                                        onEditingFinished: { root.pomodoroTitle = text; root._setStr("pomodoro_title", text); root.showToast(root.tr("Default title saved")) }
                                    }
                                }
                                SettingRow {
                                    rowTitle: "Completion celebration"
                                    rowSub: "Show a full-screen celebration when Pomodoro completes."
                                    GlassSwitch {
                                        style: ml; checked: root.pomodoroCelebrate
                                        onToggled: function (c) { root.pomodoroCelebrate = c; root._setBool("pomodoro_celebrate", c); root.showToast(root.onOff(c)) }
                                    }
                                }
                            }

                            // 快捷键（#3 自定义）：备忘 / 番茄全局键可点按重设（字母，可带修饰键）；其余为内置只读。
                            SettingsCard {
                                badge: "⌘"
                                cardTitle: "Hotkeys"
                                cardDesc: "Customize the Memo and Pomodoro global hotkeys: click a key cap, then press your combination. Ctrl / Shift / Alt are allowed, and Delete turns the hotkey off. The rest are built in."
                                keywords: "hotkey keyboard shortcut custom memo pomodoro N P modifier combination disable delete"
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Repeater {
                                        model: [
                                            { which: "memo", d: root.tr("Open / close Memo") },
                                            { which: "pomo", d: root.tr("Open / close Pomodoro") }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: parent.width
                                            height: 40
                                            radius: 14
                                            color: ml.calSunkBg
                                            border.width: 1; border.color: ml.cellHair
                                            Row {
                                                id: hotkeyRow
                                                anchors.left: parent.left
                                                anchors.leftMargin: 10
                                                anchors.right: parent.right
                                                anchors.rightMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 10
                                                KeyCaptureChip {
                                                    id: hotkeyChip
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    keyText: root.hotkeyLabel(modelData.which === "memo" ? root.memoHotkeyKey
                                                                                                         : root.pomodoroHotkeyKey)
                                                    // 设置成功就退出捕获态，键帽回到显示新键位；被拒时留着，可直接再按一次。
                                                    onCaptured: function (k) {
                                                        if (root.setHotkey(modelData.which, k))
                                                            hotkeyChip.capturing = false
                                                    }
                                                    // 捕获期间让 Shell（进而 macOS 菜单栏）知道，别把 ⌘ 组合抢在键帽之前。
                                                    onCapturingChanged: root.setCapturing(modelData.which, capturing)
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    // 组合键把键帽撑宽后说明文字要让位，否则会顶出卡片。
                                                    width: Math.max(0, hotkeyRow.width - hotkeyChip.width - hotkeyRow.spacing)
                                                    elide: Text.ElideRight
                                                    text: modelData.d; color: ml.textSecondary; font.pixelSize: 11
                                                }
                                            }
                                        }
                                    }
                                    Repeater {
                                        model: [
                                            { k: "Del", d: root.tr("Delete selected note / object") },
                                            { k: "Esc", d: root.tr("Close recap / settings / clear selection") },
                                            { k: "Wheel", d: root.tr("Switch cards / scroll list") }
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
                                cardTitle: "Settings Migration"
                                cardDesc: "Restore preferences from a settings file, or copy a troubleshooting summary."
                                keywords: "import json backup copy summary"

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    GhostBtn { label: "Import Settings"; primary: true; onTapped: importDialog.open() }
                                    GhostBtn { label: "Copy Config Summary"; onTapped: root.copySummary() }
                                }
                            }

                            SettingsCard {
                                badge: "⇩"; wide: true
                                cardTitle: "Database Backup & Restore"
                                cardDesc: "Export the usage database as a backup file, or restore from one. Stop collection before restoring."
                                keywords: "backup restore database sqlite db full vacuum"

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    GhostBtn { label: "Back Up Database"; primary: true; onTapped: root.doBackupDatabase() }
                                    GhostBtn { label: "Restore Database"; danger: true; onTapped: restoreDialog.open() }
                                }
                            }

                            // D2：服务数据库目录（用户可选目录 + 还原默认）
                            SettingsCard {
                                badge: "⇧"; wide: true
                                cardTitle: "Service Database Folder"
                                cardDesc: "Choose the folder where the background service writes timearc_service.db. TimeArc only updates the location pointer and never moves the database file. Restart collection when you are done."
                                keywords: "database location folder path disk db_dir redirect service"

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
                                        Text { text: root.tr("Current Location"); color: ml.textTertiary; font.pixelSize: 10; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.3 }
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
                                    GhostBtn { label: "Set Folder…"; primary: true; onTapped: dbFolderDialog.open() }
                                    GhostBtn {
                                        label: "Restore Default Location"
                                        opacity: enabled ? 1 : 0.45
                                        enabled: !!(databaseManager && databaseManager.isUsingCustomDatabaseLocation
                                                    && databaseManager.isUsingCustomDatabaseLocation())
                                        onTapped: root.doRestoreDefaultLocation()
                                    }
                                }
                            }

                            SettingsCard {
                                badge: "≈"
                                cardTitle: "Current Data Overview"
                                cardDesc: "Today's usage and local record size."
                                keywords: "status data overview"

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 10
                                    MetricTile { tileLabel: "Today Usage"; tileValue: root.todayUsageText() }
                                    MetricTile { tileLabel: "Switches"; tileValue: root.todaySwitchesText }
                                    MetricTile { tileLabel: "Memo Pages"; tileValue: root.memoPagesText }
                                    MetricTile { tileLabel: "Pomodoro"; tileValue: root.pomodoroTodayText }   // 今日完成数（已接真引擎）
                                }
                            }

                            SettingsCard {
                                badge: "↺"
                                cardTitle: "Restore & Reset"
                                cardDesc: "Quickly restore visual defaults."
                                keywords: "reset restore defaults clear"

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    GhostBtn { label: "Restore Visual Defaults"; onTapped: root.restoreVisualDefaults() }
                                    GhostBtn {
                                        label: "Clear Local Cache"; danger: true
                                        onTapped: root.askConfirm("Clear Local Cache",
                                            "Clears the UI's own derived cache (window position and similar). Usage history, preferences, and memo content are not affected.",
                                            "Clear", true, function () { root.clearUiCache() })
                                    }
                                }
                            }

                        }

                        // ===== about 关于与开源许可 =====
                        SectionGrid {
                            id: aboutSec
                            tabKey: "about"

                            // F2：应用内第三方许可证页面（独立设置分区）。
                            // 满足 rules/06 §4(1) 名称+版本+全文、§4(2) 离线可达、CHARTER I6「reachable from the UI」。
                            // 每个组件都是一个设置卡；TimeArc 的版本与自身许可合并在首卡。
                            Repeater {
                                model: root.licenseComponents
                                delegate: SettingsCard {
                                    id: licenseCard
                                    required property var modelData
                                    readonly property var comp: licenseCard.modelData

                                    badge: comp.badge
                                    wide: true
                                    cardTitle: comp.name
                                    cardDesc: comp.name === "TimeArc"
                                              ? root.sentence("localVersion", {version: root.appVersion})
                                              : "v" + comp.version + " · " + root.tr(comp.linkage)
                                    keywords: "about license open source third party copyright "
                                              + comp.name + " " + comp.license

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.tr(licenseCard.comp.license)
                                        color: ml.textSecondary
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Repeater {
                                            model: licenseCard.comp.texts
                                            delegate: GhostBtn {
                                                required property var modelData
                                                label: root.tr(modelData.btn)
                                                onTapped: root.showLicenseText(
                                                    modelData.file, licenseCard.comp.name,
                                                    root.tr(licenseCard.comp.license))
                                            }
                                        }
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
    // 应用选择菜单：和确认框同级的浮层，不受设置页滚动/裁剪影响。
    Rectangle {
        id: appPickerSheet
        anchors.fill: parent
        z: 340
        color: Qt.rgba(0, 0, 0, 0.42)
        visible: opacity > 0.01
        opacity: root.appPickerOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        MouseArea { anchors.fill: parent; preventStealing: true; onClicked: root.appPickerOpen = false }

        GlassPanel {
            style: ml
            radius: 20
            width: Math.min(420, parent.width - 60)
            height: Math.min(430, parent.height - 100)
            anchors.centerIn: parent
            MouseArea { anchors.fill: parent; preventStealing: true }   // 吞掉点击，别关掉自己

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: root.tr("Choose app")
                        color: ml.textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold
                    }
                    IconBtn {
                        glyph: "\u2715"; hint: "Close"
                        onTapped: root.appPickerOpen = false
                    }
                }

                GlassTextField {
                    Layout.fillWidth: true
                    style: ml
                    search: true
                    placeholderText: root.tr("Search apps...")
                    text: root.appPickerQuery
                    onTextEdited: function (t) { root.appPickerQuery = t }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: root.appPickerResults
                    delegate: Rectangle {
                        required property var modelData
                        readonly property string entryIcon: AppVisual.modelIconSource(modelData)
                        width: ListView.view ? ListView.view.width : 0
                        height: 40
                        radius: 9
                        color: entryMa.containsMouse ? ml.calGhostHover : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 9
                            spacing: 9
                            Rectangle {
                                width: 24; height: 24; radius: 7
                                Layout.alignment: Qt.AlignVCenter
                                color: ml.calGhostBg
                                clip: true
                                Image {
                                    id: entryImage
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    visible: entryIcon.length > 0 && status === Image.Ready
                                    source: entryIcon
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: entryIcon.length === 0 || entryImage.status !== Image.Ready
                                    text: AppVisual.modelIconLabel(modelData)
                                    color: ml.aqua; font.pixelSize: 11; font.weight: Font.DemiBold
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: AppVisual.modelDisplayNameForLanguage(modelData, root.languageMode)
                                color: ml.textPrimary; font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                text: root.categoryLabelOf(AppVisual.modelCategory(modelData) || "other")
                                color: ml.textTertiary; font.pixelSize: 10
                            }
                        }
                        MouseArea {
                            id: entryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Cursor.button()
                            onClicked: root.pickRuleApp(modelData)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.appPickerResults.length === 0
                    text: root.tr("No matching apps.")
                    color: ml.textTertiary; font.pixelSize: 11
                }
            }
        }
    }

    Rectangle {
        id: confirmCard
        property bool shown: false
        property string titleText: ""
        property string msgText: ""
        property string confirmLabel: "Confirm"
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
                // 标题/正文都要过 tr()：按钮走 GhostBtn 内的 tr()，这两行此前直接渲染
                // 中文原文，于是英/日模式下出现「Cancel + 中文标题正文」混排。
                // 正文里的动态串（路径、条数）已在调用点用 sentence() 组好，
                // 再过一次 tr() 只是查不到的空转，不会二次翻译。
                Text {
                    text: root.tr(confirmCard.titleText); color: ml.textPrimary
                    font.pixelSize: 17; font.weight: Font.DemiBold
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }
                Text {
                    text: root.tr(confirmCard.msgText); color: ml.textSecondary
                    font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.Wrap; lineHeight: 1.35
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }
                    GhostBtn { label: "Cancel"; onTapped: confirmCard.shown = false }
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
    // 许可全文弹层（F2）：玻璃卡 + 暗遮罩 + SilkyFlickable 滚动；文本经 readTextFile 读 :/ qrc 内嵌资源（离线）。
    // 模 confirmCard 范式：点遮罩 / 「关闭」收起；卡内 MouseArea 吞点击不冒泡到遮罩。
    // ============================================================
    Rectangle {
        id: licenseViewer
        property bool shown: false
        property string titleText: ""
        property string subText: ""
        property string bodyText: ""
        anchors.fill: parent
        z: 360
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: opacity > 0.01
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea { anchors.fill: parent; preventStealing: true; onClicked: licenseViewer.shown = false }

        GlassPanel {
            style: ml
            strong: true
            radius: 22
            width: Math.min(720, parent.width - 64)
            height: Math.min(560, parent.height - 80)
            anchors.centerIn: parent
            MouseArea { anchors.fill: parent }   // 吞卡内点击，避免冒泡到遮罩关闭

            ColumnLayout {
                anchors { fill: parent; margins: 18 }
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: licenseViewer.titleText; color: ml.textPrimary
                            font.pixelSize: 17; font.weight: Font.DemiBold; wrapMode: Text.WordWrap
                        }
                        Text {
                            visible: licenseViewer.subText !== ""
                            Layout.fillWidth: true
                            text: licenseViewer.subText; color: ml.textTertiary
                            font.pixelSize: 11; wrapMode: Text.WrapAnywhere
                        }
                    }
                    GhostBtn { label: "Close"; onTapped: licenseViewer.shown = false }
                }
                ThinRule {}
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: ml.calSunkBg
                    border.width: 1; border.color: ml.cellHair
                    clip: true
                    SilkyFlickable {
                        id: licenseScroll
                        style: ml
                        anchors { fill: parent; margins: 12 }
                        Text {
                            width: licenseScroll.width - 14
                            text: licenseViewer.bodyText
                            textFormat: Text.PlainText   // 许可文本含 <http://…> 等，禁富文本解析
                            color: ml.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            lineHeight: 1.3
                        }
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
                    Text {
                        text: root.tr(card.cardTitle)
                        color: ml.textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: card.cardDesc !== ""
                        Layout.fillWidth: true
                        text: root.tr(card.cardDesc); color: ml.textTertiary; font.pixelSize: 12; wrapMode: Text.WordWrap
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
            Text { text: root.tr(srow.rowTitle); color: ml.textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Text {
                visible: srow.rowSub !== ""
                text: root.tr(srow.rowSub); color: ml.textTertiary; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap
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
        property string text: ""
        Layout.fillWidth: true
        Layout.preferredHeight: noteText.implicitHeight + 24
        radius: 14
        color: ml.calSunkBg
        border.width: 1; border.color: ml.cellHair
        Text {
            id: noteText
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
            text: root.tr(parent.text)
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
            Text { text: root.tr(tileLabel); color: ml.textTertiary; font.pixelSize: 10; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.3 }
            Text { text: tileValue; color: ml.textPrimary; font.pixelSize: 21; font.weight: 900; font.letterSpacing: 0 }
        }
    }

    // ghost / primary / danger 按钮（复用 stats StatsGhostButton 配方）
    // 行内图标按钮：命中区比字形大，悬停有底色 + 文字提示，所以「是个能点的东西」
    // 一眼看得出来，也不会点不中。
    component IconBtn: Rectangle {
        id: ibtn
        property string glyph: ""
        property string hint: ""
        property bool danger: false
        signal tapped()
        implicitWidth: 30
        implicitHeight: 30
        radius: 10
        color: ibtnMa.containsMouse
               ? (ibtn.danger ? ml.calDangerWash : ml.calGhostHover)
               : "transparent"
        border.width: 1
        border.color: ibtnMa.containsMouse
                      ? (ibtn.danger
                         ? Qt.rgba(ml.calDangerWash.r, ml.calDangerWash.g, ml.calDangerWash.b, 0.7)
                         : ml.calGhostBorder)
                      : "transparent"
        Behavior on color { ColorAnimation { duration: 110 } }
        Text {
            anchors.centerIn: parent
            text: ibtn.glyph
            color: ibtn.danger ? ml.dangerText : ml.calGlyph
            font.pixelSize: 14
        }
        MouseArea {
            id: ibtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Cursor.button()
            preventStealing: true
            onClicked: ibtn.tapped()
        }
        Rectangle {
            visible: ibtnMa.containsMouse && ibtn.hint.length > 0
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: hintText.implicitWidth + 14
            height: 22
            radius: 7
            color: ml.calSunkBg
            border.width: 1; border.color: ml.cellHair
            z: 60
            Text {
                id: hintText
                anchors.centerIn: parent
                text: root.tr(ibtn.hint)
                color: ml.textSecondary
                font.pixelSize: 10
            }
        }
    }

    component GhostBtn: Rectangle {
        id: gbtn
        property string label: ""
        property bool primary: false
        property bool danger: false
        signal tapped()
        implicitWidth: Math.min(Math.max(gbtnLabel.implicitWidth + 28, 72), 190)
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
            width: parent.width - 18
            text: root.tr(gbtn.label)
            color: gbtn.primary ? ml.calBtnInk
                   : (gbtn.danger ? ml.dangerText : ml.calGlyph)
            font.pixelSize: 13; font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        MouseArea {
            id: gbtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Cursor.button()
            preventStealing: true
            onClicked: gbtn.tapped()
        }
    }

    // 快捷键捕获键帽（#3）：点击进入捕获、按下「A–Z + 任意修饰键」设定、Esc 取消。
    // 受控（不自写 keyText，父经 setHotkey 回写 → 绑定回流）。捕获态也是受控的：按键只发
    // captured，退不退出由外面按 setHotkey 的返回值决定——成功清、被拒留（可直接再按一次）。
    // capturing 是这件事唯一的开关，别在页面侧另写一份：本页拿不到这枚键帽，
    // 两处各写一半就成了「页面以为结束了、键帽还亮着等按键」。
    // Keys.onShortcutOverride 让捕获时吃掉全局 Shortcut（否则按旧 N/P 会触发备忘/番茄而非被捕获）；
    // 它管不到 macOS 菜单栏的 NSMenu，那条路由 hotkeyCapturing 在 MacMenuBar 侧置灰。
    component KeyCaptureChip: Rectangle {
        id: kc
        property string keyText: "N"
        property bool capturing: false
        signal captured(string key)
        implicitWidth: Math.max(54, kcLabel.implicitWidth + 18); implicitHeight: 30
        radius: 9
        color: capturing ? ml.accentSoft : ml.calGhostBg
        border.width: 1
        border.color: capturing ? ml.accentSoftBorder : ml.calGhostBorder
        Text {
            id: kcLabel
            anchors.centerIn: parent
            text: kc.capturing ? root.tr("Press…") : kc.keyText
            color: kc.capturing ? ml.aqua : ml.textPrimary
            font.pixelSize: 12; font.weight: 900
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Cursor.button()
            onClicked: { kc.capturing = true; kc.forceActiveFocus() }
        }
        Keys.onShortcutOverride: function (e) { if (kc.capturing) e.accepted = true }
        Keys.onPressed: function (e) {
            if (!kc.capturing) return
            if (e.key === Qt.Key_Escape) { kc.capturing = false; e.accepted = true; return }
            // Delete / Backspace = 停用本条快捷键。送空串出去，怎么解释由 setHotkey 决定
            // （macOS 停不掉，会改成恢复出厂键位）。
            if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) {
                kc.captured("")
                e.accepted = true
                return
            }
            // 只认字母做基键。单按修饰键（Qt.Key_Shift 等于 0x01000020）本来就落在区间外，
            // 于是「按住 ⌘ 还没按字母」这段自然什么都不发生。
            if (e.key >= Qt.Key_A && e.key <= Qt.Key_Z) {
                kc.captured(root._seqFromEvent(e))   // Qt.Key_A==65 → 'A'
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
            cursorShape: Cursor.button()
            preventStealing: true
            onClicked: {
                // Shell 同步把 nightModeToggled→nightMode 回写本页，故 toast 必须读「目标值」而非回写后的 root.nightMode。
                var goingNight = !root.nightMode
                root.nightModeToggled(goingNight)
                root.showToast(goingNight ? "Switched to dark mode" : "Switched to light mode")
            }
        }
    }
}
