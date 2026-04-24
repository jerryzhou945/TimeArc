import QtQuick
import QtQuick.Controls
import time_arc

ApplicationWindow {
    property bool forceMobileShell: typeof mobilePreview !== "undefined" && mobilePreview

    width: forceMobileShell ? 390 : 1440
    height: forceMobileShell ? 844 : 900
    visible: true
    title: forceMobileShell ? qsTr("TimeArc Mobile Preview") : qsTr("TimeArc")
    color: "#F6F1EA"

    Loader {
        anchors.fill: parent
        sourceComponent: forceMobileShell || width <= 720 ? mobileShell : desktopShell
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
