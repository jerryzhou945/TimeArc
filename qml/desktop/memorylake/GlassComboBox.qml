import QtQuick
import QtQuick.Controls

// 暗玻璃下拉（v88 select §7.2）。纯自绘字段 + Controls.Popup 弹层（Popup 的 background 自定义所有
// 样式都支持，故不触发 native ComboBox 的「current style does not support customization」告警；
// 同时 popup 走 overlay 层，可穿出卡片/SilkyFlickable 裁剪）。受控：currentIndex 由父绑定，选项点击
// 发 activated(i)，不自写 currentIndex（父回写 → 绑定刷新）。色全取 MemoryLakeStyle 令牌（G1）。
Item {
    id: combo

    property MemoryLakeStyle style
    property var model: []
    property int currentIndex: 0
    property int popupMinWidth: 132
    signal activated(int index)

    readonly property string currentText:
        (model && currentIndex >= 0 && currentIndex < model.length) ? ("" + model[currentIndex]) : ""
    function closePopup() { pop.close() }

    implicitHeight: 34
    implicitWidth: Math.max(popupMinWidth, fieldText.implicitWidth + 52)

    TextMetrics { id: _m; font: fieldText.font; text: combo.currentText }

    Rectangle {
        id: field
        anchors.fill: parent
        radius: 12
        color: combo.style ? combo.style.calSunkBg : Qt.rgba(0, 0, 0, 0.16)
        border.width: 1
        border.color: pop.visible ? (combo.style ? combo.style.chipEventBd : Qt.rgba(0.55, 0.87, 1.0, 0.4))
                                   : (combo.style ? combo.style.calInputBorder : Qt.rgba(0.55, 0.87, 1.0, 0.12))
        antialiasing: true
        Behavior on border.color { ColorAnimation { duration: 160 } }

        Text {
            id: fieldText
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chev.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: combo.currentText
            color: combo.style ? combo.style.textPrimary : Qt.rgba(1, 1, 1, 0.86)
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Text {
            id: chev
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "▾"
            color: combo.style ? combo.style.textSecondary : Qt.rgba(1, 1, 1, 0.56)
            font.pixelSize: 12
            rotation: pop.visible ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 160 } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onClicked: pop.visible ? pop.close() : pop.open()
        }
    }

    Popup {
        id: pop
        y: combo.height + 6
        x: 0
        width: Math.max(combo.width, combo.popupMinWidth)
        padding: 6
        implicitHeight: Math.min(list.contentHeight + 12, 264)
        // 不透明深色底：原 calPanelBg 在夜间是 rgba(1,1,1,0.045)（近全透）→ 选项与身后内容混叠。
        // 改用 panelBg 的 RGB 并把 alpha 钳到 1（夜=深、昼=浅），保证任意背景上下拉都清晰不透。
        background: Rectangle {
            radius: 12
            color: combo.style ? Qt.rgba(combo.style.panelBg.r, combo.style.panelBg.g, combo.style.panelBg.b, 1.0)
                               : Qt.rgba(0.055, 0.075, 0.12, 1.0)
            border.width: 1
            border.color: combo.style ? combo.style.panelBorder : Qt.rgba(1, 1, 1, 0.1)
        }
        contentItem: ListView {
            id: list
            clip: true
            implicitHeight: contentHeight
            model: combo.model
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: opt
                required property int index
                required property var modelData
                width: ListView.view ? ListView.view.width : 0
                height: 34
                radius: 8
                color: (optHov.hovered || opt.index === combo.currentIndex)
                       ? (combo.style ? combo.style.accentSoft : Qt.rgba(0.62, 0.90, 0.93, 0.075))
                       : "transparent"
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "" + opt.modelData
                    color: combo.style ? combo.style.textPrimary : Qt.rgba(1, 1, 1, 0.88)
                    font.pixelSize: 13
                    font.weight: (opt.index === combo.currentIndex) ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                HoverHandler { id: optHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { combo.activated(opt.index); combo.closePopup() } }   // 受控：不自写 currentIndex
            }
        }
    }
}
