import QtQuick

// 今日结论 / Today Conclusion（设计稿 .today-briefing）：中栏顶部宽卡。
// v88 复刻：玻璃底 + 左上 aqua / 右上 violet 双角径向辉光 + 28px 方格底纹 + 顶沿内高光；
// 左列 kicker/标题/描述，右侧 score 盒（今日总计），底部 chips（最高占比/待办剩余/高峰/建议）。
// 数据来自 dailyCardService.memoryLakeDay().todayConclusion；待办剩余 chip 由页面叠加。
// 折叠（翻面时「今日结论暂时收起」）由页面驱动 height/opacity，本组件 clip 收口即可。
Rectangle {
    id: card

    property MemoryLakeStyle style
    property var model: ({})
    property int todoRemaining: -1   // <0 表示未知/隐藏待办 chip

    readonly property var modelChips: (model && model.chips) ? model.chips : []
    readonly property string kicker: (model && model.kicker) ? model.kicker : "Today Conclusion"
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

    readonly property real gs: style ? style.glowStrength : 1.0

    radius: 24
    // 毛玻璃质感：极淡白霜膜叠在中栏包裹板的暗玻璃上（夜），昼为浅瓷膜。
    // 靠「白霜 + 顶沿柔光 + 细边 + 方格」读作磨砂玻璃，而非平涂暗块或大面积泛光角落。
    color: style ? (style.night ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.66))
                 : Qt.rgba(1, 1, 1, 0.05)
    border.width: 1
    border.color: style ? Qt.rgba(style.glowCyan.r, style.glowCyan.g, style.glowCyan.b, 0.16 * (style.night ? 1 : 0.7))
                        : Qt.rgba(0.56, 0.87, 1, 0.16)
    antialiasing: true
    // 圆角裁切交给下方 RoundedFrame；clip:true 只裁矩形包围盒，会让方格/辉光在圆角处戳出方角「色块」。
    clip: false

    // —— 顶向白渐变（设计稿 linear 180° white .07 → .035），磨砂顶沿漫射受光（已圆角）——
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: card.style && !card.style.night ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.08) }
            GradientStop { position: 0.5; color: "transparent" }
        }
    }

    // —— 28px 方格底纹（设计稿 ::before grid）。今日结论按用户要求做「均匀毛玻璃质感」：
    // 霜面 + 顶沿柔光 + 方格，**不放角落霓虹光斑**；方格用 RoundedFrame round-clip 收在圆角内，不留方角色块。
    RoundedFrame {
        anchors.fill: parent
        radius: card.radius
        GridTexture {
            anchors.fill: parent
            lineColor: card.style ? card.style.gridLine : Qt.rgba(1, 1, 1, 0.032)
            cell: 28
            textureOpacity: card.style && !card.style.night ? 0.5 : 0.22
        }
    }

    // —— 顶沿 1px 内高光（玻璃上唇，inset 0 1px white .07）。左右内缩半径，不越圆角 ——
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 1; leftMargin: card.radius; rightMargin: card.radius }
        height: 1
        color: card.style ? (card.style.night ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.6)) : Qt.rgba(1, 1, 1, 0.07)
    }

    // —— 内容 ——
    Item {
        anchors.fill: parent
        anchors.margins: 18

        // briefing-top：左 kicker/标题/描述，右 score 盒
        Item {
            id: topRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(textCol.height, scoreBox.height)

            Column {
                id: textCol
                anchors.left: parent.left
                anchors.right: scoreBox.left
                anchors.rightMargin: 12
                anchors.top: parent.top
                spacing: 0

                Text {
                    text: card.kicker
                    color: card.style ? card.style.glowCyan : "#8EDFFF"
                    font.pixelSize: 11
                    font.weight: 800
                    font.letterSpacing: 0.7
                    font.capitalization: Font.AllUppercase
                }
                Text {
                    topPadding: 6
                    width: parent.width
                    text: card.title
                    color: card.style ? card.style.textPrimary : "#fff"
                    font.pixelSize: 23
                    font.weight: 900
                    font.letterSpacing: -0.62
                    lineHeight: 1.15
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    topPadding: 8
                    width: parent.width
                    visible: card.desc.length > 0
                    text: card.desc
                    color: card.style ? card.style.textSecondary : "#aaa"
                    font.pixelSize: 12
                    lineHeight: 1.5
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            // score 盒：min-w70 h54 r18，135° aqua→violet 浅染，大数 + 「今日总计」
            Rectangle {
                id: scoreBox
                anchors.right: parent.right
                anchors.top: parent.top
                width: Math.max(78, scoreCol.width + 22)
                height: 54
                radius: 18
                visible: card.total.length > 0
                gradient: Gradient {
                    GradientStop { position: 0; color: card.style ? Qt.rgba(card.style.glowCyan.r, card.style.glowCyan.g, card.style.glowCyan.b, 0.18 * card.gs) : Qt.rgba(0.56, 0.87, 1, 0.18) }
                    GradientStop { position: 1; color: card.style ? Qt.rgba(card.style.violet.r, card.style.violet.g, card.style.violet.b, 0.15 * card.gs) : Qt.rgba(0.61, 0.55, 1, 0.15) }
                }
                border.width: 1
                border.color: card.style ? Qt.rgba(card.style.glowCyan.r, card.style.glowCyan.g, card.style.glowCyan.b, 0.18) : Qt.rgba(0.56, 0.87, 1, 0.18)
                Column {
                    id: scoreCol
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: card.total
                        color: card.style ? card.style.textPrimary : "#fff"
                        font.pixelSize: 21
                        font.weight: 900
                        font.letterSpacing: -0.4
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "今日总计"
                        color: card.style ? card.style.textTertiary : "#888"
                        font.pixelSize: 9
                        font.weight: 700
                    }
                }
            }
        }

        // chips（设计稿 .briefing-chips，mt14，圆胶囊，label + 高亮 value）
        Flow {
            id: chipFlow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 8

            Repeater {
                model: card.allChips
                delegate: Rectangle {
                    required property var modelData
                    height: 30
                    radius: 15
                    width: chipRow.implicitWidth + 22
                    color: card.style ? card.style.pillScrim : Qt.rgba(0, 0, 0, 0.15)
                    border.width: 1
                    border.color: card.style ? card.style.panelBorder : Qt.rgba(1, 1, 1, 0.07)
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: modelData.label
                            color: card.style ? card.style.textSecondary : "#bbb"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.value
                            color: card.style ? card.style.textPrimary : "#fff"
                            font.pixelSize: 11
                            font.weight: 800
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
