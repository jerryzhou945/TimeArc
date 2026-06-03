import QtQuick
import QtQuick.Effects

// 圆角裁切帧：把所有子项 + 顶层描边整体合成进一张多重采样 layer，再用单一圆角 MultiEffect
// 遮罩一次裁切。修复 clip:true 只裁矩形包围盒、圆角处方角内容（图片棱角 / 渐变 / 文本）溢出
// 圆角边的问题——与 MemoryCard.qml 卡面同一套遮罩思路：描边进同一张被裁合成、与内容共用同一
// 条圆角边；maskThresholdMin 0.5 把内容边卡在几何圆角半径，描边据此严丝合缝盖住，无漏边。
//
// 用法：当普通 Item 容器用，子项（Image / 渐变 / 文本…）直接写在内部即可。
//   radius   圆角半径（= 半边长即得正圆，用于环形头像）。
//   border   描边（border.width / border.color），可选。
Item {
    id: frame

    property real radius: 28
    property alias border: rim.border
    default property alias content: holder.data

    Item {
        id: holder
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.samples: 4
        layer.smooth: true

        // 顶层描边：与内容同处一张被裁合成、共用同一圆角；z 抬到所有用户子项之上。
        Rectangle {
            id: rim
            anchors.fill: parent
            z: 1000
            color: "transparent"
            radius: frame.radius
            antialiasing: true
        }
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: frame.radius
        color: "white"
        antialiasing: true
        visible: false
        layer.enabled: true
        layer.samples: 4
        layer.smooth: true
    }

    MultiEffect {
        anchors.fill: parent
        source: holder
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.28
    }
}
