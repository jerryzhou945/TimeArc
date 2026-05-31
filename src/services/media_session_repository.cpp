#include "services/media_session_repository.h"

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

QString normalizedMediaType(const QString& mediaType) {
  const QString value = mediaType.trimmed().toLower();
  if (value == QStringLiteral("audio") || value == QStringLiteral("video") ||
      value == QStringLiteral("unknown")) {
    return value;
  }

  return QStringLiteral("unknown");
}

bool validateRange(qint64 startUnixSec, qint64 endUnixSec) {
  if (endUnixSec <= startUnixSec) {
    qWarning() << "Invalid media session range:" << startUnixSec
               << endUnixSec;
    return false;
  }

  if (endUnixSec - startUnixSec > std::numeric_limits<int>::max()) {
    qWarning() << "Media session duration is too large:" << startUnixSec
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

MediaSessionRepository::MediaSessionRepository(QObject* parent)
    : QObject(parent) {}

bool MediaSessionRepository::addMediaSession(const QString& appIdentifier,
                                             const QString& mediaType,
                                             const QString& mediaTitle,
                                             qint64 startUnixSec,
                                             qint64 endUnixSec,
                                             int playbackSec) {
  const QString normalizedIdentifier = appIdentifier.trimmed();
  if (normalizedIdentifier.isEmpty()) {
    qWarning() << "Cannot add media session with empty app_identifier.";
    return false;
  }

  if (!validateRange(startUnixSec, endUnixSec)) return false;

  if (playbackSec < 0) {
    qWarning() << "Media playbackSec cannot be negative:" << playbackSec;
    return false;
  }

  const int correctedPlaybackSec =
      static_cast<int>(endUnixSec - startUnixSec);
  const qint64 now = QDateTime::currentSecsSinceEpoch();

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
INSERT OR IGNORE INTO media_sessions (
    app_identifier,
    media_type,
    media_title,
    start_unix_sec,
    end_unix_sec,
    playback_sec,
    created_at
) VALUES (
    :app_identifier,
    :media_type,
    :media_title,
    :start_unix_sec,
    :end_unix_sec,
    :playback_sec,
    :created_at
);
)SQL"))) {
    qWarning() << "Failed to prepare addMediaSession:"
               << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":app_identifier"), normalizedIdentifier);
  query.bindValue(QStringLiteral(":media_type"), normalizedMediaType(mediaType));
  query.bindValue(QStringLiteral(":media_title"), mediaTitle);
  query.bindValue(QStringLiteral(":start_unix_sec"), startUnixSec);
  query.bindValue(QStringLiteral(":end_unix_sec"), endUnixSec);
  query.bindValue(QStringLiteral(":playback_sec"), correctedPlaybackSec);
  query.bindValue(QStringLiteral(":created_at"), now);

  if (!query.exec()) {
    qWarning() << "Failed to add media session:" << query.lastError().text();
    return false;
  }

  if (query.numRowsAffected() == 0) {
    qDebug() << "Duplicate media session skipped:" << normalizedIdentifier
             << normalizedMediaType(mediaType) << mediaTitle << startUnixSec
             << endUnixSec;
    return true;
  }

  return true;
}

QVariantList MediaSessionRepository::getSessionsByRange(qint64 startUnixSec,
                                                        qint64 endUnixSec) {
  QVariantList sessions;
  if (!validateRange(startUnixSec, endUnixSec)) return sessions;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return sessions;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    ms.id,
    ms.app_identifier,
    ms.media_type,
    ms.media_title,
    ms.start_unix_sec,
    ms.end_unix_sec,
    ms.playback_sec,
    ms.created_at,
    COALESCE(NULLIF(a.display_name, ''), a.app_name, ms.app_identifier) AS display_name,
    a.app_icon_path
FROM media_sessions ms
LEFT JOIN apps a ON a.app_identifier = ms.app_identifier
WHERE ms.start_unix_sec < :end_unix_sec
  AND ms.end_unix_sec > :start_unix_sec
ORDER BY ms.start_unix_sec ASC;
)SQL"))) {
    qWarning() << "Failed to prepare getMediaSessionsByRange:"
               << query.lastError().text();
    return sessions;
  }

  bindRange(&query, startUnixSec, endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query media sessions:"
               << query.lastError().text();
    return sessions;
  }

  while (query.next()) {
    QVariantMap session;
    const int playbackSec = query.value(6).toInt();
    session.insert(QStringLiteral("id"), query.value(0));
    session.insert(QStringLiteral("appIdentifier"), query.value(1).toString());
    session.insert(QStringLiteral("mediaType"), query.value(2).toString());
    session.insert(QStringLiteral("mediaTitle"), query.value(3).toString());
    session.insert(QStringLiteral("startUnixSec"), query.value(4).toLongLong());
    session.insert(QStringLiteral("endUnixSec"), query.value(5).toLongLong());
    session.insert(QStringLiteral("playbackSec"), playbackSec);
    session.insert(QStringLiteral("createdAt"), query.value(7).toLongLong());
    session.insert(QStringLiteral("displayName"), query.value(8).toString());
    session.insert(QStringLiteral("appIconPath"), query.value(9).toString());
    session.insert(QStringLiteral("durationText"), formatDuration(playbackSec));
    sessions.append(session);
  }

  return sessions;
}

QVariantList MediaSessionRepository::getIntervalsByRange(qint64 startUnixSec,
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
    media_type,
    start_unix_sec,
    end_unix_sec,
    playback_sec
FROM media_sessions
WHERE start_unix_sec < :end_unix_sec
  AND end_unix_sec > :start_unix_sec
ORDER BY start_unix_sec ASC;
)SQL"))) {
    qWarning() << "Failed to prepare getMediaIntervalsByRange:"
               << query.lastError().text();
    return intervals;
  }

  bindRange(&query, startUnixSec, endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query media intervals:"
               << query.lastError().text();
    return intervals;
  }

  while (query.next()) {
    QVariantMap interval;
    interval.insert(QStringLiteral("id"), query.value(0));
    interval.insert(QStringLiteral("appIdentifier"), query.value(1).toString());
    interval.insert(QStringLiteral("mediaType"), query.value(2).toString());
    interval.insert(QStringLiteral("startUnixSec"),
                    query.value(3).toLongLong());
    interval.insert(QStringLiteral("endUnixSec"), query.value(4).toLongLong());
    interval.insert(QStringLiteral("playbackSec"), query.value(5).toInt());
    intervals.append(interval);
  }

  return intervals;
}

int MediaSessionRepository::getTotalPlaybackSecondsByRange(
    qint64 startUnixSec,
    qint64 endUnixSec) {
  if (!validateRange(startUnixSec, endUnixSec)) return 0;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return 0;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT COALESCE(SUM(playback_sec), 0)
FROM media_sessions
WHERE start_unix_sec < :end_unix_sec
  AND end_unix_sec > :start_unix_sec;
)SQL"))) {
    qWarning() << "Failed to prepare getTotalPlaybackSecondsByRange:"
               << query.lastError().text();
    return 0;
  }

  bindRange(&query, startUnixSec, endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query total media playback seconds:"
               << query.lastError().text();
    return 0;
  }

  if (!query.next()) return 0;
  return query.value(0).toInt();
}

QVariantList MediaSessionRepository::getTodayMediaRanking() {
  QVariantList ranking;
  const qint64 startUnixSec =
      QDateTime::currentDateTime().date().startOfDay().toSecsSinceEpoch();
  const qint64 endUnixSec = startUnixSec + 24 * 60 * 60;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return ranking;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    ms.app_identifier,
    COALESCE(NULLIF(a.display_name, ''), a.app_name, ms.app_identifier) AS display_name,
    a.app_icon_path,
    ms.media_type,
    SUM(ms.playback_sec) AS total_sec
FROM media_sessions ms
LEFT JOIN apps a ON a.app_identifier = ms.app_identifier
WHERE ms.start_unix_sec < :end_unix_sec
  AND ms.end_unix_sec > :start_unix_sec
GROUP BY
    ms.app_identifier,
    ms.media_type,
    a.display_name,
    a.app_name,
    a.app_icon_path
HAVING total_sec > 0
ORDER BY total_sec DESC;
)SQL"))) {
    qWarning() << "Failed to prepare getTodayMediaRanking:"
               << query.lastError().text();
    return ranking;
  }

  bindRange(&query, startUnixSec, endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query today media ranking:"
               << query.lastError().text();
    return ranking;
  }

  while (query.next()) {
    QVariantMap item;
    const int playbackSec = query.value(4).toInt();
    item.insert(QStringLiteral("appIdentifier"), query.value(0).toString());
    item.insert(QStringLiteral("displayName"), query.value(1).toString());
    item.insert(QStringLiteral("appIconPath"), query.value(2).toString());
    item.insert(QStringLiteral("mediaType"), query.value(3).toString());
    item.insert(QStringLiteral("playbackSec"), playbackSec);
    item.insert(QStringLiteral("durationText"), formatDuration(playbackSec));
    ranking.append(item);
  }

  return ranking;
}
