import QtQuick
import "../components"

Rectangle {
    id: root

    required property var theme

    color: theme.bg

    property var cards: [
        { "id": 1, "title": "今日主线卡", "index": "01", "accentKey": "accent", "backText": "点击翻开，查看今天最集中的时间去向", "duration": "4h20m", "body": "你在 VSCode、CMake、GitHub 和 Qt 文档之间切换了 4小时20分钟。", "summary": "今天的时间主要集中在开发任务上。", "tags": ["VSCode", "CMake", "GitHub"] },
        { "id": 2, "title": "娱乐卡", "index": "02", "accentKey": "amber", "backText": "点击翻开，查看今天的放松时段", "duration": "2h15m", "body": "你今天在 Steam 和视频内容上花了 2小时15分钟。", "summary": "娱乐时间主要集中在晚上。", "tags": ["Steam", "Bilibili"] },
        { "id": 3, "title": "音乐 / 视频卡", "index": "03", "accentKey": "green", "backText": "点击翻开，查看最长的陪伴片段", "duration": "3h12m", "body": "最长的一段播放出现在 23:10–00:30。", "summary": "夜间的音乐陪伴是今天的重要背景。", "tags": ["Spotify", "Video"] },
        { "id": 4, "title": "反差卡", "index": "04", "accentKey": "red", "backText": "点击翻开，查看计划与实际的差距", "duration": "1h25m", "body": "计划学习 3 小时，实际学习相关时间 1小时25分钟。", "summary": "今天的学习执行度偏低。", "tags": ["Study", "Docs"] },
        { "id": 5, "title": "随机翻牌卡", "index": "05", "accentKey": "textMuted", "backText": "点击翻开，查看今天的小发现", "duration": "480次", "body": "今天最常打开的软件是：微信。", "summary": "碎片化打开次数很多，社交占据了不少注意力。", "tags": ["WeChat", "Chat"] }
    ]

    Column {
        anchors.fill: parent

        MobileStatusBar {
            width: parent.width
            theme: root.theme
        }

        Item {
            width: parent.width
            height: headerColumn.implicitHeight + 18

            Column {
                id: headerColumn
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 6
                anchors.bottomMargin: 12
                spacing: 10

                Rectangle {
                    width: recordRow.width + 20
                    height: 26
                    radius: 13
                    color: root.theme.pill
                    border.color: root.theme.border
                    border.width: 1

                    Row {
                        id: recordRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: root.theme.green
                        }

                        Text {
                            text: "正在记录 · VSCode"
                            color: root.theme.pillText
                            font.pixelSize: 11
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "今日时间卡"
                    color: root.theme.textPrimary
                    font.pixelSize: 21
                    font.weight: Font.DemiBold
                    lineHeight: 1.3
                }

                Text {
                    width: parent.width
                    text: "5月31日 · 本地生成"
                    color: root.theme.textMuted
                    font.pixelSize: 13
                }

                Rectangle {
                    width: parent.width
                    height: summaryColumn.implicitHeight + 24
                    radius: 14
                    color: root.theme.card
                    border.color: root.theme.border
                    border.width: 1

                    Column {
                        id: summaryColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            width: parent.width
                            text: "今天的主线是：项目开发"
                            color: root.theme.textPrimary
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: "已记录 7小时42分钟"
                            color: root.theme.textMuted
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Flickable {
            id: list
            width: parent.width
            height: parent.height - y
            clip: true
            contentHeight: cardsColumn.implicitHeight + 20

            Column {
                id: cardsColumn
                width: list.width - 32
                x: 16
                spacing: 10

                Repeater {
                    model: root.cards.length

                    MobileFlipCard {
                        required property int index

                        width: cardsColumn.width
                        theme: root.theme
                        card: root.cards[index]
                    }
                }

                Text {
                    width: parent.width
                    text: "点击卡片翻面 · 查看时间详情"
                    color: root.theme.textMuted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
