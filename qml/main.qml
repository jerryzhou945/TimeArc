import QtQuick
import QtQuick.Controls
import time_arc

ApplicationWindow {
    id: appWindow

    property real fixedAspectRatio: 16 / 10
    property bool enforcingAspectRatio: false
    property bool useMobileShell: mobilePreview || width <= 720

    width: mobilePreview ? 390 : 1440
    height: mobilePreview ? 844 : 900
    minimumWidth: 360
    minimumHeight: 600
    visible: true
    title: qsTr("TimeArc")
    color: "#F6F1EA"

    onWidthChanged: {
        if (enforcingAspectRatio || width <= 0 || useMobileShell)
            return
        enforcingAspectRatio = true
        height = Math.round(width / fixedAspectRatio)
        enforcingAspectRatio = false
    }

    onHeightChanged: {
        if (enforcingAspectRatio || height <= 0 || useMobileShell)
            return
        enforcingAspectRatio = true
        width = Math.round(height * fixedAspectRatio)
        enforcingAspectRatio = false
    }

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
