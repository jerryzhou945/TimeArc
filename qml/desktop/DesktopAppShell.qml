import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import time_arc

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
    readonly property bool onMemoryLake: selectedIndex === 2 && !showingTimerPage
    readonly property bool memoryLakeHasAmbient:
        onMemoryLake && pageLoader.item && ("hasAmbient" in pageLoader.item) && pageLoader.item.hasAmbient
    readonly property color memoryLakeAmbientColor:
        (onMemoryLake && pageLoader.item && ("ambientColor" in pageLoader.item)) ? pageLoader.item.ambientColor : "#9FE7EE"

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
    property var navItems: [
        {
            title: "首页",
            icon: Qt.resolvedUrl("../../resources/icons/home.svg")
        },
        {
            title: "备忘",
            icon: Qt.resolvedUrl("../../resources/icons/chat.svg")
        },
        {
            title: "记忆湖",
            icon: Qt.resolvedUrl("../../resources/icons/home.svg")
        },
        {
            title: "日历",
            icon: Qt.resolvedUrl("../../resources/icons/calendar.svg")
        },
        {
            title: "统计",
            icon: Qt.resolvedUrl("../../resources/icons/stats.svg")
        },
        {
            title: "我的",
            icon: Qt.resolvedUrl("../../resources/icons/user.svg")
        }
    ]

    // =========================
    // 当前 Loader 要加载哪个页面
    // =========================
    property string currentPageSource: {
        if (showingTimerPage)
            return Qt.resolvedUrl("pages/DesktopTimerPage.qml");

        if (selectedIndex === 0)
            return Qt.resolvedUrl("pages/DesktopHomePage.qml");
        if (selectedIndex === 1)
            return Qt.resolvedUrl("pages/DesktopChatPage.qml");
        if (selectedIndex === 2)
            return Qt.resolvedUrl("pages/DesktopMemoryLakePage.qml");
        if (selectedIndex === 3)
            return Qt.resolvedUrl("pages/DesktopCalenderPage.qml");
        if (selectedIndex === 4)
            return Qt.resolvedUrl("pages/DesktopStatsPage.qml");
        if (selectedIndex === 5)
            return Qt.resolvedUrl("pages/DesktopProfilePage.qml");

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

            // 记忆湖：整个 App 背景 = 当前 APP 的 appColor 色彩晕染（§4.4 / issue A7）。
            // 不再用游戏海报模糊大图；改双色渐变交叉淡入（切换卡牌时柔和过渡），底部柔光晕。
            Item {
                anchors.fill: parent
                visible: onMemoryLake && memoryLakeHasAmbient
                // 双色渐变交叉淡入淡出：保留原 A/B 乒乓 + 450ms Behavior（仅把图换成色）。
                Item {
                    id: mlBgSrc
                    anchors.fill: parent
                    property color src: memoryLakeAmbientColor
                    property bool frontIsA: true
                    onSrcChanged: {
                        if (frontIsA) { mlRectB.tint = src; frontIsA = false }
                        else { mlRectA.tint = src; frontIsA = true }
                    }
                    Component.onCompleted: { mlRectA.tint = src; frontIsA = true }
                    Rectangle {
                        id: mlRectA
                        anchors.fill: parent
                        property color tint: mlBgSrc.src
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(mlRectA.tint, nightMode ? 0.85 : 1.06) }
                            GradientStop { position: 1.0; color: Qt.darker(mlRectA.tint, nightMode ? 2.4 : 1.30) }
                        }
                        opacity: mlBgSrc.frontIsA ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
                    }
                    Rectangle {
                        id: mlRectB
                        anchors.fill: parent
                        property color tint: mlBgSrc.src
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(mlRectB.tint, nightMode ? 0.85 : 1.06) }
                            GradientStop { position: 1.0; color: Qt.darker(mlRectB.tint, nightMode ? 2.4 : 1.30) }
                        }
                        opacity: mlBgSrc.frontIsA ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
                    }
                }
                // 点缀层：appColor 柔光晕（模糊圆），随选中色平滑过渡，增加"记忆湖"层次。
                Rectangle {
                    id: mlGlowSrc
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.20
                    width: Math.min(parent.width, parent.height) * 0.9
                    height: width
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                    color: memoryLakeAmbientColor
                    Behavior on color { ColorAnimation { duration: 450 } }
                }
                MultiEffect {
                    anchors.fill: mlGlowSrc
                    source: mlGlowSrc
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    opacity: nightMode ? 0.28 : 0.42
                    autoPaddingEnabled: true
                }
                // 整个 App 统一压成「记忆湖」暗色水面（避免中间亮四周暗的不一致）。
                Rectangle {
                    anchors.fill: parent
                    color: nightMode ? Qt.rgba(0.02, 0.03, 0.06, 0.50) : Qt.rgba(0.10, 0.13, 0.20, 0.34)
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

                // 导航列表
                Column {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: navItems

                        delegate: Rectangle {
                            required property int index
                            required property var modelData

                            width: parent.width
                            height: 56
                            radius: 18
                            color: selectedIndex === index && !showingTimerPage ? appSelectedItem
                                   : navMouse.containsMouse ? (nightMode ? "#4B526F" : "#F4E8C8")
                                                            : "transparent"
                            border.width: selectedIndex === index && !showingTimerPage ? 1 : 0
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
                                    opacity: selectedIndex === index && !showingTimerPage ? 1.0 : 0.72
                                }

                                Text {
                                    visible: !sidebarCollapsed
                                    text: modelData.title
                                    color: selectedIndex === index && !showingTimerPage ? appTextPrimary : appTextSecondary
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    showingTimerPage = false;
                                    selectedIndex = index;
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    Layout.fillHeight: true
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
                // 记忆湖时去掉内容区外框，让暗色水面真正铺满全 App、不再有「框中框」
                border.width: onMemoryLake ? 0 : 1
                border.color: appPanelBorder

                Rectangle {
                    x: 0
                    y: 12
                    width: parent.width
                    height: parent.height
                    radius: parent.radius
                    color: appShadowColor
                    opacity: onMemoryLake ? 0 : (nightMode ? 0.26 : 0.08)
                    z: -2
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 31
                    color: appPanelGlass
                    // 记忆湖时透明，让整个 App 模糊背景 + 卡牌占位符背景透出（Issue 1/2）
                    opacity: onMemoryLake ? 0 : (nightMode ? 0.76 : 0.82)
                    z: -1
                }

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    // 记忆湖几乎铺满占位符（卡牌作为背景层覆盖最大圆角方体，Issue 2）
                    anchors.margins: onMemoryLake ? 8 : 22
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

                        // 首页：连接开始计时信号
                        if (selectedIndex === 0 && item.startProject) {
                            item.startProject.connect(function (projectName, tagName) {
                                console.log("startProject signal received:", projectName);
                                if (timerManager) {
                                    pendingProjectTag = tagName;
                                    pendingTodoDateKey = "";
                                    pendingTodoText = "";
                                    pendingTodoTag = "";
                                    pendingTodoLinkedProject = "";
                                    timerManager.startProject(projectName);
                                    showingTimerPage = true;
                                }
                            });
                        }

                        // 我的页：连接夜晚模式开关信号
                        if (selectedIndex === 5 && item.nightModeToggled) {
                            item.nightModeToggled.connect(function (enabled) {
                                nightMode = enabled;
                            });
                        }

                        // 我的页：把当前 nightMode 同步给 profile page
                        if (selectedIndex === 5 && "nightMode" in item) {
                            item.nightMode = nightMode;
                        }

                        if (selectedIndex === 3 && item.startTodoProject) {
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
