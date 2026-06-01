import QtQuick
import "MemoryLakeMock.js" as Mock

// 左栏「APP 使用排行」面板内容：标题 + 排行列表。
// 选择/悬停通过信号上抛，由页面统一调度（滚动在阶段 C 接入 SilkyFlickable）。
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

    // 列表对外暴露，便于阶段 C 替换为 SilkyFlickable
    property alias listView: list

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

        ListView {
            id: list
            width: parent.width
            height: parent.height - 30
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: rankRoot.ranking

            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData
                readonly property int cardIndex: modelData
                readonly property var app: rankRoot.apps[cardIndex]
                readonly property bool active: rankRoot.selectedIndex === cardIndex

                width: ListView.view.width
                height: 58
                radius: 16
                color: active ? (rankRoot.style ? rankRoot.style.accentSoft : "#8edfff14")
                              : (hover.hovered ? Qt.rgba(1, 1, 1, rankRoot.style && rankRoot.style.night ? 0.035 : 0.10)
                                               : "transparent")
                border.width: active ? 1 : 0
                border.color: rankRoot.style ? rankRoot.style.accentSoftBorder : "#8edfff33"
                opacity: rankRoot.locked && !active ? 0.42 : 1.0

                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on opacity { NumberAnimation { duration: 160 } }

                Row {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 10

                    // 图标
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

                    // 主体
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

                    // 名次
                    Text {
                        width: 22
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: String(row.index + 1).padStart(2, "0")
                        color: rankRoot.style ? rankRoot.style.textTertiary : "#888"
                        font.pixelSize: 11
                    }
                }

                HoverHandler { id: hover; enabled: !rankRoot.locked }
                TapHandler {
                    enabled: !rankRoot.locked || row.active
                    onTapped: rankRoot.requestSelect(row.cardIndex)
                }
                onActiveChanged: {}
                Connections {
                    target: hover
                    function onHoveredChanged() {
                        if (hover.hovered) rankRoot.hoverCard(row.cardIndex)
                        else rankRoot.unhoverCard()
                    }
                }
            }
        }
    }
}
