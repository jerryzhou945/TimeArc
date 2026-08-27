import QtQuick
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }
    required property var profile
    property int pageIndex: 0
    property bool reducedMotion: false
    property real sceneScale: 1.0 + pageIndex * 0.012

    clip: true

    Image {
        id: sceneImage
        anchors.centerIn: parent
        width: parent.width * root.sceneScale
        height: parent.height * root.sceneScale
        source: root.profile.sceneSource || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true

        Behavior on scale {
            NumberAnimation {
                duration: root.reducedMotion ? 0 : 900
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#38101518" }
            GradientStop { position: 0.42; color: "#09000000" }
            GradientStop { position: 1.0; color: "#6E071015" }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.pageIndex % 2 === 0 ? "#08000000" : "#12132324"
    }

    Repeater {
        model: root.profile.particleCount || 0

        Item {
            id: particle
            required property int index

            readonly property string kind: root.profile.particleKind || "dust"
            readonly property real seedX: ((index * 47 + 13) % 101) / 100
            readonly property real seedY: ((index * 71 + 29) % 103) / 102
            readonly property real drift: 12 + (index % 5) * 7

            x: seedX * root.width
            y: seedY * root.height
            width: kind === "rain" || kind === "lateRain" || kind === "storm"
                   ? 2 : 6 + index % 8
            height: kind === "rain" || kind === "lateRain" || kind === "storm"
                    ? 22 + index % 26 : width
            opacity: 0.30 + (index % 5) * 0.09

            Rectangle {
                id: rainDrop
                anchors.fill: parent
                visible: particle.kind === "rain"
                         || particle.kind === "lateRain"
                         || particle.kind === "storm"
                radius: width / 2
                color: "#C9E9F1"
                rotation: 5
            }

            Rectangle {
                anchors.fill: parent
                visible: particle.kind === "snow" || particle.kind === "melt"
                radius: width / 2
                color: "#EDF7FC"
            }

            Rectangle {
                anchors.fill: parent
                visible: particle.kind === "firefly"
                radius: width / 2
                color: "#DFF585"
                border.width: 2
                border.color: "#55DFF585"
            }

            Rectangle {
                anchors.fill: parent
                visible: particle.kind === "dust"
                         || particle.kind === "grain"
                radius: width / 2
                color: particle.kind === "grain" ? "#E7C66F" : "#FFF0C7"
            }

            Rectangle {
                anchors.fill: parent
                visible: particle.kind === "petal"
                         || particle.kind === "leaf"
                         || particle.kind === "ginkgo"
                radius: particle.kind === "petal" ? width : 2
                color: particle.kind === "petal" ? "#F3BBC7"
                      : (particle.kind === "leaf" ? "#D9854F" : "#E7C75D")
                rotation: index * 31
            }

            SequentialAnimation on y {
                running: !root.reducedMotion
                loops: Animation.Infinite
                PauseAnimation { duration: particle.index * 73 }
                NumberAnimation {
                    from: -particle.height - particle.seedY * root.height
                    to: root.height + particle.height
                    duration: particle.kind === "rain"
                              || particle.kind === "lateRain"
                              || particle.kind === "storm"
                              ? 900 + particle.index % 7 * 95
                              : 5200 + particle.index % 9 * 430
                    easing.type: Easing.Linear
                }
            }

            SequentialAnimation on x {
                running: !root.reducedMotion
                loops: Animation.Infinite
                NumberAnimation {
                    from: particle.seedX * root.width - particle.drift
                    to: particle.seedX * root.width + particle.drift
                    duration: 1800 + particle.index % 6 * 310
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: particle.seedX * root.width - particle.drift
                    duration: 1800 + particle.index % 6 * 310
                    easing.type: Easing.InOutSine
                }
            }

            SequentialAnimation on opacity {
                running: !root.reducedMotion && particle.kind === "firefly"
                loops: Animation.Infinite
                NumberAnimation { to: 0.18; duration: 700 + particle.index * 21 }
                NumberAnimation { to: 0.92; duration: 900 + particle.index * 17 }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.profile.particleKind === "storm"
        color: "#44EAF7FF"
        opacity: 0

        SequentialAnimation on opacity {
            running: visible && !root.reducedMotion
            loops: Animation.Infinite
            PauseAnimation { duration: 3900 }
            NumberAnimation { to: 0.34; duration: 55 }
            NumberAnimation { to: 0.0; duration: 140 }
            PauseAnimation { duration: 1700 }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.36
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00101618" }
            GradientStop { position: 1.0; color: "#A7101618" }
        }
    }
}
