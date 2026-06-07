import QtQuick

// 暗玻璃文本输入（v88 input §7.3 / 搜索框同族）。下沉底 calSunkBg + aqua 描边 calInputBorder，
// 关原生 frame（用 TextInput 而非 Controls.TextField，杜绝原生浅皮 G9）。search:true → 放大镜 + 清除。
// 色全取 MemoryLakeStyle（G1）。
Rectangle {
    id: field

    property MemoryLakeStyle style
    property alias text: input.text
    property string placeholderText: ""
    property bool search: false
    signal textEdited(string text)
    signal editingFinished()
    signal accepted()

    implicitWidth: search ? 240 : 160
    implicitHeight: search ? 40 : 34
    radius: search ? 14 : 12
    color: style ? style.calSunkBg : Qt.rgba(0, 0, 0, 0.16)
    border.width: 1
    border.color: input.activeFocus ? (style ? style.chipEventBd : Qt.rgba(0.55, 0.87, 1.0, 0.4))
                                     : (style ? style.calInputBorder : Qt.rgba(0.55, 0.87, 1.0, 0.12))
    antialiasing: true
    Behavior on border.color { ColorAnimation { duration: 160 } }

    // 放大镜（搜索变体）
    Text {
        id: magnifier
        visible: field.search
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "⌕"
        color: field.style ? field.style.textTertiary : Qt.rgba(1, 1, 1, 0.34)
        font.pixelSize: 16
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: field.search ? 34 : 12
        anchors.rightMargin: (field.search && input.text.length > 0) ? 30 : 12
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: field.style ? field.style.textPrimary : Qt.rgba(1, 1, 1, 0.88)
        selectionColor: field.style ? Qt.rgba(field.style.aqua.r, field.style.aqua.g, field.style.aqua.b, 0.35) : Qt.rgba(0.62, 0.90, 0.93, 0.35)
        selectedTextColor: color
        font.pixelSize: 13
        onTextEdited: field.textEdited(text)
        onEditingFinished: field.editingFinished()
        onAccepted: field.accepted()
    }

    // placeholder
    Text {
        anchors.left: input.left
        anchors.verticalCenter: input.verticalCenter
        visible: input.text.length === 0
        text: field.placeholderText
        color: field.style ? field.style.textTertiary : Qt.rgba(1, 1, 1, 0.30)
        font.pixelSize: 13
    }

    // 清除按钮（搜索变体，有内容时）
    Text {
        visible: field.search && input.text.length > 0
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "✕"
        color: field.style ? field.style.textTertiary : Qt.rgba(1, 1, 1, 0.34)
        font.pixelSize: 12
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: { input.text = ""; field.textEdited("") }
        }
    }
}
