import QtQuick
import QtQuick.Controls
import time_arc

ApplicationWindow {
    id: appWindow

    property real fixedAspectRatio: 16 / 10
    property bool enforcingAspectRatio: false

    width: 1440
    height: 900
    minimumWidth: 960
    minimumHeight: 600
    visible: true
    title: qsTr("TimeArc")
    color: "#F6F1EA"

    onWidthChanged: {
        if (enforcingAspectRatio || width <= 0)
            return
        enforcingAspectRatio = true
        height = Math.round(width / fixedAspectRatio)
        enforcingAspectRatio = false
    }

    onHeightChanged: {
        if (enforcingAspectRatio || height <= 0)
            return
        enforcingAspectRatio = true
        width = Math.round(height * fixedAspectRatio)
        enforcingAspectRatio = false
    }

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
