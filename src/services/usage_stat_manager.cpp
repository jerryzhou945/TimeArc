#include "usage_stat_manager.h"

#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QMap>
#include <QProcessEnvironment>
#include <QVariantMap>
#include <QVector>
#include <algorithm>
#include <initializer_list>
#include <limits>

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
  // activity key 比 app key 更细：Chrome 里的 B 站被提升成 site:bilibili，
  // 这样 UI 统计里不会只显示“Google Chrome”。
  if (isChromeApp(appId, appName, path) && isBilibiliWindowTitle(windowTitle)) {
    return "site:bilibili";
  }

  return appGroupKey(appId, appName, path);
}

QString activityDisplayName(const QString& groupKey, const QString& appId,
                            const QString& appName, const QString& path) {
  if (groupKey == "site:bilibili") {
    return bilibiliDisplayName();
  }

  return appDisplayName(appId, appName, path);
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
  // refresh 是 UI 的数据入口：重读历史 JSONL，再尝试叠加仍在运行的 current 快照。
  // 因为 service 独立进程写文件，UI 不能只依赖内存状态。
  QList<UsageRecord> records;

  QFile file(recordsFilePath());
  if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
    while (!file.atEnd()) {
      const QByteArray line = file.readLine().trimmed();
      if (line.isEmpty()) continue;

      const QJsonDocument doc = parseJsonLine(line);
      if (!doc.isObject()) continue;

      const QJsonObject object = doc.object();
      if (object.value("platform").toString() != "windows") continue;

      // 目前 UI 只消费 Windows service 写出的记录；macOS 记录后续接入时再放开。
      UsageRecord record = parseRecordObject(object, false);

      if (record.startUnixSec <= 0 || record.durationSec == 0) continue;
      if (record.appId.trimmed().isEmpty() &&
          record.appName.trimmed().isEmpty())
        continue;

      records.append(record);
    }
  }

  m_records = records;

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
    bool live = false;
    bool hasForeground = false;
    bool hasAudio = false;
  };

  QMap<QString, Aggregate> grouped;
  const auto addRecord = [&](const UsageRecord& record) {
    if (!matchesRange(record, range)) return;
    if (!matchesSource(record, sourceFilter)) return;
    if (record.durationSec == 0) return;

    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    const qint64 endUnixSec =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    if (record.startUnixSec <= 0 || endUnixSec <= record.startUnixSec) return;

    Aggregate aggregate = grouped.value(key);
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
    aggregate.live = aggregate.live || record.live;
    grouped[key] = aggregate;
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
    item["appId"] = aggregate.appId;
    item["appName"] = aggregate.appName;
    item["name"] = displayName;
    item["path"] = aggregate.path;
    if (aggregate.groupKey == "site:bilibili") {
      item["siteDomain"] = "bilibili.com";
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
        aggregate.groupKey == "site:bilibili"
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
  if (groupKey == "site:bilibili") {
    item["siteDomain"] = "bilibili.com";
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

QVariantList UsageStatManager::foregroundSegmentsForRange(
    const QString& range) const {
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
    if (!matchesRange(record, range)) return;
    if (record.durationSec == 0) return;

    const qint64 endUnixSec =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    if (record.startUnixSec <= 0 || endUnixSec <= record.startUnixSec) return;

    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    AppSessions& app = grouped[key];
    if (app.groupKey.trimmed().isEmpty()) {
      app.groupKey = key;
      app.appId = !record.appId.trimmed().isEmpty() ? record.appId : key;
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

  return false;
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
