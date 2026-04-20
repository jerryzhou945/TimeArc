import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import time_arc

Item {
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
    property bool nightMode: false

    // =========================
    // 背景图路径
    // 白天 / 夜晚分别一张图
    // =========================
    property string dayBackgroundSource: Qt.resolvedUrl("../../resources/background.png")
    property string nightBackgroundSource: Qt.resolvedUrl("../../resources/background_night.png")

    // 当前实际使用的背景图
    property string appBackgroundSource: nightMode ? nightBackgroundSource : dayBackgroundSource

    // =========================
    // 全局主题颜色
    // 白天：奶油薄荷、米杏、浅粉紫
    // 夜晚：保留低亮度雾感紫灰
    // =========================

    // 文字颜色
    property color appTextPrimary: nightMode ? "#F3F0FF" : "#2D2724"
    property color appTextSecondary: nightMode ? "#C9C4DD" : "#7C746D"

    // 侧边栏玻璃层与边框
    property color appSidebarGlass: nightMode ? "#34394F" : "#FBF8F4"
    property color appSidebarBorder: nightMode ? "#5F6687" : "#E8E0D8"

    // 主内容区玻璃层与边框
    property color appPanelGlass: nightMode ? "#3C425C" : "#FBF8F4"
    property color appPanelBorder: nightMode ? "#626A90" : "#E8E0D8"

    // 当前选中的导航项
    property color appSelectedItem: nightMode ? "#596184" : "#DDF1E5"
    property color appSelectedItemBorder: nightMode ? "#8188B1" : "#BFDCCB"

    // 收起侧栏按钮
    property color appCollapseButton: nightMode ? "#4B526F" : "#F4E8C8"
    property color appCollapseButtonBorder: nightMode ? "#767DA7" : "#E8D9BC"

    // 强调色（logo 圆点 / 强调按钮）
    // 白天偏奶茶，夜晚偏柔和蓝紫
    property color appAccentWarm: nightMode ? "#8E93D8" : "#CFE8D8"
    property color appAccentWarmText: nightMode ? "#F8F7FF" : "#2D2724"

    // 左下角陪伴卡片
    property color appBottomCardBorder: nightMode ? "#7078A5" : "#E8E0D8"
    property color appBottomCardGlass: nightMode ? "#444B67" : "#FFFDF9"

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
            title: "聊天",
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
    // 这里继续保留你现在已经验证能跑的
    // Loader.source 路径切页方案
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
        applyThemeToLoadedPage();
    }

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
            opacity: nightMode ? 0.52 : 0.06
            smooth: true
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: nightMode ? "#2D3148" : "#E8F4EC"
                }
                GradientStop {
                    position: 0.46
                    color: nightMode ? "#353A56" : "#F7F3EE"
                }
                GradientStop {
                    position: 1.0
                    color: nightMode ? "#3B4160" : "#FBF8F4"
                }
            }
            opacity: nightMode ? 0.46 : 0.96
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: nightMode ? "#4E5578" : "#CFE8D8" }
                GradientStop { position: 0.38; color: nightMode ? "#3F4665" : "#F4E8C8" }
                GradientStop { position: 0.72; color: nightMode ? "#303650" : "#F7F3EE" }
                GradientStop { position: 1.0; color: nightMode ? "#24283D" : "#EBC9CF" }
            }
            opacity: nightMode ? 0.28 : 0.42
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
        Rectangle {
            id: contentPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 32
            color: "transparent"
            border.width: 1
            border.color: appPanelBorder

            Rectangle {
                x: 0
                y: 12
                width: parent.width
                height: parent.height
                radius: parent.radius
                color: appShadowColor
                opacity: nightMode ? 0.26 : 0.08
                z: -2
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 31
                color: appPanelGlass
                opacity: nightMode ? 0.76 : 0.84
                z: -1
            }

            Loader {
                id: pageLoader
                anchors.fill: parent
                anchors.margins: 22
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

                    // 首页：连接导入软件信号
                    if (selectedIndex === 0 && item.importSoftware) {
                        item.importSoftware.connect(function () {
                            console.log("导入想查看时间的软件");
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

    // =========================
    // 监听计时结束
    // 结束后：
    // 1. 把本次时间累计到项目
    // 2. 返回首页
    // =========================
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
