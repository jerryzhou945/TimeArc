import QtQuick
import QtQuick.Controls
import time_arc

ApplicationWindow {
    id: appWindow

    property bool useMobileShell: mobilePreview || width <= 720

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
        anchors.fill: parent
        sourceComponent: useMobileShell ? mobileShell : desktopShell
    }

    Component {
        id: desktopShell

        DesktopAppShell {
            anchors.fill: parent
        }
    }

    Component {
        id: mobileShell

        MobileAppShell {
            anchors.fill: parent
        }
    }
}
