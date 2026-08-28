import QtQuick
import "../components/TagPalette.js" as TagPalette
import "../../shared/I18n.js" as I18n

// 统一「真·标签」chip：每个 tag 永远显示自己的语义色 —— 底/边/导色点/文字都由固定色 ink 派生。
// 自包含调色板（TagPalette.js 单一来源）——任意位置 TagChip { tag: "学习" } 即可。
// selected 只控制「强调程度」（选择器里：选中=更亮底+更重边+加粗），未选仍显示本色（只是淡一档）。
// big=true 为选择器尺寸（更大、可点）；默认小尺寸内联（议程/今日事项副标）。
Rectangle {
    id: chip

    property string tag: ""
    property var style: null          // 预留（当前不依赖主题中性色）
    property bool selected: true      // 强调态：选择器里表示「已选」
    property bool big: false          // 选择器尺寸 / 默认内联小尺寸
    property string languageMode: "zh"

    readonly property color ink: TagPalette.tagColor(tag)

    implicitWidth: row.implicitWidth + (big ? 22 : 16)
    implicitHeight: big ? 30 : 20
    radius: big ? 10 : 8
    antialiasing: true
    color: Qt.rgba(ink.r, ink.g, ink.b, selected ? 0.22 : 0.12)
    border.width: 1
    border.color: Qt.rgba(ink.r, ink.g, ink.b, selected ? 0.58 : 0.28)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: chip.big ? 6 : 5

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: chip.big ? 7 : 6
            height: width
            radius: width / 2
            color: chip.ink
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tag(chip.languageMode, chip.tag)
            color: chip.ink
            font.pixelSize: chip.big ? 12 : 11
            font.weight: chip.selected ? Font.DemiBold : Font.Medium
        }
    }
}
