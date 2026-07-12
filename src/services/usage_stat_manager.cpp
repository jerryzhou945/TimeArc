#include "usage_stat_manager.h"

#include <QColor>
#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileIconProvider>
#include <QFileInfo>
#include <QHash>
#include <QIcon>
#include <QImage>
#include <QMap>
#include <QPixmap>
#include <QRegularExpression>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>
#include <QVector>
#include <algorithm>
#include <initializer_list>
#include <limits>

#include "services/adapters/activity_adapter_registry.h"
#include "services/site_catalog.h"

namespace {

struct UsageInterval {
  // 用闭区间语义以外的 [start, end) 表示法，方便合并相邻/重叠时间段。
  qint64 start = 0;
  qint64 end = 0;
};

bool containsAny(const QString& text, std::initializer_list<QString> words) {
  for (const QString& word : words) {
    if (text.contains(word)) return true;
  }
  return false;
}

QString normalizedSource(const QString& source) {
  const QString normalized = source.trimmed().toLower();
  return normalized == "audio" ? "audio" : "foreground";
}

QString bilibiliDisplayName() {
  return QStringLiteral("\u54D4\u54E9\u54D4\u54E9");
}

bool isChromeApp(const QString& appId, const QString& appName,
                 const QString& path) {
  const QString text = (appId + " " + appName + " " + path).toLower();
  return containsAny(text, {"chrome.exe", "google\\chrome", "google/chrome"});
}

bool isBilibiliWindowTitle(const QString& windowTitle) {
  // 保守版网站识别：不读取浏览器 URL，只从 Chrome 窗口标题猜测当前站点。
  // 将来接浏览器扩展后，这里应迁移到 domain/favIconUrl 规则。
  const QString title = windowTitle.trimmed();
  if (title.isEmpty()) return false;

  const QString lowerTitle = title.toLower();
  return title.contains(QStringLiteral("\u54D4\u54E9\u54D4\u54E9")) ||
         containsAny(lowerTitle, {"bilibili", "b23.tv", "bilibili.com"});
}

bool isBrowserApp(const QString& appId, const QString& appName,
                  const QString& path) {
  const QString text = (appId + " " + appName + " " + path).toLower();
  return containsAny(text, {"chrome.exe", "google\\chrome", "google/chrome",
                            "msedge", "edge.exe", "firefox", "opera.exe",
                            "brave", "vivaldi", "360se", "qqbrowser",
                            "sogouexplorer", "ucbrowser"});
}

const TimeArcSiteCatalog::SiteDefinition* siteForGroupKey(
    const QString& groupKey) {
  return TimeArcSiteCatalog::findBySiteId(groupKey);
}

const TimeArcSiteCatalog::SiteDefinition* siteForBrowserTitle(
    const QString& appId, const QString& appName, const QString& path,
    const QString& title) {
  return TimeArcSiteCatalog::matchBrowserHostedActivity(appId, appName, path,
                                                        title);
}

TimeArcAdapters::AdapterInput adapterInputFromActivity(
    const QString& appId, const QString& appName, const QString& path,
    const QString& windowTitle, const QString& source = QString()) {
  TimeArcAdapters::AdapterInput input;
  input.source = source;
  input.appId = appId;
  input.appName = appName;
  input.path = path;
  input.title = windowTitle;
  return input;
}

TimeArcAdapters::AdapterMetadata adapterMetadataForIdentifier(
    const QString& identifier, const TimeArcAdapters::AdapterInput& input) {
  for (const TimeArcAdapters::AdapterDefinition& adapter :
       TimeArcAdapters::registeredWebsiteAdapters()) {
    if (adapter.identifier == identifier) {
      return TimeArcAdapters::metadataFromDefinition(adapter, 1.0, input);
    }
  }
  for (const TimeArcAdapters::AdapterDefinition& adapter :
       TimeArcAdapters::registeredDesktopAppAdapters()) {
    if (adapter.identifier == identifier) {
      return TimeArcAdapters::metadataFromDefinition(adapter, 1.0, input);
    }
  }
  return TimeArcAdapters::AdapterMetadata();
}

TimeArcAdapters::AdapterMetadata resolveActivityMetadata(
    const QString& appId, const QString& appName, const QString& path,
    const QString& windowTitle, const QString& source = QString()) {
  const TimeArcAdapters::AdapterInput input =
      adapterInputFromActivity(appId, appName, path, windowTitle, source);
  if (isBrowserApp(appId, appName, path)) {
    const TimeArcAdapters::AdapterMetadata website =
        TimeArcAdapters::resolveWebsite(input);
    if (website.matched && !website.identifier.trimmed().isEmpty()) {
      return website;
    }
  }
  return TimeArcAdapters::resolveDesktopApp(input);
}

void applyAdapterMetadata(QVariantMap* item,
                          const TimeArcAdapters::AdapterMetadata& metadata,
                          const QString& fallbackIconPath) {
  if (item == nullptr || metadata.identifier.trimmed().isEmpty()) return;

  item->insert(QStringLiteral("adapterIdentifier"), metadata.identifier);
  item->insert(QStringLiteral("sourceType"), metadata.sourceType);
  item->insert(QStringLiteral("adapterDisplayName"), metadata.displayName);
  item->insert(QStringLiteral("adapterConfidence"), metadata.confidence);
  item->insert(QStringLiteral("supportsMediaDetection"),
               metadata.supportsMediaDetection);

  if (!metadata.domain.trimmed().isEmpty()) {
    item->insert(QStringLiteral("domain"), metadata.domain);
    item->insert(QStringLiteral("siteDomain"), metadata.domain);
  }
  if (!metadata.iconUrl.trimmed().isEmpty()) {
    item->insert(QStringLiteral("iconUrl"), metadata.iconUrl);
  }

  QString iconPath = metadata.iconPath;
  if (iconPath.trimmed().isEmpty() &&
      metadata.sourceType == QStringLiteral("desktopApp")) {
    iconPath = fallbackIconPath;
  }
  if (!iconPath.trimmed().isEmpty()) {
    item->insert(QStringLiteral("iconPath"), iconPath);
    if (iconPath.startsWith(QStringLiteral("qrc:"))) {
      item->insert(QStringLiteral("iconSource"), iconPath);
    }
  }
  if (!metadata.iconLabel.trimmed().isEmpty()) {
    item->insert(QStringLiteral("iconLabel"), metadata.iconLabel);
  }
  if (!metadata.brandColor.trimmed().isEmpty()) {
    item->insert(QStringLiteral("brandColor"), metadata.brandColor);
  }
  if (!metadata.category.trimmed().isEmpty()) {
    item->insert(QStringLiteral("adapterCategory"), metadata.category);
  }
}

quint64 mergedIntervalSeconds(QVector<UsageInterval> intervals) {
  // foreground 与 audio 可能在同一时间段重叠。active 总时长按区间并集计算，
  // 避免“看视频时前台 + 音频”被重复加两次。
  if (intervals.isEmpty()) return 0;

  std::sort(intervals.begin(), intervals.end(),
            [](const UsageInterval& left, const UsageInterval& right) {
              if (left.start == right.start) return left.end < right.end;
              return left.start < right.start;
            });

  quint64 total = 0;
  qint64 currentStart = intervals[0].start;
  qint64 currentEnd = intervals[0].end;

  for (int i = 1; i < intervals.size(); ++i) {
    const UsageInterval& interval = intervals[i];
    if (interval.end <= interval.start) continue;

    if (interval.start <= currentEnd) {
      currentEnd = std::max(currentEnd, interval.end);
      continue;
    }

    if (currentEnd > currentStart) {
      total += static_cast<quint64>(currentEnd - currentStart);
    }
    currentStart = interval.start;
    currentEnd = interval.end;
  }

  if (currentEnd > currentStart) {
    total += static_cast<quint64>(currentEnd - currentStart);
  }

  return total;
}

QString appDisplayName(const QString& appId, const QString& appName,
                       const QString& path) {
  // 把 exe/path 归一成更适合 UI 的名称。没有命中特例时回退到 exe 文件名。
  const QString text = (appId + " " + appName + " " + path).toLower();
  const QString displayExeName =
      QFileInfo(!path.trimmed().isEmpty() ? path : appName).fileName().toLower();

  if (containsAny(text, {"uu.exe", "uu\\", "uu/", "uu accelerator",
                         "uu booster", "netease\\uu", "netease/uu"}))
    return "UU Accelerator";
  if (containsAny(text, {"cloudmusic", "cloudmusic.exe",
                         "netease cloud music", "orpheus"}))
    return "网易云音乐";
  if (displayExeName == "r5apex.exe" || displayExeName == "r5apex_dx12.exe" ||
      containsAny(text, {"apex legends"}))
    return "Apex Legends";
  if (displayExeName == "nvcontainer.exe") return "NVIDIA Container";
  if (displayExeName == "svchost.exe") return "Service Host";
  if (containsAny(text, {"runtimebroker.exe"})) return "Runtime Broker";
  if (containsAny(text, {"searchhost.exe", "searchapp.exe"})) return "Windows Search";
  if (containsAny(text, {"chrome.exe", "google\\chrome", "google/chrome"}))
    return "Google Chrome";
  if (containsAny(text, {"codex"}))
    return "Codex";
  if (containsAny(text,
                  {"code.exe", "visual studio code", "microsoft vs code"}))
    return "VS Code";
  if (containsAny(text, {"discord"})) return "Discord";
  if (containsAny(text, {"weixin", "wechat"})) return "微信";
  if (containsAny(text, {"jianyingpro", "jianying", "capcut"}))
    return QString::fromUtf8(u8"剪映专业版");
  if (containsAny(text, {"wallpaperengine", "wallpaper engine", "wallpaperui",
                         "wallpaper32", "wallpaper64", "webwallpaper"}))
    return "Wallpaper Engine";
  if (displayExeName == "qq.exe") return "QQ";
  if (displayExeName == "tim.exe") return "TIM";
  if (containsAny(text, {"qqscreenshot", "qqscreentshot", "qqscreen",
                         "qqscreenclip", "qqcapture"}))
    return "QQ 截图";
  if (containsAny(text, {"qqmusic"})) return "QQ Music";
  if (displayExeName == "steam.exe" || displayExeName == "steamwebhelper.exe")
    return "Steam";
  if (containsAny(text, {"msedge", "edge.exe"})) return "Microsoft Edge";
  if (containsAny(text, {"firefox"})) return "Firefox";
  if (containsAny(text, {"explorer.exe", "windows\\explorer"}))
    return "File Explorer";
  if (containsAny(text, {"powershell", "windowsterminal", "cmd.exe"}))
    return "Terminal";

  const QString fallback =
      !appName.trimmed().isEmpty() ? appName : QFileInfo(path).fileName();
  if (fallback.endsWith(".exe", Qt::CaseInsensitive)) {
    return fallback.left(fallback.size() - 4);
  }
  return fallback;
}

QString normalizedExeName(const QString& appName, const QString& path) {
  QString name =
      !appName.trimmed().isEmpty() ? appName : QFileInfo(path).fileName();
  name = name.trimmed().toLower();
  if (name.endsWith(".exe")) name.chop(4);
  return name;
}

QString appGroupKey(const QString& appId, const QString& appName,
                    const QString& path) {
  // group key 是统计聚合的身份。多个实际进程可以归到同一个 app key，
  // 例如 steam.exe 和 steamwebhelper.exe 都算 Steam。
  const QString text = (appId + " " + appName + " " + path).toLower();
  const QString exeName = normalizedExeName(appName, path);

  if (containsAny(text, {"weixin", "wechat", "wechatappex", "wechatbrowser"}))
    return "app:wechat";
  if (containsAny(text, {"jianyingpro", "jianying", "capcut"}))
    return "app:jianying-pro";
  if (containsAny(text, {"wallpaperengine", "wallpaper engine", "wallpaperui",
                         "wallpaper32", "wallpaper64", "webwallpaper"}))
    return "app:wallpaper-engine";
  if (containsAny(text, {"qqscreenshot", "qqscreentshot", "qqscreen",
                         "qqscreenclip", "qqcapture"}))
    return "app:qq-screenshot";
  if (exeName == "qq")
    return "app:qq";
  if (exeName == "tim")
    return "app:tim";
  if (containsAny(text, {"uu.exe", "uu\\", "uu/", "uu accelerator",
                         "uu booster", "netease\\uu", "netease/uu"}))
    return "app:uu-accelerator";
  if (containsAny(text, {"cloudmusic", "cloudmusic.exe",
                         "netease cloud music", "orpheus"}))
    return "app:netease-cloud-music";
  if (exeName == "r5apex" || exeName == "r5apex_dx12" ||
      containsAny(text, {"apex legends"}))
    return "app:apex-legends";
  if (exeName == "nvcontainer")
    return "app:nvidia-container";
  if (exeName == "svchost")
    return "app:windows-service-host";
  if (containsAny(text, {"runtimebroker.exe", "searchhost.exe", "searchapp.exe",
                         "startmenuexperiencehost.exe", "applicationframehost.exe",
                         "widgets.exe", "taskhostw.exe", "dllhost.exe",
                         "conhost.exe", "wmiprvse.exe", "audiodg.exe"}))
    return "app:windows-system";
  if (containsAny(text, {"chrome.exe", "google\\chrome", "google/chrome"}))
    return "app:google-chrome";
  if (containsAny(text, {"codex"}))
    return "app:codex";
  if (containsAny(text,
                  {"code.exe", "visual studio code", "microsoft vs code"}))
    return "app:vscode";
  if (containsAny(text, {"discord"}))
    return "app:discord";
  if (containsAny(text, {"qqmusic"}))
    return "app:qq-music";
  if (exeName == "steam" || exeName == "steamwebhelper")
    return "app:steam";
  if (containsAny(text, {"msedge", "edge.exe"}))
    return "app:microsoft-edge";
  if (containsAny(text, {"firefox"}))
    return "app:firefox";
  if (containsAny(text, {"explorer.exe", "windows\\explorer"}))
    return "app:file-explorer";
  if (containsAny(text, {"powershell", "windowsterminal", "cmd.exe"}))
    return "app:terminal";
  if (containsAny(text, {"telegram"}))
    return "app:telegram";
  if (containsAny(text, {"spotify"}))
    return "app:spotify";
  if (containsAny(text, {"zoom.exe"}))
    return "app:zoom";

  if (!exeName.isEmpty()) return "exe:" + exeName;

  const QString fallback = !appId.trimmed().isEmpty() ? appId : path;
  return "path:" + fallback.toLower();
}

bool isHomeRankVisibleActivity(const QString& groupKey, const QString& appId,
                               const QString& appName, const QString& path,
                               const QString& displayName,
                               const QString& category) {
  if (category == QStringLiteral("系统")) return false;
  const QString id =
      (groupKey + " " + appId + " " + appName + " " + path + " " + displayName)
          .toLower();
  if (containsAny(id, {"app:windows-system", "app:windows-service-host",
                       "app:nvidia-container", "app:qq-screenshot",
                       "qqscreenshot", "qqscreentshot", "qqscreenclip",
                       "qqcapture", "crashpad_handler", "werfault.exe",
                       "backgroundtaskhost.exe", "securityhealthsystray.exe",
                       "shellexperiencehost.exe"}))
    return false;
  return true;
}

bool isSettingsListVisibleActivity(const QString& groupKey,
                                   const QString& appId,
                                   const QString& appName,
                                   const QString& path,
                                   const QString& displayName,
                                   const QString& category, quint64 seconds) {
  if (groupKey.startsWith(QLatin1String("site:"))) return true;

  const QString id =
      (groupKey + " " + appId + " " + appName + " " + path + " " + displayName)
          .toLower();
  if (category == QStringLiteral("系统")) return false;
  if (containsAny(id, {"pid:", ".dll", "app:windows-system",
                       "app:windows-service-host", "app:nvidia-container",
                       "app:qq-screenshot", "qqscreenshot", "qqscreentshot",
                       "qqscreenclip", "qqcapture", "permissioncenterui",
                       "pickerhost", "shellexperiencehost", "runtimebroker",
                       "crashpad_handler", "werfault.exe",
                       "backgroundtaskhost.exe", "securityhealthsystray.exe",
                       "startmenuexperiencehost.exe", "applicationframehost.exe",
                       "widgets.exe", "taskhostw.exe", "dllhost.exe",
                       "conhost.exe", "wmiprvse.exe", "audiodg.exe"}))
    return false;

  static const QSet<QString> kPublicApps = {
      QStringLiteral("app:wechat"),
      QStringLiteral("app:qq"),
      QStringLiteral("app:tim"),
      QStringLiteral("app:uu-accelerator"),
      QStringLiteral("app:netease-cloud-music"),
      QStringLiteral("app:apex-legends"),
      QStringLiteral("app:google-chrome"),
      QStringLiteral("app:codex"),
      QStringLiteral("app:vscode"),
      QStringLiteral("app:discord"),
      QStringLiteral("app:qq-music"),
      QStringLiteral("app:steam"),
      QStringLiteral("app:microsoft-edge"),
      QStringLiteral("app:firefox"),
      QStringLiteral("app:file-explorer"),
      QStringLiteral("app:terminal"),
      QStringLiteral("app:telegram"),
      QStringLiteral("app:spotify"),
      QStringLiteral("app:zoom"),
      QStringLiteral("app:jianying-pro"),
      QStringLiteral("app:wallpaper-engine"),
  };
  if (kPublicApps.contains(groupKey)) return true;

  return seconds >= 300;
}

bool isLowFrequencySettingsActivity(qlonglong seconds) { return seconds < 60; }

QString activityGroupKey(const QString& appId, const QString& appName,
                         const QString& path, const QString& windowTitle) {
  // 记忆化：纯函数 + 确定性 + 站点目录编译期静态 → 进程内静态缓存无需失效。同一身份元组
  // 在 46k 记录里高频重复，缓存把每条的多次 containsAny/站点扫描降为一次 hash 查找。
  static QHash<QString, QString> cache;
  const QChar sep(QChar(0x1f));
  const QString k = appId + sep + appName + sep + path + sep + windowTitle;
  const auto it = cache.constFind(k);
  if (it != cache.constEnd()) return it.value();

  QString value;
  if (const TimeArcSiteCatalog::SiteDefinition* site =
          siteForBrowserTitle(appId, appName, path, windowTitle)) {
    value = site->siteId;
  } else if (const TimeArcAdapters::AdapterMetadata metadata =
                 resolveActivityMetadata(appId, appName, path, windowTitle);
             metadata.matched && !metadata.identifier.trimmed().isEmpty()) {
    value = metadata.identifier;
  } else {
    value = appGroupKey(appId, appName, path);
  }
  if (cache.size() < 200000) cache.insert(k, value);  // 软上限防极端无界增长
  return value;
}

QString activityDisplayName(const QString& groupKey, const QString& appId,
                            const QString& appName, const QString& path) {
  const TimeArcAdapters::AdapterInput input =
      adapterInputFromActivity(appId, appName, path, QString());
  const TimeArcAdapters::AdapterMetadata metadata =
      adapterMetadataForIdentifier(groupKey, input);
  if (!metadata.displayName.trimmed().isEmpty()) {
    return metadata.displayName;
  }

  if (const TimeArcSiteCatalog::SiteDefinition* site =
          siteForGroupKey(groupKey)) {
    return site->displayName;
  }

  return appDisplayName(appId, appName, path);
}

// 活动分类（本地确定性，记忆湖用）。除 exe/显示名外，**还读窗口标题**作为分类信号
// （仅本地：用于定类别，绝不展示原文、不进 AI、不落库，符合隐私边界=仅本地聚合）。
// 系统/外壳进程单列为「系统」，便于 UI 降权（不当主角/不当头条类别）。
// 站点特例（site:bilibili 等）已在 groupKey 体现，这里按 groupKey 直接定。
QString classifyActivityImpl(const QString& groupKey, const QString& appId,
                             const QString& appName, const QString& path,
                             const QString& windowTitle) {
  const TimeArcAdapters::AdapterInput input =
      adapterInputFromActivity(appId, appName, path, windowTitle);
  const TimeArcAdapters::AdapterMetadata metadata =
      adapterMetadataForIdentifier(groupKey, input);
  if (!metadata.category.trimmed().isEmpty()) {
    return metadata.category;
  }

  if (const TimeArcSiteCatalog::SiteDefinition* site =
          siteForGroupKey(groupKey)) {
    return site->category;
  }

  // 关键：**类别关键词只匹配 exe 身份（id）**，不匹配窗口标题——否则泛词（game/
  // excel/docker/powershell…）会被任意网页标题误命中（如 Chrome 标题含 "game" 被判
  // 游戏）。窗口标题只用于"浏览器内站点细分"这一个高置信度场景。
  const QString id = (appId + " " + appName + " " + path).toLower();
  const QString title = windowTitle.toLower();

  if (containsAny(id, {"startmenuexperiencehost", "searchhost", "searchapp",
                        "shellexperiencehost", "lockapp", "applicationframehost",
                        "textinputhost", "dwm.exe", "sihost", "ctfmon",
                        "systemsettings", "useroobe", "explorer.exe",
                        "windows\\explorer", "rundll32", "taskmgr", "winlogon",
                        "fontdrvhost", "wininit", "csrss", "smartscreen",
                        "svchost.exe", "runtimebroker.exe", "taskhostw.exe",
                        "dllhost.exe", "conhost.exe", "wmiprvse.exe",
                        "audiodg.exe", "widgets.exe", "nvcontainer.exe"}))
    return QStringLiteral("系统");

  if (containsAny(id, {"uu.exe", "uu\\", "uu/", "uu accelerator",
                       "uu booster", "netease\\uu", "netease/uu"}))
    return QStringLiteral("游戏");

  // 浏览器：先按 exe 认定，再**仅用站点专名标题词**细分到 视频/音乐，否则 浏览。
  if (containsAny(id, {"chrome.exe", "google\\chrome", "msedge", "edge.exe",
                       "firefox", "opera.exe", "brave", "vivaldi", "360se",
                       "qqbrowser", "sogouexplorer", "ucbrowser"})) {
    if (containsAny(title, {"bilibili", "b23.tv", "youtube", "youku", "iqiyi",
                            "netflix", "twitch", "douyu", "huya", "腾讯视频",
                            "爱奇艺", "优酷"}))
      return QStringLiteral("视频");
    if (containsAny(title, {"music.163", "网易云音乐", "qq音乐", "spotify"}))
      return QStringLiteral("音乐");
    return QStringLiteral("浏览");
  }

  if (containsAny(id, {"codex", "code.exe", "vscode", "devenv", "clion", "pycharm",
                       "idea64", "goland", "webstorm", "rider", "qtcreator",
                       "android studio", "sublime_text", "notepad++", "neovim",
                       "powershell", "windowsterminal", "cmd.exe", "conemu",
                       "git-bash", "mingw", "docker", "datagrip", "dbeaver",
                       "postman"}))
    return QStringLiteral("开发");

  if (containsAny(id, {"bilibili", "potplayer", "vlc.exe", "tencentvideo",
                       "qqlive", "mpv.exe", "mpc-hc", "iqiyi", "youku"}))
    return QStringLiteral("视频");

  if (containsAny(id, {"qqmusic", "cloudmusic", "netease cloud music",
                       "spotify", "kugou",
                       "kuwo", "foobar"}))
    return QStringLiteral("音乐");

  if (containsAny(id, {"weixin", "wechat", "discord", "telegram", "slack",
                       "qq.exe", "tim.exe", "dingtalk", "feishu", "lark",
                       "teams.exe", "whatsapp", "skype"}))
    return QStringLiteral("社交");

  if (containsAny(id, {"steam.exe", "steamwebhelper", "epicgames", "riotclient",
                        "leagueoflegends", "valorant", "genshin", "yuanshen",
                        "starrail", "streetfighter", "wegame", "battle.net",
                        "ubisoft", "gog galaxy", "r5apex", "apex legends"}))
    return QStringLiteral("游戏");

  if (containsAny(id, {"winword", "excel.exe", "powerpnt", "onenote", "outlook",
                       "wps.exe", "et.exe", "wpp.exe", "acrobat", "acrord32",
                       "foxit", "sumatrapdf"}))
    return QStringLiteral("办公");

  if (containsAny(id, {"photoshop", "illustrator", "premiere", "afterfx",
                       "lightroom", "figma", "blender", "obs64", "obs.exe",
                       "capcut", "jianying", "davinci", "resolve.exe",
                       "audition", "coreldraw", "3dsmax", "maya.exe",
                       "wallpaperengine", "wallpaper engine", "wallpaperui",
                       "wallpaper32", "wallpaper64", "webwallpaper"}))
    return QStringLiteral("创作");

  if (containsAny(id, {"notion", "obsidian", "typora", "evernote", "youdao",
                       "joplin", "logseq", "zotero", "calibre", "kindle"}))
    return QStringLiteral("笔记");

  return QStringLiteral("其他");
}

// 记忆化包装（同 activityGroupKey：纯函数确定性，进程内静态缓存无需失效）。
QString classifyActivity(const QString& groupKey, const QString& appId,
                         const QString& appName, const QString& path,
                         const QString& windowTitle) {
  static QHash<QString, QString> cache;
  const QChar sep(QChar(0x1f));
  const QString k = groupKey + sep + appId + sep + appName + sep + path + sep + windowTitle;
  const auto it = cache.constFind(k);
  if (it != cache.constEnd()) return it.value();
  const QString result =
      classifyActivityImpl(groupKey, appId, appName, path, windowTitle);
  if (cache.size() < 200000) cache.insert(k, result);
  return result;
}

// 从 app 图标位图提取最多 3 个主色调（跳过透明/接近灰/接近黑白），按 path 缓存。
// 用于背景/封面的多色晕染，贴合该 app 图标真实观感（取代查表/哈希的预设单色）。
QStringList iconDominantColors(const QString& path) {
  static QHash<QString, QStringList> cache;
  if (path.trimmed().isEmpty()) return QStringList();
  const auto hit = cache.constFind(path);
  if (hit != cache.constEnd()) return hit.value();

  QStringList colors;
  const QFileInfo fi(path);
  if (fi.exists()) {
    static QFileIconProvider provider;
    const QPixmap pm = provider.icon(fi).pixmap(48, 48);
    if (!pm.isNull()) {
      const QImage img = pm.toImage().convertToFormat(QImage::Format_ARGB32);
      QHash<QRgb, int> hist;
      for (int y = 0; y < img.height(); ++y) {
        for (int x = 0; x < img.width(); ++x) {
          const QColor c = img.pixelColor(x, y);
          if (c.alpha() < 128) continue;
          const int mx = std::max({c.red(), c.green(), c.blue()});
          const int mn = std::min({c.red(), c.green(), c.blue()});
          if (mx - mn < 28) continue;         // 接近灰，丢弃
          if (mx < 45 || mn > 225) continue;  // 接近黑/白，丢弃
          const int qr = (c.red() / 32) * 32 + 16;
          const int qg = (c.green() / 32) * 32 + 16;
          const int qb = (c.blue() / 32) * 32 + 16;
          hist[qRgb(qr, qg, qb)] += 1;
        }
      }
      struct Bin { QRgb rgb; int n; };
      QVector<Bin> bins;
      for (auto it = hist.constBegin(); it != hist.constEnd(); ++it)
        bins.append({it.key(), it.value()});
      std::sort(bins.begin(), bins.end(),
                [](const Bin& a, const Bin& b) { return a.n > b.n; });
      for (int i = 0; i < bins.size() && colors.size() < 3; ++i) {
        const QColor c(bins[i].rgb);
        bool dup = false;
        for (const QString& h : colors) {
          const QColor e(h);
          if (qAbs(e.red() - c.red()) + qAbs(e.green() - c.green()) +
                  qAbs(e.blue() - c.blue()) <
              64) {
            dup = true;
            break;
          }
        }
        if (!dup) colors << c.name();
      }
    }
  }
  cache.insert(path, colors);
  return colors;
}

// SQLite history read source. The GUI opens this as a read-only service DB
// connection; the service process is the only writer.
const QString kTimearcConnection = QStringLiteral("timearc_service");

// The service writes app_id as the stable identity, display_name as the short
// app name, and executable_path as path. Keep the seven-column normalized read
// shape consumed below while using SQLite rowid as the incremental watermark.
const QString kSqlFrontmostSince = QStringLiteral(R"SQL(
SELECT fs.app_id,
       COALESCE(NULLIF(a.display_name, ''), fs.app_id),
       COALESCE(NULLIF(a.executable_path, ''), fs.app_id),
       fs.window_title, fs.start_unix_sec, fs.duration_sec, fs.rowid
FROM frontmost_sessions fs
LEFT JOIN apps a ON a.app_id = fs.app_id
WHERE fs.rowid > :sinceId
ORDER BY fs.rowid ASC;
)SQL");

// media_sessions is the audio side of the D5 union (the whole table is audio:
// the service only ever writes media_type='audio').
const QString kSqlMediaSince = QStringLiteral(R"SQL(
SELECT ms.app_id,
       COALESCE(NULLIF(a.display_name, ''), ms.app_id),
       COALESCE(NULLIF(a.executable_path, ''), ms.app_id),
       ms.media_title, ms.start_unix_sec, ms.duration_sec, ms.rowid
FROM media_sessions ms
LEFT JOIN apps a ON a.app_id = ms.app_id
WHERE ms.rowid > :sinceId
ORDER BY ms.rowid ASC;
)SQL");

}  // namespace

UsageStatManager::UsageStatManager(QObject* parent) : QObject(parent) {
  refresh();
}

int UsageStatManager::todaySoftwareMinutes() const {
  return softwareSecondsForRange("day") / 60;
}

int UsageStatManager::monthSoftwareMinutes() const {
  return softwareSecondsForRange("month") / 60;
}

int UsageStatManager::yearSoftwareMinutes() const {
  return softwareSecondsForRange("year") / 60;
}

int UsageStatManager::allSoftwareMinutes() const {
  return softwareSecondsForRange("all") / 60;
}

void UsageStatManager::refresh() {
  // refresh 是 UI 的数据入口：增量装载 SQLite 历史后 emit。增量守卫令空闲
  // 5s tick 近乎零成本（无新行→不自增 recordsGeneration→统计页跳过重算）。
  refreshHistoryFromSqlite();
  emit usageStatsChanged();
}

bool UsageStatManager::sqliteMaxIds(QSqlDatabase& db, qint64* maxFront,
                                    qint64* maxMedia) const {
  *maxFront = 0;
  *maxMedia = 0;
  if (!db.isValid() || !db.isOpen()) return false;
  QSqlQuery query(db);
  if (!query.exec(QStringLiteral(
          "SELECT (SELECT COALESCE(MAX(rowid), 0) FROM frontmost_sessions), "
          "(SELECT COALESCE(MAX(rowid), 0) FROM media_sessions);"))) {
    qWarning() << "UsageStatManager: failed to read SQLite watermarks:"
               << query.lastError().text();
    return false;
  }
  if (!query.next()) return false;
  *maxFront = query.value(0).toLongLong();
  *maxMedia = query.value(1).toLongLong();
  return true;
}

int UsageStatManager::appendSqliteSessionsSince(QList<UsageRecord>* out,
                                                const QString& sql,
                                                const QString& source,
                                                qint64* sinceMaxId) const {
  if (!QSqlDatabase::contains(kTimearcConnection)) return 0;
  QSqlDatabase db = QSqlDatabase::database(kTimearcConnection, false);
  if (!db.isValid() || !db.isOpen()) return 0;
  QSqlQuery query(db);
  if (!query.prepare(sql)) {
    qWarning() << "UsageStatManager: failed to prepare SQLite session query:"
               << query.lastError().text();
    return 0;
  }
  query.bindValue(QStringLiteral(":sinceId"), *sinceMaxId);
  if (!query.exec()) {
    qWarning() << "UsageStatManager: failed to read SQLite sessions:"
               << query.lastError().text();
    return 0;
  }
  int added = 0;
  while (query.next()) {
    const qint64 id = query.value(6).toLongLong();
    if (id > *sinceMaxId) *sinceMaxId = id;  // 推进水位（含被跳过行，避免重扫）

    UsageRecord record;
    record.appId = query.value(0).toString();
    record.appName = query.value(1).toString();
    record.path = query.value(2).toString();
    record.windowTitle = query.value(3).toString();
    record.startUnixSec = query.value(4).toLongLong();
    const qlonglong dur = query.value(5).toLongLong();
    record.durationSec = dur > 0 ? static_cast<quint64>(dur) : 0;
    record.source = source;
    // Reject invalid or empty session rows before aggregation.
    if (record.startUnixSec <= 0 || record.durationSec == 0) continue;
    if (record.appId.trimmed().isEmpty() && record.appName.trimmed().isEmpty())
      continue;
    out->append(record);
    ++added;
  }
  return added;
}

void UsageStatManager::refreshHistoryFromSqlite() {
  if (!QSqlDatabase::contains(kTimearcConnection)) {
    if (m_historyInitialized || !m_records.isEmpty()) {
      m_records.clear();
      m_sqliteFrontmostMaxId = 0;
      m_sqliteMediaMaxId = 0;
      m_historyInitialized = false;
      ++m_recordsGeneration;
    }
    return;
  }
  QSqlDatabase db = QSqlDatabase::database(kTimearcConnection, false);
  if (db.isValid() && !db.isOpen() && QFileInfo::exists(db.databaseName()) &&
      !db.open()) {
    qWarning() << "UsageStatManager: failed to open service SQLite database:"
               << db.databaseName() << db.lastError().text();
  }
  qint64 maxFront = 0;
  qint64 maxMedia = 0;
  const bool ok = sqliteMaxIds(db, &maxFront, &maxMedia);
  if (!ok) {
    if (m_historyInitialized || !m_records.isEmpty()) {
      m_records.clear();
      m_sqliteFrontmostMaxId = 0;
      m_sqliteMediaMaxId = 0;
      m_historyInitialized = false;
      ++m_recordsGeneration;
    }
    return;
  }

  bool full = !m_historyInitialized;
  const bool shrank =
      (maxFront < m_sqliteFrontmostMaxId) || (maxMedia < m_sqliteMediaMaxId);
  if (full || shrank) {  // 首次读取 / 库被替换（水位回退）→ 全量重载
    m_records.clear();
    m_sqliteFrontmostMaxId = 0;
    m_sqliteMediaMaxId = 0;
    m_historyInitialized = true;
    full = true;
  }

  int added = 0;
  if (full || maxFront > m_sqliteFrontmostMaxId ||
      maxMedia > m_sqliteMediaMaxId) {
    added += appendSqliteSessionsSince(&m_records, kSqlFrontmostSince,
                                       QStringLiteral("foreground"),
                                       &m_sqliteFrontmostMaxId);
    added += appendSqliteSessionsSince(&m_records, kSqlMediaSince,
                                       QStringLiteral("audio"),
                                       &m_sqliteMediaMaxId);
  }
  if (full || added > 0) ++m_recordsGeneration;
}

QVariantList UsageStatManager::softwareForRange(const QString& range) const {
  return activeSoftwareForRange(range);
}

QVariantList UsageStatManager::activeSoftwareForRange(
    const QString& range) const {
  return aggregateSoftwareForRange(range, QString());
}

QVariantList UsageStatManager::foregroundSoftwareForRange(
    const QString& range) const {
  return aggregateSoftwareForRange(range, "foreground");
}

QVariantList UsageStatManager::audioForRange(const QString& range) const {
  return aggregateSoftwareForRange(range, "audio");
}

QVariantList UsageStatManager::aggregateSoftwareForRange(
    const QString& range, const QString& sourceFilter) const {
  return aggregateSoftware(
      [&](const UsageRecord& record) { return matchesRange(record, range); },
      sourceFilter);
}

QVariantList UsageStatManager::aggregateSoftware(
    const std::function<bool(const UsageRecord&)>& inWindow,
    const QString& sourceFilter) const {
  // 聚合先按 activity key 收集所有时间区间，再在输出时合并重叠区间。
  // sourceFilter 为空表示 active 合并视图；否则只看 foreground 或 audio。
  struct Aggregate {
    QString groupKey;
    QString appId;
    QString appName;
    QString path;
    QVector<UsageInterval> intervals;
    QVector<UsageInterval> foregroundIntervals;
    QVector<UsageInterval> audioIntervals;
    QMap<QString, quint64> categorySeconds;  // 按窗口标题逐记录分类、时长加权
    bool hasForeground = false;
    bool hasAudio = false;
  };

  QMap<QString, Aggregate> grouped;
  const auto addRecord = [&](const UsageRecord& record) {
    if (!inWindow(record)) return;
    if (!matchesSource(record, sourceFilter)) return;
    if (record.durationSec == 0) return;

    const QString key = effectiveGroupKey(record);
    if (key.isEmpty()) return;  // 逐项显隐：被排除的 app 不计入聚合（2B）
    const qint64 endUnixSec =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    if (record.startUnixSec <= 0 || endUnixSec <= record.startUnixSec) return;

    // 引用就地累加（原先 value()拷出 + [key]=拷回 会把不断增长的 intervals 每条记录
    // 深拷两次 → O(N²)，重度前台 app 一周数千条时是 activeSoftware 的主要耗时）。
    Aggregate& aggregate = grouped[key];
    if (aggregate.groupKey.trimmed().isEmpty()) {
      aggregate.groupKey = key;
    }
    if (aggregate.appId.trimmed().isEmpty()) {
      aggregate.appId =
          !record.appId.trimmed().isEmpty() ? record.appId : key;
    }
    if (aggregate.appName.trimmed().isEmpty()) {
      aggregate.appName = !record.appName.trimmed().isEmpty()
                              ? record.appName
                              : QFileInfo(record.path).fileName();
    }
    if (aggregate.path.trimmed().isEmpty()) {
      aggregate.path = record.path;
    }
    const UsageInterval interval{record.startUnixSec, endUnixSec};
    aggregate.intervals.append(interval);
    // 保留 foreground/audio 分项，UI 可以同时显示总时长和来源拆分。
    if (record.source == "audio") {
      aggregate.audioIntervals.append(interval);
      aggregate.hasAudio = true;
    } else {
      aggregate.foregroundIntervals.append(interval);
      aggregate.hasForeground = true;
    }
    // 逐记录按窗口标题分类、按时长累加，输出时取占比最高的类别。
    aggregate.categorySeconds[classifyActivity(
        key, record.appId, record.appName, record.path, record.windowTitle)] +=
        record.durationSec;
  };

  for (const UsageRecord& record : m_records) {
    addRecord(record);
  }

  QVariantList result;
  for (const Aggregate& aggregate : grouped) {
    const quint64 seconds = mergedIntervalSeconds(aggregate.intervals);
    if (seconds == 0) continue;
    const quint64 foregroundSeconds =
        mergedIntervalSeconds(aggregate.foregroundIntervals);
    const quint64 audioSeconds = mergedIntervalSeconds(aggregate.audioIntervals);

    const QString displayName = activityDisplayName(
        aggregate.groupKey, aggregate.appId, aggregate.appName, aggregate.path);
    const TimeArcAdapters::AdapterInput adapterInput = adapterInputFromActivity(
        aggregate.appId, aggregate.appName, aggregate.path, QString());
    const TimeArcAdapters::AdapterMetadata adapterMetadata =
        adapterMetadataForIdentifier(aggregate.groupKey, adapterInput);

    QVariantMap item;
    item["groupKey"] = aggregate.groupKey;
    item["appId"] = aggregate.groupKey.startsWith("site:")
                        ? aggregate.groupKey
                        : aggregate.appId;
    item["appName"] = aggregate.appName;
    item["name"] = displayName;
    item["path"] = aggregate.path;
    QString topCategory = QStringLiteral("其他");
    quint64 topCatSec = 0;
    for (auto it = aggregate.categorySeconds.constBegin();
         it != aggregate.categorySeconds.constEnd(); ++it) {
      if (it.value() > topCatSec) {
        topCatSec = it.value();
        topCategory = it.key();
      }
    }
    // dev：适配器元数据可覆盖类别（若提供）。
    if (!adapterMetadata.category.trimmed().isEmpty()) {
      topCategory = adapterMetadata.category;
    }
    // 2A：用户开关在适配器之后再门控——关「自动分类」→ 类别一律「其他」；
    // 关「游戏识别」→ 游戏类（含适配器给出的）降级为「其他」。
    if (!m_autoClassify) {
      topCategory = QStringLiteral("其他");
    } else if (!m_gameClassify && topCategory == QStringLiteral("游戏")) {
      topCategory = QStringLiteral("其他");
    }
    item["category"] = topCategory;
    item["homeRankVisible"] =
        isHomeRankVisibleActivity(aggregate.groupKey, aggregate.appId,
                                  aggregate.appName, aggregate.path,
                                  displayName, topCategory);
    // 站点组（如 site:bilibili）的 path 是**浏览器 exe**，取图标色会错成浏览器色调
    // （用户反馈：bilibili 背景显示成 Chrome 的色）。站点组留空 -> QML 退回 appColor
    // 的站点品牌色（site:bilibili -> 粉色）。避免任何 site:* 组取到宿主浏览器色。
    item["iconColors"] = aggregate.groupKey.startsWith("site:")
                             ? QStringList()
                             : iconDominantColors(aggregate.path);
    if (const TimeArcSiteCatalog::SiteDefinition* site =
            siteForGroupKey(aggregate.groupKey)) {
      item["siteDomain"] = site->domain;
      item["brandColor"] = site->brandColor;
      item["iconLabel"] = site->iconLabel;
      item["iconSource"] = site->iconSource;
    }
    applyAdapterMetadata(&item, adapterMetadata, aggregate.path);
    item["source"] = sourceFilter.trimmed().isEmpty()
                         ? "active"
                         : normalizedSource(sourceFilter);
    item["sources"] = aggregate.hasForeground && aggregate.hasAudio
                          ? "foreground,audio"
                          : (aggregate.hasAudio ? "audio" : "foreground");
    item["seconds"] = static_cast<qlonglong>(seconds);
    item["minutes"] = static_cast<int>(seconds / 60);
    item["time"] = secondsToTimeText(seconds);
    item["foregroundSeconds"] =
        static_cast<qlonglong>(foregroundSeconds);
    item["audioSeconds"] = static_cast<qlonglong>(audioSeconds);
    item["foregroundTime"] = secondsToTimeText(foregroundSeconds);
    item["audioTime"] = secondsToTimeText(audioSeconds);
    QString subtitle;
    if (aggregate.hasForeground && aggregate.hasAudio) {
      subtitle = "Foreground + audio";
    } else if (aggregate.hasAudio) {
      subtitle = "Audio playback";
    } else {
      subtitle = "Foreground usage";
    }
    const QString subtitleName =
        aggregate.groupKey.startsWith("site:")
            ? appDisplayName(aggregate.appId, aggregate.appName, aggregate.path)
            : aggregate.appName;
    item["note"] = subtitle;
    item["subtitle"] = subtitleName == displayName
                           ? subtitle
                           : subtitleName + " - " + subtitle;
    result.append(item);
  }

  std::sort(result.begin(), result.end(),
            [](const QVariant& left, const QVariant& right) {
              return left.toMap().value("seconds", 0).toLongLong() >
                     right.toMap().value("seconds", 0).toLongLong();
            });

  return result;
}

int UsageStatManager::softwareSecondsForRange(const QString& range) const {
  return activeSoftwareSecondsForRange(range);
}

int UsageStatManager::activeSoftwareSecondsForRange(
    const QString& range) const {
  return aggregateSoftwareSecondsForRange(range, QString());
}

int UsageStatManager::foregroundSoftwareSecondsForRange(
    const QString& range) const {
  return aggregateSoftwareSecondsForRange(range, "foreground");
}

int UsageStatManager::audioSecondsForRange(const QString& range) const {
  return aggregateSoftwareSecondsForRange(range, "audio");
}

int UsageStatManager::aggregateSoftwareSecondsForRange(
    const QString& range, const QString& sourceFilter) const {
  quint64 total = 0;
  const QVariantList items = aggregateSoftwareForRange(range, sourceFilter);
  for (const QVariant& item : items) {
    total += static_cast<quint64>(
        item.toMap().value("seconds", 0).toLongLong());
  }

  return total > static_cast<quint64>(std::numeric_limits<int>::max())
             ? std::numeric_limits<int>::max()
             : static_cast<int>(total);
}

QVariantList UsageStatManager::foregroundSegmentsImpl(
    const std::function<bool(const UsageRecord&)>& inWindow) const {
  // 只看前台记录（service 已按"同 exe+同窗口标题连续"切会话；浏览器换标签标题
  // 会滚动新记录），按 activity key 分组，相邻间隙 <= 60s 合并成一次"会话段"，
  // 既消除标题抖动，又保留真实再次访问（中间隔了别的 app -> 有真实间隙，不合并）。
  struct AppSessions {
    QString groupKey;
    QString appId;
    QString appName;
    QString path;
    QVector<UsageInterval> intervals;
  };

  QMap<QString, AppSessions> grouped;
  const auto addRecord = [&](const UsageRecord& record) {
    if (record.source == "audio") return;  // 仅前台
    if (!inWindow(record)) return;
    if (record.durationSec == 0) return;

    const qint64 endUnixSec =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    if (record.startUnixSec <= 0 || endUnixSec <= record.startUnixSec) return;

    const QString key = effectiveGroupKey(record);
    if (key.isEmpty()) return;  // 逐项显隐：被排除的 app 不计入会话段（2B）
    AppSessions& app = grouped[key];
    if (app.groupKey.trimmed().isEmpty()) {
      app.groupKey = key;
      app.appId = key.startsWith("site:")
                      ? key
                      : (!record.appId.trimmed().isEmpty() ? record.appId : key);
      app.appName = !record.appName.trimmed().isEmpty()
                        ? record.appName
                        : QFileInfo(record.path).fileName();
      app.path = record.path;
    }
    if (app.path.trimmed().isEmpty() && !record.path.trimmed().isEmpty()) {
      app.path = record.path;
    }
    app.intervals.append({record.startUnixSec, endUnixSec});
  };

  for (const UsageRecord& record : m_records) addRecord(record);

  // 相邻会话间隙 <= 60s 视为同一次连续使用。
  constexpr qint64 kMergeGapSec = 60;

  QVariantList result;
  for (AppSessions& app : grouped) {
    std::sort(app.intervals.begin(), app.intervals.end(),
              [](const UsageInterval& a, const UsageInterval& b) {
                return a.start < b.start;
              });

    QVariantList segments;
    qint64 longestSec = 0;
    qint64 curStart = 0;
    qint64 curEnd = 0;
    bool open = false;
    const auto flush = [&]() {
      if (!open) return;
      const qint64 secs = curEnd - curStart;
      QVariantMap seg;
      seg["startUnixSec"] = static_cast<qlonglong>(curStart);
      seg["endUnixSec"] = static_cast<qlonglong>(curEnd);
      seg["seconds"] = static_cast<qlonglong>(secs);
      segments.append(seg);
      if (secs > longestSec) longestSec = secs;
      open = false;
    };

    for (const UsageInterval& interval : app.intervals) {
      if (!open) {
        curStart = interval.start;
        curEnd = interval.end;
        open = true;
        continue;
      }
      if (interval.start - curEnd <= kMergeGapSec) {
        curEnd = std::max(curEnd, interval.end);
      } else {
        flush();
        curStart = interval.start;
        curEnd = interval.end;
        open = true;
      }
    }
    flush();

    QVariantMap item;
    item["groupKey"] = app.groupKey;
    item["appId"] = app.appId;
    item["appName"] = app.appName;
    item["path"] = app.path;
    item["sessionCount"] = segments.size();
    item["longestSec"] = static_cast<qlonglong>(longestSec);
    item["segments"] = segments;
    const TimeArcAdapters::AdapterInput adapterInput =
        adapterInputFromActivity(app.appId, app.appName, app.path, QString());
    applyAdapterMetadata(
        &item, adapterMetadataForIdentifier(app.groupKey, adapterInput),
        app.path);
    result.append(item);
  }

  return result;
}

QVariantList UsageStatManager::foregroundSegmentsForRange(
    const QString& range) const {
  return foregroundSegmentsImpl(
      [&](const UsageRecord& record) { return matchesRange(record, range); });
}

// 任意窗口版（统计页期次 prev/next）：按记录起始 unix 落在 [start,end] 闭区间筛选，
// 与 matchesRange 当前周/月/年的按起始日口径一致（QML 传入本地周期边界，末秒为 end）。
QVariantList UsageStatManager::foregroundSegmentsForWindow(
    qint64 startUnixSec, qint64 endUnixSec) const {
  return foregroundSegmentsImpl([&](const UsageRecord& record) {
    return record.startUnixSec >= startUnixSec &&
           record.startUnixSec <= endUnixSec;
  });
}

QVariantList UsageStatManager::activeSoftwareForWindow(qint64 startUnixSec,
                                                       qint64 endUnixSec) const {
  return aggregateSoftware(
      [&](const UsageRecord& record) {
        return record.startUnixSec >= startUnixSec &&
               record.startUnixSec <= endUnixSec;
      },
      QString());
}

int UsageStatManager::activeSoftwareSecondsForWindow(qint64 startUnixSec,
                                                     qint64 endUnixSec) const {
  quint64 total = 0;
  const QVariantList items = activeSoftwareForWindow(startUnixSec, endUnixSec);
  for (const QVariant& item : items) {
    total += static_cast<quint64>(
        item.toMap().value("seconds", 0).toLongLong());
  }
  return total > static_cast<quint64>(std::numeric_limits<int>::max())
             ? std::numeric_limits<int>::max()
             : static_cast<int>(total);
}

QVariantList UsageStatManager::activeSoftwareForMonth(int year,
                                                      int month) const {
  return aggregateSoftware(
      [&](const UsageRecord& record) {
        return matchesYearMonth(record, year, month);
      },
      QString());
}

QVariantList UsageStatManager::dailySecondsForMonth(int year, int month) const {
  // 按天分桶：day -> (groupKey -> intervals)。每天对各 app 自身区间求并集时长
  // 再相加，与 softwareSecondsForRange("month") 同口径（避免与月总值自相矛盾）。
  QMap<int, QMap<QString, QVector<UsageInterval>>> byDay;
  const auto add = [&](const UsageRecord& record) {
    if (record.durationSec == 0) return;
    const QDate d =
        QDateTime::fromSecsSinceEpoch(record.startUnixSec).toLocalTime().date();
    if (!d.isValid() || d.year() != year || d.month() != month) return;
    const qint64 end =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    if (record.startUnixSec <= 0 || end <= record.startUnixSec) return;
    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    if (m_hiddenKeys.contains(key)) return;  // 2B 隐藏 app 不计入趋势
    byDay[d.day()][key].append({record.startUnixSec, end});
  };
  for (const UsageRecord& record : m_records) add(record);

  QVariantList result;
  // 当月只覆盖到"今天"为止——绝不把尚未发生的未来天补成 0，否则趋势会被未来的
  // 全 0 尾巴误判成"月末回落"（一种数据不支持的断言）。过去的月用整月天数。
  const QDate today = QDate::currentDate();
  int days = QDate(year, month, 1).daysInMonth();
  if (year == today.year() && month == today.month()) days = today.day();
  for (int day = 1; day <= days; ++day) {
    qint64 total = 0;
    const auto dayIt = byDay.constFind(day);
    if (dayIt != byDay.constEnd()) {
      for (auto it = dayIt->constBegin(); it != dayIt->constEnd(); ++it) {
        total += static_cast<qint64>(mergedIntervalSeconds(it.value()));
      }
    }
    QVariantMap m;
    m["day"] = day;
    m["seconds"] = static_cast<qlonglong>(total);
    result.append(m);
  }
  return result;
}

QVariantList UsageStatManager::dailySecondsForRange(qint64 startUnixSec,
                                                    qint64 endUnixSec) const {
  // 任意窗口逐日 active(前台+音频并集) 秒数，口径与 dailySecondsForMonth 完全一致
  // （每天对各 app 自身区间求并集再相加，按记录起始日分桶）。返回窗口内每个本地
  // 自然日一项 [{dayStartUnix:qlonglong, seconds:qlonglong}]（无记录补 0），供
  // 周 7 柱 / 任意期次序列用。只组合自身 m_records，不开新数据路径，安全面同月版。
  QVariantList result;
  if (endUnixSec <= startUnixSec) return result;

  const QDate startDate =
      QDateTime::fromSecsSinceEpoch(startUnixSec).toLocalTime().date();
  const QDate endDate =
      QDateTime::fromSecsSinceEpoch(endUnixSec).toLocalTime().date();
  if (!startDate.isValid() || !endDate.isValid()) return result;

  // 按本地自然日分桶：ISO 日期串 -> (groupKey -> intervals)。
  QMap<QString, QMap<QString, QVector<UsageInterval>>> byDay;
  const auto add = [&](const UsageRecord& record) {
    if (record.durationSec == 0) return;
    const qint64 recEnd =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    if (record.startUnixSec <= 0 || recEnd <= record.startUnixSec) return;
    const QDate d =
        QDateTime::fromSecsSinceEpoch(record.startUnixSec).toLocalTime().date();
    if (!d.isValid() || d < startDate || d > endDate) return;
    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    if (m_hiddenKeys.contains(key)) return;  // 2B 隐藏 app 不计入趋势
    byDay[d.toString(Qt::ISODate)][key].append({record.startUnixSec, recEnd});
  };
  for (const UsageRecord& record : m_records) add(record);

  for (QDate d = startDate; d <= endDate; d = d.addDays(1)) {
    qint64 total = 0;
    const auto dayIt = byDay.constFind(d.toString(Qt::ISODate));
    if (dayIt != byDay.constEnd()) {
      for (auto it = dayIt->constBegin(); it != dayIt->constEnd(); ++it) {
        total += static_cast<qint64>(mergedIntervalSeconds(it.value()));
      }
    }
    QVariantMap m;
    m["dayStartUnix"] =
        static_cast<qlonglong>(d.startOfDay().toSecsSinceEpoch());
    m["seconds"] = static_cast<qlonglong>(total);
    result.append(m);
  }
  return result;
}

QVariantList UsageStatManager::monthlySecondsForYear(int year) const {
  // 指定年的 12 个月 active(前台∪音频并集) 秒序列，口径同 dailySecondsForMonth。
  // 单遍扫描 m_records 按月分桶（替代统计页年视图 12 次 activeSoftwareForMonth）。
  // 当年只到当前月、过去年整 12 月、未来年全 0（不造假未来）。
  QMap<int, QMap<QString, QVector<UsageInterval>>> byMonth;
  const auto add = [&](const UsageRecord& record) {
    if (record.durationSec == 0) return;
    const QDate d =
        QDateTime::fromSecsSinceEpoch(record.startUnixSec).toLocalTime().date();
    if (!d.isValid() || d.year() != year) return;
    const qint64 end =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    if (record.startUnixSec <= 0 || end <= record.startUnixSec) return;
    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    if (m_hiddenKeys.contains(key)) return;  // 2B 隐藏 app 不计入趋势
    byMonth[d.month()][key].append({record.startUnixSec, end});
  };
  for (const UsageRecord& record : m_records) add(record);

  const QDate today = QDate::currentDate();
  int upTo = 12;
  if (year == today.year()) upTo = today.month();
  if (year > today.year()) upTo = 0;

  QVariantList result;
  for (int mo = 1; mo <= 12; ++mo) {
    qint64 total = 0;
    if (mo <= upTo) {
      const auto it = byMonth.constFind(mo);
      if (it != byMonth.constEnd()) {
        for (auto j = it->constBegin(); j != it->constEnd(); ++j)
          total += static_cast<qint64>(mergedIntervalSeconds(j.value()));
      }
    }
    QVariantMap m;
    m["month"] = mo;
    m["seconds"] = static_cast<qlonglong>(total);
    result.append(m);
  }
  return result;
}

QVariantMap UsageStatManager::focusStatsForWindow(qint64 startUnixSec,
                                                  qint64 endUnixSec) const {
  // 专注（A-5）= 开发/办公/笔记 类目的活动派生连续块：把窗口内 focus 类目记录跨 app
  // 汇成时间轴，相邻间隙 <= 10min 合并成块，块时长 >= 5min 才计入。
  // focusSeconds = 块总秒；focusDays = 含 focus 块的本地自然日数。只读 m_records。
  constexpr qint64 kFocusGapSec = 600;   // 10min
  constexpr qint64 kMinBlockSec = 300;   // 5min
  static const QSet<QString> kFocusCats = {QStringLiteral("开发"),
                                           QStringLiteral("办公"),
                                           QStringLiteral("笔记")};
  // 2A 关「自动分类」→ 无类别基础，专注归零（与 ranking 类别口径一致，不残留旧分类）。
  if (!m_autoClassify) {
    QVariantMap zero;
    zero["focusSeconds"] = static_cast<qlonglong>(0);
    zero["focusDays"] = 0;
    return zero;
  }
  QVector<UsageInterval> intervals;
  const auto add = [&](const UsageRecord& record) {
    if (record.durationSec == 0) return;
    if (record.startUnixSec < startUnixSec || record.startUnixSec > endUnixSec)
      return;
    const qint64 end =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    if (record.startUnixSec <= 0 || end <= record.startUnixSec) return;
    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    if (m_hiddenKeys.contains(key)) return;  // 2B 隐藏 app 不计入专注
    const QString cat = classifyActivity(key, record.appId, record.appName,
                                         record.path, record.windowTitle);
    if (!kFocusCats.contains(cat)) return;
    intervals.append({record.startUnixSec, end});
  };
  for (const UsageRecord& record : m_records) add(record);

  std::sort(intervals.begin(), intervals.end(),
            [](const UsageInterval& a, const UsageInterval& b) {
              return a.start < b.start;
            });

  qint64 focusSeconds = 0;
  QSet<qint64> focusDays;
  qint64 curStart = 0;
  qint64 curEnd = 0;
  bool open = false;
  const auto flush = [&]() {
    if (!open) return;
    const qint64 secs = curEnd - curStart;
    if (secs >= kMinBlockSec) {
      focusSeconds += secs;
      const QDate d0 =
          QDateTime::fromSecsSinceEpoch(curStart).toLocalTime().date();
      const QDate d1 =
          QDateTime::fromSecsSinceEpoch(curEnd).toLocalTime().date();
      for (QDate d = d0; d.isValid() && d <= d1; d = d.addDays(1))
        focusDays.insert(d.toJulianDay());
    }
    open = false;
  };
  for (const UsageInterval& iv : intervals) {
    if (!open) {
      curStart = iv.start;
      curEnd = iv.end;
      open = true;
      continue;
    }
    if (iv.start - curEnd <= kFocusGapSec) {
      curEnd = std::max(curEnd, iv.end);
    } else {
      flush();
      curStart = iv.start;
      curEnd = iv.end;
      open = true;
    }
  }
  flush();

  QVariantMap m;
  m["focusSeconds"] = static_cast<qlonglong>(focusSeconds);
  m["focusDays"] = focusDays.size();
  return m;
}

QString UsageStatManager::exportReport(const QString& fileBaseName,
                                       const QString& jsonContent) const {
  // 把 UI 组装好的统计 JSON 写到 下载/文档 目录（**报告文件，非 usage 数据**，
  // 不动磁盘契约、不写 usage/SQLite）。返回完整路径，失败返回空串。
  QString dir =
      QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
  if (dir.isEmpty())
    dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
  if (dir.isEmpty())
    dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
  QDir().mkpath(dir);

  QString base = fileBaseName;
  base.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9_.-]")),
               QStringLiteral("_"));
  base.remove(QRegularExpression(QStringLiteral("^_+|_+$")));  // 去净化产生的首尾下划线
  if (base.trimmed().isEmpty()) base = QStringLiteral("timearc-stats");
  const QString path = QDir(dir).filePath(base + QStringLiteral(".json"));

  QFile file(path);
  if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) return QString();
  const QByteArray bytes = jsonContent.toUtf8();
  const qint64 written = file.write(bytes);
  file.close();
  if (written != bytes.size()) return QString();  // 短写（磁盘满等）→ 报失败而非假成功
  return path;
}

double UsageStatManager::fileSizeBytes(const QString& path) const {
  // 只读文件大小（QFileInfo）。不读内容、不写、不触碰磁盘契约。文件不存在 → 0。
  QString localPath = path;
  const QUrl url(path);
  if (url.isLocalFile()) localPath = url.toLocalFile();
  if (localPath.trimmed().isEmpty()) return 0.0;
  const QFileInfo info(localPath);
  return info.exists() ? static_cast<double>(info.size()) : 0.0;
}

int UsageStatManager::recordCount() const {
  return static_cast<int>(m_records.size());
}

QString UsageStatManager::effectiveGroupKey(const UsageRecord& record) const {
  // 站点组（site:*）始终保持独立身份（合并开关不影响“看了哪个站点”）。
  const QString mergedKey = activityGroupKey(record.appId, record.appName,
                                             record.path, record.windowTitle);
  if (m_hiddenKeys.contains(mergedKey)) return QString();  // 2B 逐项显隐：排除
  if (m_mergeSimilar || mergedKey.startsWith(QLatin1String("site:")))
    return mergedKey;
  // 2A 关「合并相似应用」：不并多进程变体，按 exe 名细分；无 exe 时退回合并键。
  const QString exe = normalizedExeName(record.appName, record.path);
  return exe.isEmpty() ? mergedKey : (QStringLiteral("exe:") + exe);
}

void UsageStatManager::setReadFilters(bool autoClassify, bool gameClassify,
                                      bool mergeSimilar, bool hideTitles,
                                      const QStringList& hiddenKeys) {
  // UI 私有读层偏好（启动 + 开关变更时由 QML 推入）。只影响 UI 聚合读出，
  // 不写/不删 usage、不动磁盘契约/服务。
  const QSet<QString> hidden(hiddenKeys.begin(), hiddenKeys.end());
  const bool changed =
      m_autoClassify != autoClassify || m_gameClassify != gameClassify ||
      m_mergeSimilar != mergeSimilar || m_hideTitles != hideTitles ||
      m_hiddenKeys != hidden;
  if (!changed) return;
  m_autoClassify = autoClassify;
  m_gameClassify = gameClassify;
  m_mergeSimilar = mergeSimilar;
  m_hideTitles = hideTitles;
  m_hiddenKeys = hidden;
  // 读层口径变化：自增代际让统计页“无新数据则跳过重算”的守卫失效，强制重算 + 刷新各页。
  ++m_recordsGeneration;
  emit usageStatsChanged();
}

QVariantList UsageStatManager::allApps() const {
  // 始终以合并键身份去重（与隐藏集口径一致），忽略合并开关 → 清单稳定。
  struct AppListEntry {
    QString groupKey;
    QString appId;
    QString appName;
    QString path;
    QVector<UsageInterval> intervals;
  };

  QMap<QString, AppListEntry> seen;
  const auto addApp = [&](const UsageRecord& record) {
    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    if (key.isEmpty()) return;
    const qint64 endUnixSec =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    if (record.startUnixSec <= 0 || endUnixSec <= record.startUnixSec) return;

    const QString appName = !record.appName.trimmed().isEmpty()
                                ? record.appName
                                : QFileInfo(record.path).fileName();
    AppListEntry& entry = seen[key];
    if (entry.groupKey.trimmed().isEmpty()) {
      entry.groupKey = key;
      entry.appId = key.startsWith(QLatin1String("site:")) ? key : record.appId;
      entry.appName = appName;
      entry.path = record.path;
    } else if (entry.path.trimmed().isEmpty() && !record.path.trimmed().isEmpty()) {
      entry.path = record.path;
    }
    entry.intervals.append({record.startUnixSec, endUnixSec});
  };
  for (const UsageRecord& record : m_records) addApp(record);

  QVariantList result;
  for (AppListEntry& entry : seen) {
    std::sort(entry.intervals.begin(), entry.intervals.end(),
              [](const UsageInterval& a, const UsageInterval& b) {
                return a.start < b.start;
              });
    const quint64 seconds = mergedIntervalSeconds(entry.intervals);
    const QString displayName =
        activityDisplayName(entry.groupKey, entry.appId, entry.appName,
                            entry.path);
    const QString category =
        classifyActivity(entry.groupKey, entry.appId, entry.appName, entry.path,
                         QString());

    QVariantMap item;
    item["groupKey"] = entry.groupKey;
    item["appId"] = entry.appId;
    item["appName"] = entry.appName;
    item["name"] = displayName;
    item["displayName"] = displayName;
    item["path"] = entry.path;
    item["category"] = category;
    item["seconds"] = static_cast<qlonglong>(seconds);
    item["settingsVisible"] = isSettingsListVisibleActivity(
        entry.groupKey, entry.appId, entry.appName, entry.path, displayName,
        category, seconds);
    item["hidden"] = m_hiddenKeys.contains(entry.groupKey);  // 含被隐藏项，供取消隐藏
    const TimeArcAdapters::AdapterInput adapterInput =
        adapterInputFromActivity(entry.appId, entry.appName, entry.path,
                                 QString());
    applyAdapterMetadata(
        &item, adapterMetadataForIdentifier(entry.groupKey, adapterInput),
        entry.path);
    result.append(item);
  }
  std::sort(result.begin(), result.end(),
            [](const QVariant& a, const QVariant& b) {
              const QVariantMap am = a.toMap();
              const QVariantMap bm = b.toMap();
              const qlonglong as = am.value("seconds").toLongLong();
              const qlonglong bs = bm.value("seconds").toLongLong();
              const bool al = isLowFrequencySettingsActivity(as);
              const bool bl = isLowFrequencySettingsActivity(bs);
              if (al != bl) return !al;
              const QString an = am.value("name").toString();
              const QString bn = bm.value("name").toString();
              if (al && bl) return an.localeAwareCompare(bn) < 0;
              if (as != bs) return as > bs;
              return an.localeAwareCompare(bn) < 0;
            });
  return result;
}

bool UsageStatManager::matchesRange(const UsageRecord& record,
                                    const QString& range) const {
  if (range == "all") return true;

  const QDate recordDate =
      QDateTime::fromSecsSinceEpoch(record.startUnixSec).toLocalTime().date();
  if (!recordDate.isValid()) return false;

  const QDate today = QDate::currentDate();
  if (range == "day") return recordDate == today;
  if (range == "month")
    return recordDate.year() == today.year() &&
           recordDate.month() == today.month();
  if (range == "year") return recordDate.year() == today.year();
  if (range == "week") {
    // 当周（周一为首，含两端），对齐 v88/日历 ISO 周口径。dayOfWeek(): 周一=1..周日=7。
    const QDate weekStart = today.addDays(-(today.dayOfWeek() - 1));
    const QDate weekEnd = weekStart.addDays(6);
    return recordDate >= weekStart && recordDate <= weekEnd;
  }

  return false;
}

bool UsageStatManager::matchesYearMonth(const UsageRecord& record, int year,
                                        int month) const {
  const QDate recordDate =
      QDateTime::fromSecsSinceEpoch(record.startUnixSec).toLocalTime().date();
  if (!recordDate.isValid()) return false;
  return recordDate.year() == year && recordDate.month() == month;
}

bool UsageStatManager::matchesSource(const UsageRecord& record,
                                     const QString& sourceFilter) const {
  if (sourceFilter.trimmed().isEmpty()) return true;
  return record.source == normalizedSource(sourceFilter);
}

QString UsageStatManager::secondsToTimeText(quint64 totalSeconds) const {
  if (totalSeconds == 0) return "0m";
  if (totalSeconds < 60) return "<1m";

  const quint64 hours = totalSeconds / 3600;
  const quint64 minutes = (totalSeconds % 3600) / 60;

  if (hours > 0)
    return QString::number(hours) + "h " + QString::number(minutes) + "m";
  return QString::number(minutes) + "m";
}
