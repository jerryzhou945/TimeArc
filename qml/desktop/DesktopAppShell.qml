import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import time_arc
import "memorylake"
import "components/AppVisual.js" as AppVisual
import "components/I18n.js" as I18n

Item {
    id: root
    anchors.fill: parent

    // 无边框窗口：顶部为自绘标题栏（main.qml 的 WindowChrome）预留的高度。背景层仍铺满全窗
    // （沉浸式：暗色水面/渐变铺到窗口顶边），只把交互内容 RowLayout 下移这一段，避免被标题栏遮挡。
    property int topReserve: 0
    // macOS 原生交通灯占用侧栏顶端；Windows/移动端保持原布局。
    property bool macSidebarChrome: false
    // 暴露给 WindowChrome：备忘黑板开启时让位隐藏；深底页（记忆湖/夜晚）时标题栏改用浅色线条。
    readonly property bool memoOpen: memoOverlay.open
    readonly property bool prefersLightChrome: nightMode
    signal trayShowRequested
    signal trayQuitRequested

    // 记忆湖统一色板（单一事实源，G1）：Shell 的记忆湖/回顾 chrome（蓝黑深度坡背景、
    // 角落辅光对、导航 active 发光点、渐变 logo）全部取自这里，杜绝散落 hex/rgba。
    MemoryLakeStyle {
        id: mlStyle
        night: root.nightMode
        accentSeed: root.accentColor
        injectedTextPrimary: root.appTextPrimary
        injectedTextSecondary: root.appTextSecondary
    }

    // =========================
    // 页面切换状态
    // =========================
    property int selectedIndex: 0
    property bool sidebarCollapsed: false
    property bool showingTimerPage: false
    property string pendingProjectTag: ""
    property string pendingTodoDateKey: ""
    property string pendingTodoText: ""
    property string pendingTodoTag: ""
    property string pendingTodoLinkedProject: ""

    // =========================
    // 主题切换状态
    // false = 白天
    // true  = 夜晚
    // =========================
    property bool nightMode: settingsRepository ? settingsRepository.getBool("night_mode", false) : false
    property string languageMode: settingsRepository ? settingsRepository.languageMode() : "en"
    property string accentColor: settingsRepository ? settingsRepository.getValue("accent_color", "#9FE7EE") : "#9FE7EE"

    function tr(source) {
        return I18n.t(languageMode, source);
    }
    function sentence(key, params, fallback) {
        return I18n.sentence(languageMode, key, params, fallback);
    }

    // =========================
    // 背景图路径
    // 白天 / 夜晚分别一张图
    // =========================
    property string dayBackgroundSource: Qt.resolvedUrl("../../resources/app/backgrounds/background.png")
    property string nightBackgroundSource: Qt.resolvedUrl("../../resources/app/backgrounds/background_night.png")

    // 当前实际使用的背景图
    property string appBackgroundSource: nightMode ? nightBackgroundSource : dayBackgroundSource

    // 记忆湖：整个 App 背景改为当前 APP 的 appColor 色彩晕染（§4.4，取代游戏海报模糊大图）。
    readonly property bool onMemoryLake: selectedPage === "memorylake" && !showingTimerPage
    // 记忆湖首页 + 月度回顾页都铺满内容区（去外框/玻璃，让暗色水面铺满整窗）。
    readonly property bool fullBleedPage: (selectedPage === "memorylake" || selectedPage === "recap" || selectedPage === "calendar" || selectedPage === "stats" || selectedPage === "settings") && !showingTimerPage
    readonly property bool memoryLakeHasAmbient: onMemoryLake && pageLoader.item && ("hasAmbient" in pageLoader.item) && pageLoader.item.hasAmbient
    readonly property color memoryLakeAmbientColor: (onMemoryLake && pageLoader.item && ("ambientColor" in pageLoader.item)) ? pageLoader.item.ambientColor : "#9FE7EE"
    // 当前 APP 图标主色数组（多色 blend 背景用）；缺失退回单色。
    readonly property var memoryLakeAmbientColors: (onMemoryLake && pageLoader.item && ("ambientColors" in pageLoader.item)) ? pageLoader.item.ambientColors : [memoryLakeAmbientColor]

    // 备忘黑板入口守卫：当前记忆卡处于翻面态时不可打开（功能文 §2.1 / C0）。
    // 翻面状态由记忆湖页暴露（DesktopMemoryLakePage.locked = flippedIndex >= 0）。
    readonly property bool memoLocked: onMemoryLake && pageLoader.item && ("locked" in pageLoader.item) && pageLoader.item.locked

    // 记忆湖时导航栏配色对齐记忆湖左右玻璃面板（全部取自 mlStyle 单一事实源，G1/NAV6）
    readonly property color mlNavGlass: mlStyle.panelBg
    readonly property color mlNavBorder: mlStyle.panelBorder
    readonly property color mlNavSelected: mlStyle.accentSoft
    readonly property color mlNavSelectedBorder: mlStyle.accentSoftBorder
    readonly property color mlNavSoft: nightMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color mlNavAccent: mlStyle.aqua

    // =========================
    // 全局主题颜色
    // 白天：奶油薄荷、米杏、浅粉紫
    // 夜晚：保留低亮度雾感紫灰
    // =========================

    // 文字颜色
    property color appTextPrimary: nightMode ? "#F3F0FF" : "#2D2724"
    property color appTextSecondary: nightMode ? "#C9C4DD" : "#7C746D"

    // 侧边栏玻璃层与边框（v88 暗底全幅页——记忆湖/日历/月度回顾——统一对齐 v88 玻璃面板，消除日历侧栏色差）
    property color appSidebarGlass: fullBleedPage ? mlNavGlass : (nightMode ? "#34394F" : "#FBF8F4")
    property color appSidebarBorder: fullBleedPage ? mlNavBorder : (nightMode ? "#5F6687" : "#E8E0D8")

    // 主内容区玻璃层与边框
    property color appPanelGlass: nightMode ? "#3C425C" : "#FBF8F4"
    property color appPanelBorder: nightMode ? "#626A90" : "#E8E0D8"

    // 当前选中的导航项
    property color appSelectedItem: fullBleedPage ? mlNavSelected : (nightMode ? "#596184" : "#DDF1E5")
    property color appSelectedItemBorder: fullBleedPage ? mlNavSelectedBorder : (nightMode ? "#8188B1" : "#BFDCCB")

    // 收起侧栏按钮
    property color appCollapseButton: fullBleedPage ? mlNavSoft : (nightMode ? "#4B526F" : "#F4E8C8")
    property color appCollapseButtonBorder: fullBleedPage ? mlNavBorder : (nightMode ? "#767DA7" : "#E8D9BC")

    // 强调色（logo 圆点 / 强调按钮）
    // 白天偏奶茶，夜晚偏柔和蓝紫；记忆湖偏霓虹 aqua
    property color appAccentWarm: fullBleedPage ? mlNavAccent : accentColor
    property color appAccentWarmText: fullBleedPage ? "#05070D" : (nightMode ? "#F8F7FF" : "#2D2724")

    // 左下角陪伴卡片
    property color appBottomCardBorder: fullBleedPage ? mlNavBorder : (nightMode ? "#7078A5" : "#E8E0D8")
    property color appBottomCardGlass: fullBleedPage ? mlNavSoft : (nightMode ? "#444B67" : "#FFFDF9")

    // 夜晚模式下的小高光文字
    property color appNightAccentText: "#BFC7FF"
    property color appShadowColor: nightMode ? "#05070D" : "#BFAE9D"

    // =========================
    // 左侧导航项
    // =========================
    // 顺序 / 文案对齐 v88 设计稿。page = 路由键（与下标解耦，供 currentPageSource /
    // onMemoryLake / 信号连接使用）；bottom = true 的项固定在菜单最底部（月度回顾）。
    property var navItems: [
        {
            title: "首页",
            subtitle: "Dashboard",
            page: "memorylake",
            icon: Qt.resolvedUrl("../../resources/app/icons/navigation/home.svg"),
            nightIcon: Qt.resolvedUrl("../../resources/app/icons/navigation/home_white.svg")
        },
        {
            title: "日历",
            subtitle: "Calendar",
            page: "calendar",
            icon: Qt.resolvedUrl("../../resources/app/icons/navigation/calendar.svg"),
            nightIcon: Qt.resolvedUrl("../../resources/app/icons/navigation/calendar_white.svg")
        },
        {
            title: "统计",
            subtitle: "Stats",
            page: "stats",
            icon: Qt.resolvedUrl("../../resources/app/icons/navigation/stats.svg"),
            nightIcon: Qt.resolvedUrl("../../resources/app/icons/navigation/stats_white.svg")
        },
        {
            title: "设置",
            subtitle: "Settings",
            page: "settings",
            icon: Qt.resolvedUrl("../../resources/app/icons/navigation/settings.svg"),
            nightIcon: Qt.resolvedUrl("../../resources/app/icons/navigation/settings_white.svg")
        },
        // 「备忘」= 动作（打开黑板模态覆盖层），不是页面路由：无 page 键，点击触发
        // memoOverlay.open，不切 selectedIndex（功能文 §2.1 / C0）。
        {
            title: "备忘",
            subtitle: "Notes",
            action: "memo",
            icon: Qt.resolvedUrl("../../resources/app/icons/navigation/note.svg"),
            nightIcon: Qt.resolvedUrl("../../resources/app/icons/navigation/note_white.svg")
        },
        {
            title: "记忆湖",
            subtitle: "Memory Recap",
            page: "recap",
            bottom: true,
            icon: Qt.resolvedUrl("../../resources/app/icons/navigation/recap.svg"),
            nightIcon: Qt.resolvedUrl("../../resources/app/icons/navigation/recap_white.svg")
        }
    ]

    readonly property var topNavItems: navItems.filter(function (it) {
        return !it.bottom;
    })
    readonly property var bottomNavItems: navItems.filter(function (it) {
        return it.bottom;
    })

    // 当前选中项的路由键。
    readonly property string selectedPage: (selectedIndex >= 0 && selectedIndex < navItems.length) ? navItems[selectedIndex].page : "memorylake"
    readonly property var pageGuideModel: ({
            "calendar": {
                eyebrow: "视觉路径",
                title: "先看今日安排，再处理待办",
                next: "下一步：从上到下扫过议程，先处理带时间的事项。"
            },
            "stats": {
                eyebrow: "视觉路径",
                title: "先看趋势，再看应用明细",
                next: "下一步：确认时间分布，再下钻到具体应用。"
            },
            "settings": {
                eyebrow: "视觉路径",
                title: "先选左侧分区，再改右侧卡片",
                next: "下一步：常用启动、托盘、自启在通用和追踪分区。"
            },
            "recap": {
                eyebrow: "视觉路径",
                title: "先看月度结论，再翻具体卡片",
                next: "下一步：按时间线查看高峰、分类和代表应用。"
            }
        })
    readonly property var currentPageGuide: pageGuideModel[selectedPage] || null
    readonly property bool showPageGuide: !showingTimerPage && selectedPage !== "memorylake" && currentPageGuide !== null

    function indexOfPage(key) {
        for (var i = 0; i < navItems.length; i++)
            if (navItems[i].page === key)
                return i;
        return -1;
    }

    // =========================
    // 当前 Loader 要加载哪个页面
    // =========================
    property string currentPageSource: {
        if (showingTimerPage)
            return Qt.resolvedUrl("pages/DesktopTimerPage.qml");

        switch (selectedPage) {
        case "memorylake":
            return Qt.resolvedUrl("pages/DesktopMemoryLakePage.qml");
        case "calendar":
            return Qt.resolvedUrl("pages/DesktopCalenderPage.qml");
        case "stats":
            return Qt.resolvedUrl("pages/DesktopStatsPage.qml");
        case "settings":
            return Qt.resolvedUrl("pages/DesktopProfilePage.qml");
        case "recap":
            return Qt.resolvedUrl("pages/DesktopMonthlyRecapPage.qml");
        }
        return "";
    }

    // =========================
    // 把 AppShell 的主题同步给当前加载的页面
    // 页面里如果定义了这些属性，就会自动接收到
    // =========================
    function applyThemeToLoadedPage() {
        if (!pageLoader.item)
            return;
        var item = pageLoader.item;

        if ("nightMode" in item)
            item.nightMode = nightMode;
        if ("themeTextPrimary" in item)
            item.themeTextPrimary = appTextPrimary;
        if ("themeTextSecondary" in item)
            item.themeTextSecondary = appTextSecondary;
        if ("themePanelColor" in item)
            item.themePanelColor = appPanelGlass;
        if ("themeBorderColor" in item)
            item.themeBorderColor = appPanelBorder;
        if ("themeAccentColor" in item)
            item.themeAccentColor = appAccentWarm;
        if ("languageMode" in item)
            item.languageMode = languageMode;
    }

    function notifyClosedToTray() {
        if (notifierLoader.item)
            notifierLoader.item.notify(root.tr("TimeArc 已隐藏到托盘"), root.tr("后台采集会继续运行；从托盘菜单可重新打开或退出。"));
    }

    // 关窗/退出前把备忘黑板的待存盘落地（窗口只认识 Shell，不该伸手进覆盖层内部）。
    function flushMemoDoc() {
        memoOverlay.flushPendingSave();
    }

    onNightModeChanged: {
        if (settingsRepository)
            settingsRepository.setBool("night_mode", nightMode);
        applyThemeToLoadedPage();
    }

    onLanguageModeChanged: applyThemeToLoadedPage()
    onAccentColorChanged: applyThemeToLoadedPage()

    // 启动时把设置页的读层过滤推入 usageStatManager（2A 游戏/分类/合并 · 2B 逐项显隐 ·
    // 2C 标题脱敏），让首页/统计/记忆湖在用户打开设置页前就遵从已存偏好。
    // 只读层、UI 私有；不写/不删 usage（I1/I2）。
    function applyReadFiltersFromSettings() {
        if (!usageStatManager || !usageStatManager.setReadFilters || !settingsRepository)
            return;
        var hidden = [];
        try {
            var a = JSON.parse(settingsRepository.getValue("hidden_apps", "[]"));
            if (Array.isArray(a))
                hidden = a;
        } catch (e) {}
        usageStatManager.setReadFilters(settingsRepository.getBool("auto_classify", true), settingsRepository.getBool("game_mode", true), settingsRepository.getBool("merge_windows", true), settingsRepository.getBool("hide_titles", true), hidden);
    }

    // 备忘 / 番茄全局快捷键（#3 自定义）：设置 KV 无变更信号，故设置页改键后发 hotkeysChanged，
    // Shell 重读到这两个响应式属性 → 下方 Shortcut.sequences 即时重绑（单字母）。
    property string memoHotkeyKey: "N"
    property string pomodoroHotkeyKey: "P"
    property bool notifyEnabled: true   // 系统通知开关（驱动托盘可见 + 是否发通知）
    // 设置页改键 / 改通知开关后发 hotkeysChanged → Shell 重读这些 Shell 侧消费的设置。
    function applyHotkeysFromSettings() {
        if (!settingsRepository)
            return;
        memoHotkeyKey = settingsRepository.getValue("memo_hotkey_key", "N");
        pomodoroHotkeyKey = settingsRepository.getValue("pomodoro_hotkey_key", "P");
        notifyEnabled = settingsRepository.getBool("notify_enabled", true);
    }

    // =========================
    // macOS 菜单栏命令入口（qml/desktop/MacMenuBar.qml）
    // 菜单栏只在 macOS 实例化，这些函数在 Windows/Linux 上没有调用方。备忘/番茄沿用
    // memoLocked 守卫（与字母键一致）；memo_hotkey_n 是「字母键要不要生效」的偏好，
    // 与菜单命令无关——关掉字母键不该顺带让菜单里的备忘黑板消失。
    // =========================
    function menuNavigateTo(pageKey) {
        var idx = indexOfPage(pageKey);
        if (idx < 0)
            return;
        showingTimerPage = false;
        selectedIndex = idx;
    }
    function menuToggleMemo() {
        if (memoLocked)
            return;
        memoOverlay.open = !memoOverlay.open;
    }
    function menuTogglePomodoro() {
        if (memoLocked)
            return;
        if (memoOverlay.togglePomodoro)
            memoOverlay.togglePomodoro();
    }
    function menuToggleNightMode() {
        nightMode = !nightMode;   // onNightModeChanged 负责写 KV 并下发给当前页
    }
    function menuSetLanguage(mode) {
        if (settingsRepository)
            settingsRepository.setValue("language_mode", mode);
        languageMode = mode;      // onLanguageModeChanged 下发给当前页（含设置页的语言卡）
    }
    // 「文件」里的设置类动作：先切到设置页，页面就位后再调它自己的函数——用户随后看到的
    // 是自己刚改动的那一页，也复用页面内既有的保存反馈卡（showSavedAt/toast）。
    function menuRunSettingsAction(fn) {
        menuNavigateTo("settings");
        Qt.callLater(function () {
            var it = pageLoader.item;
            if (it && typeof it[fn] === "function")
                it[fn]();
        });
    }
    // 统计导出导的是当前视图的期次，菜单项只在统计页可点，故直接调当前页。
    function menuExportStatsReport() {
        var it = pageLoader.item;
        if (it && typeof it.doExport === "function")
            it.doExport();
    }

    Component.onCompleted: {
        applyReadFiltersFromSettings();
        applyHotkeysFromSettings();
        // G-LANDING 默认页：landing_page = memorylake(默认/下标0) | recap | memo(开黑板覆盖层)。
        var lp = settingsRepository ? settingsRepository.getValue("landing_page", "memorylake") : "memorylake";
        if (lp === "memo") {
            memoOverlay.open = true;            // 备忘是动作而非页面：开覆盖层、保留首页
        } else {
            var idx = indexOfPage(lp);
            if (idx >= 0)
                selectedIndex = idx;  // memorylake 即默认 0；recap 切到对应页
        }
    }

    // G-MEMO：按 N 开/关备忘黑板（门控 memo_hotkey_n + 记忆卡翻面锁）。Qt 的 ShortcutOverride
    // 让聚焦中的文本框（设置搜索 / 便签署名 / 便签文字）吃掉该键，故输入时不会误触发；
    // 偏好在触发时实读，关掉开关后下次按 N 立即失效（无需依赖不存在的设置变更信号）。
    Shortcut {
        sequences: root.memoHotkeyKey.length > 0 ? [root.memoHotkeyKey] : []
        enabled: !root.memoLocked && root.memoHotkeyKey.length > 0
        onActivated: {
            if (settingsRepository && !settingsRepository.getBool("memo_hotkey_n", true))
                return;
            memoOverlay.open = !memoOverlay.open;
        }
    }

    // G-MEMO/#3：番茄钟全局快捷键 —— 开备忘黑板并开/关番茄浮窗（同样 ShortcutOverride 安全）。
    Shortcut {
        sequences: root.pomodoroHotkeyKey.length > 0 ? [root.pomodoroHotkeyKey] : []
        enabled: !root.memoLocked && root.pomodoroHotkeyKey.length > 0
        onActivated: {
            if (memoOverlay.togglePomodoro)
                memoOverlay.togglePomodoro();
        }
    }

    Item {
        id: desktopStage
        anchors.fill: parent

        // =========================
        // 整体背景层
        // 这里做白天 / 夜晚背景图切换
        // 同时叠一层渐变遮罩，让整体更统一
        // =========================
        Item {
            anchors.fill: parent

            Image {
                anchors.fill: parent
                source: appBackgroundSource
                fillMode: Image.PreserveAspectCrop
                opacity: nightMode ? 0.52 : 0.04
                smooth: true
                asynchronous: true
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: nightMode ? "#2D3148" : "#DDF1E5"
                    }
                    GradientStop {
                        position: 0.46
                        color: nightMode ? "#353A56" : "#F7F1E8"
                    }
                    GradientStop {
                        position: 1.0
                        color: nightMode ? "#3B4160" : "#FFF7ED"
                    }
                }
                // 记忆湖/月度回顾页隐藏紫灰底，让蓝黑深度坡当家（BG1）；其它页不变。
                opacity: fullBleedPage ? 0 : (nightMode ? 0.46 : 1.0)
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: nightMode ? "#4E5578" : "#BFE4D0"
                    }
                    GradientStop {
                        position: 0.36
                        color: nightMode ? "#3F4665" : "#F2DFAF"
                    }
                    GradientStop {
                        position: 0.70
                        color: nightMode ? "#303650" : "#F8EFE7"
                    }
                    GradientStop {
                        position: 1.0
                        color: nightMode ? "#24283D" : "#E7B7C3"
                    }
                }
                opacity: fullBleedPage ? 0 : (nightMode ? 0.28 : 0.52)
            }

            // ============================================================
            // 记忆湖 / 月度回顾：蓝黑深度坡底（BG1）+ 角落 aqua/violet 辅光对（BG2/BG4）
            // ============================================================
            Item {
                anchors.fill: parent
                visible: fullBleedPage
                // 蓝黑深度坡竖直渐变（夜 #05070D→#0D1320→#121A2A；昼暖坡）
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: mlStyle.bg0
                        }
                        GradientStop {
                            position: 0.52
                            color: mlStyle.bg2
                        }
                        GradientStop {
                            position: 1.0
                            color: mlStyle.bg3
                        }
                    }
                }
                // 招牌角落辅光对：左上 aqua、右上 violet。圆心落在窗角附近、向内自然衰减。
                // 用 GlowCircle（模糊实心圆）近似设计稿 radial（QML 渐变不支持辐射）。
                GlowCircle {
                    readonly property real d: Math.min(parent.width, parent.height) * 0.66
                    width: d
                    height: d
                    x: parent.width * 0.08 - d / 2
                    y: -d * 0.42
                    glowColor: mlStyle.aqua
                    glowOpacity: mlStyle.glowStrength * 0.22   // 径向中心在角落、向内自然淡出（设计稿 8% 0% 角落光）
                }
                GlowCircle {
                    readonly property real d: Math.min(parent.width, parent.height) * 0.64
                    width: d
                    height: d
                    x: parent.width * 0.95 - d / 2
                    y: -d * 0.40
                    glowColor: mlStyle.violet
                    glowOpacity: mlStyle.glowStrength * 0.18
                }

                // 日历页 / 统计页：整 App v88 42px 蓝图栅格纹（选中时铺满全窗，对齐 .stats-page::before 42px）。
                // 边缘用羽化白圆角矩形作 MultiEffect 遮罩 → 渐隐不硬切；窗口 DWM 圆角再裁四角，无方角外露。
                Item {
                    anchors.fill: parent
                    visible: selectedPage === "calendar" || selectedPage === "stats" || selectedPage === "settings"

                    GridTexture {
                        anchors.fill: parent
                        cell: 42
                        lineColor: mlStyle.gridLine
                        textureOpacity: 0.95
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: calGridFeather
                            maskThresholdMin: 0.40
                            maskSpreadAtMin: 0.34
                        }
                    }

                    Rectangle {
                        id: calGridFeather
                        anchors.fill: parent
                        anchors.margins: 12
                        radius: 64
                        color: "#FFFFFF"
                        visible: false
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 64
                            autoPaddingEnabled: false
                        }
                    }
                }
            }

            // 记忆湖：整个 App 背景 = 当前 APP **图标主色**的多色晕染（§4.4 / issue A7/B4）。
            // 不再用游戏海报；改图标主色（2–3 色）渐变交叉淡入 + 两团模糊色块混入，仍重模糊。
            Item {
                anchors.fill: parent
                visible: onMemoryLake && memoryLakeHasAmbient
                // 多色渐变交叉淡入淡出：保留原 A/B 乒乓 + 450ms Behavior（颜色数组驱动）。
                Item {
                    id: mlBgSrc
                    anchors.fill: parent
                    property var cols: memoryLakeAmbientColors
                    property bool frontIsA: true
                    // 取色数组第 i 项（不足则取末项；空则兜底）。
                    function col(arr, i) {
                        return (arr && arr.length > 0) ? arr[Math.min(i, arr.length - 1)] : "#9FE7EE";
                    }
                    onColsChanged: {
                        if (frontIsA) {
                            mlRectB.cols = cols;
                            frontIsA = false;
                        } else {
                            mlRectA.cols = cols;
                            frontIsA = true;
                        }
                    }
                    Component.onCompleted: {
                        mlRectA.cols = cols;
                        frontIsA = true;
                    }
                    Rectangle {
                        id: mlRectA
                        anchors.fill: parent
                        property var cols: mlBgSrc.cols
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: Qt.lighter(AppVisual.ambientTone(mlBgSrc.col(mlRectA.cols, 0), nightMode), 1.06)
                            }
                            GradientStop {
                                position: 0.5
                                color: AppVisual.ambientTone(mlBgSrc.col(mlRectA.cols, 1), nightMode)
                            }
                            GradientStop {
                                position: 1.0
                                color: Qt.darker(AppVisual.ambientTone(mlBgSrc.col(mlRectA.cols, 2), nightMode), 1.16)
                            }
                        }
                        // BG3：层②压到 ambientImageOpacity(.34)，让蓝黑深度坡透出，不再盖过底。
                        opacity: mlBgSrc.frontIsA ? mlStyle.ambientImageOpacity : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 350
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                    Rectangle {
                        id: mlRectB
                        anchors.fill: parent
                        property var cols: mlBgSrc.cols
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: Qt.lighter(AppVisual.ambientTone(mlBgSrc.col(mlRectB.cols, 0), nightMode), 1.06)
                            }
                            GradientStop {
                                position: 0.5
                                color: AppVisual.ambientTone(mlBgSrc.col(mlRectB.cols, 1), nightMode)
                            }
                            GradientStop {
                                position: 1.0
                                color: Qt.darker(AppVisual.ambientTone(mlBgSrc.col(mlRectB.cols, 2), nightMode), 1.16)
                            }
                        }
                        opacity: mlBgSrc.frontIsA ? 0 : mlStyle.ambientImageOpacity
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 350
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
                // BG4：两团 APP 图标主色模糊圆重定位到上半角落带（左上 / 右上），为 aqua/violet
                // 角落辅光注入当前 APP 的色彩；圆心内缩、不抢极角，保 BG2 四角青/紫主导。
                Rectangle {
                    id: mlBlobA
                    width: Math.min(parent.width, parent.height) * 0.72
                    height: width
                    radius: width / 2
                    x: parent.width * 0.22 - width / 2
                    y: parent.height * 0.20 - height / 2
                    visible: false
                    layer.enabled: true
                    color: AppVisual.ambientTone(mlBgSrc.col(memoryLakeAmbientColors, 0), nightMode)
                    Behavior on color {
                        ColorAnimation {
                            duration: 350
                        }
                    }
                }
                MultiEffect {
                    anchors.fill: mlBlobA
                    source: mlBlobA
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    opacity: nightMode ? 0.14 : 0.22
                    autoPaddingEnabled: true
                }
                Rectangle {
                    id: mlBlobB
                    width: Math.min(parent.width, parent.height) * 0.68
                    height: width
                    radius: width / 2
                    x: parent.width * 0.80 - width / 2
                    y: parent.height * 0.24 - height / 2
                    visible: false
                    layer.enabled: true
                    color: AppVisual.ambientTone(mlBgSrc.col(memoryLakeAmbientColors, 1), nightMode)
                    Behavior on color {
                        ColorAnimation {
                            duration: 350
                        }
                    }
                }
                MultiEffect {
                    anchors.fill: mlBlobB
                    source: mlBlobB
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    opacity: nightMode ? 0.12 : 0.18
                    autoPaddingEnabled: true
                }
                // BG5：顶层薄霜 veil → 近黑薄膜 rgba(2,4,8,.12) 量级，统一磨光而不把色调压灰。
                Rectangle {
                    anchors.fill: parent
                    color: nightMode ? Qt.rgba(0.008, 0.016, 0.031, 0.14) : Qt.rgba(0.14, 0.16, 0.22, 0.10)
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            // macOS 使用边到边内容：无单独标题栏，侧栏直接贴合窗口左、上、下边缘。
            // Windows/其他平台继续保留原有 20px 浮动卡片边距。
            anchors.leftMargin: root.macSidebarChrome ? 0 : 20
            anchors.rightMargin: 20
            anchors.topMargin: root.macSidebarChrome ? 0 : 20 + root.topReserve
            anchors.bottomMargin: root.macSidebarChrome ? 0 : 20
            spacing: 20

            // =========================
            // 左侧侧边栏
            // =========================
            Item {
                id: sidebarSlot
                width: sidebarCollapsed ? 88 : 232
                Layout.preferredWidth: width
                Layout.fillHeight: true

                Behavior on width {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: sidebar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.top: parent.top
                    // macOS 侧栏从窗口左上角贯穿到底部且没有卡片边界；原生交通灯直接覆盖在其中。
                    radius: root.macSidebarChrome ? 0 : 28
                    color: "transparent"
                    border.width: root.macSidebarChrome ? 0 : 1
                    border.color: appSidebarBorder

                    // 记忆湖/月度回顾（设计稿）侧栏无生硬下沉阴影：fullBleed 时关掉这道偏移色块。
                    Rectangle {
                        x: 0
                        y: 10
                        width: parent.width
                        height: parent.height
                        radius: parent.radius
                        color: appShadowColor
                        opacity: root.macSidebarChrome || fullBleedPage ? 0 : (nightMode ? 0.24 : 0.09)
                        z: -2
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: root.macSidebarChrome ? 0 : 1
                        radius: root.macSidebarChrome ? 0 : 27
                        color: appSidebarGlass
                        opacity: nightMode ? 0.88 : 0.92
                        z: -1
                    }

                    // macOS：空白侧栏与无交互品牌区支持原生挪窗及双击缩放；后声明的
                    // 按钮/导航位于其上方，继续优先接收点击，不会被背景手势截获。
                    // 备忘黑板打开时必须整组停手：DragHandler/TapHandler 是指针处理器，事件分发
                    // 会先给命中点下**所有** item 的 handler 一次机会，覆盖层自己的 MouseArea 挡不住
                    // （过阈值后 DragHandler 还能把独占抓取抢走）。不禁用的话在黑板左侧横拖会变成
                    // 挪窗口、双击会变成缩放，而不是画笔/框选。同理，普通 MouseArea 型导航不会漏。
                    Item {
                        anchors.fill: parent
                        enabled: root.macSidebarChrome && !root.memoOpen

                        DragHandler {
                            target: null
                            dragThreshold: 4
                            onActiveChanged: {
                                if (active && root.Window.window)
                                    root.Window.window.startSystemMove()
                            }
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.DragThreshold
                            onDoubleTapped: {
                                if (macTrafficLightsController)
                                    macTrafficLightsController.performTitlebarDoubleClickAction()
                            }
                        }
                    }

                    // 导航项委托：顶部主菜单与底部「记忆湖」入口共用（index 由 page 反查，与下标解耦）。
                    Component {
                        id: navItemDelegate
                        Rectangle {
                            required property var modelData
                            readonly property int navIndex: root.indexOfPage(modelData.page)
                            readonly property bool isSel: selectedIndex === navIndex && !showingTimerPage
                            // 「备忘」是动作项（无 page）：点击开黑板覆盖层；翻面锁定时置禁用态。
                            readonly property bool isMemoAction: modelData.action === "memo"
                            readonly property bool memoDisabled: isMemoAction && root.memoLocked

                            width: parent ? parent.width : 0
                            height: 56
                            radius: 18
                            opacity: memoDisabled ? 0.4 : 1.0
                            color: isSel ? appSelectedItem : navMouse.containsMouse ? (nightMode ? "#4B526F" : "#F4E8C8") : "transparent"
                            border.width: isSel ? 1 : 0
                            border.color: appSelectedItemBorder

                            // 翻面锁定时的禁用提示（对齐 v88：title「当前卡牌翻面时不可打开备忘录」）。
                            ToolTip.visible: navMouse.containsMouse && memoDisabled
                            ToolTip.text: root.tr("当前卡牌翻面时不可打开备忘录")

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: sidebarCollapsed ? undefined : parent.left
                                anchors.leftMargin: sidebarCollapsed ? 0 : 16
                                anchors.horizontalCenter: sidebarCollapsed ? parent.horizontalCenter : undefined
                                spacing: 14

                                Image {
                                    source: (nightMode && modelData.nightIcon) ? modelData.nightIcon : modelData.icon
                                    width: 22
                                    height: 22
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: isSel ? 1.0 : 0.72
                                }

                                Column {
                                    visible: !sidebarCollapsed
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: root.tr(modelData.title)
                                        color: isSel ? appTextPrimary : appTextSecondary
                                        font.pixelSize: 16
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        width: sidebarCollapsed ? 0 : 120
                                    }

                                    Text {
                                        text: modelData.subtitle ? root.tr(modelData.subtitle) : ""
                                        visible: text.length > 0
                                        color: appTextSecondary
                                        font.pixelSize: 10
                                        opacity: 0.7
                                        elide: Text.ElideRight
                                        width: sidebarCollapsed ? 0 : 120
                                    }
                                }
                            }

                            // active 三重信号之三（NAV2）：右侧 5px 发光 aqua 点。
                            // 叠 2 层低透圆 + 亮芯仿 box-shadow 0 0 14px aqua .65 柔晕（§3.6，不挂 MultiEffect）。
                            Item {
                                visible: isSel && fullBleedPage && !sidebarCollapsed
                                width: 20
                                height: 20
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: Qt.rgba(mlStyle.aqua.r, mlStyle.aqua.g, mlStyle.aqua.b, 0.16)
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: Qt.rgba(mlStyle.aqua.r, mlStyle.aqua.g, mlStyle.aqua.b, 0.45)
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: mlStyle.aqua
                                }
                            }

                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: memoDisabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                onClicked: {
                                    // 动作项：打开黑板模态覆盖层（不切页、不动 selectedIndex）。
                                    if (isMemoAction) {
                                        if (!root.memoLocked)
                                            memoOverlay.open = true;
                                        return;
                                    }
                                    showingTimerPage = false;
                                    selectedIndex = navIndex;
                                }
                            }
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        // 原生交通灯约占窗口顶部 28px；Logo 从其下方开始。
                        anchors.topMargin: root.macSidebarChrome ? 48 : 18
                        spacing: 16

                        // 顶部 Logo
                        Row {
                            width: parent.width
                            height: 62
                            spacing: 12

                            Rectangle {
                                readonly property real logoScale: width / 36

                                width: root.macSidebarChrome ? 52 : 36
                                height: width
                                radius: (fullBleedPage ? 14 : 18) * logoScale
                                color: fullBleedPage ? "transparent" : appAccentWarm
                                anchors.verticalCenter: parent.verticalCenter

                                // NAV3 / 配方#4：记忆湖品牌渐变方块 aqua→violet。竖直渐变近似 145°
                                // （36px 尺度下与斜向差异可忽略，省去 Shapes/FBO 开销），上压暗墨「T」(900)。
                                // 暗底全幅页（记忆湖/日历/月度回顾）统一用渐变品牌方块，侧栏与首页一致。
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    visible: fullBleedPage
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0
                                            color: mlStyle.aqua
                                        }
                                        GradientStop {
                                            position: 1
                                            color: mlStyle.violet
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "T"
                                    color: appAccentWarmText
                                    font.pixelSize: 18 * parent.logoScale
                                    font.weight: fullBleedPage ? 900 : Font.Bold
                                }
                            }

                            Text {
                                visible: !sidebarCollapsed
                                text: "TimeArc"
                                color: appTextPrimary
                                font.pixelSize: 24
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // 收起侧栏按钮
                        Rectangle {
                            width: parent.width
                            height: 48
                            radius: 18
                            color: appCollapseButton
                            border.width: 1
                            border.color: appCollapseButtonBorder

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 17
                                color: "#FFFFFF"
                                opacity: nightMode ? 0.07 : 0.18
                                z: -1
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    text: sidebarCollapsed ? "»" : "«"
                                    color: nightMode ? "#D5DAFF" : "#2D2724"
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                Text {
                                    visible: !sidebarCollapsed
                                    text: sidebarCollapsed ? root.tr("展开侧栏") : root.tr("收起侧栏")
                                    color: appTextPrimary
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: sidebarCollapsed = !sidebarCollapsed
                            }
                        }

                        // 导航列表（顶部主菜单：非 bottom 项）
                        Column {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: root.topNavItems
                                delegate: navItemDelegate
                            }
                        }
                    }

                    // 底部固定区：分隔的「记忆湖 / Memory Recap」入口 + 陪伴卡片
                    Column {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 18
                        spacing: 12

                        Rectangle {
                            visible: !sidebarCollapsed
                            width: parent.width
                            height: 1
                            color: appSidebarBorder
                            opacity: 0.6
                        }

                        Repeater {
                            model: root.bottomNavItems
                            delegate: navItemDelegate
                        }

                        // 左下角状态卡片（纯装饰）。窗口压到最小（1280×720）时侧栏放不下「顶部导航列 +
                        // 底部 记忆湖 + 这张陪伴卡」，两栏会顶撞（备忘 ⟷ 记忆湖 文字叠印）。故侧栏过矮时隐藏本卡，
                        // 把高度让回去，底部的 记忆湖 入口下沉、不再与上方 备忘 重叠。阈值 740 留足余量
                        // （顶部列底沿 ~472 + 底部带含本卡 ~221 + 余量）。
                        Rectangle {
                            visible: !sidebarCollapsed && sidebar.height >= 740
                            width: parent.width
                            height: 122
                            radius: 22
                            color: appBottomCardGlass
                            border.width: 1
                            border.color: appBottomCardBorder

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 21
                                color: "#FFFFFF"
                                opacity: nightMode ? 0.05 : 0.14
                                z: -1
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8

                                Text {
                                    text: root.tr("记忆湖陪伴")
                                    color: appTextPrimary
                                    font.pixelSize: 15
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: nightMode ? root.tr("夜晚模式中") : root.tr("白天模式中")
                                    color: nightMode ? appNightAccentText : "#2F7A5B"
                                    font.pixelSize: 22
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: nightMode ? root.tr("今晚也慢慢积累。") : root.tr("慢慢积累，也很好。")
                                    color: appTextSecondary
                                    font.pixelSize: 13
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }
                    }
                }
            }

            // =========================
            // 主内容区域
            // =========================
            Item {
                id: contentSlot
                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    id: contentPanel
                    anchors.fill: parent
                    radius: 32
                    color: "transparent"
                    // 记忆湖/月度回顾时去掉内容区外框，让暗色水面真正铺满全 App、不再有「框中框」
                    border.width: fullBleedPage ? 0 : 1
                    border.color: appPanelBorder

                    Rectangle {
                        x: 0
                        y: 12
                        width: parent.width
                        height: parent.height
                        radius: parent.radius
                        color: appShadowColor
                        opacity: fullBleedPage ? 0 : (nightMode ? 0.26 : 0.08)
                        z: -2
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 31
                        color: appPanelGlass
                        // 记忆湖/月度回顾时透明，让整个 App 模糊背景 + 卡牌占位符背景透出（Issue 1/2）
                        opacity: fullBleedPage ? 0 : (nightMode ? 0.76 : 0.82)
                        z: -1
                    }

                    Rectangle {
                        id: guideRail
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: fullBleedPage ? 8 : 22
                        anchors.rightMargin: fullBleedPage ? 8 : 22
                        anchors.topMargin: fullBleedPage ? 8 : 22
                        height: 44
                        radius: 14
                        visible: root.showPageGuide
                        color: fullBleedPage ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, nightMode ? 0.08 : 0.56)
                        border.width: 1
                        border.color: fullBleedPage ? mlStyle.panelBorder : appPanelBorder
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.currentPageGuide ? root.tr(root.currentPageGuide.eyebrow) : ""
                                color: fullBleedPage ? mlStyle.aqua : appAccentWarm
                                font.pixelSize: 11
                                font.weight: 900
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.currentPageGuide ? root.tr(root.currentPageGuide.title) : ""
                                color: appTextPrimary
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(120, parent.width - 360)
                                text: root.currentPageGuide ? root.tr(root.currentPageGuide.next) : ""
                                color: appTextSecondary
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Loader {
                        id: pageLoader
                        anchors.fill: parent
                        // 记忆湖/月度回顾几乎铺满占位符（卡牌作为背景层覆盖最大圆角方体，Issue 2）
                        anchors.leftMargin: fullBleedPage ? 8 : 22
                        anchors.rightMargin: fullBleedPage ? 8 : 22
                        anchors.bottomMargin: fullBleedPage ? 8 : 22
                        anchors.topMargin: root.showPageGuide ? (fullBleedPage ? 60 : 74) : (fullBleedPage ? 8 : 22)
                        source: currentPageSource

                        onLoaded: {
                            console.log("Loader loaded:", source);

                            if (!item)
                                return;

                            // 页面加载后，把当前主题注入进去
                            applyThemeToLoadedPage();

                            // 计时页不需要再连首页 signal
                            if (showingTimerPage)
                                return;

                            // 记忆湖首页 / 月度回顾页 / 统计页 / 设置页：请求切页（今日事项「日历」、返回湖面、统计/设置返回首页等）。
                            if ((selectedPage === "memorylake" || selectedPage === "recap" || selectedPage === "stats" || selectedPage === "settings") && item.requestNavigate) {
                                item.requestNavigate.connect(function (pageKey) {
                                    var idx = indexOfPage(pageKey);
                                    if (idx >= 0) {
                                        showingTimerPage = false;
                                        selectedIndex = idx;
                                    }
                                });
                            }

                            // 设置页：连接夜晚模式开关 + 同步当前 nightMode。
                            if (selectedPage === "settings") {
                                if (item.nightModeToggled) {
                                    item.nightModeToggled.connect(function (enabled) {
                                        nightMode = enabled;
                                    });
                                }
                                // #3：设置页改键 → Shell 重读 memo/pomodoro 全局键（Shortcut 即时重绑）。
                                if (item.hotkeysChanged)
                                    item.hotkeysChanged.connect(applyHotkeysFromSettings);
                                if (item.accentChanged)
                                    item.accentChanged.connect(function (color) {
                                        root.accentColor = color;
                                        root.applyThemeToLoadedPage();
                                    });
                                if (item.languageChanged)
                                    item.languageChanged.connect(function (mode) {
                                        root.languageMode = mode;
                                    });
                                if ("nightMode" in item)
                                    item.nightMode = nightMode;
                            }

                            // 日历页：注入备忘覆盖层引用，使议程上「便签待办行」的勾选/删除能回写到便签。
                            if (selectedPage === "calendar" && ("memoOverlayRef" in item))
                                item.memoOverlayRef = memoOverlay;

                            // 日历页：待办计时。
                            if (selectedPage === "calendar" && item.startTodoProject) {
                                item.startTodoProject.connect(function (projectName, tagName, dateKey, linkedProjectName) {
                                    if (timerManager) {
                                        pendingProjectTag = "";
                                        pendingTodoDateKey = dateKey;
                                        pendingTodoText = projectName;
                                        pendingTodoTag = tagName;
                                        pendingTodoLinkedProject = linkedProjectName;
                                        timerManager.startProject(projectName);
                                        showingTimerPage = true;
                                    }
                                });
                            }
                        }

                        onStatusChanged: {
                            console.log("Loader status:", status, "source:", source);
                        }
                    }
                }
            }
        }
    }

    // =========================
    // 监听计时结束
    // 结束后：
    // 1. 把本次时间累计到项目
    // 2. 返回首页
    // =========================
    AchievementToast {
        id: achievementToast
        anchors.fill: parent
        nightMode: root.nightMode
    }

    // 备忘黑板·模态覆盖层（入口=动作）：盖在首页+导航之上、z 最高，关闭退回底层原页。
    // backdropSource = desktopStage：进入时截一张首页快照重模糊作黑板磨砂底（M0）。
    MemoOverlay {
        id: memoOverlay
        anchors.fill: parent
        style: mlStyle
        languageMode: root.languageMode
        macSidebarChrome: root.macSidebarChrome   // 左上角 chrome 让开原生交通灯按钮带
        backdropSource: desktopStage
        store: settingsRepository    // UI 私有持久化（通用 key-value；非服务磁盘契约）
    }

    // 欢迎入场动画（一次性，启动）：show_welcome 门控（默认开）；**第一帧即满屏显示**→驻留→淡出
    // （开屏不需要淡入，否则启动瞬间会先瞥见底层内容）。可点按提前关；done 后 visible=false 永不挡交互。
    // willShow 关时 opacity 直接 0，避免 onCompleted 置 done 前的一帧闪屏。复用 mlStyle.aqua/violet 令牌。
    Rectangle {
        id: welcomeOverlay
        anchors.fill: parent
        z: 9000
        color: nightMode ? "#070A12" : "#F6F1EA"
        property bool done: false
        readonly property bool willShow: settingsRepository ? settingsRepository.getBool("show_welcome", true) : true
        opacity: willShow ? 1 : 0
        visible: opacity > 0.01 && !done
        Column {
            anchors.centerIn: parent
            spacing: 22
            Rectangle {
                width: 76
                height: 76
                radius: 22
                anchors.horizontalCenter: parent.horizontalCenter
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: mlStyle.aqua
                    }
                    GradientStop {
                        position: 1
                        color: mlStyle.violet
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "T"
                    color: "#05070D"
                    font.pixelSize: 40
                    font.weight: Font.Black
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "TimeArc"
                color: appTextPrimary
                font.pixelSize: 30
                font.weight: Font.Bold
                font.letterSpacing: 0.5
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.tr("时间的弧线 · 慢慢积累，很好")
                color: appTextSecondary
                font.pixelSize: 14
                elide: Text.ElideRight
                width: Math.min(parent.width, 360)
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: welcomeOverlay.dismiss()
        }
        function dismiss() {
            if (done || welcomeOut.running)
                return;
            welcomeSeq.stop();
            welcomeOut.start();
        }
        // 即显 → 驻留 → 淡出（无淡入）。
        SequentialAnimation {
            id: welcomeSeq
            PauseAnimation {
                duration: 1700
            }
            NumberAnimation {
                target: welcomeOverlay
                property: "opacity"
                from: 1
                to: 0
                duration: 650
                easing.type: Easing.InCubic
            }
            onFinished: welcomeOverlay.done = true
        }
        NumberAnimation {
            id: welcomeOut
            target: welcomeOverlay
            property: "opacity"
            to: 0
            duration: 320
            onFinished: welcomeOverlay.done = true
        }
        Component.onCompleted: {
            if (!willShow) {
                done = true;
                return;
            }
            welcomeSeq.start();
        }
    }

    // 系统通知载体（G-NOTIFY）：Loader 容错加载——平台无 Qt.labs.platform 插件时静默失败、不拖垮整页。
    Loader {
        id: notifierLoader
        source: "memorylake/NotifierTray.qml"
        onLoaded: {
            item.iconSource = Qt.resolvedUrl("../../resources/app/TimeArc.svg");
            item.notifyOn = Qt.binding(function () {
                return root.notifyEnabled;
            });
            item.stayResident = true;
            item.showRequested.connect(function () {
                root.trayShowRequested();
            });
            item.quitRequested.connect(function () {
                root.trayQuitRequested();
            });
        }
    }
    // 番茄钟完成 → 仅当窗口不在前台（已无全屏庆祝可见）时发系统通知，避免与庆祝重复。
    Connections {
        target: memoOverlay
        function onPomodoroFinished(title) {
            if (!root.notifyEnabled || (root.Window.window && root.Window.window.active))
                return;
            if (notifierLoader.item)
                notifierLoader.item.notify(root.tr("番茄钟完成"), (title && title.length > 0 ? title : root.tr("专注")) + " · " + root.tr("这一程结束了"));
        }
    }

    Connections {
        target: timerManager

        function onTimerStopped(projectName, elapsedSeconds) {
            if (projectManager && pendingTodoDateKey !== "")
                projectManager.addTodoElapsedTimeOnDate(projectName, pendingTodoTag, pendingTodoLinkedProject, elapsedSeconds, pendingTodoDateKey);
            else if (projectManager && pendingProjectTag !== "")
                projectManager.addElapsedTimeForTag(projectName, pendingProjectTag, elapsedSeconds);
            else if (projectManager)
                projectManager.addElapsedTime(projectName, elapsedSeconds);

            if (calendarManager && elapsedSeconds > 0 && pendingTodoDateKey !== "" && pendingTodoText === projectName)
                calendarManager.completeTodo(pendingTodoDateKey, pendingTodoText);

            pendingProjectTag = "";
            pendingTodoDateKey = "";
            pendingTodoText = "";
            pendingTodoTag = "";
            pendingTodoLinkedProject = "";

            showingTimerPage = false;
            selectedIndex = 0;
        }
    }
}
