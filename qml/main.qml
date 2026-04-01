import QtQuick
import QtQuick.Controls
import time_arc

ApplicationWindow {
    width: 1440
    height: 900
    visible: true
    title: qsTr("TimeArc")
    color: "#F6F1EA"

    DesktopAppShell {
        anchors.fill: parent
    }
}
