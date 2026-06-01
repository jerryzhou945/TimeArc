import QtQuick
import "MemoryLakeMock.js" as Mock

// 右栏详情卡：标题 + 封面 + 类别/时长 + 心情 + 分析，跟随当前 APP。
// 1:1 对应设计稿 .detail-panel。
Rectangle {
    id: detail

    property MemoryLakeStyle style
    property var app

    radius: 18
    color: style ? style.cardBg : "#0e1422"
    border.width: 1
    border.color: style ? style.cardBorder : "#ffffff14"
    clip: true

    Column {
        anchors.fill: parent

        Text {
            x: 15
            topPadding: 14
            width: parent.width - 30
            text: (detail.app ? detail.app.name : "") + " · 使用时间分布"
            color: detail.style ? detail.style.textPrimary : "#fff"
            font.pixelSize: 16
            font.bold: true
            elide: Text.ElideRight
        }

        Item {
            width: parent.width
            height: 104
            clip: true
            Image {
                anchors.fill: parent
                source: detail.app ? Mock.imagePath(detail.app.image) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: detail.style && detail.style.night ? Qt.rgba(0.012, 0.027, 0.055, 0.86) : Qt.rgba(1, 1, 1, 0.4) }
                }
            }
        }

        Column {
            x: 15
            width: parent.width - 30
            topPadding: 12
            spacing: 6
            Text {
                text: detail.app ? (detail.app.type + " · " + detail.app.time) : ""
                color: detail.style ? detail.style.textTertiary : "#888"
                font.pixelSize: 12
            }
            Text {
                text: detail.app ? detail.app.mood : ""
                color: detail.style ? detail.style.textPrimary : "#fff"
                font.pixelSize: 21
                font.bold: true
            }
            Text {
                width: parent.width
                text: detail.app ? detail.app.analysis : ""
                color: detail.style ? detail.style.textSecondary : "#bbb"
                font.pixelSize: 13
                lineHeight: 1.35
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }
}
