// 共享 APP 视觉助手：APP 身份 -> 柔和底色 / 系统小图标 source。
// 单一实现，首页（DesktopHomePage.qml）与记忆湖共用，杜绝两套色表/取图逻辑漂移。
// 详见 docs/memory-lake-backend-integration-plan.md §2.2。
.pragma library

function containsAny(text, words) {
    for (var i = 0; i < words.length; i++) {
        if (text.indexOf(words[i]) >= 0)
            return true;
    }
    return false;
}

// 未知 APP 走哈希取色：同一身份稳定得到同一柔和色，避免每次刷新跳色。
function hashedColor(text) {
    var palette = ["#CFE8D8", "#D9D0F2", "#EFDCC3", "#EBC9CF", "#BFD7EA", "#DDF1E5", "#E7D4EA", "#D8D1CA"];
    var hash = 0;
    for (var i = 0; i < text.length; i++)
        hash = ((hash * 31) + text.charCodeAt(i)) & 0x7fffffff;
    return palette[hash % palette.length];
}

// 由 APP 身份推出的柔和底色：已知品牌固定色，未知哈希取色。
function appColor(appId, appName, path) {
    var identity = appId ? appId.toString() : "";
    var text = (identity + " " + (appName || "") + " " + (path || "")).toLowerCase();

    if (identity === "site:bilibili" || containsAny(text, ["bilibili", "b23.tv"])) return '#fabecf';
    if (containsAny(text, ["cloudmusic", "netease", "wycloudmusic"])) return "#D98E9F";
    if (containsAny(text, ["chrome.exe", "google\\chrome", "google/chrome"])) return "#BFD7EA";
    if (containsAny(text, ["code.exe", "visual studio code", "microsoft vs code"])) return "#9FC7DE";
    if (containsAny(text, ["discord"])) return "#D9D0F2";
    if (containsAny(text, ["weixin", "wechat"])) return "#CFE8D8";
    if (containsAny(text, ["qqmusic", "qqmusic.exe"])) return "#DDF1E5";
    if (containsAny(text, ["steam.exe", "steam\\steam", "steam/steam"])) return "#B9B5C8";
    if (containsAny(text, ["msedge", "edge.exe"])) return "#A8D5C0";
    if (containsAny(text, ["firefox"])) return "#EFDCC3";
    if (containsAny(text, ["explorer.exe", "windows\\explorer"])) return "#F4E8C8";
    if (containsAny(text, ["powershell", "windowsterminal", "cmd.exe"])) return "#BFD7EA";
    if (containsAny(text, ["telegram"])) return "#BFD7EA";
    if (containsAny(text, ["spotify"])) return "#CFE8D8";
    if (containsAny(text, ["zoom.exe"])) return "#BFD7EA";

    return hashedColor(text);
}

// 背景色调：把图标主色**强力降饱和 + 提亮**到清新淡雅的范围，避免 vivid 红/多色
// 背景哗众取宠（如 bilibili 粉、chrome 多色）。保留一点色相做区分，但整体淡、统一、高端。
function ambientTone(c, night) {
    var col = Qt.lighter(c, 1.0);   // 兼容字符串/颜色入参，coerce 成 color
    var h = col.hslHue;
    var s = col.hslSaturation;
    var l = col.hslLightness;
    if (h < 0 || isNaN(h)) {        // 无彩色（灰白黑）-> 中性淡色
        return night ? Qt.hsla(0, 0, 0.42, 1.0) : Qt.hsla(0, 0, 0.88, 1.0);
    }
    var ns = Math.min(s * 0.40, night ? 0.18 : 0.24);            // 强降饱和 + 硬上限
    var nl = night ? (0.44 + l * 0.08) : (0.82 - (1 - l) * 0.05); // 夜 ~0.44–0.52 / 日 ~0.78+
    return Qt.hsla(h, ns, nl, 1.0);
}

// 封面色调：比 ambientTone **略保留鲜明度**（封面是焦点"专辑封面"），但仍明显压低
// 饱和，去掉刺眼红/多色。淡化幅度约为背景的 80–90%（不与背景一样淡）。
function coverTone(c, night) {
    var col = Qt.lighter(c, 1.0);
    var h = col.hslHue;
    var s = col.hslSaturation;
    var l = col.hslLightness;
    if (h < 0 || isNaN(h)) {
        return night ? Qt.hsla(0, 0, 0.40, 1.0) : Qt.hsla(0, 0, 0.84, 1.0);
    }
    var ns = Math.min(s * 0.55, night ? 0.30 : 0.38);
    var nl = night ? (0.42 + l * 0.10) : (0.78 - (1 - l) * 0.06);
    return Qt.hsla(h, ns, nl, 1.0);
}

// 系统小图标 source。site:bilibili 走内置 SVG；无 path 返回 ""（由调用方走 appColor 兜底）。
function appIconSource(appId, path) {
    var identity = appId ? appId.toString() : "";
    if (identity === "site:bilibili")
        return Qt.resolvedUrl("../../../resources/icons/bilibili.svg");

    var raw = path ? path.toString() : "";
    if (raw.length === 0)
        return "";
    return "image://appicon/" + encodeURIComponent(raw);
}
