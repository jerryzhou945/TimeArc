import QtQuick
import QtQuick.Controls

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
        NumberAnimation { target: bounceShift; property: "y"; to: bounceAnim.to; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: bounceShift; property: "y"; to: 0; duration: 290; easing.type: Easing.OutBack }
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

    ScrollBar.vertical: ScrollBar {
        id: vbar
        policy: silky.maxY() > 0 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        width: 7
        contentItem: Rectangle {
            implicitWidth: 7
            radius: 3.5
            color: silky.style ? Qt.rgba(silky.style.aqua.r, silky.style.aqua.g, silky.style.aqua.b, vbar.pressed ? 0.7 : 0.4)
                               : Qt.rgba(0.5, 0.9, 1, 0.4)
            opacity: vbar.active ? 1 : 0.55
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        background: Rectangle {
            implicitWidth: 7
            radius: 3.5
            color: silky.style ? silky.style.trackBg : Qt.rgba(1, 1, 1, 0.05)
        }
    }
}
