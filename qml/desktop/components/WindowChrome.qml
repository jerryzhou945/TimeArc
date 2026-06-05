import QtQuick
import QtQuick.Window

// 无边框窗口自定义 chrome（沉浸式悬浮，QQ 音乐式）。
// 透明全窗覆盖层：顶部拖动带 + 左上品牌图标 + 右上 最小化/最大化/关闭，四周 8 向缩放边。
// 中心区不放任何输入项 → 鼠标事件穿透到下方 shell。
// 系统行为走 Qt 原生助手 startSystemMove() / startSystemResize()（原生循环 ⇒ Windows 拖拽贴边仍生效）。
Item {
    id: chrome

    // 由 main.qml 注入的窗口引用（ApplicationWindow 继承 Window，自带 startSystemMove/Resize）。
    property var window: null
    // 标题栏高度（= 内容上方预留高度 topReserve）。
    property int barHeight: 40
    // 缩放命中边宽。
    property int resizeMargin: 6
    // 深底模式（记忆湖/夜晚）：图标线条转浅色以保对比。
    property bool dark: false
    // 左上品牌图标（与任务栏共用同一 SVG）。
    property url iconSource: ""

    // 无边框窗口最大化在部分路径下 visibility 报 FullScreen(5) 而非 Maximized(4)（实测：
    // 外部/Aero 贴边最大化 → 5；showMaximized 可能为 4）。两者都按「已最大化」处理，否则
    // 还原图标与切换逻辑会与真实窗口状态脱节。
    readonly property bool isMax: window
        && (window.visibility === Window.Maximized
            || window.visibility === Window.FullScreen)
    readonly property color glyph: dark ? "#F1EEFF" : "#2D2724"

    function toggleMaximize() {
        if (!window)
            return;
        if (isMax)
            window.showNormal();
        else
            window.showMaximized();
    }

    // —— 顶部拖动带（含品牌图标 + 控制键）——
    Item {
        id: caption
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: chrome.barHeight

        // 拖动：DragHandler(target:null) 越过阈值才触发原生移动，单击/双击仍可用。
        DragHandler {
            target: null
            dragThreshold: 4
            onActiveChanged: if (active && chrome.window) chrome.window.startSystemMove()
        }
        // 双击标题栏 = 最大化/还原切换。
        TapHandler {
            gesturePolicy: TapHandler.DragThreshold
            onDoubleTapped: chrome.toggleMaximize()
        }

        // 左上品牌图标
        Image {
            id: brand
            visible: chrome.iconSource != ""
            source: chrome.iconSource
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            sourceSize.width: 44
            sourceSize.height: 44
            smooth: true
            fillMode: Image.PreserveAspectFit
        }

        // 右上控制键
        Row {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            CaptionButton { kind: "min";   onActivated: if (chrome.window) chrome.window.showMinimized() }
            CaptionButton { kind: "max";   onActivated: chrome.toggleMaximize() }
            CaptionButton { kind: "close"; danger: true; onActivated: if (chrome.window) chrome.window.close() }
        }
    }

    // —— 控制键组件 ——
    component CaptionButton: Rectangle {
        id: btn
        property string kind: "min"
        property bool danger: false
        signal activated()

        width: 34
        height: 28
        radius: 8
        color: !hover.hovered ? "transparent"
                              : danger ? "#E5484D"
                                       : (chrome.dark ? Qt.rgba(1, 1, 1, 0.14)
                                                      : Qt.rgba(0, 0, 0, 0.08))
        Behavior on color { ColorAnimation { duration: 110 } }

        readonly property color ink: (danger && hover.hovered) ? "#FFFFFF" : chrome.glyph

        // minimize —— 一横
        Rectangle {
            visible: btn.kind === "min"
            anchors.centerIn: parent
            width: 11; height: 1.6; radius: 0.8
            color: btn.ink
        }

        // maximize / restore
        Item {
            visible: btn.kind === "max"
            anchors.centerIn: parent
            width: 12; height: 12
            // 还原态：后方错位小方（露出右上 L）
            Rectangle {
                visible: chrome.isMax
                x: 3; y: 0; width: 9; height: 9; radius: 1.5
                color: "transparent"; border.width: 1.6; border.color: btn.ink
            }
            // 主方：最大化时缩小下移模拟前盖，否则单枚正方。
            Rectangle {
                x: 0; y: chrome.isMax ? 3 : 0.5
                width: chrome.isMax ? 9 : 11
                height: chrome.isMax ? 9 : 11
                radius: 1.5
                color: "transparent"; border.width: 1.6; border.color: btn.ink
            }
        }

        // close —— ✕（两根旋转细条）
        Item {
            visible: btn.kind === "close"
            anchors.centerIn: parent
            width: 13; height: 13
            Rectangle { anchors.centerIn: parent; width: 14; height: 1.6; radius: 0.8; color: btn.ink; rotation: 45 }
            Rectangle { anchors.centerIn: parent; width: 14; height: 1.6; radius: 0.8; color: btn.ink; rotation: -45 }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: btn.activated() }
    }

    // —— 8 向缩放边（最大化时禁用）——
    // 声明在 caption 之后 ⇒ 顶边/顶角的极薄缩放带叠在标题栏之上，符合 Windows「顶边可拉伸」。
    readonly property bool canResize: window && !isMax
    readonly property int corner: resizeMargin + 6

    // 上
    MouseArea {
        enabled: chrome.canResize
        height: chrome.resizeMargin
        anchors.top: parent.top
        anchors.left: parent.left; anchors.leftMargin: chrome.corner
        anchors.right: parent.right; anchors.rightMargin: chrome.corner
        hoverEnabled: true; cursorShape: Qt.SizeVerCursor
        onPressed: if (chrome.window) chrome.window.startSystemResize(Qt.TopEdge)
    }
    // 下
    MouseArea {
        enabled: chrome.canResize
        height: chrome.resizeMargin
        anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.leftMargin: chrome.corner
        anchors.right: parent.right; anchors.rightMargin: chrome.corner
        hoverEnabled: true; cursorShape: Qt.SizeVerCursor
        onPressed: if (chrome.window) chrome.window.startSystemResize(Qt.BottomEdge)
    }
    // 左
    MouseArea {
        enabled: chrome.canResize
        width: chrome.resizeMargin
        anchors.left: parent.left
        anchors.top: parent.top; anchors.topMargin: chrome.corner
        anchors.bottom: parent.bottom; anchors.bottomMargin: chrome.corner
        hoverEnabled: true; cursorShape: Qt.SizeHorCursor
        onPressed: if (chrome.window) chrome.window.startSystemResize(Qt.LeftEdge)
    }
    // 右
    MouseArea {
        enabled: chrome.canResize
        width: chrome.resizeMargin
        anchors.right: parent.right
        anchors.top: parent.top; anchors.topMargin: chrome.corner
        anchors.bottom: parent.bottom; anchors.bottomMargin: chrome.corner
        hoverEnabled: true; cursorShape: Qt.SizeHorCursor
        onPressed: if (chrome.window) chrome.window.startSystemResize(Qt.RightEdge)
    }
    // 四角
    MouseArea {
        enabled: chrome.canResize
        width: chrome.corner; height: chrome.corner
        anchors.left: parent.left; anchors.top: parent.top
        hoverEnabled: true; cursorShape: Qt.SizeFDiagCursor
        onPressed: if (chrome.window) chrome.window.startSystemResize(Qt.LeftEdge | Qt.TopEdge)
    }
    MouseArea {
        enabled: chrome.canResize
        width: chrome.corner; height: chrome.corner
        anchors.right: parent.right; anchors.top: parent.top
        hoverEnabled: true; cursorShape: Qt.SizeBDiagCursor
        onPressed: if (chrome.window) chrome.window.startSystemResize(Qt.RightEdge | Qt.TopEdge)
    }
    MouseArea {
        enabled: chrome.canResize
        width: chrome.corner; height: chrome.corner
        anchors.left: parent.left; anchors.bottom: parent.bottom
        hoverEnabled: true; cursorShape: Qt.SizeBDiagCursor
        onPressed: if (chrome.window) chrome.window.startSystemResize(Qt.LeftEdge | Qt.BottomEdge)
    }
    MouseArea {
        enabled: chrome.canResize
        width: chrome.corner; height: chrome.corner
        anchors.right: parent.right; anchors.bottom: parent.bottom
        hoverEnabled: true; cursorShape: Qt.SizeFDiagCursor
        onPressed: if (chrome.window) chrome.window.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
    }
}
