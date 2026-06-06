import QtQuick

// 记忆湖统一色板。夜晚 = 设计稿深色霓虹原值（1:1）；白天 = 派生浅色映射。
// 布局尺寸、动画时长、交互逻辑两套主题完全一致，只换颜色与发光强度。
// 详见 docs/memory-lake-implementation-plan.md §5。
QtObject {
    id: style

    property bool night: true

    // 霓虹强调色（两套主题共用，白天略降发光）
    readonly property color aqua: "#9FE7EE"
    readonly property color violet: "#9B8BFF"
    readonly property color pink: "#D88AAC"

    // 整体舞台底（记忆窗口背景）
    readonly property color stageBg: night ? "#070A11" : "#F4EFE6"
    readonly property color stageGlow1: night ? Qt.rgba(0.62, 0.90, 0.93, 0.07)
                                              : Qt.rgba(0.62, 0.90, 0.93, 0.16)
    readonly property color stageGlow2: night ? Qt.rgba(0.61, 0.55, 1.0, 0.06)
                                              : Qt.rgba(0.61, 0.55, 1.0, 0.12)

    // 三栏面板（提高不透明度：左右栏会盖住滑到其后的非焦点卡牌，0.72 时卡牌清晰透出很违和；
    // QML 无逐面板实时背景模糊，故以更实的叠色来挡住后面的卡牌，仍保留一点点通透感）
    readonly property color panelBg: night ? Qt.rgba(0.043, 0.063, 0.106, 0.94)
                                            : Qt.rgba(1, 1, 1, 0.92)
    readonly property color panelBorder: night ? Qt.rgba(1, 1, 1, 0.075)
                                               : Qt.rgba(0.40, 0.34, 0.28, 0.22)
    readonly property color panelBorderStrong: night ? Qt.rgba(1, 1, 1, 0.13)
                                                     : Qt.rgba(0.40, 0.34, 0.28, 0.30)

    // 内层小卡（profile/overview/theme/usage/detail/time-tree/note）
    readonly property color cardBg: night ? Qt.rgba(1, 1, 1, 0.035)
                                          : Qt.rgba(1, 1, 1, 0.55)
    readonly property color cardBorder: night ? Qt.rgba(1, 1, 1, 0.065)
                                              : Qt.rgba(0.40, 0.34, 0.28, 0.18)

    // 记忆卡牌面
    readonly property color faceBg: night ? "#0D121D" : "#FBF7F0"
    readonly property color faceBorder: night ? Qt.rgba(1, 1, 1, 0.08)
                                             : Qt.rgba(0.40, 0.34, 0.28, 0.20)
    readonly property color faceBorderActive: night ? Qt.rgba(0.62, 0.90, 0.93, 0.55)
                                                   : Qt.rgba(0.40, 0.55, 0.52, 0.55)

    // 文字（接主题契约：白天用注入色，夜晚用设计稿值）
    property color injectedTextPrimary: "#2D2724"
    property color injectedTextSecondary: "#7C746D"
    readonly property color textPrimary: night ? Qt.rgba(1, 1, 1, 0.88) : injectedTextPrimary
    readonly property color textSecondary: night ? Qt.rgba(1, 1, 1, 0.56) : injectedTextSecondary
    readonly property color textTertiary: night ? Qt.rgba(1, 1, 1, 0.34)
                                               : Qt.rgba(0.40, 0.34, 0.28, 0.55)

    // 进度/数据条
    readonly property color trackBg: night ? Qt.rgba(1, 1, 1, 0.055)
                                           : Qt.rgba(0.40, 0.34, 0.28, 0.12)

    // 强调薄底（active 项 / pill）
    readonly property color accentSoft: night ? Qt.rgba(0.62, 0.90, 0.93, 0.075)
                                             : Qt.rgba(0.40, 0.55, 0.52, 0.16)
    readonly property color accentSoftBorder: night ? Qt.rgba(0.62, 0.90, 0.93, 0.17)
                                                   : Qt.rgba(0.40, 0.55, 0.52, 0.30)
    readonly property color accentText: night ? Qt.rgba(0.86, 0.96, 0.97, 0.88) : "#2F5C56"

    // 锁定（翻面）警示色
    readonly property color lockBg: night ? Qt.rgba(0.16, 0.11, 0.04, 0.52)
                                         : Qt.rgba(0.55, 0.42, 0.18, 0.20)
    readonly property color lockBorder: Qt.rgba(1, 0.84, 0.61, 0.22)
    readonly property color lockText: night ? Qt.rgba(1, 0.93, 0.80, 0.90) : "#7A5A1E"

    // APP 大背景图模糊层不透明度（.app-bg opacity .34）
    readonly property real ambientImageOpacity: night ? 0.34 : 0.22

    // 发光强度（白天显著降低）
    readonly property real glowStrength: night ? 1.0 : 0.45

    // 圆角
    readonly property int radiusPanel: 18
    readonly property int radiusCard: 18
    readonly property int radiusInner: 16

    // ============================================================
    // 蓝黑深度坡（Cookbook §2 / §4.1）：底→面越上越亮。夜晚 = 设计稿 :root --ml-bg-*；
    // 白天 = 米杏暖坡（与 stageBg 同族）。供 Shell 记忆湖/回顾背景与角落辅光对落座。
    // ============================================================
    readonly property color bg0: night ? "#05070D" : "#F4EFE6"   // 最深 void / 页底
    readonly property color bg1: night ? "#090D16" : "#EFE7DA"   // 深度坡 1
    readonly property color bg2: night ? "#0D1320" : "#E8DECF"   // 深度坡 2
    readonly property color bg3: night ? "#121A2A" : "#E0D4C2"   // 深度坡 3 / 最高不透明面

    // ============================================================
    // 显式阴影 / 边缘光令牌（Cookbook §2 / §3.4 / §3.5）
    // ============================================================
    // 廉价偏移色块投影（GlassPanel 用，黑↔暖灰随主题）
    readonly property color shadowColor: night ? "#05070D" : "#BFAE9D"
    readonly property real  shadowOpacity: night ? 0.22 : 0.10
    // MultiEffect 软投影（少数 Floating/Focused 焦点面用，如回顾壳）
    readonly property color shadowAmbient: night ? "#000000" : "#4E6A88"
    readonly property real  shadowSoftOpacity:  night ? 0.46 : 0.18   // --ml-shadow-soft
    readonly property real  shadowFocusOpacity: night ? 0.62 : 0.24   // --ml-shadow-focus
    // 顶沿 1px 内高光（主光斜面）：夜极淡、白天瓷光。配 panelBorderStrong 做「玻璃下唇」边缘光对。
    readonly property color edgeHighlight: night ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.62)

    // ============================================================
    // 品牌缓动三曲线（Cookbook §6.1 / 法规 X4）：y∈[0,1] 强 ease-out，不过冲；
    // 过冲请用关键帧中间值（SequentialAnimation），别指望曲线。全 app 引用，杜绝散落 bezier 数组。
    // ============================================================
    readonly property var easeSoft:   [0.2,  0.8, 0.2, 1, 1, 1]   // 柔落 soft-settle：卡滑动/翻面/弹层/折叠
    readonly property var easeSnappy:  [0.18, 0.9, 0.2, 1, 1, 1]   // 弹入 snappy：区块切换/揭示/脉冲
    readonly property var easeHero:    [0.16, 0.9, 0.2, 1, 1, 1]   // 英雄 gentle：海报/回顾壳

    // 饼图分类色（Cookbook §4.3：aqua/violet/gold/pink/slate，图例点与扇区严格对齐）
    readonly property color shareGold: "#FFE6A3"
    readonly property color sharePink: "#FF7A9A"
    readonly property color shareOther: night ? "#6F7C91" : "#9AA1B0"   // slate「其它」

    // ============================================================
    // v88 首页霓虹/玻璃复刻令牌（今日结论 / 今日事项格纹+霓虹 / 占比甜甜圈霓虹 / 时间河流）
    // ============================================================
    // 霓虹辉光青：设计稿 rgba(142,223,255) 系（比 aqua #9FE7EE 略偏蓝），用于今日结论/今日事项/
    // 占比面板的角向径向辉光、发丝边、甜甜圈 0 0 32px 外辉光。两主题同色，靠 glowStrength + 低 alpha 收昼。
    readonly property color glowCyan: "#8EDFFF"
    // 时间河流节点青：设计稿 rgba(130,239,255)。
    readonly property color nodeCyan: "#82EFFF"
    // .cards-zone 中栏卡区圆角暗箱底（设计稿 rgba(3,7,14,.28)）：半透，让 Shell 深度坡微透。
    readonly property color cardsZoneBg: night ? Qt.rgba(0.012, 0.027, 0.055, 0.28)
                                              : Qt.rgba(0.42, 0.46, 0.52, 0.10)
    // 网格纸纹线色（设计稿白发丝 .022~.035 / 昼用极淡墨线）：今日结论/今日事项/占比/时间图共用。
    readonly property color gridLine: night ? Qt.rgba(1, 1, 1, 0.032)
                                           : Qt.rgba(0.20, 0.26, 0.34, 0.05)
    // 甜甜圈中心孔暗填充（设计稿 rgba(20,24,34)→(10,13,21)）+ 顶部 aqua 高光；昼用浅瓷面。
    readonly property color donutHoleTop: night ? "#141822" : "#EEF3F8"
    readonly property color donutHoleBottom: night ? "#0A0D15" : "#DFE7EF"

    // 深色磨砂提示胶囊底（wheel-tip / 回顾 pill / mode-note 等半透黑底）
    readonly property color pillScrim: night ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(0, 0, 0, 0.06)

    // 月度回顾专用（设计稿 .summary-* 有效最终值）
    readonly property color recapBackdrop: night ? Qt.rgba(0.008, 0.02, 0.04, 1.0) : Qt.rgba(0.10, 0.12, 0.18, 0.97)
    readonly property color recapShell: night ? Qt.rgba(0.024, 0.04, 0.07, 1.0) : Qt.rgba(1, 1, 1, 0.92)
    readonly property color recapStage: night ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(0, 0, 0, 0.12)   // .summary-stage/.side（v25 最终 .20）
    readonly property color changeDown: "#FF8FB5"   // .change.down（对比下降色）
    // 回顾票根（kraft 纸）渐变与墨字（.ticket-card 设计稿固定色）
    readonly property color ticketTop: "#DED3BD"
    readonly property color ticketBottom: "#BFAE91"
    readonly property color ticketInk: "#1A130D"
    readonly property color ticketRow: Qt.rgba(0, 0, 0, 0.08)   // 票根行底（墨色薄底，随票根固定）
    // 封面/海报媒体底部暗罩（白字压在生成式封面上保可读，两主题同为暗罩）
    readonly property color mediaScrim: Qt.rgba(0, 0, 0, 0.78)

    // ============================================================
    // v88 备忘黑板复刻令牌（memo overlay）。黑板**恒为暗**（G10：不分昼夜、点阵画在底层），
    // 故以下令牌不随 night 切换。详见 docs/memory-lake-memo-render-pipeline-replication.md
    // §1.1/§4.1/§4.2/§9。色/角辉复用既有 glowCyan(#8EDFFF)/violet。
    // ============================================================
    // 黑板近黑竖渐变（设计稿 .memo-overlay V41：rgba(9,11,18,.82) → rgba(6,8,14,.86)）
    readonly property color memoBoardTop: Qt.rgba(9 / 255, 11 / 255, 18 / 255, 0.82)
    readonly property color memoBoardBottom: Qt.rgba(6 / 255, 8 / 255, 14 / 255, 0.86)
    // 整体压暗黑罩（::before rgba(0,0,0,.10)）
    readonly property color memoScrim: Qt.rgba(0, 0, 0, 0.10)
    // 黑板点阵（设计稿 radial 白点 10.5% / 1px 半径 / 24px 平铺）
    readonly property color memoDotColor: Qt.rgba(1, 1, 1, 0.105)
    readonly property int memoDotPitch: 24
    readonly property real memoDotRadius: 1
    // 角落辅光不透明度（设计稿 aqua 左上 18%,12% @6% / violet 右下 76%,72% @5.5%）
    readonly property real memoGlowAquaOpacity: 0.06
    readonly property real memoGlowVioletOpacity: 0.055
    // 黑板磨砂：身后首页快照重模糊半径（M0 等效 backdrop-filter blur(10px)，QML 用更大值更糊）
    readonly property real memoBackdropBlurMax: 40
    // 粉笔墨水（设计稿 rgba(255,236,150,.96) 暖粉笔黄 #FFEC96）+ 笔宽 4 / 橡皮宽 28
    readonly property color memoInk: Qt.rgba(255 / 255, 236 / 255, 150 / 255, 0.96)
    readonly property real memoPenWidth: 4
    readonly property real memoEraserWidth: 28
    // 笔色调板（gap #2）：暖粉笔黄(默认) + 青/紫/粉/薄荷/白，统一 chalk 透明度。
    readonly property var memoInkPalette: [
        memoInk,
        Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.94),
        Qt.rgba(155 / 255, 139 / 255, 255 / 255, 0.94),
        Qt.rgba(216 / 255, 138 / 255, 172 / 255, 0.94),
        Qt.rgba(168 / 255, 240 / 255, 184 / 255, 0.94),
        Qt.rgba(255 / 255, 255 / 255, 255 / 255, 0.92)
    ]
    // 便签暖黄纸（设计稿 .sticky-note #FFE6A3，与 shareGold 同值、语义独立）+ 便签墨字
    readonly property color stickyPaper: "#FFE6A3"
    readonly property color stickyInk: "#1E1E1E"
    // aqua 选中环（设计稿 rgba(142,223,255,.58)，复用 glowCyan 色 + alpha）
    readonly property color memoSelectRing: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.58)
    // 工具条「更多/退出」破坏红（设计稿 .exit hover rgba(255,95,95,.22)）
    readonly property color memoDanger: Qt.rgba(255 / 255, 95 / 255, 95 / 255, 1.0)
    // 番茄钟色族（设计稿 #FF5B5E 红 + 琥珀双闪 rgba(255,230,163)）；进度条 aqua→violet 复用既有色。
    readonly property color pomodoroRed: "#FF5B5E"
    readonly property color pomodoroRedDark: "#D8413F"
    readonly property color pomodoroRedHi: "#FF9A8A"
    readonly property color pomodoroLeaf: "#5FBF6B"
    readonly property color pomodoroLeafDark: "#3E8F4E"
    readonly property color pomodoroAmber: Qt.rgba(255 / 255, 230 / 255, 163 / 255, 1.0)

    // ============================================================
    // v88 日历页复刻令牌（calendar）。夜 = 设计稿 .calendar-* 暗玻璃原值（1:1）；
    // 昼 = light 覆盖（~13289 / 13524 / 13632）派生浅瓷映射。事件类型固定语义色三种。
    // 详见 docs/calendar-refactor-render-pipeline-replication.md §1。
    // ============================================================
    // 整页基底竖直近黑渐变（不透明替代 backdrop-filter：设计稿 rgba(20,24,34,.94)→rgba(8,11,18,.94)）
    readonly property color calPageTop:     night ? "#141822" : "#FCFDFE"
    readonly property color calPageBottom:  night ? "#080B12" : "#F1F6FA"
    // .calendar-panel 玻璃底（设计稿 rgba(255,255,255,.045)）— 供非 GlassPanel 处复用
    readonly property color calPanelBg:     night ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.86)
    // 下沉小卡 / 表单输入 / 选中日卡底（设计稿 rgba(0,0,0,.16~.18)）
    readonly property color calSunkBg:      night ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(0.40, 0.46, 0.54, 0.06)
    // 表单输入 aqua 描边（设计稿 rgba(142,223,255,.12)；昼用墨青）
    readonly property color calInputBorder: night ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.12)
                                                  : Qt.rgba(8 / 255, 145 / 255, 178 / 255, 0.20)
    // cell 发丝分隔线（右/下 1px，设计稿 rgba(255,255,255,.055)；昼 rgba(24,42,62,.10)）
    readonly property color cellHair:       night ? Qt.rgba(1, 1, 1, 0.055)
                                                  : Qt.rgba(24 / 255, 42 / 255, 62 / 255, 0.10)
    // 今日 cell 底洗（设计稿 aqua .04）
    readonly property color todayWash:      night ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.04)
                                                  : Qt.rgba(8 / 255, 145 / 255, 178 / 255, 0.06)
    // cell hover 洗（设计稿 aqua .055）
    readonly property color cellHover:      night ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.055)
                                                  : Qt.rgba(8 / 255, 145 / 255, 178 / 255, 0.05)
    // 选中日 2px 描边环（设计稿 aqua .32）
    readonly property color selectedRing:   night ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.32)
                                                  : Qt.rgba(8 / 255, 145 / 255, 178 / 255, 0.42)
    // cell 日号字（设计稿 rgba(245,250,255,.78)；今日转 aqua 由用处给）
    readonly property color cellDateText:   night ? Qt.rgba(245 / 255, 250 / 255, 255 / 255, 0.78)
                                                  : Qt.rgba(0.18, 0.22, 0.28, 0.82)
    // 事件胶囊三类型色（event=aqua / todo=琥珀 / focus=violet）+ 胶囊墨字
    readonly property color chipEventBg:    night ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.12)
                                                  : Qt.rgba(8 / 255, 145 / 255, 178 / 255, 0.12)
    readonly property color chipEventBd:    night ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.14)
                                                  : Qt.rgba(8 / 255, 145 / 255, 178 / 255, 0.22)
    readonly property color chipTodoBg:     night ? Qt.rgba(255 / 255, 230 / 255, 163 / 255, 0.10)
                                                  : Qt.rgba(176 / 255, 132 / 255, 24 / 255, 0.12)
    readonly property color chipTodoBd:     night ? Qt.rgba(255 / 255, 230 / 255, 163 / 255, 0.16)
                                                  : Qt.rgba(176 / 255, 132 / 255, 24 / 255, 0.24)
    readonly property color chipFocusBg:    night ? Qt.rgba(155 / 255, 139 / 255, 255 / 255, 0.12)
                                                  : Qt.rgba(109 / 255, 91 / 255, 208 / 255, 0.14)
    readonly property color chipFocusBd:    night ? Qt.rgba(155 / 255, 139 / 255, 255 / 255, 0.16)
                                                  : Qt.rgba(109 / 255, 91 / 255, 208 / 255, 0.26)
    readonly property color chipText:       night ? Qt.rgba(245 / 255, 250 / 255, 255 / 255, 0.88)
                                                  : Qt.rgba(0.16, 0.20, 0.26, 0.92)
    // toast 磨砂底（设计稿 rgba(14,18,26,.86)）
    readonly property color calToastBg:     night ? Qt.rgba(14 / 255, 18 / 255, 26 / 255, 0.86)
                                                  : Qt.rgba(255 / 255, 255 / 255, 255 / 255, 0.94)
    // event-add / 主按钮亮渐变上的近黑墨字（设计稿 rgba(4,8,14,.92)）
    readonly property color calBtnInk:      Qt.rgba(4 / 255, 8 / 255, 14 / 255, 0.92)
}
