import QtQuick
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    required property var theme
    property bool reducedMotion: false
    property bool started: false
    signal finished()

    anchors.fill: parent
    z: 1000

    function begin() {
        if (root.reducedMotion) {
            root.opacity = 0
            Qt.callLater(root.finished)
            return
        }
        root.started = true
    }

    Rectangle {
        anchors.fill: parent
        color: root.theme.bg
    }

    Item {
        id: mark
        anchors.centerIn: parent
        width: Math.min(148, parent.width * 0.34)
        height: width
        transformOrigin: Item.Center

        Image {
            anchors.fill: parent
            source: "../../../resources/app/TimeArc.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Canvas {
            id: arc
            anchors.centerIn: parent
            width: parent.width * 1.24
            height: width
            rotation: -70

            onPaint: {
                var context = getContext("2d")
                context.reset()
                context.lineWidth = Math.max(2, width * 0.024)
                context.lineCap = "round"
                context.strokeStyle = root.theme.accentBright
                context.globalAlpha = 0.82
                context.beginPath()
                context.arc(width / 2, height / 2, width * 0.44,
                            -Math.PI * 0.72, Math.PI * 0.46)
                context.stroke()
            }
        }
    }

    SequentialAnimation {
        id: launchMotion
        running: root.started && !root.reducedMotion

        ParallelAnimation {
            NumberAnimation {
                target: arc
                property: "rotation"
                from: -70
                to: 290
                duration: 960
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: mark
                property: "scale"
                from: 0.9
                to: 1.0
                duration: 720
                easing.type: Easing.OutBack
            }
        }
        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: 160
            easing.type: Easing.OutCubic
        }
        ScriptAction { script: root.finished() }
    }

}
