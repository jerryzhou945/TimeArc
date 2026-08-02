#include "services/mobile/mobile_usage_repository.h"

#include <QDate>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QCoreApplication>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QThread>
#include <QVariantMap>

#include "services/app_repository.h"

namespace {

const QString kConnectionName = QStringLiteral("timearc");
const QString kAndroidPlatform = QStringLiteral("android");
const QString kAndroidPrefix = QStringLiteral("android:");
const QString kFallbackDeviceId = QStringLiteral("android-device");
const QString kDefaultSource = QStringLiteral("android_usage_stats_aggregate");
const QString kEventsSource = QStringLiteral("android_usage_events");
const QString kObservedConfidence = QStringLiteral("observed");
const QString kEstimatedConfidence = QStringLiteral("estimated");

QSqlDatabase database() {
#ifdef Q_OS_ANDROID
  const QCoreApplication* app = QCoreApplication::instance();
  if (app != nullptr && QThread::currentThread() != app->thread()) {
    const QString connectionName = QStringLiteral("%1_%2")
                                       .arg(kConnectionName)
                                       .arg(reinterpret_cast<quintptr>(
                                                QThread::currentThreadId()),
                                            0, 16);
    QSqlDatabase db = QSqlDatabase::contains(connectionName)
                          ? QSqlDatabase::database(connectionName)
                          : QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"),
                                                      connectionName);
    if (db.databaseName().isEmpty()) {
      const QString appDataLocation =
          QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
      db.setDatabaseName(
          QDir(appDataLocation).filePath(QStringLiteral("timearc.db")));
    }
    if (!db.isOpen() && !db.open()) {
      qWarning() << "Database is not open:" << db.lastError().text();
      return db;
    }
    QSqlQuery(QStringLiteral("PRAGMA busy_timeout = 5000;"), db);
    QSqlQuery(QStringLiteral("PRAGMA journal_mode = WAL;"), db);
    return db;
  }
#endif

  QSqlDatabase db = QSqlDatabase::database(kConnectionName);
  if (!db.isValid() || !db.isOpen()) {
    qWarning() << "Database is not open.";
  }
  return db;
}

QString normalizePlatform(const QString& platform) {
  const QString trimmed = platform.trimmed().toLower();
  return trimmed.isEmpty() ? kAndroidPlatform : trimmed;
}

QString normalizeDeviceId(const QString& deviceId) {
  const QString trimmed = deviceId.trimmed();
  return trimmed.isEmpty() ? kFallbackDeviceId : trimmed;
}

QString normalizeSource(const QString& source) {
  const QString trimmed = source.trimmed();
  return trimmed.isEmpty() ? kDefaultSource : trimmed;
}

QString normalizeConfidence(const QString& confidence) {
  const QString trimmed = confidence.trimmed().toLower();
  return trimmed == kEstimatedConfidence ? kEstimatedConfidence
                                         : kObservedConfidence;
}

bool isIsoDate(const QString& value) {
  return QDate::fromString(value, Qt::ISODate).isValid();
}

void bindDateRange(QSqlQuery* query,
                   const QString& startDateLocal,
                   const QString& endDateLocal,
                   const QString& platform) {
  query->bindValue(QStringLiteral(":start_date_local"), startDateLocal);
  query->bindValue(QStringLiteral(":end_date_local"), endDateLocal);
  query->bindValue(QStringLiteral(":platform"), normalizePlatform(platform));
}

QVariantMap usageMapFromQuery(const QSqlQuery& query) {
  QVariantMap row;
  row.insert(QStringLiteral("id"), query.value(0));
  row.insert(QStringLiteral("platform"), query.value(1).toString());
  row.insert(QStringLiteral("deviceId"), query.value(2).toString());
  row.insert(QStringLiteral("appIdentifier"), query.value(3).toString());
  row.insert(QStringLiteral("packageName"), query.value(4).toString());
  row.insert(QStringLiteral("dateLocal"), query.value(5).toString());
  row.insert(QStringLiteral("rangeStartUnixSec"), query.value(6).toLongLong());
  row.insert(QStringLiteral("rangeEndUnixSec"), query.value(7).toLongLong());
  row.insert(QStringLiteral("foregroundSec"), query.value(8).toInt());
  row.insert(QStringLiteral("source"), query.value(9).toString());
  row.insert(QStringLiteral("firstSyncedAt"), query.value(10).toLongLong());
  row.insert(QStringLiteral("lastSyncedAt"), query.value(11).toLongLong());
  row.insert(QStringLiteral("createdAt"), query.value(12).toLongLong());
  row.insert(QStringLiteral("updatedAt"), query.value(13).toLongLong());
  row.insert(QStringLiteral("displayName"), query.value(14).toString());
  row.insert(QStringLiteral("appIconPath"), query.value(15).toString());
  return row;
}

QVariantMap sessionMapFromQuery(const QSqlQuery& query) {
  QVariantMap row;
  row.insert(QStringLiteral("id"), query.value(0));
  row.insert(QStringLiteral("platform"), query.value(1).toString());
  row.insert(QStringLiteral("deviceId"), query.value(2).toString());
  row.insert(QStringLiteral("appIdentifier"), query.value(3).toString());
  row.insert(QStringLiteral("packageName"), query.value(4).toString());
  row.insert(QStringLiteral("sessionStartUnixSec"), query.value(5).toLongLong());
  row.insert(QStringLiteral("sessionEndUnixSec"), query.value(6).toLongLong());
  row.insert(QStringLiteral("durationSec"), query.value(7).toInt());
  row.insert(QStringLiteral("source"), query.value(8).toString());
  row.insert(QStringLiteral("confidence"), query.value(9).toString());
  row.insert(QStringLiteral("createdAt"), query.value(10).toLongLong());
  row.insert(QStringLiteral("displayName"), query.value(11).toString());
  row.insert(QStringLiteral("appIconPath"), query.value(12).toString());
  return row;
}

}  // namespace

MobileUsageRepository::MobileUsageRepository(QObject* parent)
    : QObject(parent) {}

QString MobileUsageRepository::androidAppIdentifierForPackage(
    const QString& packageName) {
  const QString package = androidPackageForIdentifier(packageName);
  return package.isEmpty() ? QString() : kAndroidPrefix + package;
}

QString MobileUsageRepository::androidPackageForIdentifier(
    const QString& appIdentifier) {
  QString trimmed = appIdentifier.trimmed();
  if (trimmed.startsWith(kAndroidPrefix, Qt::CaseInsensitive)) {
    trimmed = trimmed.mid(kAndroidPrefix.size()).trimmed();
  }
  return trimmed;
}

bool MobileUsageRepository::upsertDailyUsageSummary(
    const QString& deviceId,
    const QString& packageName,
    const QString& appName,
    const QString& displayName,
    const QString& dateLocal,
    qint64 rangeStartUnixSec,
    qint64 rangeEndUnixSec,
    int foregroundSec,
    const QString& source,
    const QString& appIconPath) {
  const QString normalizedPackage = androidPackageForIdentifier(packageName);
  const QString appIdentifier = androidAppIdentifierForPackage(normalizedPackage);
  if (normalizedPackage.isEmpty() || appIdentifier.isEmpty()) {
    qWarning() << "Cannot upsert Android usage with empty package name.";
    return false;
  }
  if (!isIsoDate(dateLocal)) {
    qWarning() << "Cannot upsert Android usage with invalid local date:"
               << dateLocal;
    return false;
  }
  if (rangeEndUnixSec <= rangeStartUnixSec || foregroundSec < 0) {
    qWarning() << "Cannot upsert Android usage with invalid range or duration:"
               << rangeStartUnixSec << rangeEndUnixSec << foregroundSec;
    return false;
  }

  AppRepository appRepository;
  const QString normalizedAppName =
      appName.trimmed().isEmpty() ? normalizedPackage : appName.trimmed();
  const QString normalizedDisplayName =
      displayName.trimmed().isEmpty() ? normalizedAppName : displayName.trimmed();
  const QString normalizedAppIconPath = appIconPath.trimmed();
  if (!appRepository.upsertApp(appIdentifier, normalizedAppName,
                               normalizedDisplayName, normalizedAppIconPath,
                               normalizedPackage, kAndroidPlatform)) {
    return false;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;

  const qint64 now = QDateTime::currentSecsSinceEpoch();
  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
INSERT INTO device_usage_summaries (
    platform,
    device_id,
    app_identifier,
    package_name,
    date_local,
    range_start_unix_sec,
    range_end_unix_sec,
    foreground_sec,
    source,
    first_synced_at,
    last_synced_at,
    created_at,
    updated_at
) VALUES (
    :platform,
    :device_id,
    :app_identifier,
    :package_name,
    :date_local,
    :range_start_unix_sec,
    :range_end_unix_sec,
    :foreground_sec,
    :source,
    :first_synced_at,
    :last_synced_at,
    :created_at,
    :updated_at
)
ON CONFLICT(platform, device_id, app_identifier, date_local, source)
DO UPDATE SET
    package_name = excluded.package_name,
    range_start_unix_sec = excluded.range_start_unix_sec,
    range_end_unix_sec = excluded.range_end_unix_sec,
    foreground_sec = excluded.foreground_sec,
    last_synced_at = excluded.last_synced_at,
    updated_at = excluded.updated_at;
)SQL"))) {
    qWarning() << "Failed to prepare upsertDailyUsageSummary:"
               << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":platform"), kAndroidPlatform);
  query.bindValue(QStringLiteral(":device_id"), normalizeDeviceId(deviceId));
  query.bindValue(QStringLiteral(":app_identifier"), appIdentifier);
  query.bindValue(QStringLiteral(":package_name"), normalizedPackage);
  query.bindValue(QStringLiteral(":date_local"), dateLocal);
  query.bindValue(QStringLiteral(":range_start_unix_sec"), rangeStartUnixSec);
  query.bindValue(QStringLiteral(":range_end_unix_sec"), rangeEndUnixSec);
  query.bindValue(QStringLiteral(":foreground_sec"), foregroundSec);
  query.bindValue(QStringLiteral(":source"), normalizeSource(source));
  query.bindValue(QStringLiteral(":first_synced_at"), now);
  query.bindValue(QStringLiteral(":last_synced_at"), now);
  query.bindValue(QStringLiteral(":created_at"), now);
  query.bindValue(QStringLiteral(":updated_at"), now);

  if (!query.exec()) {
    qWarning() << "Failed to upsert Android usage summary:"
               << query.lastError().text();
    return false;
  }
  return true;
}

bool MobileUsageRepository::clearDailyUsageSummaries(
    const QString& deviceId,
    const QString& dateLocal,
    const QString& source) {
  if (!isIsoDate(dateLocal)) {
    qWarning() << "Cannot clear Android usage with invalid local date:"
               << dateLocal;
    return false;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
DELETE FROM device_usage_summaries
WHERE platform = :platform
  AND device_id = :device_id
  AND date_local = :date_local
  AND source = :source;
)SQL"))) {
    qWarning() << "Failed to prepare clearDailyUsageSummaries:"
               << query.lastError().text();
    return false;
  }
  query.bindValue(QStringLiteral(":platform"), kAndroidPlatform);
  query.bindValue(QStringLiteral(":device_id"), normalizeDeviceId(deviceId));
  query.bindValue(QStringLiteral(":date_local"), dateLocal);
  query.bindValue(QStringLiteral(":source"), normalizeSource(source));
  if (!query.exec()) {
    qWarning() << "Failed to clear Android daily usage summaries:"
               << query.lastError().text();
    return false;
  }
  return true;
}

QVariantList MobileUsageRepository::getUsageByDateRange(
    const QString& startDateLocal,
    const QString& endDateLocal,
    const QString& platform) {
  QVariantList rows;
  if (!isIsoDate(startDateLocal) || !isIsoDate(endDateLocal) ||
      startDateLocal > endDateLocal) {
    qWarning() << "Invalid Android usage date range:" << startDateLocal
               << endDateLocal;
    return rows;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return rows;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    dus.id,
    dus.platform,
    dus.device_id,
    dus.app_identifier,
    dus.package_name,
    dus.date_local,
    dus.range_start_unix_sec,
    dus.range_end_unix_sec,
    dus.foreground_sec,
    dus.source,
    dus.first_synced_at,
    dus.last_synced_at,
    dus.created_at,
    dus.updated_at,
    COALESCE(NULLIF(a.display_name, ''), a.app_name, dus.package_name) AS display_name,
    a.app_icon_path
FROM device_usage_summaries dus
LEFT JOIN apps a ON a.app_identifier = dus.app_identifier
WHERE dus.platform = :platform
  AND dus.date_local >= :start_date_local
  AND dus.date_local <= :end_date_local
ORDER BY dus.date_local ASC, dus.foreground_sec DESC, display_name COLLATE NOCASE ASC;
)SQL"))) {
    qWarning() << "Failed to prepare getUsageByDateRange:"
               << query.lastError().text();
    return rows;
  }

  bindDateRange(&query, startDateLocal, endDateLocal, platform);
  if (!query.exec()) {
    qWarning() << "Failed to query Android usage summaries:"
               << query.lastError().text();
    return rows;
  }

  while (query.next()) {
    rows.append(usageMapFromQuery(query));
  }
  return rows;
}

int MobileUsageRepository::getTotalForegroundSecondsByDateRange(
    const QString& startDateLocal,
    const QString& endDateLocal,
    const QString& platform) {
  if (!isIsoDate(startDateLocal) || !isIsoDate(endDateLocal) ||
      startDateLocal > endDateLocal) {
    qWarning() << "Invalid Android usage total date range:" << startDateLocal
               << endDateLocal;
    return 0;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return 0;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT COALESCE(SUM(foreground_sec), 0)
FROM device_usage_summaries
WHERE platform = :platform
  AND date_local >= :start_date_local
  AND date_local <= :end_date_local;
)SQL"))) {
    qWarning() << "Failed to prepare getTotalForegroundSecondsByDateRange:"
               << query.lastError().text();
    return 0;
  }

  bindDateRange(&query, startDateLocal, endDateLocal, platform);
  if (!query.exec() || !query.next()) {
    qWarning() << "Failed to query Android usage total:"
               << query.lastError().text();
    return 0;
  }

  return query.value(0).toInt();
}

bool MobileUsageRepository::addUsageSession(const QString& deviceId,
                                            const QString& packageName,
                                            const QString& appName,
                                            const QString& displayName,
                                            qint64 sessionStartUnixSec,
                                            qint64 sessionEndUnixSec,
                                            const QString& source,
                                            const QString& confidence,
                                            const QString& appIconPath) {
  const QString normalizedPackage = androidPackageForIdentifier(packageName);
  const QString appIdentifier = androidAppIdentifierForPackage(normalizedPackage);
  if (normalizedPackage.isEmpty() || appIdentifier.isEmpty()) {
    qWarning() << "Cannot add Android usage session with empty package name.";
    return false;
  }
  if (sessionEndUnixSec <= sessionStartUnixSec) {
    qWarning() << "Cannot add Android usage session with invalid range:"
               << sessionStartUnixSec << sessionEndUnixSec;
    return false;
  }

  AppRepository appRepository;
  const QString normalizedAppName =
      appName.trimmed().isEmpty() ? normalizedPackage : appName.trimmed();
  const QString normalizedDisplayName =
      displayName.trimmed().isEmpty() ? normalizedAppName : displayName.trimmed();
  const QString normalizedAppIconPath = appIconPath.trimmed();
  if (!appRepository.upsertApp(appIdentifier, normalizedAppName,
                               normalizedDisplayName, normalizedAppIconPath,
                               normalizedPackage, kAndroidPlatform)) {
    return false;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;

  const qint64 now = QDateTime::currentSecsSinceEpoch();
  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
INSERT OR IGNORE INTO device_usage_sessions (
    platform,
    device_id,
    app_identifier,
    package_name,
    session_start_unix_sec,
    session_end_unix_sec,
    duration_sec,
    source,
    confidence,
    created_at
) VALUES (
    :platform,
    :device_id,
    :app_identifier,
    :package_name,
    :session_start_unix_sec,
    :session_end_unix_sec,
    :duration_sec,
    :source,
    :confidence,
    :created_at
);
)SQL"))) {
    qWarning() << "Failed to prepare addUsageSession:"
               << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":platform"), kAndroidPlatform);
  query.bindValue(QStringLiteral(":device_id"), normalizeDeviceId(deviceId));
  query.bindValue(QStringLiteral(":app_identifier"), appIdentifier);
  query.bindValue(QStringLiteral(":package_name"), normalizedPackage);
  query.bindValue(QStringLiteral(":session_start_unix_sec"),
                  sessionStartUnixSec);
  query.bindValue(QStringLiteral(":session_end_unix_sec"), sessionEndUnixSec);
  query.bindValue(QStringLiteral(":duration_sec"),
                  static_cast<int>(sessionEndUnixSec - sessionStartUnixSec));
  query.bindValue(QStringLiteral(":source"),
                  source.trimmed().isEmpty() ? kEventsSource
                                             : source.trimmed());
  query.bindValue(QStringLiteral(":confidence"), normalizeConfidence(confidence));
  query.bindValue(QStringLiteral(":created_at"), now);

  if (!query.exec()) {
    qWarning() << "Failed to add Android usage session:"
               << query.lastError().text();
    return false;
  }
  return true;
}

QVariantList MobileUsageRepository::getSessionsByRange(qint64 startUnixSec,
                                                       qint64 endUnixSec,
                                                       const QString& platform) {
  QVariantList rows;
  if (endUnixSec <= startUnixSec) {
    qWarning() << "Invalid Android usage session query range:" << startUnixSec
               << endUnixSec;
    return rows;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return rows;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    dus.id,
    dus.platform,
    dus.device_id,
    dus.app_identifier,
    dus.package_name,
    dus.session_start_unix_sec,
    dus.session_end_unix_sec,
    dus.duration_sec,
    dus.source,
    dus.confidence,
    dus.created_at,
    COALESCE(NULLIF(a.display_name, ''), a.app_name, dus.package_name) AS display_name,
    a.app_icon_path
FROM device_usage_sessions dus
LEFT JOIN apps a ON a.app_identifier = dus.app_identifier
WHERE dus.platform = :platform
  AND dus.session_start_unix_sec < :end_unix_sec
  AND dus.session_end_unix_sec > :start_unix_sec
ORDER BY dus.session_start_unix_sec ASC;
)SQL"))) {
    qWarning() << "Failed to prepare getSessionsByRange:"
               << query.lastError().text();
    return rows;
  }

  query.bindValue(QStringLiteral(":platform"), normalizePlatform(platform));
  query.bindValue(QStringLiteral(":start_unix_sec"), startUnixSec);
  query.bindValue(QStringLiteral(":end_unix_sec"), endUnixSec);
  if (!query.exec()) {
    qWarning() << "Failed to query Android usage sessions:"
               << query.lastError().text();
    return rows;
  }

  while (query.next()) {
    rows.append(sessionMapFromQuery(query));
  }
  return rows;
}
