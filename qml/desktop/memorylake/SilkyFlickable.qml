import QtQuick

// 丝滑滚动容器：缓动滚轮 + 到边界回弹 + 细霓虹滚动条。
// 1:1 对应设计稿 setupSilkyScroll（rAF lerp 0.22 + bounce 关键帧）。
// 用法：把内容放进来即可（自动按内容高度设置 contentHeight）。
Flickable {
    id: silky

    property MemoryLakeStyle style
    default property alias content: holder.data

    contentWidth: width
    contentHeight: holder.childrenRect.height
    boundsBehavior: Flickable.OvershootBounds
    flickDeceleration: 2600
    clip: true

    Item {
        id: holder
        width: silky.width
        // 回弹位移（滚轮到边界时）
        transform: Translate { id: bounceShift; y: 0 }
    }

    // 缓动滚轮
    NumberAnimation {
        id: wheelAnim
        target: silky
        property: "contentY"
        duration: 320
        easing.type: Easing.OutCubic
    }

    function maxY() { return Math.max(0, contentHeight - height) }

    function edgeBounce(down) {
        bounceShift.y = 0
        bounceAnim.stop()
        bounceAnim.from = 0
        bounceAnim.to = down ? -18 : 18
        bounceAnim.restart()
    }

    SequentialAnimation {
        id: bounceAnim
        property real from: 0
        property real to: 0
        // contentBounce* 关键帧：0 → ±18px(35%) → 0，单段平滑回正（无二次过冲）
        NumberAnimation { target: bounceShift; property: "y"; to: bounceAnim.to; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: bounceShift; property: "y"; to: 0; duration: 290; easing.type: Easing.OutCubic }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            var max = silky.maxY()
            var goingUp = event.angleDelta.y > 0
            if (max <= 0 || (goingUp && silky.contentY <= 0) || (!goingUp && silky.contentY >= max)) {
                silky.edgeBounce(!goingUp)
                event.accepted = true
                return
            }
            var base = wheelAnim.running ? wheelAnim.to : silky.contentY
            var target = Math.max(0, Math.min(max, base - event.angleDelta.y * 0.9))
            wheelAnim.stop()
            wheelAnim.to = target
            wheelAnim.start()
            event.accepted = true
        }
    }

    onMovementStarted: wheelAnim.stop()

    // 细霓虹滚动条（手绘 Rectangle）：原生 Windows Controls 样式不支持 ScrollBar 自定义
    // contentItem（会被忽略并刷告警），故直接画常显 thumb，随内容平滑移动、可拖拽。
    Item {
        id: vbar
        width: 7
        anchors.right: parent.right
        anchors.rightMargin: 1
        y: silky.contentY            // 固定在视口内（抵消 Flickable 内容滚动）
        height: silky.height
        z: 50
        visible: silky.maxY() > 0

        // 轨道
        Rectangle {
            anchors.fill: parent
            radius: 3.5
            color: silky.style ? silky.style.trackBg : Qt.rgba(1, 1, 1, 0.05)
            opacity: 0.6
        }

        // thumb：rgba(129,232,255,.40) ≈ aqua@.40，按下略亮
        Rectangle {
            id: thumb
            width: 7
            radius: 3.5
            readonly property real track: vbar.height - height
            height: Math.max(28, vbar.height * silky.height / Math.max(silky.contentHeight, 1))
            y: (!thumbMA.drag.active && silky.maxY() > 0)
               ? (silky.contentY / silky.maxY()) * track
               : y
            color: silky.style ? Qt.rgba(silky.style.aqua.r, silky.style.aqua.g, silky.style.aqua.b, thumbMA.pressed ? 0.6 : 0.4)
                               : Qt.rgba(0.5, 0.9, 1, 0.4)
            Behavior on color { ColorAnimation { duration: 160 } }

            MouseArea {
                id: thumbMA
                anchors.fill: parent
                drag.target: thumb
                drag.axis: Drag.YAxis
                drag.minimumY: 0
                drag.maximumY: thumb.track
                onPositionChanged: if (drag.active && thumb.track > 0)
                    silky.contentY = (thumb.y / thumb.track) * silky.maxY()
            }
        }
    }
}
