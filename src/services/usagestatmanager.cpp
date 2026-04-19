#include "usagestatmanager.h"

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
  qint64 start = 0;
  qint64 end = 0;
};

QString usageDataDir() {
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

quint64 mergedIntervalSeconds(QVector<UsageInterval> intervals) {
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
  struct Aggregate {
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

    const QString key =
        appGroupKey(record.appId, record.appName, record.path);
    const qint64 endUnixSec =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    if (record.startUnixSec <= 0 || endUnixSec <= record.startUnixSec) return;

    Aggregate aggregate = grouped.value(key);
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

    const QString displayName =
        appDisplayName(aggregate.appId, aggregate.appName, aggregate.path);

    QVariantMap item;
    item["appId"] = aggregate.appId;
    item["appName"] = aggregate.appName;
    item["name"] = displayName;
    item["path"] = aggregate.path;
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
    item["note"] = subtitle;
    item["subtitle"] = aggregate.appName == displayName
                           ? subtitle
                           : aggregate.appName + " - " + subtitle;
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
  const QString appName = !record.appName.trimmed().isEmpty()
                              ? record.appName
                              : QFileInfo(record.path).fileName();
  const QString appId =
      appGroupKey(record.appId, appName, record.path);
  const QString displayName = appDisplayName(appId, appName, record.path);

  QVariantMap item;
  item["appId"] = appId;
  item["appName"] = appName;
  item["name"] = displayName;
  item["path"] = record.path;
  item["windowTitle"] = record.windowTitle;
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
