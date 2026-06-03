import QtQuick
import "../memorylake"

// 月度记忆回顾：独立页面（菜单底部「记忆湖 / Memory Recap」）。
// 原本是记忆湖页内的覆盖层，现拆为整页。打开即自动播放；返回湖面 / Esc → 回首页。
Item {
    id: root
    anchors.fill: parent
    clip: true

    // —— 主题契约（由 DesktopAppShell.applyThemeToLoadedPage 注入）——
    property bool nightMode: true
    property color themeTextPrimary: "#2D2724"
    property color themeTextSecondary: "#7C746D"
    property color themePanelColor: "#FBF8F4"
    property color themeBorderColor: "#E8E0D8"
    property color themeAccentColor: "#CFE8D8"

    // 请求切换导航页（shell 在 onLoaded 里连接）。
    signal requestNavigate(string pageKey)

    // 月度回顾模型：用首页同款只读路径取当月+上月数据，交后端组装（QML 只渲染）。
    property var recapModel: ({})
    property var recapApps: []
    function buildRecap() {
        if (!usageStatManager || !dailyCardService) {
            root.recapModel = ({}); root.recapApps = []; return;
        }
        usageStatManager.refresh();
        var monthApps = usageStatManager.activeSoftwareForRange("month");
        var monthSegs = usageStatManager.foregroundSegmentsForRange("month");
        var now = new Date();
        var y = now.getFullYear();
        var m = now.getMonth() + 1;
        var pm = m === 1 ? 12 : m - 1;
        var py = m === 1 ? y - 1 : y;
        var lastApps = usageStatManager.activeSoftwareForMonth(py, pm);
        var series = usageStatManager.dailySecondsForMonth(y, m);
        root.recapApps = monthApps;
        root.recapModel = dailyCardService.memoryLakeRecap(monthApps, monthSegs, lastApps, series);
    }

    Component.onCompleted: {
        root.buildRecap();
        recap.open();
    }

    MemoryLakeStyle {
        id: ml
        night: root.nightMode
        injectedTextPrimary: root.themeTextPrimary
        injectedTextSecondary: root.themeTextSecondary
    }

    RecapOverlay {
        id: recap
        anchors.fill: parent
        style: ml
        apps: root.recapApps
        model: root.recapModel
        onExitRequested: root.requestNavigate("memorylake")
    }
}
