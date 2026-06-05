import QtQuick
import QtQuick.Controls
import time_arc

ApplicationWindow {
    id: appWindow

    property bool useMobileShell: mobilePreview || width <= 720

    // 无边框化（去掉 Win11 原生白色标题栏，改用自绘沉浸式 chrome）。
    // 仅真桌面无边框；移动预览（开发工具）保留原生边框，方便挪窗/关闭。
    // MinMaxButtonsHint：即便无边框，Windows 仍启用最小化动画 + Win+方向键贴靠。
    readonly property bool frameless: !mobilePreview
    flags: frameless ? (Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinMaxButtonsHint)
                     : Qt.Window
    // 自绘标题栏高度 = 各 shell 顶部为交互内容预留的高度（背景仍铺到顶边，保沉浸）。
    readonly property int chromeReserve: frameless ? 40 : 0

    // 桌面默认 16:9（1440x810），可自由缩放、全屏铺满（不再锁 16:10——那会让 16:9 屏右侧露桌面）。
    // 最小取 1280x720（标准 16:9 下限）：记忆湖三栏需 ~1240px 宽中间卡牌才不会被左右栏遮住；
    // 960 宽时 300+310 两栏几乎贴合、中卡被遮（实测），故以 1280x720 作可用下限。
    width: mobilePreview ? 390 : 1440
    height: mobilePreview ? 844 : 810
    minimumWidth: mobilePreview ? 360 : 1280
    minimumHeight: mobilePreview ? 600 : 720
    visible: true
    title: qsTr("TimeArc")
    color: "#F6F1EA"

    Loader {
        id: shellLoader
        anchors.fill: parent
        sourceComponent: useMobileShell ? mobileShell : desktopShell
    }

    Component {
        id: desktopShell

        DesktopAppShell {
            anchors.fill: parent
            topReserve: appWindow.chromeReserve
        }
    }

    Component {
        id: mobileShell

        MobileAppShell {
            anchors.fill: parent
            topReserve: appWindow.chromeReserve
        }
    }

    // 自定义窗口 chrome（无边框时）：浮在所有 shell 之上、中心穿透。
    // 备忘黑板为全屏模态（自带退出 + 顶部工具条/档案袋），开启时让位隐藏，避免顶部冲突。
    WindowChrome {
        anchors.fill: parent
        window: appWindow
        barHeight: appWindow.chromeReserve
        iconSource: Qt.resolvedUrl("../resources/icons/app_icon.svg")
        dark: shellLoader.item && ("prefersLightChrome" in shellLoader.item)
              ? shellLoader.item.prefersLightChrome : false
        visible: appWindow.frameless
                 && !(shellLoader.item && ("memoOpen" in shellLoader.item)
                      && shellLoader.item.memoOpen)
    }
}
