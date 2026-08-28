#include "usage_stat_manager.h"

#include "services/app_identity_policy.h"
#include "services/categorization/normalize.h"

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
#include <QTimeZone>
#include <QUrl>
#include <QVariantMap>
#include <QVector>
#include <algorithm>
#include <initializer_list>
#include <limits>

#include "services/categorization_manager.h"

namespace {

struct UsageInterval {
  // 用闭区间语义以外的 [start, end) 表示法，方便合并相邻/重叠时间段。
  qint64 start = 0;
  qint64 end = 0;
};

// 把 [start, end) 按本地自然日切片，对每个被跨越的日子回调一次（区间已截到当天）。
// 逐日/逐月分桶的读路径都要用它：此前它们按 record 的**起始日**整段入桶，一条
// 跨午夜的会话会把全部时长记给起始那天，于是趋势柱与「今日」总时长同时失真。
template <typename Fn>
void forEachLocalDaySlice(qint64 start, qint64 end, Fn&& fn) {
  if (end <= start) return;
  QDate day = QDateTime::fromSecsSinceEpoch(start).toLocalTime().date();
  qint64 cursor = start;
  while (cursor < end && day.isValid()) {
    const qint64 dayEnd = day.addDays(1).startOfDay().toSecsSinceEpoch();
    if (dayEnd <= cursor) break;  // 时区异常兜底，绝不空转
    const qint64 sliceEnd = std::min(end, dayEnd);
    fn(day, cursor, sliceEnd);
    cursor = sliceEnd;
    day = day.addDays(1);
  }
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


QString normalizedExeName(const QString& appName, const QString& path) {
  QString name =
      !appName.trimmed().isEmpty() ? appName : QFileInfo(path).fileName();
  name = name.trimmed().toLower();
  if (name.endsWith(".exe")) name.chop(4);
  return name;
}


bool isHomeRankVisibleActivity(const QString& groupKey, const QString& appId,
                               const QString& appName, const QString& path,
                               const QString& displayName,
                               bool deprioritized) {
  if (deprioritized) return false;
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
                                   bool deprioritized, quint64 seconds) {
  if (groupKey.startsWith(QLatin1String("site:"))) return true;

  const QString id =
      (groupKey + " " + appId + " " + appName + " " + path + " " + displayName)
          .toLower();
  if (deprioritized) return false;
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





// 从 app 图标位图提取最多 3 个主色调（跳过透明/接近灰/接近黑白），按 path 缓存。
// 用于背景/封面的多色晕染，贴合该 app 图标真实观感（取代查表/哈希的预设单色）。
QStringList iconDominantColors(const QString& path) {
  static QHash<QString, QStringList> cache;
  if (path.trimmed().isEmpty()) return QStringList();
  const auto hit = cache.constFind(path);
  if (hit != cache.constEnd()) return hit.value();

  QStringList colors;
  QImage source;
  if (path.startsWith(QLatin1String("qrc:")) ||
      path.startsWith(QLatin1Char(':'))) {
    QString resource = path;
    if (resource.startsWith(QLatin1String("qrc:"))) resource = resource.mid(3);
    source = QImage(resource);
  } else {
    const QFileInfo fi(path);
    if (fi.exists()) {
      static QFileIconProvider provider;
      const QPixmap pm = provider.icon(fi).pixmap(48, 48);
      if (!pm.isNull()) source = pm.toImage();
    }
  }
  {
    {
      const QImage img = source.isNull()
                             ? QImage()
                             : source.convertToFormat(QImage::Format_ARGB32);
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

// UsageRecord::source for rows loaded from frontmost_sessions. The stats page
// reads this source exclusively; see the header for why.
const QString kForegroundSource = QStringLiteral("foreground");

// The service writes app_id as the stable identity, display_name as the short
// app name, and executable_path as path. Keep the eight-column normalized read
// shape consumed below while using SQLite rowid as the incremental watermark.
//
// Column 7 is the **counted** length. For a foreground session that is
// active_sec, not duration_sec: a session stays open across idle (CHARTER
// v0.11), so duration_sec is wall clock and includes the locked screen and
// every coffee break. The UI counts time the user was actually there.
const QString kSqlFrontmostSince = QStringLiteral(R"SQL(
SELECT fs.app_id,
       COALESCE(NULLIF(a.display_name, ''), fs.app_id),
       COALESCE(NULLIF(a.executable_path, ''), fs.app_id),
       fs.window_title, fs.start_unix_sec, fs.duration_sec, fs.rowid,
       fs.active_sec
FROM frontmost_sessions fs
LEFT JOIN apps a ON a.app_id = fs.app_id
WHERE fs.rowid > :sinceId
ORDER BY fs.rowid ASC;
)SQL");

// media_sessions is the background-evidence side of the D5 union. Most rows
// are audio; contract-safe unknown rows may represent verified agent work.
const QString kSqlMediaSince = QStringLiteral(R"SQL(
SELECT ms.app_id,
       COALESCE(NULLIF(a.display_name, ''), ms.app_id),
       COALESCE(NULLIF(a.executable_path, ''), ms.app_id),
       ms.media_title, ms.start_unix_sec, ms.duration_sec, ms.rowid,
       ms.duration_sec
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
    // 计时长度：前台取 active_sec（媒体表没有这一列，SQL 里回填 duration_sec）。
    // 服务侧 CHECK 保证 0 <= active_sec <= duration_sec，这里再夹一次，别让一条
    // 坏行把某个 app 的时长撑爆。
    const qlonglong act = query.value(7).toLongLong();
    record.activeSec = act > 0 ? std::min(static_cast<quint64>(act),
                                          record.durationSec)
                               : 0;
    record.source = source;
    // Reject invalid or empty session rows before aggregation.
    if (record.startUnixSec <= 0 || record.durationSec == 0) continue;
    if (record.appId.trimmed().isEmpty() && record.appName.trimmed().isEmpty())
      continue;
    // 本地自然日算一次、随记录存下来（range/年月判定全部读它，不再逐次换算时区）。
    // 放在所有 continue 之后：被丢弃的行不必付这次换算。
    record.localDate =
        QDateTime::fromSecsSinceEpoch(record.startUnixSec).toLocalTime().date();
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

  // 预存的 localDate 是按某个系统时区算出来的；用户中途改时区就得全部重算。
  // 只是一次字符串比较，比原先「每条记录每次判定都做一次时区换算」便宜得多。
  const QByteArray timeZoneId = QTimeZone::systemTimeZoneId();
  const bool timeZoneChanged =
      m_historyInitialized && timeZoneId != m_recordsTimeZoneId;
  m_recordsTimeZoneId = timeZoneId;

  bool full = !m_historyInitialized;
  const bool shrank =
      (maxFront < m_sqliteFrontmostMaxId) || (maxMedia < m_sqliteMediaMaxId);
  if (full || shrank || timeZoneChanged) {  // 首次 / 库被替换 / 改时区 → 全量重载
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
  // 窗口解析一次，而不是每条记录一次（原先谓词里既造 QDateTime 又调 currentDate()）。
  const ClipWindow window = clipWindowForDates(rangeWindow(range));
  return aggregateSoftware(window, sourceFilter);
}

QVariantList UsageStatManager::aggregateSoftware(
    const ClipWindow& window, const QString& sourceFilter) const {
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
    qint64 lastUsedUnixSec = 0;
    bool hasForeground = false;
    bool hasAudio = false;
  };

  QMap<QString, Aggregate> grouped;
  const auto addRecord = [&](const UsageRecord& record) {
    if (!matchesSource(record, sourceFilter)) return;

    // 区间相交入选 + 截断到窗口内（见 ClipWindow）。窗口边界上的会话只贡献
    // 落在窗口里的那一段，跨午夜的会话两天各拿自己的一半。
    qint64 startUnixSec = 0;
    qint64 endUnixSec = 0;
    if (!window.clip(record.startUnixSec, record.activeSec, &startUnixSec,
                     &endUnixSec))
      return;

    const QString key = effectiveGroupKey(record);
    if (key.isEmpty()) return;  // 逐项显隐：被排除的 app 不计入聚合（2B）

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
      const QString representative = representativePathForGroup(key);
      aggregate.path = representative.isEmpty() ? record.path : representative;
    }
    const UsageInterval interval{startUnixSec, endUnixSec};
    aggregate.intervals.append(interval);
    // 「最近使用」问的是墙钟时刻，不是计入了多少秒，所以用会话真实结束时间。
    aggregate.lastUsedUnixSec = std::max(
        aggregate.lastUsedUnixSec,
        record.startUnixSec + static_cast<qint64>(record.durationSec));
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
        static_cast<quint64>(endUnixSec - startUnixSec);
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

    const QString defaultDisplayName = activityDisplayName(
        aggregate.groupKey, aggregate.appId, aggregate.appName, aggregate.path);
    const auto displayIdentity = TimeArc::AppIdentityPolicy::applyDisplayName(
        aggregate.groupKey, defaultDisplayName,
        displayNameOverrideFor(aggregate.appId, aggregate.appName,
                               aggregate.path));
    const QString displayName = displayIdentity.displayName;
    QVariantMap item;
    item["groupKey"] = aggregate.groupKey;
    item["appId"] = aggregate.groupKey.startsWith("site:")
                        ? aggregate.groupKey
                        : aggregate.appId;
    item["appName"] = aggregate.appName;
    item["name"] = displayName;
    item["displayName"] = displayName;
    item["defaultDisplayName"] = defaultDisplayName;
    item["customDisplayName"] = displayNameOverrideFor(
        aggregate.appId, aggregate.appName, aggregate.path);
    item["path"] = aggregate.path;
    // 逐记录分类按时长加权，占比最高的类别代表这个 app。规则不再覆盖这个投票：
    // 规则的特异性已经体现在每条记录的打分里（见 categorization/matcher.h）。
    QString topCategory = QStringLiteral("other");
    quint64 topCatSec = 0;
    for (auto it = aggregate.categorySeconds.constBegin();
         it != aggregate.categorySeconds.constEnd(); ++it) {
      if (it.value() > topCatSec) {
        topCatSec = it.value();
        topCategory = it.key();
      }
    }
    // 「游戏识别」关 → 游戏类降级；这是 categoryState 的一个特例，保留旧开关语义。
    if (!m_gameClassify && topCategory == QStringLiteral("game")) {
      topCategory = QStringLiteral("other");
    }
    item["category"] = topCategory;
    item["homeRankVisible"] =
        isHomeRankVisibleActivity(aggregate.groupKey, aggregate.appId,
                                  aggregate.appName, aggregate.path,
                                  displayName,
                                  isDeprioritizedCategory(topCategory));
    // 取色一律从**规则自己的图标**读：站点规则带 qrc 图标，不会再取到宿主浏览器
    // 的色（旧实现只能整组留空，见 site:bilibili 显示成 Chrome 色的反馈）。
    item["iconColors"] = ruleIconColors(aggregate.groupKey, aggregate.path);
    applyRuleMetadata(&item, aggregate.groupKey, aggregate.path);
    item["source"] = sourceFilter.trimmed().isEmpty()
                         ? "active"
                         : normalizedSource(sourceFilter);
    item["sources"] = aggregate.hasForeground && aggregate.hasAudio
                          ? "foreground,audio"
                          : (aggregate.hasAudio ? "audio" : "foreground");
    item["seconds"] = static_cast<qlonglong>(seconds);
    item["minutes"] = static_cast<int>(seconds / 60);
    item["time"] = secondsToTimeText(seconds);
    item["lastUsedUnixSec"] = aggregate.lastUsedUnixSec;
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
    // 站点组的副标题显示**宿主应用**：忽略窗口标题重解一次身份，就拿到
    // 「Google Chrome」而不是 chrome.exe。
    QString subtitleName = aggregate.appName;
    if (aggregate.groupKey.startsWith("site:")) {
      const QString hostKey =
          resolveActivity(aggregate.appId, aggregate.appName, QString()).identity;
      subtitleName = activityDisplayName(hostKey, aggregate.appId,
                                         aggregate.appName, aggregate.path);
    }
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
    const ClipWindow& window) const {
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
    // 同 aggregateSoftware：相交入选 + 截断，环上的会话段不会伸出当天之外。
    qint64 startUnixSec = 0;
    qint64 endUnixSec = 0;
    if (!window.clip(record.startUnixSec, record.activeSec, &startUnixSec,
                     &endUnixSec))
      return;

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
      const QString representative = representativePathForGroup(key);
      app.path = representative.isEmpty() ? record.path : representative;
    }
    if (app.path.trimmed().isEmpty() && !record.path.trimmed().isEmpty()) {
      app.path = record.path;
    }
    app.intervals.append({startUnixSec, endUnixSec});
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
    applyRuleMetadata(&item, app.groupKey, app.path);
    const QString defaultDisplayName = activityDisplayName(
        app.groupKey, app.appId, app.appName, app.path);
    const auto displayIdentity = TimeArc::AppIdentityPolicy::applyDisplayName(
        app.groupKey, defaultDisplayName,
        displayNameOverrideFor(app.appId, app.appName, app.path));
    item["name"] = displayIdentity.displayName;
    item["displayName"] = displayIdentity.displayName;
    item["defaultDisplayName"] = defaultDisplayName;
    item["customDisplayName"] =
        displayNameOverrideFor(app.appId, app.appName, app.path);
    result.append(item);
  }

  return result;
}

QVariantList UsageStatManager::foregroundSegmentsForRange(
    const QString& range) const {
  // 同上：每次聚合解析一次
  return foregroundSegmentsImpl(clipWindowForDates(rangeWindow(range)));
}

// 任意窗口版（统计页期次 prev/next）：与窗口**相交**的记录入选，区间截断到
// [start, end]（QML 传入本地周期边界，末秒为 end）。口径与 range 版一致。
QVariantList UsageStatManager::foregroundSegmentsForWindow(
    qint64 startUnixSec, qint64 endUnixSec) const {
  return foregroundSegmentsImpl(clipWindowForBounds(startUnixSec, endUnixSec));
}

QVariantList UsageStatManager::foregroundSoftwareForWindow(
    qint64 startUnixSec, qint64 endUnixSec) const {
  return aggregateSoftware(clipWindowForBounds(startUnixSec, endUnixSec),
                           kForegroundSource);
}

int UsageStatManager::foregroundSoftwareSecondsForWindow(
    qint64 startUnixSec, qint64 endUnixSec) const {
  quint64 total = 0;
  const QVariantList items =
      foregroundSoftwareForWindow(startUnixSec, endUnixSec);
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
  DateWindow month_window;
  month_window.valid = QDate(year, month, 1).isValid();
  month_window.from = QDate(year, month, 1);
  month_window.to = month_window.from.addDays(month_window.from.daysInMonth() - 1);
  return aggregateSoftware(clipWindowForDates(month_window), QString());
}

QVariantList UsageStatManager::dailySecondsForMonth(int year, int month) const {
  // 按天分桶：day -> (groupKey -> intervals)。每天对各 app 自身区间求并集时长
  // 再相加，与 softwareSecondsForRange("month") 同口径（避免与月总值自相矛盾）。
  QMap<int, QMap<QString, QVector<UsageInterval>>> byDay;
  const auto add = [&](const UsageRecord& record) {
    if (record.activeSec == 0 || record.startUnixSec <= 0) return;
    const qint64 end =
        record.startUnixSec + static_cast<qint64>(record.activeSec);
    if (end <= record.startUnixSec) return;
    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    // 2B 隐藏 app 不计入趋势（按别名判定）
    if (isHiddenActivity(record.appId, record.appName, record.path,
                         record.windowTitle))
      return;
    // 跨午夜的会话按天切开，每天只拿自己的那一段。
    forEachLocalDaySlice(record.startUnixSec, end,
                         [&](const QDate& d, qint64 from, qint64 to) {
                           if (d.year() != year || d.month() != month) return;
                           byDay[d.day()][key].append({from, to});
                         });
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

QVariantList UsageStatManager::foregroundDailySecondsForRange(
    qint64 startUnixSec, qint64 endUnixSec) const {
  // 任意窗口逐日**前台**秒数，分桶方式与 dailySecondsForMonth 一致
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
    // 统计页只看前台：media_sessions 与前台并发，混进来同一秒会被两个 app 各算一次。
    if (!matchesSource(record, kForegroundSource)) return;
    if (record.activeSec == 0 || record.startUnixSec <= 0) return;
    const qint64 recEnd =
        record.startUnixSec + static_cast<qint64>(record.activeSec);
    if (recEnd <= record.startUnixSec) return;
    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    // 2B 隐藏 app 不计入趋势（按别名判定）
    if (isHiddenActivity(record.appId, record.appName, record.path,
                         record.windowTitle))
      return;
    // 跨午夜的会话按天切开，每天只拿自己的那一段。
    forEachLocalDaySlice(record.startUnixSec, recEnd,
                         [&](const QDate& d, qint64 from, qint64 to) {
                           if (d < startDate || d > endDate) return;
                           byDay[d.toString(Qt::ISODate)][key].append(
                               {from, to});
                         });
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

QVariantList UsageStatManager::foregroundMonthlySecondsForYear(int year) const {
  // 指定年的 12 个月**前台**秒序列，分桶方式同 dailySecondsForMonth。
  // 单遍扫描 m_records 按月分桶（替代统计页年视图 12 次 activeSoftwareForMonth）。
  // 当年只到当前月、过去年整 12 月、未来年全 0（不造假未来）。
  QMap<int, QMap<QString, QVector<UsageInterval>>> byMonth;
  const auto add = [&](const UsageRecord& record) {
    // 统计页只看前台：media_sessions 与前台并发，混进来同一秒会被两个 app 各算一次。
    if (!matchesSource(record, kForegroundSource)) return;
    if (record.activeSec == 0 || record.startUnixSec <= 0) return;
    const qint64 end =
        record.startUnixSec + static_cast<qint64>(record.activeSec);
    if (end <= record.startUnixSec) return;
    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    // 2B 隐藏 app 不计入趋势（按别名判定）
    if (isHiddenActivity(record.appId, record.appName, record.path,
                         record.windowTitle))
      return;
    // 按天切片再入月桶：跨年末/月末的会话不会整段落到起始月。
    forEachLocalDaySlice(record.startUnixSec, end,
                         [&](const QDate& d, qint64 from, qint64 to) {
                           if (d.year() != year) return;
                           byMonth[d.month()][key].append({from, to});
                         });
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

QVariantMap UsageStatManager::foregroundFocusStatsForWindow(
    qint64 startUnixSec, qint64 endUnixSec) const {
  // 专注（A-5）= 开发/办公/笔记 类目的活动派生连续块：把窗口内 focus 类目记录跨 app
  // 汇成时间轴，相邻间隙 <= 10min 合并成块，块时长 >= 5min 才计入。
  // focusSeconds = 块总秒；focusDays = 含 focus 块的本地自然日数。只读 m_records。
  constexpr qint64 kFocusGapSec = 600;   // 10min
  constexpr qint64 kMinBlockSec = 300;   // 5min
  const QSet<QString> kFocusCats = focusCategories();
  if (kFocusCats.isEmpty()) {
    QVariantMap zero;
    zero["focusSeconds"] = static_cast<qlonglong>(0);
    zero["focusDays"] = 0;
    return zero;
  }
  QVector<UsageInterval> intervals;
  const ClipWindow window = clipWindowForBounds(startUnixSec, endUnixSec);
  const auto add = [&](const UsageRecord& record) {
    // 统计页只看前台：media_sessions 与前台并发，混进来同一秒会被两个 app 各算一次。
    if (!matchesSource(record, kForegroundSource)) return;
    // 同聚合路径：相交入选 + 截断，专注块不会伸出期次之外。
    qint64 from = 0;
    qint64 to = 0;
    if (!window.clip(record.startUnixSec, record.activeSec, &from, &to))
      return;
    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, record.windowTitle);
    // 2B 隐藏 app 不计入专注（按别名判定）
    if (isHiddenActivity(record.appId, record.appName, record.path,
                         record.windowTitle))
      return;
    const QString cat = classifyActivity(key, record.appId, record.appName,
                                         record.path, record.windowTitle);
    if (!kFocusCats.contains(cat)) return;
    intervals.append({from, to});
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

QStringList UsageStatManager::activityAliases(const QString& appId,
                                              const QString& appName,
                                              const QString& path,
                                              const QString& windowTitle) const {
  QStringList aliases;
  const auto add = [&aliases](const QString& key) {
    if (!key.trimmed().isEmpty() && !aliases.contains(key)) aliases.append(key);
  };
  // 1) 当前规则表下的细化键（含窗口标题，可能是 site:*）。
  add(activityGroupKey(appId, appName, path, windowTitle));
  // 2) 应用级键（忽略窗口标题）——设置页的清单就是按这个去重的，所以隐藏一个
  //    浏览器会连它下面的 site:* 一起隐藏，这正是「停用这个应用」的意思。
  add(activityGroupKey(appId, appName, path, QString()));
  // 3) 规则命中前的旧回退键：存量 hidden_apps 里存的往往是它。
  add(TimeArc::Categorization::fallbackIdentity(
      TimeArc::Categorization::normalize(appName),
      TimeArc::Categorization::normalize(appId)));
  // 4) 关「合并相似应用」时 effectiveGroupKey 产出的 exe: 键。
  const QString exe = normalizedExeName(appName, path);
  if (!exe.isEmpty()) add(QStringLiteral("exe:") + exe);
  return aliases;
}

bool UsageStatManager::isHiddenActivity(const QString& appId,
                                        const QString& appName,
                                        const QString& path,
                                        const QString& windowTitle) const {
  if (m_hiddenKeys.isEmpty()) return false;
  for (const QString& alias :
       activityAliases(appId, appName, path, windowTitle)) {
    if (m_hiddenKeys.contains(alias)) return true;
  }
  return false;
}

QString UsageStatManager::displayNameOverrideFor(const QString& appId,
                                                 const QString& appName,
                                                 const QString& path) const {
  if (m_displayNameOverrides.isEmpty()) return QString();
  // 别名按「当前键 → 旧回退键」的顺序排列，所以先命中的一定是最新方案的那个。
  for (const QString& alias :
       activityAliases(appId, appName, path, QString())) {
    const auto it = m_displayNameOverrides.constFind(alias);
    if (it != m_displayNameOverrides.constEnd()) return it.value();
  }
  return QString();
}

QHash<QString, QString> UsageStatManager::legacyKeyMap() const {
  QHash<QString, QString> legacyToCurrent;
  for (const UsageRecord& record : m_records) {
    const QString current = activityGroupKey(record.appId, record.appName,
                                             record.path, QString());
    if (current.isEmpty()) continue;
    for (const QString& alias : activityAliases(record.appId, record.appName,
                                                record.path, QString())) {
      if (alias == current) continue;
      if (alias.startsWith(QLatin1String("exe:")) ||
          alias.startsWith(QLatin1String("path:")))
        legacyToCurrent.insert(alias, current);
    }
  }
  return legacyToCurrent;
}

QStringList UsageStatManager::canonicalHiddenKeys(
    const QStringList& stored) const {
  const QHash<QString, QString> legacyToCurrent = legacyKeyMap();
  QStringList out;
  for (const QString& key : stored) {
    const QString trimmed = key.trimmed();
    if (trimmed.isEmpty()) continue;
    const QString mapped = legacyToCurrent.value(trimmed, trimmed);
    if (!out.contains(mapped)) out.append(mapped);
  }
  return out;
}

QVariantMap UsageStatManager::canonicalDisplayNameKeys(
    const QVariantMap& stored) const {
  const QHash<QString, QString> legacyToCurrent = legacyKeyMap();
  QVariantMap out;
  for (auto it = stored.constBegin(); it != stored.constEnd(); ++it) {
    const QString key = it.key().trimmed();
    if (key.isEmpty()) continue;
    const QString mapped = legacyToCurrent.value(key, key);
    // 旧键和新键同时存在时，当前方案的那个说了算——它是用户最近一次改名写下的。
    if (mapped != key && stored.contains(mapped)) continue;
    out.insert(mapped, it.value());
  }
  return out;
}

QString UsageStatManager::effectiveGroupKey(const UsageRecord& record) const {
  // 站点组（site:*）始终保持独立身份（合并开关不影响“看了哪个站点”）。
  const QString mergedKey = activityGroupKey(record.appId, record.appName,
                                             record.path, record.windowTitle);
  // 2B 逐项显隐：按别名排除（见 activityAliases）
  if (isHiddenActivity(record.appId, record.appName, record.path,
                       record.windowTitle))
    return QString();
  if (m_mergeSimilar || mergedKey.startsWith(QLatin1String("site:")))
    return mergedKey;
  // 2A 关「合并相似应用」：不并多进程变体，按 exe 名细分；无 exe 时退回合并键。
  const QString exe = normalizedExeName(record.appName, record.path);
  return exe.isEmpty() ? mergedKey : (QStringLiteral("exe:") + exe);
}

void UsageStatManager::rebuildRepresentativePaths() const {
  if (m_representativePathsGeneration == m_recordsGeneration) return;

  m_representativePaths.clear();
  QHash<QString, qint64> scores;
  const auto consider = [&](const QString& key, const UsageRecord& record) {
    if (key.isEmpty() || record.path.trimmed().isEmpty()) return;
    const qint64 recency =
        record.startUnixSec + static_cast<qint64>(record.durationSec);
    const qint64 score = TimeArc::AppIdentityPolicy::representativePathScore(
        key, record.path, QFileInfo::exists(record.path), recency);
    if (!scores.contains(key) || score > scores.value(key)) {
      scores.insert(key, score);
      m_representativePaths.insert(key, record.path);
    }
  };

  for (const UsageRecord& record : m_records) {
    const QString rawKey = activityGroupKey(record.appId, record.appName,
                                            record.path, record.windowTitle);
    consider(rawKey, record);
    consider(effectiveGroupKey(record), record);
  }
  m_representativePathsGeneration = m_recordsGeneration;
}

QString UsageStatManager::representativePathForGroup(
    const QString& groupKey) const {
  rebuildRepresentativePaths();
  return m_representativePaths.value(groupKey);
}

void UsageStatManager::setAppDisplayNameOverrides(const QVariantMap& overrides) {
  QHash<QString, QString> normalized;
  for (auto it = overrides.constBegin(); it != overrides.constEnd(); ++it) {
    const QString rawKey = it.key().trimmed();
    const QString displayName = it.value().toString().trimmed().left(80);
    if (!rawKey.isEmpty() && !displayName.isEmpty())
      normalized.insert(rawKey, displayName);
  }
  if (normalized == m_displayNameOverrides) return;
  m_displayNameOverrides = normalized;
  ++m_recordsGeneration;
  emit usageStatsChanged();
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
  // 「自动分类」的口径归规则表所有：用户亲手建/改过的规则不算推断，关掉开关也留着。
  if (m_categorization != nullptr) {
    m_categorization->setAutoClassify(autoClassify);
  }
  m_mergeSimilar = mergeSimilar;
  m_hideTitles = hideTitles;
  m_hiddenKeys = hidden;
  // 读层口径变化：自增代际让统计页“无新数据则跳过重算”的守卫失效，强制重算 + 刷新各页。
  ++m_recordsGeneration;
  emit usageStatsChanged();
}

QVariantList UsageStatManager::allApps() const {
  // 全来源清单：设置页的应用管理要列出服务见过的每一个 app（含只出过声的）。
  return allAppsImpl(QString(), &m_allAppsCache, &m_allAppsGeneration);
}

QVariantList UsageStatManager::foregroundApps() const {
  // 统计页清单：只看前台记录，与该页其余读路径同口径（见头文件）。
  return allAppsImpl(kForegroundSource, &m_foregroundAppsCache,
                     &m_foregroundAppsGeneration);
}

QVariantList UsageStatManager::allAppsImpl(const QString& sourceFilter,
                                           QVariantList* cache,
                                           int* cacheGeneration) const {
  // 记忆化：结果是全历史的、与任何时间窗口无关，只随 m_records / 读层过滤 / 规则表 /
  // UI 语言变化，而这些全都自增 m_recordsGeneration。统计页 rebuild() 每次切周/月/年
  // 或换期次都会调它，此前每次都全量重扫 + 逐组排序 + 每个 app 造一个 QVariantMap。
  if (*cacheGeneration == m_recordsGeneration) return *cache;

  // 设置页的应用清单**按应用去重**：解析身份时不看窗口标题，所以一个浏览器只出
  // 现一行，不会被 site:* 规则拆成好几条。窗口标题规则在该应用的编辑面板里列出。
  struct AppListEntry {
    QString groupKey;
    QString appId;
    QString appName;
    QString path;
    QVector<UsageInterval> intervals;
    qint64 lastUsedUnixSec = 0;
  };

  QMap<QString, AppListEntry> seen;
  const auto addApp = [&](const UsageRecord& record) {
    if (!matchesSource(record, sourceFilter)) return;
    const QString key = activityGroupKey(record.appId, record.appName,
                                         record.path, QString());
    if (key.isEmpty()) return;
    const qint64 endUnixSec =
        record.startUnixSec + static_cast<qint64>(record.activeSec);
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
    entry.lastUsedUnixSec = std::max(
        entry.lastUsedUnixSec,
        record.startUnixSec + static_cast<qint64>(record.durationSec));
  };
  for (const UsageRecord& record : m_records) addApp(record);

  QVariantList result;
  for (AppListEntry& entry : seen) {
    const QString representative = representativePathForGroup(entry.groupKey);
    if (!representative.isEmpty()) entry.path = representative;
    std::sort(entry.intervals.begin(), entry.intervals.end(),
              [](const UsageInterval& a, const UsageInterval& b) {
                return a.start < b.start;
              });
    const quint64 seconds = mergedIntervalSeconds(entry.intervals);
    const QString defaultDisplayName = activityDisplayName(
        entry.groupKey, entry.appId, entry.appName, entry.path);
    const auto displayIdentity = TimeArc::AppIdentityPolicy::applyDisplayName(
        entry.groupKey, defaultDisplayName,
        displayNameOverrideFor(entry.appId, entry.appName, entry.path));
    const QString displayName = displayIdentity.displayName;
    QString category =
        classifyActivity(entry.groupKey, entry.appId, entry.appName, entry.path,
                         QString());
    if (!m_gameClassify && category == QStringLiteral("game")) {
      category = QStringLiteral("other");
    }

    QVariantMap item;
    item["groupKey"] = entry.groupKey;
    item["originalGroupKey"] = entry.groupKey;
    item["defaultDisplayName"] = defaultDisplayName;
    item["customDisplayName"] =
        displayNameOverrideFor(entry.appId, entry.appName, entry.path);
    item["appId"] = entry.appId;
    item["appName"] = entry.appName;
    item["name"] = displayName;
    item["displayName"] = displayName;
    item["path"] = entry.path;
    item["category"] = category;
    item["seconds"] = static_cast<qlonglong>(seconds);
    item["lastUsedUnixSec"] = entry.lastUsedUnixSec;
    item["settingsVisible"] = isSettingsListVisibleActivity(
        entry.groupKey, entry.appId, entry.appName, entry.path, displayName,
        isDeprioritizedCategory(category), seconds);
    // 含被隐藏项，供取消隐藏；按别名判定，陈旧键也要让复选框显示为已隐藏
    item["hidden"] =
        isHiddenActivity(entry.appId, entry.appName, entry.path, QString());
    applyRuleMetadata(&item, entry.groupKey, entry.path);
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
  *cache = result;
  *cacheGeneration = m_recordsGeneration;
  return result;
}

bool UsageStatManager::ClipWindow::clip(qint64 recStartUnixSec,
                                        quint64 durationSec, qint64* outStart,
                                        qint64* outEnd) const {
  if (!valid) return false;
  if (recStartUnixSec <= 0 || durationSec == 0) return false;
  const qint64 recEnd = recStartUnixSec + static_cast<qint64>(durationSec);
  if (recEnd <= recStartUnixSec) return false;

  qint64 from = recStartUnixSec;
  qint64 to = recEnd;
  if (!unbounded) {
    from = std::max(from, start);
    to = std::min(to, end);
  }
  if (to <= from) return false;  // 与窗口无交集

  *outStart = from;
  *outEnd = to;
  return true;
}

UsageStatManager::ClipWindow UsageStatManager::clipWindowForDates(
    const DateWindow& window) {
  ClipWindow clipped;
  if (window.matchesAll) {
    clipped.unbounded = true;
    return clipped;
  }
  if (!window.valid || !window.from.isValid() || !window.to.isValid()) {
    clipped.valid = false;
    return clipped;
  }
  // 本地自然日闭区间 [from, to] → 半开 [from 00:00, to+1 00:00)。用 startOfDay()
  // 而不是 +86400，DST 当天的 23h/25h 才落得准。
  clipped.start = window.from.startOfDay().toSecsSinceEpoch();
  clipped.end = window.to.addDays(1).startOfDay().toSecsSinceEpoch();
  if (clipped.end <= clipped.start) clipped.valid = false;
  return clipped;
}

UsageStatManager::ClipWindow UsageStatManager::clipWindowForBounds(
    qint64 startUnixSec, qint64 endUnixSec) {
  ClipWindow clipped;
  clipped.start = startUnixSec;
  clipped.end = endUnixSec + 1;  // QML 传的是期次末秒（闭区间右端）
  if (clipped.end <= clipped.start) clipped.valid = false;
  return clipped;
}

UsageStatManager::DateWindow UsageStatManager::rangeWindow(
    const QString& range) const {
  DateWindow window;
  if (range == "all") {
    window.matchesAll = true;
    return window;
  }

  const QDate today = QDate::currentDate();
  if (range == "day") {
    window.valid = true;
    window.from = today;
    window.to = today;
  } else if (range == "month") {
    window.valid = true;
    window.from = QDate(today.year(), today.month(), 1);
    window.to = window.from.addDays(window.from.daysInMonth() - 1);
  } else if (range == "year") {
    window.valid = true;
    window.from = QDate(today.year(), 1, 1);
    window.to = QDate(today.year(), 12, 31);
  } else if (range == "week") {
    // 当周（周一为首，含两端），对齐 v88/日历 ISO 周口径。dayOfWeek(): 周一=1..周日=7。
    window.valid = true;
    window.from = today.addDays(-(today.dayOfWeek() - 1));
    window.to = window.from.addDays(6);
  }
  // 无法识别的 range → valid 保持 false → contains() 恒 false（同旧行为的 return false）。
  return window;
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


// ---------------------------------------------------------------------------
// 分类：读层通过 CategorizationManager 的规则表解析身份 / 名称 / 类别。
// 这些是成员函数（不是匿名命名空间的自由函数），因为它们需要规则表。
// ---------------------------------------------------------------------------

void UsageStatManager::setCategorizationManager(CategorizationManager* manager) {
  if (m_categorization == manager) return;
  m_categorization = manager;
  if (m_categorization != nullptr) {
    connect(m_categorization, &CategorizationManager::rulesChanged, this,
            [this]() {
              m_resolutionCache.clear();
              m_resolutionGeneration = -1;
              ++m_recordsGeneration;  // 令统计页的“无新数据则跳过重算”守卫失效
              emit usageStatsChanged();
            });
  }
  m_resolutionCache.clear();
  m_resolutionGeneration = -1;
  ++m_recordsGeneration;
  emit usageStatsChanged();
}

const TimeArc::Categorization::Matcher& UsageStatManager::matcher() const {
  // 没接管理器时（测试、早期启动）用出厂表，保证分类永远是全函数。
  static const TimeArc::Categorization::Matcher fallback{
      TimeArc::Categorization::defaultRuleSet()};
  return m_categorization != nullptr ? m_categorization->matcher() : fallback;
}

QString UsageStatManager::uiLanguage() const {
  return m_categorization != nullptr ? m_categorization->options().language
                                     : QStringLiteral("en");
}

// 记忆化：规则表代际变化即整表失效（规则是纯函数，同代际内结果确定）。
TimeArc::Categorization::Resolution UsageStatManager::resolveActivity(
    const QString& appId, const QString& appName,
    const QString& windowTitle) const {
  const int generation =
      m_categorization != nullptr ? m_categorization->generation() : 0;
  if (generation != m_resolutionGeneration) {
    m_resolutionCache.clear();
    m_resolutionGeneration = generation;
  }

  const QChar sep(QChar(0x1f));
  const QString key = appId + sep + appName + sep + windowTitle;
  const auto hit = m_resolutionCache.constFind(key);
  if (hit != m_resolutionCache.constEnd()) return hit.value();

  const TimeArc::Categorization::MatchOptions options =
      m_categorization != nullptr ? m_categorization->options()
                                  : TimeArc::Categorization::MatchOptions();
  const TimeArc::Categorization::Resolution resolution =
      matcher().resolve(appId, appName, windowTitle, options);
  if (m_resolutionCache.size() < 200000) m_resolutionCache.insert(key, resolution);
  return resolution;
}

QString UsageStatManager::activityGroupKey(const QString& appId,
                                           const QString& appName,
                                           const QString& path,
                                           const QString& windowTitle) const {
  Q_UNUSED(path);
  return resolveActivity(appId, appName, windowTitle).identity;
}

QString UsageStatManager::activityDisplayName(const QString& groupKey,
                                              const QString& appId,
                                              const QString& appName,
                                              const QString& path) const {
  Q_UNUSED(appId);
  const QString label = matcher().labelFor(groupKey, uiLanguage());
  if (!label.trimmed().isEmpty()) return label;

  QString fallback =
      !appName.trimmed().isEmpty() ? appName : QFileInfo(path).fileName();
  if (fallback.endsWith(QLatin1String(".exe"), Qt::CaseInsensitive)) {
    fallback.chop(4);
  }
  return fallback.trimmed().isEmpty() ? groupKey : fallback.trimmed();
}

QString UsageStatManager::classifyActivity(const QString& groupKey,
                                           const QString& appId,
                                           const QString& appName,
                                           const QString& path,
                                           const QString& windowTitle) const {
  Q_UNUSED(groupKey);
  Q_UNUSED(path);
  return resolveActivity(appId, appName, windowTitle).category;
}

const TimeArc::Categorization::Rule* UsageStatManager_findRule(
    const TimeArc::Categorization::RuleSet& set, const QString& ruleId) {
  for (const TimeArc::Categorization::Rule& rule : set.rules) {
    if (rule.id == ruleId) return &rule;
  }
  return nullptr;
}

void UsageStatManager::applyRuleMetadata(QVariantMap* item,
                                         const QString& ruleId,
                                         const QString& path) const {
  if (item == nullptr || ruleId.trimmed().isEmpty()) return;

  item->insert(QStringLiteral("adapterIdentifier"), ruleId);
  item->insert(QStringLiteral("sourceType"),
               ruleId.startsWith(QLatin1String("site:"))
                   ? QStringLiteral("website")
                   : QStringLiteral("desktopApp"));

  const TimeArc::Categorization::Rule* rule =
      UsageStatManager_findRule(matcher().ruleSet(), ruleId);
  if (rule == nullptr) {
    if (!path.trimmed().isEmpty())
      item->insert(QStringLiteral("iconPath"), path);
    return;
  }

  const QString label = TimeArc::Categorization::displayLabel(*rule, uiLanguage());
  if (!label.trimmed().isEmpty()) {
    item->insert(QStringLiteral("adapterDisplayName"), label);
    item->insert(QStringLiteral("iconLabel"), label.left(1).toUpper());
  }
  // 「游戏识别」关 -> 规则元数据里的游戏类同样降级。这里原样写入 rule->category，
  // 而 aggregateSoftware()/allApps() 早在几行前就把 item["category"] 从 game 降到
  // other，于是同一行数据带着两个互相矛盾的类别出门；任何优先读 adapterCategory 的
  // UI（AppVisual.modelCategory）都会绕过这个读层开关。降级是读层的事，不写盘。
  QString adapterCategory = rule->category;
  if (!m_gameClassify && adapterCategory == QStringLiteral("game")) {
    adapterCategory = QStringLiteral("other");
  }
  item->insert(QStringLiteral("adapterCategory"), adapterCategory);

  const QString icon = rule->icon.trimmed();
  if (!icon.isEmpty()) {
    item->insert(QStringLiteral("iconPath"), icon);
    item->insert(QStringLiteral("iconSource"), icon);
  } else if (!path.trimmed().isEmpty()) {
    item->insert(QStringLiteral("iconPath"), path);
  }
}

QStringList UsageStatManager::ruleIconColors(const QString& ruleId,
                                             const QString& path) const {
  const TimeArc::Categorization::Rule* rule =
      UsageStatManager_findRule(matcher().ruleSet(), ruleId);
  if (rule != nullptr && !rule->icon.trimmed().isEmpty()) {
    return iconDominantColors(rule->icon);
  }
  return iconDominantColors(path);
}

QSet<QString> UsageStatManager::focusCategories() const {
  QSet<QString> result;
  // 关「自动分类」→ 没有类别基础，专注归零（与排行口径一致）。
  const bool inferenceOn = m_categorization != nullptr
                               ? m_categorization->autoClassify()
                               : m_autoClassify;
  if (!inferenceOn) return result;
  for (const TimeArc::Categorization::CategoryDef& category :
       matcher().ruleSet().categories) {
    if (category.enabled && category.hasTrait(QStringLiteral("focus"))) {
      result.insert(category.id);
    }
  }
  return result;
}

// 「降权」是类别的一个特征位，不是写死的「系统」——用户给自建类别打上同样的
// 特征，首页排行与今日主题也会一并让开。
bool UsageStatManager::isDeprioritizedCategory(const QString& category) const {
  const TimeArc::Categorization::CategoryDef* definition =
      matcher().ruleSet().category(category);
  return definition != nullptr &&
         definition->hasTrait(QStringLiteral("deprioritize"));
}

QVariantList UsageStatManager::recordedAppIdentities() const {
  struct Identity {
    QString appId;
    QString displayName;
    QString path;
    qint64 lastUsedUnixSec = 0;
    quint64 seconds = 0;
  };
  QMap<QString, Identity> seen;
  for (const UsageRecord& record : m_records) {
    if (record.startUnixSec <= 0 || record.activeSec == 0) continue;
    const QString key = record.appId.trimmed().isEmpty()
                            ? record.appName.trimmed().toLower()
                            : record.appId;
    if (key.isEmpty()) continue;
    Identity& identity = seen[key];
    if (identity.appId.isEmpty() && identity.displayName.isEmpty()) {
      identity.appId = record.appId;
      identity.displayName = !record.appName.trimmed().isEmpty()
                                 ? record.appName
                                 : QFileInfo(record.path).fileName();
      identity.path = record.path;
    }
    identity.seconds += record.activeSec;
    identity.lastUsedUnixSec =
        std::max(identity.lastUsedUnixSec,
                 record.startUnixSec + static_cast<qint64>(record.durationSec));
  }

  QVariantList result;
  for (const Identity& identity : seen) {
    QVariantMap item;
    item.insert(QStringLiteral("appId"), identity.appId);
    item.insert(QStringLiteral("displayName"), identity.displayName);
    item.insert(QStringLiteral("path"), identity.path);
    item.insert(QStringLiteral("seconds"),
                static_cast<qlonglong>(identity.seconds));
    item.insert(QStringLiteral("lastUsedUnixSec"), identity.lastUsedUnixSec);
    result.append(item);
  }
  return result;
}
