import QtQuick

// 今日结论卡：替换左栏原「月度回顾 CTA」的位置（月度回顾已独立成页，见底部菜单）。
// 数据来自 dailyCardService.memoryLakeDay().todayConclusion；待办剩余 chip 由页面叠加。
Rectangle {
    id: card

    property MemoryLakeStyle style
    property var model: ({})
    property int todoRemaining: -1   // <0 表示未知/隐藏待办 chip

    readonly property var modelChips: (model && model.chips) ? model.chips : []
    readonly property string kicker: (model && model.kicker) ? model.kicker : "今日结论"
    readonly property string title: (model && model.title) ? model.title : "今天还很安静"
    readonly property string desc: (model && model.desc) ? model.desc : ""
    readonly property string total: (model && model.total) ? model.total : ""

    // 后端 chips（最高占比/高峰时段/建议）+ 待办剩余（QML 叠加，插在第一项之后，贴合 v88 顺序）。
    readonly property var allChips: {
        var arr = [];
        var inserted = false;
        for (var i = 0; i < modelChips.length; i++) {
            arr.push(modelChips[i]);
            if (i === 0 && todoRemaining >= 0) {
                arr.push({ label: "待办剩余", value: todoRemaining + " 项" });
                inserted = true;
            }
        }
        if (!inserted && todoRemaining >= 0)
            arr.push({ label: "待办剩余", value: todoRemaining + " 项" });
        return arr;
    }

    radius: 19
    color: style ? style.cardBg : "#16181f"
    border.width: 1
    border.color: style ? style.cardBorder : "#2a2d36"
    clip: true

    Item {
        anchors.fill: parent
        anchors.margins: 12

        Text {
            id: kickerText
            anchors.top: parent.top
            anchors.left: parent.left
            text: card.kicker
            color: style ? style.aqua : "#9FE7EE"
            font.pixelSize: 11
            opacity: 0.85
        }

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            text: card.total
            visible: card.total.length > 0
            color: style ? style.textPrimary : "#fff"
            font.pixelSize: 15
            font.bold: true
        }

        Text {
            id: titleText
            anchors.top: kickerText.bottom
            anchors.topMargin: 5
            anchors.left: parent.left
            anchors.right: parent.right
            text: card.title
            color: style ? style.textPrimary : "#fff"
            font.pixelSize: 16
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Flow {
            id: chipFlow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 6

            Repeater {
                model: card.allChips
                delegate: Rectangle {
                    required property var modelData
                    height: 22
                    radius: 11
                    width: chipRow.implicitWidth + 16
                    color: style ? style.accentSoft : "#22303a"
                    border.width: 1
                    border.color: style ? style.accentSoftBorder : "#33505c"
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: modelData.label
                            color: style ? style.textSecondary : "#bbb"
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.value
                            color: style ? style.textPrimary : "#fff"
                            font.pixelSize: 10
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        Text {
            anchors.top: titleText.bottom
            anchors.topMargin: 5
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: chipFlow.top
            anchors.bottomMargin: 6
            text: card.desc
            visible: card.desc.length > 0
            color: style ? style.textSecondary : "#aaa"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            clip: true
        }
    }
}
