import QtQuick
import QtQuick.Effects

// 备忘黑板·模态覆盖层（v88 #memoOverlay）。
// **入口是动作不是路由**：盖在首页之上、底层页面原样保留，关闭后退回原处，全程不换页
// （功能文 §2.1 / 验收 C0）。本切片（F-B1 / M-B1）只搭壳 + 黑板底 + 三层分离骨架
// （背景层 / 透明墨水层 host / 对象层 host）；工具条 / 画布 / 便签 / 番茄由后续切片填充。
// 黑板恒暗（G10），不随昼夜；点阵画在底层。
// 美术见 docs/memory-lake-memo-render-pipeline-replication.md §1.1/§4.1/§4.2。
Item {
    id: memo

    // 记忆湖色板（单一令牌源，G1）。由 Shell 注入。
    property MemoryLakeStyle style
    // 身后首页快照源（M0：QML 无实时 backdrop-filter，截首页快照重模糊当黑板磨砂底）。
    property Item backdropSource: null

    // 开合状态（动作）。开合唯一动画 = opacity .26s ease（功能文 §2.1 / C0）。
    property bool open: false

    anchors.fill: parent
    visible: opacity > 0.001
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }

    // 开启时抓一张首页快照（重模糊底）并取得焦点（Esc 关闭）。
    onOpenChanged: {
        if (open) {
            if (homeShot.sourceItem)
                homeShot.scheduleUpdate();
            memo.forceActiveFocus();
        }
    }

    focus: open
    Keys.onEscapePressed: memo.open = false

    // 模态：拦截一切落向首页的输入。后续切片的工具/画布/对象层叠在此之上各自接管命中。
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onClicked: memo.forceActiveFocus()
    }

    // ===== L0 身后首页快照 + 重模糊（M0；等效 backdrop-filter blur(10px)）=====
    ShaderEffectSource {
        id: homeShot
        anchors.fill: parent
        sourceItem: memo.backdropSource
        live: false          // 静态快照：进入备忘时抓一帧，期间首页不再实时重绘
        hideSource: false
        visible: false        // 仅作纹理源，重模糊结果由下面的 MultiEffect 呈现
    }
    MultiEffect {
        anchors.fill: parent
        source: homeShot
        visible: memo.backdropSource !== null
        blurEnabled: true
        blur: 1.0
        blurMax: memo.style ? memo.style.memoBackdropBlurMax : 40
    }

    // ===== L1 近黑竖渐变 + 角落辅光对 + 10% 黑罩 =====
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: memo.style ? memo.style.memoBoardTop
                                                             : Qt.rgba(9 / 255, 11 / 255, 18 / 255, 0.82) }
            GradientStop { position: 1.0; color: memo.style ? memo.style.memoBoardBottom
                                                             : Qt.rgba(6 / 255, 8 / 255, 14 / 255, 0.86) }
        }
    }
    // 左上 aqua 辅光（设计稿 18% 12% @6%）：GlowCircle 圆心落在该百分点、向内自然淡出到透明。
    GlowCircle {
        readonly property real d: Math.max(memo.width, memo.height) * 0.70
        width: d; height: d
        x: memo.width * 0.18 - d / 2
        y: memo.height * 0.12 - d / 2
        glowColor: memo.style ? memo.style.glowCyan : "#8EDFFF"
        glowOpacity: memo.style ? memo.style.memoGlowAquaOpacity : 0.06
    }
    // 右下 violet 辅光（设计稿 76% 72% @5.5%）。
    GlowCircle {
        readonly property real d: Math.max(memo.width, memo.height) * 0.72
        width: d; height: d
        x: memo.width * 0.76 - d / 2
        y: memo.height * 0.72 - d / 2
        glowColor: memo.style ? memo.style.violet : "#9B8BFF"
        glowOpacity: memo.style ? memo.style.memoGlowVioletOpacity : 0.055
    }
    // 整体 10% 黑罩（::before rgba(0,0,0,.10)）。
    Rectangle {
        anchors.fill: parent
        color: memo.style ? memo.style.memoScrim : Qt.rgba(0, 0, 0, 0.10)
    }

    // ===== L2 黑板点阵（白点 10.5% / 24px 平铺）=====
    MemoDotTexture {
        anchors.fill: parent
        dotColor: memo.style ? memo.style.memoDotColor : Qt.rgba(1, 1, 1, 0.105)
        pitch: memo.style ? memo.style.memoDotPitch : 24
        dotRadius: memo.style ? memo.style.memoDotRadius : 1
    }

    // ===== 三层分离骨架（G3 / §5.2）=====
    // 确立 z 次序：透明墨水层（画笔/橡皮 destination-out，只擦墨水不擦点阵/便签）→
    // 对象层（便签 z 高于文字）。本切片留空 host，由后续切片填充。
    Item { id: inkLayerHost; anchors.fill: parent }      // F-B3 MemoInkCanvas 落点
    Item { id: objectLayerHost; anchors.fill: parent }   // F-B4/F-B5 便签 + 文字层落点
}
