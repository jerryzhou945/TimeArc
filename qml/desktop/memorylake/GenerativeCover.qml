import QtQuick
import QtQuick.Effects
import "../components/AppVisual.js" as AppVisual

// 生成式封面（§4.3）：不把小图标拉满糊大图，而是合成一张"专辑封面"式的图——
// APP 专属 appColor 柔和渐变底 + 居中清晰系统图标（向 provider 请求 256，按中等
// 尺寸显示）+ 一圈柔光。图标缺失（无 path / 透明）时退到首字母，版式与色仍完整。
// 用于卡牌封面 / 详情封面 / 回顾主角图等 128–460px 场景。
Item {
    id: genCover

    property MemoryLakeStyle style
    property var app                 // 期望 {appId, name, appName, path}
    property int iconSize: 96        // 图标显示边长（不超过容器的一半）
    property real glowStrength: 0.5

    readonly property string _appId: app ? (app.sourceAppId ? app.sourceAppId.toString()
                                                           : (app.appId ? app.appId.toString() : "")) : ""
    readonly property string _name: app ? (app.name ? app.name.toString()
                                                     : (app.appName ? app.appName.toString() : "")) : ""
    readonly property string _path: app ? (app.path ? app.path.toString() : "") : ""
    readonly property bool night: style ? style.night : true
    readonly property color baseColor: app && app.brandColor ? app.brandColor : AppVisual.appColor(_appId, _name, _path)
    readonly property string iconSrc: app && app.iconSource ? app.iconSource : AppVisual.appIconSource(_appId, _path)
    readonly property string iconLabel: app && app.iconLabel ? app.iconLabel : AppVisual.appIconLabel(_appId, _name)
    readonly property int side: Math.round(Math.min(iconSize, Math.min(width, height) * 0.52))

    // 图标主色（最多 3 色，来自后端提取）；缺失退回 appColor 预设色。
    readonly property var iconColors: app && app.iconColors && app.iconColors.length > 0 ? app.iconColors : []
    readonly property color c0: iconColors.length > 0 ? iconColors[0] : baseColor
    readonly property color c1: iconColors.length > 1 ? iconColors[1] : c0
    readonly property color c2: iconColors.length > 2 ? iconColors[2] : c1

    // 底：图标主色系多色渐变，**经 coverTone 淡化**（去刺眼红/多色，比背景略鲜明），
    // 绝对平滑、零像素感，贴合该 app 图标观感。
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(AppVisual.coverTone(genCover.c0, genCover.night), 1.05) }
            GradientStop { position: 0.5; color: AppVisual.coverTone(genCover.c1, genCover.night) }
            GradientStop { position: 1.0; color: Qt.darker(AppVisual.coverTone(genCover.c2, genCover.night), 1.12) }
        }
    }

    // 图标柔光：让图标"坐得住"。
    Rectangle {
        id: glowSrc
        anchors.centerIn: parent
        width: genCover.side * 1.4
        height: genCover.side * 1.4
        radius: width / 2
        visible: false
        layer.enabled: true
        color: Qt.rgba(1, 1, 1, genCover.night ? 0.16 : 0.34)
    }
    MultiEffect {
        anchors.fill: glowSrc
        source: glowSrc
        blurEnabled: true
        blur: 1.0
        blurMax: 40
        opacity: genCover.glowStrength
        autoPaddingEnabled: true
    }

    // 主体：居中系统图标（请求 256，按中等尺寸显示，不拉伸）。
    Image {
        id: coverIcon
        anchors.centerIn: parent
        width: genCover.side
        height: genCover.side
        source: genCover.iconSrc
        sourceSize.width: 256
        sourceSize.height: 256
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        visible: genCover.iconSrc !== "" && status === Image.Ready
    }

    // 缺图标兜底：显示名首字（仍坐在 appColor 底上，不破版）。
    Text {
        anchors.centerIn: parent
        visible: genCover.iconSrc === "" || coverIcon.status === Image.Error
        text: genCover.iconLabel
        color: Qt.rgba(1, 1, 1, genCover.night ? 0.9 : 0.78)
        font.pixelSize: Math.max(18, genCover.side * 0.6)
        font.bold: true
    }
}
