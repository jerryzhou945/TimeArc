import QtQuick
import "MemoryLakeMock.js" as Mock

// 左栏「APP 使用排行」面板内容：标题 + 排行列表（丝滑滚动）。
// 选择/悬停通过信号上抛，由页面统一调度。
Item {
    id: rankRoot

    property MemoryLakeStyle style
    property var apps: []
    property var ranking: []
    property int selectedIndex: 0
    property bool locked: false

    signal requestSelect(int cardIndex)
    signal hoverCard(int cardIndex)
    signal unhoverCard()

    Column {
        anchors.fill: parent
        spacing: 10

        // 标题行
        Item {
            width: parent.width
            height: 20
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "APP 使用排行"
                color: rankRoot.style ? rankRoot.style.textPrimary : "#fff"
                font.pixelSize: 15
                font.bold: true
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "给排行榜更多空间"
                color: rankRoot.style ? rankRoot.style.textTertiary : "#888"
                font.pixelSize: 11
            }
        }

        SilkyFlickable {
            width: parent.width
            height: parent.height - 30
            style: rankRoot.style

            Column {
                // 右侧留出 12px 让常显滚动条（宽 7 + 右距 1）独占，行内容不再被滚动条压住重叠
                width: parent.width - 12
                spacing: 8

                Repeater {
                    model: rankRoot.ranking

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property var modelData
                        readonly property int cardIndex: modelData
                        readonly property var app: rankRoot.apps[cardIndex]
                        readonly property bool active: rankRoot.selectedIndex === cardIndex

                        width: parent.width
                        height: 58
                        radius: 16
                        color: active ? (rankRoot.style ? rankRoot.style.accentSoft : "#8edfff14")
                                      : (hover.hovered ? Qt.rgba(1, 1, 1, rankRoot.style && rankRoot.style.night ? 0.035 : 0.10)
                                                       : "transparent")
                        border.width: (active || hover.hovered) ? 1 : 0
                        border.color: active ? (rankRoot.style ? rankRoot.style.accentSoftBorder : "#8edfff33")
                                             : Qt.rgba(1, 1, 1, 0.06)
                        opacity: rankRoot.locked && !active ? 0.42 : 1.0

                        // .usage-item:hover { transform: translateX(2px) }
                        transform: Translate {
                            x: hover.hovered ? 2 : 0
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }

                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 10

                            Rectangle {
                                width: 34; height: 34; radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#00000022"
                                border.width: 1
                                border.color: rankRoot.style ? rankRoot.style.cardBorder : "#ffffff20"
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: row.app ? Mock.imagePath(row.app.image) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            Column {
                                width: parent.width - 34 - 10 - 22 - 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7
                                Row {
                                    width: parent.width
                                    Text {
                                        width: parent.width - timeText.width
                                        text: row.app ? row.app.name : ""
                                        color: rankRoot.style ? Qt.rgba(rankRoot.style.textPrimary.r, rankRoot.style.textPrimary.g, rankRoot.style.textPrimary.b, rankRoot.style.night ? 0.82 : 1.0) : "#fff"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        id: timeText
                                        text: row.app ? row.app.time : ""
                                        color: rankRoot.style ? rankRoot.style.accentText : "#dffaff"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                                Rectangle {
                                    width: parent.width
                                    height: 5
                                    radius: 3
                                    color: rankRoot.style ? rankRoot.style.trackBg : "#ffffff14"
                                    Rectangle {
                                        width: parent.width * (row.app ? row.app.progress : 0)
                                        height: parent.height
                                        radius: 3
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: rankRoot.style ? rankRoot.style.aqua : "#83efff" }
                                            GradientStop { position: 1; color: rankRoot.style ? rankRoot.style.violet : "#d77fff" }
                                        }
                                    }
                                }
                            }

                            Text {
                                width: 22
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: String(row.index + 1).padStart(2, "0")
                                color: rankRoot.style ? rankRoot.style.textTertiary : "#888"
                                font.pixelSize: 11
                            }
                        }

                        HoverHandler {
                            id: hover
                            enabled: !rankRoot.locked
                            onHoveredChanged: hovered ? rankRoot.hoverCard(row.cardIndex) : rankRoot.unhoverCard()
                        }
                        TapHandler {
                            enabled: !rankRoot.locked || row.active
                            onTapped: rankRoot.requestSelect(row.cardIndex)
                        }
                    }
                }
            }
        }
    }
}
