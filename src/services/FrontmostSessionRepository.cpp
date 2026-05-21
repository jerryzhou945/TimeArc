#include "services/FrontmostSessionRepository.h"

#include <QDateTime>
#include <QDebug>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantMap>

#include <limits>

namespace {

const QString kConnectionName = QStringLiteral("timearc");

QSqlDatabase database() {
  QSqlDatabase db = QSqlDatabase::database(kConnectionName);
  if (!db.isValid() || !db.isOpen()) {
    qWarning() << "Database is not open.";
  }
  return db;
}

QString formatDuration(int seconds) {
  const int safeSeconds = qMax(0, seconds);
  if (safeSeconds < 60) {
    return QStringLiteral("%1s").arg(safeSeconds);
  }

  const int minutes = safeSeconds / 60;
  if (minutes < 60) {
    return QStringLiteral("%1m").arg(minutes);
  }

  const int hours = minutes / 60;
  const int remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) {
    return QStringLiteral("%1h").arg(hours);
  }

  return QStringLiteral("%1h %2m").arg(hours).arg(remainingMinutes);
}

bool validateRange(qint64 startUnixSec, qint64 endUnixSec) {
  if (endUnixSec <= startUnixSec) {
    qWarning() << "Invalid session range:" << startUnixSec << endUnixSec;
    return false;
  }

  if (endUnixSec - startUnixSec > std::numeric_limits<int>::max()) {
    qWarning() << "Session duration is too large:" << startUnixSec
               << endUnixSec;
    return false;
  }

  return true;
}

void bindRange(QSqlQuery* query, qint64 startUnixSec, qint64 endUnixSec) {
  query->bindValue(QStringLiteral(":start_unix_sec"), startUnixSec);
  query->bindValue(QStringLiteral(":end_unix_sec"), endUnixSec);
}

}  // namespace

FrontmostSessionRepository::FrontmostSessionRepository(QObject* parent)
    : QObject(parent) {}

bool FrontmostSessionRepository::addFrontmostSession(
    const QString& appIdentifier,
    const QString& windowTitle,
    qint64 startUnixSec,
    qint64 endUnixSec,
    int durationSec,
    int activeSec,
    int idleSec) {
  const QString normalizedIdentifier = appIdentifier.trimmed();
  if (normalizedIdentifier.isEmpty()) {
    qWarning() << "Cannot add frontmost session with empty app_identifier.";
    return false;
  }

  if (!validateRange(startUnixSec, endUnixSec)) return false;

  if (durationSec < 0 || activeSec < 0 || idleSec < 0) {
    qWarning() << "Frontmost session duration values cannot be negative:"
               << durationSec << activeSec << idleSec;
    return false;
  }

  const int correctedDurationSec =
      static_cast<int>(endUnixSec - startUnixSec);
  const qint64 now = QDateTime::currentSecsSinceEpoch();

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
INSERT OR IGNORE INTO frontmost_sessions (
    app_identifier,
    window_title,
    start_unix_sec,
    end_unix_sec,
    duration_sec,
    active_sec,
    idle_sec,
    created_at
) VALUES (
    :app_identifier,
    :window_title,
    :start_unix_sec,
    :end_unix_sec,
    :duration_sec,
    :active_sec,
    :idle_sec,
    :created_at
);
)SQL"))) {
    qWarning() << "Failed to prepare addFrontmostSession:"
               << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":app_identifier"), normalizedIdentifier);
  query.bindValue(QStringLiteral(":window_title"), windowTitle);
  query.bindValue(QStringLiteral(":start_unix_sec"), startUnixSec);
  query.bindValue(QStringLiteral(":end_unix_sec"), endUnixSec);
  query.bindValue(QStringLiteral(":duration_sec"), correctedDurationSec);
  query.bindValue(QStringLiteral(":active_sec"), activeSec);
  query.bindValue(QStringLiteral(":idle_sec"), idleSec);
  query.bindValue(QStringLiteral(":created_at"), now);

  if (!query.exec()) {
    qWarning() << "Failed to add frontmost session:"
               << query.lastError().text();
    return false;
  }

  if (query.numRowsAffected() == 0) {
    qDebug() << "Duplicate frontmost session skipped:" << normalizedIdentifier
             << windowTitle << startUnixSec << endUnixSec;
    return true;
  }

  return true;
}

QVariantList FrontmostSessionRepository::getSessionsByRange(
    qint64 startUnixSec,
    qint64 endUnixSec) {
  QVariantList sessions;
  if (!validateRange(startUnixSec, endUnixSec)) return sessions;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return sessions;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    fs.id,
    fs.app_identifier,
    fs.window_title,
    fs.start_unix_sec,
    fs.end_unix_sec,
    fs.duration_sec,
    fs.active_sec,
    fs.idle_sec,
    fs.created_at,
    COALESCE(NULLIF(a.display_name, ''), a.app_name, fs.app_identifier) AS display_name,
    a.app_icon_path
FROM frontmost_sessions fs
LEFT JOIN apps a ON a.app_identifier = fs.app_identifier
WHERE fs.start_unix_sec < :end_unix_sec
  AND fs.end_unix_sec > :start_unix_sec
ORDER BY fs.start_unix_sec ASC;
)SQL"))) {
    qWarning() << "Failed to prepare getSessionsByRange:"
               << query.lastError().text();
    return sessions;
  }

  bindRange(&query, startUnixSec, endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query frontmost sessions:"
               << query.lastError().text();
    return sessions;
  }

  while (query.next()) {
    QVariantMap session;
    const int durationSec = query.value(5).toInt();
    session.insert(QStringLiteral("id"), query.value(0));
    session.insert(QStringLiteral("appIdentifier"), query.value(1).toString());
    session.insert(QStringLiteral("windowTitle"), query.value(2).toString());
    session.insert(QStringLiteral("startUnixSec"), query.value(3).toLongLong());
    session.insert(QStringLiteral("endUnixSec"), query.value(4).toLongLong());
    session.insert(QStringLiteral("durationSec"), durationSec);
    session.insert(QStringLiteral("activeSec"), query.value(6).toInt());
    session.insert(QStringLiteral("idleSec"), query.value(7).toInt());
    session.insert(QStringLiteral("createdAt"), query.value(8).toLongLong());
    session.insert(QStringLiteral("displayName"), query.value(9).toString());
    session.insert(QStringLiteral("appIconPath"), query.value(10).toString());
    session.insert(QStringLiteral("durationText"), formatDuration(durationSec));
    sessions.append(session);
  }

  return sessions;
}

QVariantList FrontmostSessionRepository::getIntervalsByRange(
    qint64 startUnixSec,
    qint64 endUnixSec) {
  QVariantList intervals;
  if (!validateRange(startUnixSec, endUnixSec)) return intervals;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return intervals;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    id,
    app_identifier,
    start_unix_sec,
    end_unix_sec,
    duration_sec,
    active_sec,
    idle_sec
FROM frontmost_sessions
WHERE start_unix_sec < :end_unix_sec
  AND end_unix_sec > :start_unix_sec
ORDER BY start_unix_sec ASC;
)SQL"))) {
    qWarning() << "Failed to prepare getIntervalsByRange:"
               << query.lastError().text();
    return intervals;
  }

  bindRange(&query, startUnixSec, endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query frontmost intervals:"
               << query.lastError().text();
    return intervals;
  }

  while (query.next()) {
    QVariantMap interval;
    interval.insert(QStringLiteral("id"), query.value(0));
    interval.insert(QStringLiteral("appIdentifier"), query.value(1).toString());
    interval.insert(QStringLiteral("startUnixSec"),
                    query.value(2).toLongLong());
    interval.insert(QStringLiteral("endUnixSec"), query.value(3).toLongLong());
    interval.insert(QStringLiteral("durationSec"), query.value(4).toInt());
    interval.insert(QStringLiteral("activeSec"), query.value(5).toInt());
    interval.insert(QStringLiteral("idleSec"), query.value(6).toInt());
    intervals.append(interval);
  }

  return intervals;
}

int FrontmostSessionRepository::getTotalActiveSecondsByRange(
    qint64 startUnixSec,
    qint64 endUnixSec) {
  if (!validateRange(startUnixSec, endUnixSec)) return 0;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return 0;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT COALESCE(SUM(active_sec), 0)
FROM frontmost_sessions
WHERE start_unix_sec < :end_unix_sec
  AND end_unix_sec > :start_unix_sec;
)SQL"))) {
    qWarning() << "Failed to prepare getTotalActiveSecondsByRange:"
               << query.lastError().text();
    return 0;
  }

  bindRange(&query, startUnixSec, endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query total frontmost active seconds:"
               << query.lastError().text();
    return 0;
  }

  if (!query.next()) return 0;
  return query.value(0).toInt();
}

QVariantList FrontmostSessionRepository::getTodayFrontmostRanking() {
  QVariantList ranking;
  const qint64 startUnixSec =
      QDateTime::currentDateTime().date().startOfDay().toSecsSinceEpoch();
  const qint64 endUnixSec = startUnixSec + 24 * 60 * 60;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return ranking;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    fs.app_identifier,
    COALESCE(NULLIF(a.display_name, ''), a.app_name, fs.app_identifier) AS display_name,
    a.app_icon_path,
    SUM(fs.active_sec) AS total_sec
FROM frontmost_sessions fs
LEFT JOIN apps a ON a.app_identifier = fs.app_identifier
WHERE fs.start_unix_sec < :end_unix_sec
  AND fs.end_unix_sec > :start_unix_sec
GROUP BY
    fs.app_identifier,
    a.display_name,
    a.app_name,
    a.app_icon_path
HAVING total_sec > 0
ORDER BY total_sec DESC;
)SQL"))) {
    qWarning() << "Failed to prepare getTodayFrontmostRanking:"
               << query.lastError().text();
    return ranking;
  }

  bindRange(&query, startUnixSec, endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query today frontmost ranking:"
               << query.lastError().text();
    return ranking;
  }

  while (query.next()) {
    QVariantMap item;
    const int durationSec = query.value(3).toInt();
    item.insert(QStringLiteral("appIdentifier"), query.value(0).toString());
    item.insert(QStringLiteral("displayName"), query.value(1).toString());
    item.insert(QStringLiteral("appIconPath"), query.value(2).toString());
    item.insert(QStringLiteral("durationSec"), durationSec);
    item.insert(QStringLiteral("durationText"), formatDuration(durationSec));
    ranking.append(item);
  }

  return ranking;
}
