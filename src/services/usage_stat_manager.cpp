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
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QMap>
#include <QPixmap>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>
#include <QVector>
#include <algorithm>
#include <initializer_list>
#include <limits>

#include "services/site_catalog.h"

namespace {

struct UsageInterval {
  // 用闭区间语义以外的 [start, end) 表示法，方便合并相邻/重叠时间段。
  qint64 start = 0;
  qint64 end = 0;
};

QString usageDataDir() {
  // 必须和 service/shared/usage_paths.c 的 Windows 路径保持一致，
  // UI 才能读到后台服务写出的 JSONL/current 文件。
  const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
  QString base = env.value("LOCALAPPDATA");
  if (base.trimmed().isEmpty()) base = env.value("APPDATA");
  if (base.trimmed().isEmpty()) base = QDir::homePath();

  return QDir(base).filePath("TimeArc/usage");
}

qint64 jsonInteger(const QJsonObject& object, const QString& key) {
  const QJsonValue value = object.value(key);
  if (value.isDouble()) return static_cast<qint64>(value.toDouble());
  if (value.isString()) return value.toString().toLongLong();
  return 0;
}

quint64 jsonUnsignedInteger(const QJsonObject& object, const QString& key) {
  const qint64 value = jsonInteger(object, key);
  return value > 0 ? static_cast<quint64>(value) : 0;
}

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

const TimeArcSiteCatalog::SiteDefinition* siteForBrowserWindow(
    const QString& appId, const QString& appName, const QString& path,
    const QString& windowTitle) {
  if (!isBrowserApp(appId, appName, path)) return nullptr;
  return TimeArcSiteCatalog::matchByWindowTitle(windowTitle);
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

  if (containsAny(text, {"cloudmusic", "netease"})) return "网易云音乐";
  if (containsAny(text, {"chrome.exe", "google\\chrome", "google/chrome"}))
    return "Google Chrome";
  if (containsAny(text,
                  {"code.exe", "visual studio code", "microsoft vs code"}))
    return "VS Code";
  if (containsAny(text, {"discord"})) return "Discord";
  if (containsAny(text, {"weixin", "wechat"})) return "微信";
  if (containsAny(text, {"qqmusic"})) return "QQ Music";
  const QString displayExeName =
      QFileInfo(!path.trimmed().isEmpty() ? path : appName).fileName().toLower();
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

  if (containsAny(text, {"weixin", "wechat", "wechatappex", "wechatbrowser"}))
    return "app:wechat";
  if (containsAny(text, {"cloudmusic", "netease"}))
    return "app:netease-cloud-music";
  if (containsAny(text, {"chrome.exe", "google\\chrome", "google/chrome"}))
    return "app:google-chrome";
  if (containsAny(text,
                  {"code.exe", "visual studio code", "microsoft vs code"}))
    return "app:vscode";
  if (containsAny(text, {"discord"}))
    return "app:discord";
  if (containsAny(text, {"qqmusic"}))
    return "app:qq-music";
  const QString exeName = normalizedExeName(appName, path);
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
          siteForBrowserWindow(appId, appName, path, windowTitle)) {
    value = site->siteId;
  } else {
    value = appGroupKey(appId, appName, path);
  }
  if (cache.size() < 200000) cache.insert(k, value);  // 软上限防极端无界增长
  return value;
}

QString activityDisplayName(const QString& groupKey, const QString& appId,
                            const QString& appName, const QString& path) {
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
                       "fontdrvhost", "wininit", "csrss", "smartscreen"}))
    return QStringLiteral("系统");

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

  if (containsAny(id, {"code.exe", "vscode", "devenv", "clion", "pycharm",
                       "idea64", "goland", "webstorm", "rider", "qtcreator",
                       "android studio", "sublime_text", "notepad++", "neovim",
                       "powershell", "windowsterminal", "cmd.exe", "conemu",
                       "git-bash", "mingw", "docker", "datagrip", "dbeaver",
                       "postman"}))
    return QStringLiteral("开发");

  if (containsAny(id, {"bilibili", "potplayer", "vlc.exe", "tencentvideo",
                       "qqlive", "mpv.exe", "mpc-hc", "iqiyi", "youku"}))
    return QStringLiteral("视频");

  if (containsAny(id, {"qqmusic", "cloudmusic", "netease", "spotify", "kugou",
                       "kuwo", "foobar"}))
    return QStringLiteral("音乐");

  if (containsAny(id, {"weixin", "wechat", "discord", "telegram", "slack",
                       "qq.exe", "tim.exe", "dingtalk", "feishu", "lark",
                       "teams.exe", "whatsapp", "skype"}))
    return QStringLiteral("社交");

  if (containsAny(id, {"steam.exe", "steamwebhelper", "epicgames", "riotclient",
                       "leagueoflegends", "valorant", "genshin", "yuanshen",
                       "starrail", "streetfighter", "wegame", "battle.net",
                       "ubisoft", "gog galaxy"}))
    return QStringLiteral("游戏");

  if (containsAny(id, {"winword", "excel.exe", "powerpnt", "onenote", "outlook",
                       "wps.exe", "et.exe", "wpp.exe", "acrobat", "acrord32",
                       "foxit", "sumatrapdf"}))
    return QStringLiteral("办公");

  if (containsAny(id, {"photoshop", "illustrator", "premiere", "afterfx",
                       "lightroom", "figma", "blender", "obs64", "obs.exe",
                       "capcut", "jianying", "davinci", "resolve.exe",
                       "audition", "coreldraw", "3dsmax", "maya.exe"}))
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

QJsonDocument parseJsonLine(const QByteArray& line) {
  QJsonParseError error;
  QJsonDocument doc = QJsonDocument::fromJson(line, &error);
  if (error.error == QJsonParseError::NoError) return doc;

  // Older service builds wrote window titles with the Windows local code page.
  // Keep reading those records while new service builds write UTF-8 JSONL.
  const QByteArray utf8Line =
      QString::fromLocal8Bit(line.constData(), line.size()).toUtf8();
  doc = QJsonDocument::fromJson(utf8Line, &error);
  if (error.error == QJsonParseError::NoError) return doc;

  return QJsonDocument();
}

}  // namespace

UsageStatManager::UsageStatManager(QObject* parent) : QObject(parent) {
  refresh();
}

QString UsageStatManager::usageRecordsPath() const { return recordsFilePath(); }

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
  // refresh 是 UI 的数据入口：读历史 JSONL（**增量**：service 是 append-only，只解析自上次
  // 偏移以来新追加的完整行；size 变小=轮转/截断→全量重读），再叠加 current 实时快照。
  // 关键性能修复：16MB/46k 行全量重解析每 5s 一次会让 UI 长期卡顿；增量后空闲 tick 近乎零成本。
  const QString path = recordsFilePath();
  const QFileInfo info(path);
  const qint64 size = info.exists() ? info.size() : -1;

  if (size < 0) {
    if (!m_records.isEmpty()) {
      m_records.clear();
      ++m_recordsGeneration;
    }
    m_recordsParsedSize = -1;
    m_recordsParsedOffset = 0;
  } else {
    const bool full = (m_recordsParsedSize < 0) || (size < m_recordsParsedSize);
    if (full) {
      m_records.clear();
      m_recordsParsedOffset = 0;
    }
    int added = 0;
    if (full || m_recordsParsedOffset < size) {
      QFile file(path);
      // 非 Text 模式：按原始字节统计偏移（Text 会折叠 \r\n 致偏移与磁盘不一致）。
      if (file.open(QIODevice::ReadOnly)) {
        if (!full && m_recordsParsedOffset > 0) file.seek(m_recordsParsedOffset);
        qint64 offset = full ? 0 : m_recordsParsedOffset;
        while (!file.atEnd()) {
          const QByteArray rawLine = file.readLine();
          // 末尾无换行=半写行（service 正写到一半）→ 本次不消费，下次再读。
          if (!rawLine.endsWith('\n')) break;
          offset += rawLine.size();
          const QByteArray line = rawLine.trimmed();
          if (line.isEmpty()) continue;

          const QJsonDocument doc = parseJsonLine(line);
          if (!doc.isObject()) continue;
          const QJsonObject object = doc.object();
          if (object.value("platform").toString() != "windows") continue;

          // 目前 UI 只消费 Windows service 写出的记录；macOS 记录后续接入再放开。
          UsageRecord record = parseRecordObject(object, false);
          if (record.startUnixSec <= 0 || record.durationSec == 0) continue;
          if (record.appId.trimmed().isEmpty() &&
              record.appName.trimmed().isEmpty())
            continue;

          m_records.append(record);
          ++added;
        }
        m_recordsParsedOffset = offset;
      }
    }
    m_recordsParsedSize = size;
    if (full || added > 0) ++m_recordsGeneration;
  }

  m_hasCurrentRecord = false;
  QFile currentFile(currentFilePath());
  if (currentFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
    const QByteArray content = currentFile.readAll().trimmed();
    const QJsonDocument doc = parseJsonLine(content);
    if (doc.isObject()) {
      const QJsonObject object = doc.object();
      if (object.value("platform").toString() == "windows") {
        UsageRecord currentRecord = parseRecordObject(object, true);
        const qint64 updatedUnixSec =
            currentRecord.updatedUnixSec > 0
                ? currentRecord.updatedUnixSec
                : currentRecord.startUnixSec +
                      static_cast<qint64>(currentRecord.durationSec);
        const qint64 nowUnixSec = QDateTime::currentSecsSinceEpoch();

        // current 文件是覆盖写的实时快照。超过 15 秒没更新就视为 service 已停或
        // session 已结束，避免 UI 一直显示陈旧的“正在使用”。
        if (currentRecord.startUnixSec > 0 &&
            (!currentRecord.appId.trimmed().isEmpty() ||
             !currentRecord.appName.trimmed().isEmpty()) &&
            updatedUnixSec > 0 && nowUnixSec - updatedUnixSec <= 15) {
          currentRecord.durationSec =
              nowUnixSec > currentRecord.startUnixSec
                  ? static_cast<quint64>(nowUnixSec -
                                         currentRecord.startUnixSec)
                  : 0;
          m_currentRecord = currentRecord;
          m_hasCurrentRecord = true;
        }
      }
    }
  }

  emit usageStatsChanged();
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
    bool live = false;
    bool hasForeground = false;
    bool hasAudio = false;
  };

  QMap<QString, Aggregate> grouped;
  const auto addRecord = [&](const UsageRecord& record) {
    if (!inWindow(record)) return;
    if (!matchesSource(record, sourceFilter)) return;
    if (record.durationSec == 0) return;

    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
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
    aggregate.live = aggregate.live || record.live;
  };

  for (const UsageRecord& record : m_records) {
    addRecord(record);
  }

  if (m_hasCurrentRecord) {
    addRecord(m_currentRecord);
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
    item["category"] = topCategory;
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
    item["live"] = aggregate.live;
    QString subtitle;
    if (aggregate.hasForeground && aggregate.hasAudio) {
      subtitle = "Foreground + audio";
    } else if (aggregate.hasAudio) {
      subtitle = "Audio playback";
    } else {
      subtitle = "Foreground usage";
    }
    if (aggregate.live) {
      subtitle += " - Live";
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

QString UsageStatManager::recordsFilePath() const {
  return QDir(usageDataDir()).filePath("usage_records.jsonl");
}

QString UsageStatManager::currentFilePath() const {
  return QDir(usageDataDir()).filePath("usage_current.json");
}

UsageStatManager::UsageRecord UsageStatManager::parseRecordObject(
    const QJsonObject& object, bool live) const {
  UsageRecord record;
  record.appId = object.value("app_id").toString();
  record.source = normalizedSource(object.value("source").toString());
  record.appName = object.value("app_name").toString();
  record.windowTitle = object.value("window_title").toString();
  record.path = object.value("path").toString();
  record.startUnixSec = jsonInteger(object, "start_unix_sec");
  record.durationSec = jsonUnsignedInteger(object, "duration_sec");
  record.updatedUnixSec = jsonInteger(object, "updated_unix_sec");
  record.live = live;
  return record;
}

QVariantMap UsageStatManager::recordToVariantMap(
    const UsageRecord& record) const {
  // currentSoftware 只返回当前一条 live record，不走完整聚合；但仍复用 activity
  // 识别，保证 Chrome/B 站显示逻辑和列表一致。
  const QString appName = !record.appName.trimmed().isEmpty()
                              ? record.appName
                              : QFileInfo(record.path).fileName();
  const QString groupKey =
      activityGroupKey(record.appId, appName, record.path, record.windowTitle);
  const QString displayName =
      activityDisplayName(groupKey, record.appId, appName, record.path);

  QVariantMap item;
  item["groupKey"] = groupKey;
  item["appId"] = groupKey;
  item["appName"] = appName;
  item["name"] = displayName;
  item["path"] = record.path;
  item["windowTitle"] = record.windowTitle;
  if (const TimeArcSiteCatalog::SiteDefinition* site =
          siteForGroupKey(groupKey)) {
    item["siteDomain"] = site->domain;
    item["brandColor"] = site->brandColor;
    item["iconLabel"] = site->iconLabel;
    item["iconSource"] = site->iconSource;
  }
  item["source"] = record.source;
  item["seconds"] = static_cast<qlonglong>(record.durationSec);
  item["minutes"] = static_cast<int>(record.durationSec / 60);
  item["time"] = secondsToTimeText(record.durationSec);
  item["live"] = record.live;
  QString subtitle =
      record.source == "audio" ? "Audio playback" : "Foreground usage";
  if (record.live) {
    subtitle += " - Live";
  }
  item["note"] = subtitle;
  item["subtitle"] = subtitle;
  return item;
}

QVariantMap UsageStatManager::currentSoftware() const {
  if (!m_hasCurrentRecord) {
    return QVariantMap();
  }

  return recordToVariantMap(m_currentRecord);
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

    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
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
  if (m_hasCurrentRecord) addRecord(m_currentRecord);

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
    byDay[d.day()][key].append({record.startUnixSec, end});
  };
  for (const UsageRecord& record : m_records) add(record);
  if (m_hasCurrentRecord) add(m_currentRecord);

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
    byDay[d.toString(Qt::ISODate)][key].append({record.startUnixSec, recEnd});
  };
  for (const UsageRecord& record : m_records) add(record);
  if (m_hasCurrentRecord) add(m_currentRecord);

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
    byMonth[d.month()][key].append({record.startUnixSec, end});
  };
  for (const UsageRecord& record : m_records) add(record);
  if (m_hasCurrentRecord) add(m_currentRecord);

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
    const QString cat = classifyActivity(key, record.appId, record.appName,
                                         record.path, record.windowTitle);
    if (!kFocusCats.contains(cat)) return;
    intervals.append({record.startUnixSec, end});
  };
  for (const UsageRecord& record : m_records) add(record);
  if (m_hasCurrentRecord) add(m_currentRecord);

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
  if (dir.isEmpty()) dir = usageDataDir();
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
