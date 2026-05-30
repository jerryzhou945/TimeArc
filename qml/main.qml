import QtQuick
import QtQuick.Controls
import time_arc

ApplicationWindow {
    width: 1440
    height: 900
    visible: true
    title: qsTr("TimeArc")
    color: "#F6F1EA"

    Loader {
        anchors.fill: parent
        sourceComponent: desktopShell
    }

    Component {
        id: desktopShell

        DesktopAppShell {
            anchors.fill: parent
        }
    }
}
