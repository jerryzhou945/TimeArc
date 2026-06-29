import QtQuick
import QtQuick.Controls
import QtQuick.Window
import time_arc

ApplicationWindow {
    id: appWindow

    property bool runningOnAndroid: Qt.platform.os === "android"
    property bool useMobileShell: runningOnAndroid || mobilePreview || width <= 720
    property bool forceQuit: false
    property bool hideToTrayOnClose: !(runningOnAndroid || mobilePreview)

    // 无边框化（去掉 Win11 原生白色标题栏，改用自绘沉浸式 chrome）。
    // 仅真桌面无边框；移动预览（开发工具）保留原生边框，方便挪窗/关闭。
    // MinMaxButtonsHint：即便无边框，Windows 仍启用最小化动画 + Win+方向键贴靠。
    readonly property bool frameless: !(runningOnAndroid || mobilePreview)
    flags: frameless ? (Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinMaxButtonsHint)
                     : Qt.Window
    // 自绘标题栏高度 = 各 shell 顶部为交互内容预留的高度（背景仍铺到顶边，保沉浸）。
    readonly property int chromeReserve: frameless ? 40 : 0

    // 桌面默认 16:9（1440x810），可自由缩放、全屏铺满（不再锁 16:10——那会让 16:9 屏右侧露桌面）。
    // 最小取 1280x720（标准 16:9 下限）：记忆湖三栏需 ~1240px 宽中间卡牌才不会被左右栏遮住；
    // 960 宽时 300+310 两栏几乎贴合、中卡被遮（实测），故以 1280x720 作可用下限。
    width: useMobileShell ? 390 : 1440
    height: useMobileShell ? 844 : 810
    minimumWidth: useMobileShell ? 360 : 1280
    minimumHeight: useMobileShell ? 600 : 720
    visible: !startInTray
    title: qsTr("TimeArc")
    color: "#F6F1EA"

    function restoreFromTray() {
        visible = true
        if (visibility === Window.Minimized)
            showNormal()
        raise()
        requestActivate()
    }

    function quitFromTray() {
        forceQuit = true
        Qt.quit()
    }

    // G-WIN 恢复窗口位置：关闭时保存归一化几何（仅普通窗口态——无边框最大化的 visibility 报
    // FullScreen，跳过以免存成全屏尺寸），启动时按「启动时恢复上次位置」恢复。只写 UI 私有
    // 设置 KV，不动 usage/磁盘契约。移动预览不参与。
    Component.onCompleted: {
        if (mobilePreview || !settingsRepository) return;
        if (!settingsRepository.getBool("restore_window", true)) return;
        var w = parseInt(settingsRepository.getValue("window_width", ""));
        var h = parseInt(settingsRepository.getValue("window_height", ""));
        var px = parseInt(settingsRepository.getValue("window_x", ""));
        var py = parseInt(settingsRepository.getValue("window_y", ""));
        // 钳进当前屏幕：尺寸不超可用桌面、不低于最小；位置须落在虚拟桌面内（留可见余量），
        // 否则显示器变更/拔除后无边框窗口会飞出屏外且难拖回。
        if (!isNaN(w)) width = Math.max(minimumWidth, Math.min(w, Screen.desktopAvailableWidth));
        if (!isNaN(h)) height = Math.max(minimumHeight, Math.min(h, Screen.desktopAvailableHeight));
        if (!isNaN(px) && !isNaN(py)) {
            var maxX = Screen.virtualX + Screen.virtualWidth - 80;
            var maxY = Screen.virtualY + Screen.virtualHeight - 80;
            if (px >= Screen.virtualX && px <= maxX && py >= Screen.virtualY && py <= maxY) {
                x = px; y = py;
            }
        }
    }
    onClosing: function (close) {
        if (!mobilePreview && settingsRepository && visibility === Window.Windowed) {
            settingsRepository.setValue("window_width", "" + Math.round(width));
            settingsRepository.setValue("window_height", "" + Math.round(height));
            settingsRepository.setValue("window_x", "" + Math.round(x));
            settingsRepository.setValue("window_y", "" + Math.round(y));
        }
        if (hideToTrayOnClose && !forceQuit) {
            close.accepted = false
            hide()
            if (shellLoader.item && shellLoader.item.notifyClosedToTray)
                shellLoader.item.notifyClosedToTray()
        }
    }

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
            onTrayShowRequested: appWindow.restoreFromTray()
            onTrayQuitRequested: appWindow.quitFromTray()
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
