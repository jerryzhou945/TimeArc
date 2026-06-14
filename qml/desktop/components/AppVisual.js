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

function siteVisual(appId) {
    var identity = appId ? appId.toString() : "";
    switch (identity) {
    case "site:bilibili": return { color: "#FABECF", label: "B", icon: Qt.resolvedUrl("../../../resources/icons/sites/bilibili.png") };
    case "site:douyin": return { color: "#E8E2F1", label: "\u6296", icon: Qt.resolvedUrl("../../../resources/icons/sites/douyin.ico") };
    case "site:xiaohongshu": return { color: "#F5D7DE", label: "\u7EA2", icon: Qt.resolvedUrl("../../../resources/icons/sites/xiaohongshu.png") };
    case "site:weibo": return { color: "#E6162D", label: "\u5FAE", icon: Qt.resolvedUrl("../../../resources/icons/sites/weibo.ico") };
    case "site:zhihu": return { color: "#1772F6", label: "\u77E5", icon: Qt.resolvedUrl("../../../resources/icons/sites/zhihu.png") };
    case "site:taobao": return { color: "#FF5000", label: "\u6DD8", icon: Qt.resolvedUrl("../../../resources/icons/sites/taobao.png") };
    case "site:tmall": return { color: "#DD2727", label: "\u732B", icon: Qt.resolvedUrl("../../../resources/icons/sites/tmall.png") };
    case "site:jd": return { color: "#E2231A", label: "\u4EAC", icon: Qt.resolvedUrl("../../../resources/icons/sites/jd.ico") };
    case "site:pinduoduo": return { color: "#E02E24", label: "\u62FC", icon: Qt.resolvedUrl("../../../resources/icons/sites/pinduoduo.png") };
    case "site:baidu": return { color: "#2932E1", label: "\u767E", icon: Qt.resolvedUrl("../../../resources/icons/sites/baidu.png") };
    case "site:iqiyi": return { color: "#D8F0D6", label: "\u7231", icon: Qt.resolvedUrl("../../../resources/icons/sites/iqiyi.png") };
    case "site:youku": return { color: "#D5ECF6", label: "\u4F18", icon: Qt.resolvedUrl("../../../resources/icons/sites/youku.png") };
    case "site:tencent-video": return { color: "#F5E4BE", label: "\u817E", icon: Qt.resolvedUrl("../../../resources/icons/sites/tencent-video.png") };
    case "site:mango-tv": return { color: "#F4DDC7", label: "\u8292", icon: Qt.resolvedUrl("../../../resources/icons/sites/mango-tv.png") };
    case "site:kuaishou": return { color: "#F4D9C8", label: "\u5FEB", icon: Qt.resolvedUrl("../../../resources/icons/sites/kuaishou.ico") };
    case "site:xigua-video": return { color: "#F3D5D2", label: "\u74DC", icon: Qt.resolvedUrl("../../../resources/icons/sites/xigua-video.ico") };
    case "site:acfun": return { color: "#F5D7DD", label: "A", icon: Qt.resolvedUrl("../../../resources/icons/sites/acfun.png") };
    case "site:youtube": return { color: "#F2D4D4", label: "Y", icon: Qt.resolvedUrl("../../../resources/icons/sites/youtube.png") };
    case "site:netflix": return { color: "#EFD3D5", label: "N", icon: Qt.resolvedUrl("../../../resources/icons/sites/netflix.png") };
    case "site:twitch": return { color: "#E6DCF7", label: "T", icon: Qt.resolvedUrl("../../../resources/icons/sites/twitch.ico") };
    case "site:douyu": return { color: "#F4DEC7", label: "\u6597", icon: Qt.resolvedUrl("../../../resources/icons/sites/douyu.ico") };
    case "site:huya": return { color: "#F3E0C4", label: "\u864E", icon: Qt.resolvedUrl("../../../resources/icons/sites/huya.png") };
    case "site:douban": return { color: "#007722", label: "\u8C46", icon: Qt.resolvedUrl("../../../resources/icons/sites/douban.ico") };
    case "site:csdn": return { color: "#C92027", label: "C", icon: "" };
    case "site:alipay": return { color: "#1677FF", label: "\u652F", icon: Qt.resolvedUrl("../../../resources/icons/sites/alipay.png") };
    case "site:meituan": return { color: "#FFD100", label: "\u56E2", icon: Qt.resolvedUrl("../../../resources/icons/sites/meituan.ico") };
    case "site:dianping": return { color: "#FF7A00", label: "\u70B9", icon: Qt.resolvedUrl("../../../resources/icons/sites/dianping.ico") };
    default: return null;
    }
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
    var site = siteVisual(identity);
    if (site)
        return site.color;

    if (containsAny(text, ["bilibili", "b23.tv"])) return "#FABECF";
    if (containsAny(text, ["cloudmusic", "netease", "wycloudmusic"])) return "#D98E9F";
    if (containsAny(text, ["apex legends", "r5apex"])) return "#E6C7B8";
    if (containsAny(text, ["nvidia", "nvcontainer"])) return "#C9E8BA";
    if (containsAny(text, ["service host", "windows-system", "svchost", "runtime broker", "windows search"])) return "#C8D6E5";
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

// 系统小图标 source。站点图标优先走内置站点资源；无 path 返回 ""（由调用方走 appColor 兜底）。
function appIconSource(appId, path) {
    var identity = appId ? appId.toString() : "";
    var site = siteVisual(identity);
    if (site && site.icon)
        return site.icon;

    var raw = path ? path.toString() : "";
    if (raw.length === 0 && identity.indexOf("app:") !== 0 && identity.indexOf("site:") !== 0)
        raw = identity;
    if (raw.length === 0)
        return "";
    return "image://appicon/" + encodeURIComponent(raw);
}

function appIconLabel(appId, appName) {
    var identity = appId ? appId.toString() : "";
    var site = siteVisual(identity);
    if (site && site.label)
        return site.label;

    var name = appName ? appName.toString().trim() : "";
    return name.length > 0 ? name.charAt(0).toUpperCase() : "\u00B7";
}

function modelIdentity(row) {
    if (!row)
        return "";
    if (row.adapterIdentifier && row.adapterIdentifier.length > 0)
        return row.adapterIdentifier;
    if (row.groupKey && row.groupKey.length > 0)
        return row.groupKey;
    if (row.appId && row.appId.length > 0)
        return row.appId;
    return "";
}

function modelDisplayName(row) {
    if (!row)
        return "";
    if (row.adapterDisplayName && row.adapterDisplayName.length > 0)
        return row.adapterDisplayName;
    if (row.displayName && row.displayName.length > 0)
        return row.displayName;
    if (row.name && row.name.length > 0)
        return row.name;
    if (row.appName && row.appName.length > 0)
        return row.appName;
    return "";
}

function modelCategory(row) {
    if (!row)
        return "";
    if (row.adapterCategory && row.adapterCategory.length > 0)
        return row.adapterCategory;
    if (row.category && row.category.length > 0)
        return row.category;
    return "";
}

function modelSourceType(row) {
    if (!row)
        return "";
    if (row.sourceType && row.sourceType.length > 0)
        return row.sourceType;
    var identity = modelIdentity(row);
    return identity.indexOf("site:") === 0 ? "website" : "desktopApp";
}

function modelAppColor(row) {
    if (row && row.brandColor && row.brandColor.length > 0)
        return row.brandColor;
    return appColor(modelIdentity(row), modelDisplayName(row), row ? row.path : "");
}

function modelIconSource(row) {
    if (row && row.iconSource && row.iconSource.length > 0)
        return row.iconSource;
    if (row && row.iconPath && row.iconPath.length > 0) {
        var iconPath = row.iconPath.toString();
        if (iconPath.indexOf("qrc:") === 0 || iconPath.indexOf("file:") === 0)
            return iconPath;
        return appIconSource(row.appId ? row.appId : modelIdentity(row), iconPath);
    }
    if (row && row.iconUrl && row.iconUrl.length > 0)
        return row.iconUrl;
    return appIconSource(row && row.appId ? row.appId : modelIdentity(row),
                         row ? row.path : "");
}

function modelHasIcon(row) {
    var source = modelIconSource(row);
    return source && source.toString().length > 0;
}

function compareAppModels(a, b) {
    var as = a && a.seconds ? Number(a.seconds) : 0;
    var bs = b && b.seconds ? Number(b.seconds) : 0;
    var aLow = as < 60;
    var bLow = bs < 60;
    var an = modelDisplayName(a).toLowerCase();
    var bn = modelDisplayName(b).toLowerCase();

    if (aLow !== bLow)
        return aLow ? 1 : -1;
    if (aLow && bLow)
        return an.localeCompare(bn);
    if (as !== bs)
        return bs - as;

    var nameCompare = an.localeCompare(bn);
    if (nameCompare !== 0)
        return nameCompare;

    return modelIdentity(a).localeCompare(modelIdentity(b));
}

function modelIconLabel(row) {
    if (row && row.iconLabel && row.iconLabel.length > 0)
        return row.iconLabel;
    return appIconLabel(modelIdentity(row), modelDisplayName(row));
}
