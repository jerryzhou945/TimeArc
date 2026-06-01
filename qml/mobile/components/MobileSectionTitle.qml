import QtQuick

Column {
    id: root

    required property var theme
    property string title: ""
    property string subtitle: ""

    spacing: 2

    Text {
        width: parent.width
        text: root.title
        color: root.theme.textPrimary
        font.pixelSize: 22
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        width: parent.width
        text: root.subtitle
        color: root.theme.textMuted
        font.pixelSize: 13
        elide: Text.ElideRight
        visible: text.length > 0
    }
}
