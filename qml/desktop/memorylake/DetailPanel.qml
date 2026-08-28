import QtQuick
import "../../shared/I18n.js" as I18n
import "../components/AppVisual.js" as AppVisual

// 右栏详情卡：标题 + 封面 + 类别/时长 + 心情 + 分析，跟随当前 APP。
// 1:1 对应设计稿 .detail-panel。
Rectangle {
    id: detail

    property MemoryLakeStyle style
    property var app
    property string languageMode: "zh"

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
            text: (detail.app ? AppVisual.modelDisplayNameForLanguage(detail.app, detail.languageMode) : "") + " · " + I18n.t(detail.languageMode, "usage distribution")
            color: detail.style ? detail.style.textPrimary : "#fff"
            font.pixelSize: 16
            font.bold: true
            elide: Text.ElideRight
        }

        Item {
            width: parent.width
            height: 104
            clip: true
            // 生成式封面（§4.3）：appColor 渐变 + 居中系统图标，取代游戏海报。
            GenerativeCover {
                anchors.fill: parent
                style: detail.style
                app: detail.app
                iconSize: 64
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
                text: detail.app ? (I18n.t(detail.languageMode, detail.app.type) + " · " + detail.app.time) : ""
                color: detail.style ? detail.style.textTertiary : "#888"
                font.pixelSize: 12
            }
            Text {
                text: detail.app ? I18n.t(detail.languageMode, detail.app.mood) : ""
                color: detail.style ? detail.style.textPrimary : "#fff"
                font.pixelSize: 21
                font.bold: true
            }
            Text {
                width: parent.width
                text: detail.app ? I18n.fromModel(detail.languageMode, detail.app.analysisKey, detail.app.analysisParams) : ""
                color: detail.style ? detail.style.textSecondary : "#bbb"
                font.pixelSize: 13
                lineHeight: 1.6
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }
}
