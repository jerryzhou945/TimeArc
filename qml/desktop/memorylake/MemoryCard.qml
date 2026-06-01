import QtQuick
import "MemoryLakeMock.js" as Mock

// 单张记忆卡牌：3D 翻面（Flipable + Y 轴旋转，自带透视），选中放大，悬停预览。
// 1:1 对应设计稿 .card / .face / 翻面 rotateY。
Item {
    id: card

    property MemoryLakeStyle style
    property var app
    property bool selected: false
    property bool flipped: false
    property bool previewed: false
    property bool dimmed: false   // 翻面锁定时其它卡变暗

    signal clicked()
    signal hoverEnter()
    signal hoverLeave()

    // 布局宽高（与设计稿一致；缩放是纯视觉变换，不影响居中计算）
    readonly property int layoutW: selected ? (flipped ? 380 : 330) : 156
    readonly property int layoutH: selected ? 455 : 310

    width: layoutW
    height: layoutH

    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    scale: selected ? 1.0 : (previewed ? 0.96 : 0.88)
    opacity: selected ? 1.0 : (dimmed ? 0.25 : (previewed ? 0.82 : 0.46))
    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 260 } }

    Flipable {
        id: flip
        anchors.fill: parent

        transform: Rotation {
            origin.x: card.width / 2
            origin.y: card.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: card.flipped ? 180 : 0
            Behavior on angle {
                NumberAnimation { duration: 680; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
            }
        }

        front: Rectangle {
            anchors.fill: parent
            radius: 18
            color: card.style ? card.style.faceBg : "#0D121D"
            border.width: 1
            border.color: card.selected ? (card.style ? card.style.faceBorderActive : "#9ef1ffb0")
                                         : (card.style ? card.style.faceBorder : "#ffffff14")
            clip: true

            Column {
                anchors.fill: parent
                // 封面图
                Item {
                    width: parent.width
                    height: card.selected ? 205 : 128
                    clip: true
                    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Image {
                        anchors.fill: parent
                        source: card.app ? Mock.imagePath(card.app.image) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: 0.88
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: card.style && card.style.night ? Qt.rgba(0.027, 0.035, 0.063, 0.6) : Qt.rgba(1, 1, 1, 0.35) }
                        }
                    }
                }
                // 文本区
                Column {
                    width: parent.width
                    padding: card.selected ? 18 : 13
                    spacing: 8
                    Text {
                        width: parent.width - (card.selected ? 36 : 26)
                        text: card.app ? card.app.name : ""
                        color: card.style ? card.style.textPrimary : "#fff"
                        font.pixelSize: card.selected ? 25 : 15
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: card.app ? card.app.type : ""
                        color: card.style ? card.style.textTertiary : "#888"
                        font.pixelSize: card.selected ? 13 : 12
                    }
                    Rectangle {
                        width: pillText.width + 24
                        height: pillText.height + (card.selected ? 20 : 16)
                        radius: 14
                        color: card.style ? card.style.accentSoft : "#8edfff20"
                        border.width: 1
                        border.color: card.style ? card.style.accentSoftBorder : "#8edfff33"
                        Text {
                            id: pillText
                            anchors.centerIn: parent
                            text: card.app ? card.app.time : ""
                            color: card.style ? card.style.accentText : "#dffaff"
                            font.pixelSize: card.selected ? 18 : 14
                            font.bold: true
                        }
                    }
                    Rectangle {
                        width: parent.width - (card.selected ? 36 : 26)
                        height: 8
                        radius: 4
                        color: card.style ? card.style.trackBg : "#ffffff14"
                        Rectangle {
                            width: parent.width * (card.app ? card.app.progress : 0)
                            height: parent.height
                            radius: 4
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: card.style ? card.style.aqua : "#82efff" }
                                GradientStop { position: 1; color: card.style ? card.style.violet : "#dd7dff" }
                            }
                        }
                    }
                    Text {
                        visible: card.selected
                        text: "点击翻面后锁定选择"
                        color: card.style ? card.style.textTertiary : "#888"
                        font.pixelSize: 11
                    }
                }
            }
        }

        back: Rectangle {
            anchors.fill: parent
            radius: 18
            color: card.style ? card.style.faceBg : "#0D121D"
            border.width: 1
            border.color: card.style ? card.style.faceBorderActive : "#9ef1ffb0"
            clip: true

            Image {
                anchors.fill: parent
                source: card.app ? Mock.imagePath(card.app.image) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.18
            }
            Rectangle {
                anchors.fill: parent
                color: card.style && card.style.night ? Qt.rgba(0.05, 0.07, 0.11, 0.93) : Qt.rgba(1, 1, 1, 0.86)
            }

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14
                Text {
                    width: parent.width
                    text: card.app ? card.app.mood : ""
                    color: card.style ? card.style.textPrimary : "#fff"
                    font.pixelSize: card.selected ? 30 : 20
                    font.bold: true
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: card.app ? card.app.analysis : ""
                    color: card.style ? card.style.textSecondary : "#bbb"
                    font.pixelSize: 14
                    lineHeight: 1.4
                    wrapMode: Text.WordWrap
                }
                Row {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: card.app ? [
                            { k: "启动", v: card.app.launches },
                            { k: "最长", v: card.app.longest }
                        ] : []
                        delegate: Rectangle {
                            required property var modelData
                            width: (parent.width - 10) / 2
                            height: 44
                            radius: 14
                            color: card.style ? card.style.cardBg : "#ffffff12"
                            border.width: 1
                            border.color: card.style ? card.style.cardBorder : "#ffffff16"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.k + "  " + modelData.v
                                color: card.style ? card.style.textSecondary : "#ccc"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }

    // 选中卡牌辉光描边
    Rectangle {
        visible: card.selected
        anchors.fill: parent
        radius: 18
        color: "transparent"
        border.width: 1
        border.color: card.style ? Qt.rgba(card.style.aqua.r, card.style.aqua.g, card.style.aqua.b, card.style.night ? 0.16 : 0.10) : "transparent"
    }

    HoverHandler {
        id: hover
        onHoveredChanged: hovered ? card.hoverEnter() : card.hoverLeave()
    }
    TapHandler {
        onTapped: card.clicked()
    }
}
