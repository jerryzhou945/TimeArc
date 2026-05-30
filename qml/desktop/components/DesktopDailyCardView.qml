import QtQuick

// 单张 Daily Card 的展示。外壳复用 SoftCard，内部按 cardData.type 切布局。
// 只读 cardData.*，不做任何数据解析（解析全在 C++ DailyCardService）。
SoftCard {
    id: root

    property var cardData: ({})
    property bool nightMode: false
    property color themeTextPrimary: "#2D2724"
    property color themeTextSecondary: "#7C746D"
    property color themePanelColor: "#FBF8F4"
    property color themeBorderColor: "#E8E0D8"
    property color themeAccentColor: "#CFE8D8"

    readonly property string cardType: (cardData && cardData.type) ? cardData.type : ""
    readonly property var appList: (cardData && cardData.apps) ? cardData.apps : []
    readonly property var metricList: (cardData && cardData.metrics) ? cardData.metrics : []
    readonly property int maxAppSec: appList.length > 0 ? Math.max(1, appList[0].durationSec) : 1

    padding: 22
    fillColor: nightMode ? "#3C425C" : "#FBF8F4"
    fillOpacity: nightMode ? 0.92 : 0.94
    strokeColor: themeBorderColor
    shadowColor: nightMode ? "#05070D" : "#BFAE9D"
    height: contentColumn.implicitHeight + padding * 2

    Column {
        id: contentColumn
        width: parent.width
        spacing: 14

        Text {
            width: parent.width
            text: (cardData && cardData.title) ? cardData.title : ""
            color: root.themeTextPrimary
            font.pixelSize: 22
            font.bold: true
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: (cardData && cardData.body) ? cardData.body : ""
            color: root.themeTextSecondary
            font.pixelSize: 15
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }

        // 时间段（专注块等）——醒目地展示 timeRange
        Text {
            visible: text.length > 0
            text: (cardData && cardData.timeRange) ? cardData.timeRange : ""
            color: root.themeTextPrimary
            font.pixelSize: 26
            font.bold: true
        }

        // metric 行（mainline / focus_block 等都用）
        Row {
            visible: root.metricList.length > 0
            spacing: 26

            Repeater {
                model: root.metricList
                delegate: Column {
                    spacing: 4
                    Text {
                        text: modelData.value !== undefined ? modelData.value : ""
                        color: root.themeTextPrimary
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Text {
                        text: modelData.label !== undefined ? modelData.label : ""
                        color: root.themeTextSecondary
                        font.pixelSize: 13
                    }
                }
            }
        }

        // app 列表（top_apps / 娱乐等）：图标 + 名称 + 进度条 + 时长
        Column {
            visible: root.appList.length > 0
            width: parent.width
            spacing: 12

            Repeater {
                model: root.appList
                delegate: Row {
                    width: contentColumn.width
                    height: 34
                    spacing: 12

                    Image {
                        width: 26
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                        visible: source.toString().length > 0
                        source: (modelData.appIconPath && modelData.appIconPath.length > 0)
                                ? ("image://appicon/" + encodeURIComponent(modelData.appIconPath))
                                : ""
                    }

                    Text {
                        width: 150
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.displayName !== undefined ? modelData.displayName : ""
                        color: root.themeTextPrimary
                        font.pixelSize: 15
                        elide: Text.ElideRight
                    }

                    // 进度条轨道
                    Rectangle {
                        id: track
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(40, parent.width - 150 - 26 - 12 * 2 - 72)
                        height: 8
                        radius: 4
                        color: root.nightMode ? "#2C3147" : "#EFE7DC"

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: root.themeAccentColor
                            width: parent.width * Math.min(1.0,
                                   (modelData.durationSec ? modelData.durationSec : 0) / root.maxAppSec)
                        }
                    }

                    Text {
                        width: 72
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: modelData.durationText !== undefined ? modelData.durationText : ""
                        color: root.themeTextSecondary
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
