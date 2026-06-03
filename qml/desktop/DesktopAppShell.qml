import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import time_arc
import "components/AppVisual.js" as AppVisual

Item {
    id: root
    anchors.fill: parent

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

    // =========================
    // 背景图路径
    // 白天 / 夜晚分别一张图
    // =========================
    property string dayBackgroundSource: Qt.resolvedUrl("../../resources/background.png")
    property string nightBackgroundSource: Qt.resolvedUrl("../../resources/background_night.png")

    // 当前实际使用的背景图
    property string appBackgroundSource: nightMode ? nightBackgroundSource : dayBackgroundSource

    // 记忆湖：整个 App 背景改为当前 APP 的 appColor 色彩晕染（§4.4，取代游戏海报模糊大图）。
    readonly property bool onMemoryLake: selectedPage === "memorylake" && !showingTimerPage
    // 记忆湖首页 + 月度回顾页都铺满内容区（去外框/玻璃，让暗色水面铺满整窗）。
    readonly property bool fullBleedPage:
        (selectedPage === "memorylake" || selectedPage === "recap") && !showingTimerPage
    readonly property bool memoryLakeHasAmbient:
        onMemoryLake && pageLoader.item && ("hasAmbient" in pageLoader.item) && pageLoader.item.hasAmbient
    readonly property color memoryLakeAmbientColor:
        (onMemoryLake && pageLoader.item && ("ambientColor" in pageLoader.item)) ? pageLoader.item.ambientColor : "#9FE7EE"
    // 当前 APP 图标主色数组（多色 blend 背景用）；缺失退回单色。
    readonly property var memoryLakeAmbientColors:
        (onMemoryLake && pageLoader.item && ("ambientColors" in pageLoader.item)) ? pageLoader.item.ambientColors : [memoryLakeAmbientColor]

    // 记忆湖时导航栏配色对齐记忆湖左右玻璃面板（MemoryLakeStyle 的 panel/accent 值）
    readonly property color mlNavGlass: nightMode ? Qt.rgba(0.055, 0.080, 0.130, 0.86) : Qt.rgba(1, 1, 1, 0.66)
    readonly property color mlNavBorder: nightMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0.40, 0.34, 0.28, 0.22)
    readonly property color mlNavSelected: nightMode ? Qt.rgba(0.62, 0.90, 0.93, 0.12) : Qt.rgba(0.40, 0.55, 0.52, 0.16)
    readonly property color mlNavSelectedBorder: nightMode ? Qt.rgba(0.62, 0.90, 0.93, 0.24) : Qt.rgba(0.40, 0.55, 0.52, 0.30)
    readonly property color mlNavSoft: nightMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color mlNavAccent: nightMode ? "#9FE7EE" : "#CFE8D8"

    // =========================
    // 全局主题颜色
    // 白天：奶油薄荷、米杏、浅粉紫
    // 夜晚：保留低亮度雾感紫灰
    // =========================

    // 文字颜色
    property color appTextPrimary: nightMode ? "#F3F0FF" : "#2D2724"
    property color appTextSecondary: nightMode ? "#C9C4DD" : "#7C746D"

    // 侧边栏玻璃层与边框（记忆湖时对齐左右玻璃面板）
    property color appSidebarGlass: onMemoryLake ? mlNavGlass : (nightMode ? "#34394F" : "#FBF8F4")
    property color appSidebarBorder: onMemoryLake ? mlNavBorder : (nightMode ? "#5F6687" : "#E8E0D8")

    // 主内容区玻璃层与边框
    property color appPanelGlass: nightMode ? "#3C425C" : "#FBF8F4"
    property color appPanelBorder: nightMode ? "#626A90" : "#E8E0D8"

    // 当前选中的导航项
    property color appSelectedItem: onMemoryLake ? mlNavSelected : (nightMode ? "#596184" : "#DDF1E5")
    property color appSelectedItemBorder: onMemoryLake ? mlNavSelectedBorder : (nightMode ? "#8188B1" : "#BFDCCB")

    // 收起侧栏按钮
    property color appCollapseButton: onMemoryLake ? mlNavSoft : (nightMode ? "#4B526F" : "#F4E8C8")
    property color appCollapseButtonBorder: onMemoryLake ? mlNavBorder : (nightMode ? "#767DA7" : "#E8D9BC")

    // 强调色（logo 圆点 / 强调按钮）
    // 白天偏奶茶，夜晚偏柔和蓝紫；记忆湖偏霓虹 aqua
    property color appAccentWarm: onMemoryLake ? mlNavAccent : (nightMode ? "#8E93D8" : "#CFE8D8")
    property color appAccentWarmText: onMemoryLake ? "#05070D" : (nightMode ? "#F8F7FF" : "#2D2724")

    // 左下角陪伴卡片
    property color appBottomCardBorder: onMemoryLake ? mlNavBorder : (nightMode ? "#7078A5" : "#E8E0D8")
    property color appBottomCardGlass: onMemoryLake ? mlNavSoft : (nightMode ? "#444B67" : "#FFFDF9")

    // 夜晚模式下的小高光文字
    property color appNightAccentText: "#BFC7FF"
    property color appShadowColor: nightMode ? "#05070D" : "#BFAE9D"

    // =========================
    // 左侧导航项
    // =========================
    // 顺序 / 文案对齐 v88 设计稿。page = 路由键（与下标解耦，供 currentPageSource /
    // onMemoryLake / 信号连接使用）；bottom = true 的项固定在菜单最底部（月度回顾）。
    property var navItems: [
        { title: "首页", subtitle: "Dashboard", page: "memorylake",
          icon: Qt.resolvedUrl("../../resources/icons/home.svg") },
        { title: "日历", subtitle: "Calendar", page: "calendar",
          icon: Qt.resolvedUrl("../../resources/icons/calendar.svg") },
        { title: "统计", subtitle: "Stats", page: "stats",
          icon: Qt.resolvedUrl("../../resources/icons/stats.svg") },
        { title: "设置", subtitle: "Settings", page: "settings",
          icon: Qt.resolvedUrl("../../resources/icons/settings.svg") },
        { title: "备忘", subtitle: "Notes", page: "notes",
          icon: Qt.resolvedUrl("../../resources/icons/chat.svg") },
        { title: "记忆湖", subtitle: "Memory Recap", page: "recap", bottom: true,
          icon: Qt.resolvedUrl("../../resources/icons/recap.svg") }
    ]

    readonly property var topNavItems: navItems.filter(function (it) { return !it.bottom })
    readonly property var bottomNavItems: navItems.filter(function (it) { return it.bottom })

    // 当前选中项的路由键。
    readonly property string selectedPage:
        (selectedIndex >= 0 && selectedIndex < navItems.length)
            ? navItems[selectedIndex].page : "memorylake"

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
        case "memorylake": return Qt.resolvedUrl("pages/DesktopMemoryLakePage.qml");
        case "calendar":   return Qt.resolvedUrl("pages/DesktopCalenderPage.qml");
        case "stats":      return Qt.resolvedUrl("pages/DesktopStatsPage.qml");
        case "settings":   return Qt.resolvedUrl("pages/DesktopProfilePage.qml");
        case "notes":      return Qt.resolvedUrl("pages/DesktopChatPage.qml");
        case "recap":      return Qt.resolvedUrl("pages/DesktopMonthlyRecapPage.qml");
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
    }

    onNightModeChanged: {
        if (settingsRepository)
            settingsRepository.setBool("night_mode", nightMode)
        applyThemeToLoadedPage();
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
                opacity: nightMode ? 0.46 : 1.0
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: nightMode ? "#4E5578" : "#BFE4D0" }
                    GradientStop { position: 0.36; color: nightMode ? "#3F4665" : "#F2DFAF" }
                    GradientStop { position: 0.70; color: nightMode ? "#303650" : "#F8EFE7" }
                    GradientStop { position: 1.0; color: nightMode ? "#24283D" : "#E7B7C3" }
                }
                opacity: nightMode ? 0.28 : 0.52
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
                        return (arr && arr.length > 0) ? arr[Math.min(i, arr.length - 1)] : "#9FE7EE"
                    }
                    onColsChanged: {
                        if (frontIsA) { mlRectB.cols = cols; frontIsA = false }
                        else { mlRectA.cols = cols; frontIsA = true }
                    }
                    Component.onCompleted: { mlRectA.cols = cols; frontIsA = true }
                    Rectangle {
                        id: mlRectA
                        anchors.fill: parent
                        property var cols: mlBgSrc.cols
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(AppVisual.ambientTone(mlBgSrc.col(mlRectA.cols, 0), nightMode), 1.06) }
                            GradientStop { position: 0.5; color: AppVisual.ambientTone(mlBgSrc.col(mlRectA.cols, 1), nightMode) }
                            GradientStop { position: 1.0; color: Qt.darker(AppVisual.ambientTone(mlBgSrc.col(mlRectA.cols, 2), nightMode), 1.16) }
                        }
                        opacity: mlBgSrc.frontIsA ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
                    }
                    Rectangle {
                        id: mlRectB
                        anchors.fill: parent
                        property var cols: mlBgSrc.cols
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(AppVisual.ambientTone(mlBgSrc.col(mlRectB.cols, 0), nightMode), 1.06) }
                            GradientStop { position: 0.5; color: AppVisual.ambientTone(mlBgSrc.col(mlRectB.cols, 1), nightMode) }
                            GradientStop { position: 1.0; color: Qt.darker(AppVisual.ambientTone(mlBgSrc.col(mlRectB.cols, 2), nightMode), 1.16) }
                        }
                        opacity: mlBgSrc.frontIsA ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
                    }
                }
                // 点缀色块：两团模糊圆，取图标主色的**淡化色调**错位摆放——模糊后柔和混入，不夸张。
                Rectangle {
                    id: mlBlobA
                    width: Math.min(parent.width, parent.height) * 0.8
                    height: width; radius: width / 2
                    x: parent.width * 0.2 - width / 2
                    y: parent.height * 0.26 - height / 2
                    visible: false; layer.enabled: true
                    color: AppVisual.ambientTone(mlBgSrc.col(memoryLakeAmbientColors, 0), nightMode)
                    Behavior on color { ColorAnimation { duration: 450 } }
                }
                MultiEffect {
                    anchors.fill: mlBlobA; source: mlBlobA
                    blurEnabled: true; blur: 1.0; blurMax: 64
                    opacity: nightMode ? 0.16 : 0.24; autoPaddingEnabled: true
                }
                Rectangle {
                    id: mlBlobB
                    width: Math.min(parent.width, parent.height) * 0.74
                    height: width; radius: width / 2
                    x: parent.width * 0.8 - width / 2
                    y: parent.height * 0.72 - height / 2
                    visible: false; layer.enabled: true
                    color: AppVisual.ambientTone(mlBgSrc.col(memoryLakeAmbientColors, 1), nightMode)
                    Behavior on color { ColorAnimation { duration: 450 } }
                }
                MultiEffect {
                    anchors.fill: mlBlobB; source: mlBlobB
                    blurEnabled: true; blur: 1.0; blurMax: 64
                    opacity: nightMode ? 0.13 : 0.20; autoPaddingEnabled: true
                }
                // 轻压一层统一「水面」，淡淡的、保留清新色调（不再压成深色）。
                Rectangle {
                    anchors.fill: parent
                    color: nightMode ? Qt.rgba(0.05, 0.07, 0.11, 0.26) : Qt.rgba(0.14, 0.16, 0.22, 0.12)
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            // =========================
            // 左侧侧边栏
            // =========================
            Rectangle {
            id: sidebar
            width: sidebarCollapsed ? 88 : 232
            Layout.preferredWidth: width
            Layout.fillHeight: true
            radius: 30
            color: "transparent"
            border.width: 1
            border.color: appSidebarBorder

            Rectangle {
                x: 0
                y: 10
                width: parent.width
                height: parent.height
                radius: parent.radius
                color: appShadowColor
                opacity: nightMode ? 0.24 : 0.09
                z: -2
            }

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 29
                color: appSidebarGlass
                opacity: nightMode ? 0.88 : 0.92
                z: -1
            }

            // 导航项委托：顶部主菜单与底部「记忆湖」入口共用（index 由 page 反查，与下标解耦）。
            Component {
                id: navItemDelegate
                Rectangle {
                    required property var modelData
                    readonly property int navIndex: root.indexOfPage(modelData.page)
                    readonly property bool isSel: selectedIndex === navIndex && !showingTimerPage

                    width: parent ? parent.width : 0
                    height: 56
                    radius: 18
                    color: isSel ? appSelectedItem
                                 : navMouse.containsMouse ? (nightMode ? "#4B526F" : "#F4E8C8")
                                                          : "transparent"
                    border.width: isSel ? 1 : 0
                    border.color: appSelectedItemBorder

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: sidebarCollapsed ? undefined : parent.left
                        anchors.leftMargin: sidebarCollapsed ? 0 : 16
                        anchors.horizontalCenter: sidebarCollapsed ? parent.horizontalCenter : undefined
                        spacing: 14

                        Image {
                            source: modelData.icon
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
                                text: modelData.title
                                color: isSel ? appTextPrimary : appTextSecondary
                                font.pixelSize: 16
                                font.weight: Font.Medium
                            }

                            Text {
                                text: modelData.subtitle ? modelData.subtitle : ""
                                visible: text.length > 0
                                color: appTextSecondary
                                font.pixelSize: 10
                                opacity: 0.7
                            }
                        }
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            showingTimerPage = false;
                            selectedIndex = navIndex;
                        }
                    }
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 16

                // 顶部 Logo
                Row {
                    width: parent.width
                    height: 62
                    spacing: 12

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: appAccentWarm
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "T"
                            color: appAccentWarmText
                            font.pixelSize: 17
                            font.bold: true
                        }
                    }

                    Text {
                        visible: !sidebarCollapsed
                        text: "TimeArc"
                        color: appTextPrimary
                        font.pixelSize: 23
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
                            text: "收起侧栏"
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

                // 左下角状态卡片
                Rectangle {
                    visible: !sidebarCollapsed
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
                            text: "记忆湖陪伴"
                            color: appTextPrimary
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            text: nightMode ? "夜晚模式中" : "白天模式中"
                            color: nightMode ? appNightAccentText : "#2F7A5B"
                            font.pixelSize: 22
                            font.bold: true
                        }

                        Text {
                            text: nightMode ? "今晚也慢慢积累。" : "慢慢积累，也很好。"
                            color: appTextSecondary
                            font.pixelSize: 13
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

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    // 记忆湖/月度回顾几乎铺满占位符（卡牌作为背景层覆盖最大圆角方体，Issue 2）
                    anchors.margins: fullBleedPage ? 8 : 22
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

                        // 记忆湖首页 / 月度回顾页：请求切页（今日事项「日历」、返回湖面等）。
                        if ((selectedPage === "memorylake" || selectedPage === "recap")
                                && item.requestNavigate) {
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
                            if ("nightMode" in item)
                                item.nightMode = nightMode;
                        }

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
