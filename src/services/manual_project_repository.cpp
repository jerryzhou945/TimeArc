#include "services/manual_project_repository.h"

#include <QDateTime>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QVariant>

#include <limits>

namespace {

const QString kConnectionName = QStringLiteral("timearc");
const QString kDefaultTagName = QStringLiteral("Other");

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

QVariantMap projectMapFromQuery(const QSqlQuery& query) {
  const int totalDurationSec = query.value(5).toInt();

  QVariantMap project;
  project.insert(QStringLiteral("id"), query.value(0).toInt());
  project.insert(QStringLiteral("name"), query.value(1).toString());
  project.insert(QStringLiteral("description"), query.value(2).toString());
  project.insert(QStringLiteral("tagId"), query.value(3));
  project.insert(QStringLiteral("color"), query.value(4).toString());
  project.insert(QStringLiteral("totalDurationSec"), totalDurationSec);
  project.insert(QStringLiteral("seconds"), totalDurationSec);
  project.insert(QStringLiteral("time"), formatDuration(totalDurationSec));
  project.insert(QStringLiteral("totalDurationText"),
                 formatDuration(totalDurationSec));
  project.insert(QStringLiteral("isArchived"), query.value(6).toInt() != 0);
  project.insert(QStringLiteral("createdAt"), query.value(7).toLongLong());
  project.insert(QStringLiteral("updatedAt"), query.value(8).toLongLong());
  if (query.record().count() > 9) {
    const QString tagName = query.value(9).toString();
    project.insert(QStringLiteral("tag"),
                   tagName.trimmed().isEmpty() ? kDefaultTagName : tagName);
  } else {
    project.insert(QStringLiteral("tag"), kDefaultTagName);
  }
  return project;
}

QJsonObject noteObject(const QString& note) {
  const QJsonDocument doc = QJsonDocument::fromJson(note.toUtf8());
  return doc.isObject() ? doc.object() : QJsonObject();
}

QString metadataNote(const QString& displayName,
                     const QString& source,
                     const QString& linkedProjectName) {
  QJsonObject object;
  object.insert(QStringLiteral("displayName"), displayName);
  object.insert(QStringLiteral("source"),
                source.trimmed().isEmpty() ? QStringLiteral("manual_project")
                                           : source.trimmed());
  object.insert(QStringLiteral("linkedProjectName"),
                linkedProjectName.trimmed());
  return QString::fromUtf8(
      QJsonDocument(object).toJson(QJsonDocument::Compact));
}

QDateTime sessionDateTime(qint64 unixSec) {
  return QDateTime::fromSecsSinceEpoch(unixSec).toLocalTime();
}

bool validateProjectId(int projectId) {
  if (projectId <= 0) {
    qWarning() << "Invalid manual project id:" << projectId;
    return false;
  }

  return true;
}

bool validateRange(qint64 startUnixSec, qint64 endUnixSec) {
  if (endUnixSec <= startUnixSec) {
    qWarning() << "Invalid manual session range:" << startUnixSec
               << endUnixSec;
    return false;
  }

  return true;
}

bool projectExists(QSqlDatabase db, int projectId) {
  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT id
FROM manual_projects
WHERE id = :id
LIMIT 1;
)SQL"))) {
    qWarning() << "Failed to prepare projectExists:"
               << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":id"), projectId);

  if (!query.exec()) {
    qWarning() << "Failed to query manual project existence:"
               << query.lastError().text();
    return false;
  }

  if (!query.next()) {
    qWarning() << "Manual project does not exist:" << projectId;
    return false;
  }

  return true;
}

bool sessionExists(QSqlDatabase db,
                   int projectId,
                   qint64 startUnixSec,
                   qint64 endUnixSec,
                   const QString& note) {
  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT id
FROM manual_sessions
WHERE project_id = :project_id
  AND start_unix_sec = :start_unix_sec
  AND end_unix_sec = :end_unix_sec
  AND note = :note
LIMIT 1;
)SQL"))) {
    qWarning() << "Failed to prepare sessionExists:"
               << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":project_id"), projectId);
  query.bindValue(QStringLiteral(":start_unix_sec"), startUnixSec);
  query.bindValue(QStringLiteral(":end_unix_sec"), endUnixSec);
  query.bindValue(QStringLiteral(":note"), note);

  if (!query.exec()) {
    qWarning() << "Failed to query manual session existence:"
               << query.lastError().text();
    return false;
  }

  return query.next();
}

int tagIdForName(QSqlDatabase db, const QString& tagName) {
  const QString normalizedTag =
      tagName.trimmed().isEmpty() ? kDefaultTagName : tagName.trimmed();

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT id
FROM tags
WHERE name = :name
LIMIT 1;
)SQL"))) {
    qWarning() << "Failed to prepare tagIdForName:"
               << query.lastError().text();
    return -1;
  }

  query.bindValue(QStringLiteral(":name"), normalizedTag);
  if (!query.exec()) {
    qWarning() << "Failed to query tag id:" << query.lastError().text();
    return -1;
  }

  if (query.next()) return query.value(0).toInt();

  QSqlQuery insert(db);
  if (!insert.prepare(QStringLiteral(R"SQL(
INSERT INTO tags (
    name,
    color,
    icon,
    created_at
) VALUES (
    :name,
    :color,
    :icon,
    :created_at
);
)SQL"))) {
    qWarning() << "Failed to prepare tag insert:" << insert.lastError().text();
    return -1;
  }

  insert.bindValue(QStringLiteral(":name"), normalizedTag);
  insert.bindValue(QStringLiteral(":color"), QStringLiteral("#B7AEA6"));
  insert.bindValue(QStringLiteral(":icon"), QVariant());
  insert.bindValue(QStringLiteral(":created_at"),
                   QDateTime::currentSecsSinceEpoch());

  if (!insert.exec()) {
    qWarning() << "Failed to insert tag:" << insert.lastError().text();
    return -1;
  }

  return insert.lastInsertId().toInt();
}

QVariantMap sessionMapFromQuery(const QSqlQuery& query) {
  const qint64 startUnixSec = query.value(2).toLongLong();
  const qint64 endUnixSec = query.value(3).toLongLong();
  const int durationSec = query.value(4).toInt();
  const QString note = query.value(5).toString();
  const QJsonObject metadata = noteObject(note);
  const QDateTime localStart = sessionDateTime(startUnixSec);
  const QString projectName = query.value(7).toString();
  const QString tagName = query.value(8).toString().trimmed().isEmpty()
                              ? kDefaultTagName
                              : query.value(8).toString();
  const QString displayName =
      metadata.value(QStringLiteral("displayName")).toString(projectName);
  const QString source =
      metadata.value(QStringLiteral("source")).toString(
          QStringLiteral("manual_project"));
  const QString linkedProjectName =
      metadata.value(QStringLiteral("linkedProjectName")).toString();

  QVariantMap session;
  session.insert(QStringLiteral("id"), query.value(0).toInt());
  session.insert(QStringLiteral("projectId"), query.value(1).toInt());
  session.insert(QStringLiteral("startUnixSec"), startUnixSec);
  session.insert(QStringLiteral("endUnixSec"), endUnixSec);
  session.insert(QStringLiteral("durationSec"), durationSec);
  session.insert(QStringLiteral("seconds"), durationSec);
  session.insert(QStringLiteral("durationText"), formatDuration(durationSec));
  session.insert(QStringLiteral("note"), note);
  session.insert(QStringLiteral("createdAt"), query.value(6).toLongLong());
  session.insert(QStringLiteral("projectName"), projectName);
  session.insert(QStringLiteral("displayName"), displayName);
  session.insert(QStringLiteral("name"), displayName);
  session.insert(QStringLiteral("tag"), tagName);
  session.insert(QStringLiteral("source"), source);
  session.insert(QStringLiteral("linkedProjectName"), linkedProjectName);
  session.insert(QStringLiteral("linkedProject"),
                 !linkedProjectName.trimmed().isEmpty());
  session.insert(QStringLiteral("date"),
                 localStart.date().toString(QStringLiteral("yyyy-MM-dd")));
  session.insert(QStringLiteral("year"), localStart.date().year());
  session.insert(QStringLiteral("month"), localStart.date().month());
  session.insert(QStringLiteral("day"), localStart.date().day());
  session.insert(QStringLiteral("time"), formatDuration(durationSec));
  session.insert(QStringLiteral("minutes"), durationSec / 60);
  return session;
}

}  // namespace

ManualProjectRepository::ManualProjectRepository(QObject* parent)
    : QObject(parent) {}

bool ManualProjectRepository::createProject(const QString& name,
                                            const QString& description,
                                            int tagId,
                                            const QString& color) {
  const QString normalizedName = name.trimmed();
  if (normalizedName.isEmpty()) {
    qWarning() << "Cannot create manual project with empty name.";
    return false;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;

  const qint64 now = QDateTime::currentSecsSinceEpoch();

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
INSERT INTO manual_projects (
    name,
    description,
    tag_id,
    color,
    total_duration_sec,
    is_archived,
    created_at,
    updated_at
) VALUES (
    :name,
    :description,
    :tag_id,
    :color,
    0,
    0,
    :created_at,
    :updated_at
);
)SQL"))) {
    qWarning() << "Failed to prepare createProject:"
               << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":name"), normalizedName);
  query.bindValue(QStringLiteral(":description"), description);
  query.bindValue(QStringLiteral(":tag_id"),
                  tagId < 0 ? QVariant() : QVariant(tagId));
  query.bindValue(QStringLiteral(":color"), color);
  query.bindValue(QStringLiteral(":created_at"), now);
  query.bindValue(QStringLiteral(":updated_at"), now);

  if (!query.exec()) {
    qWarning() << "Failed to create manual project:"
               << query.lastError().text();
    return false;
  }

  return true;
}

int ManualProjectRepository::ensureProject(const QString& name,
                                           const QString& tagName,
                                           const QString& color) {
  const QString normalizedName = name.trimmed();
  if (normalizedName.isEmpty()) {
    qWarning() << "Cannot ensure manual project with empty name.";
    return -1;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return -1;

  const int tagId = tagIdForName(db, tagName);
  if (tagId <= 0) return -1;

  QSqlQuery find(db);
  if (!find.prepare(QStringLiteral(R"SQL(
SELECT id
FROM manual_projects
WHERE name = :name
  AND tag_id = :tag_id
  AND is_archived = 0
ORDER BY updated_at DESC
LIMIT 1;
)SQL"))) {
    qWarning() << "Failed to prepare ensureProject lookup:"
               << find.lastError().text();
    return -1;
  }

  find.bindValue(QStringLiteral(":name"), normalizedName);
  find.bindValue(QStringLiteral(":tag_id"), tagId);

  if (!find.exec()) {
    qWarning() << "Failed to query manual project lookup:"
               << find.lastError().text();
    return -1;
  }

  if (find.next()) return find.value(0).toInt();

  if (!createProject(normalizedName, QString(), tagId, color)) return -1;

  find.bindValue(QStringLiteral(":name"), normalizedName);
  find.bindValue(QStringLiteral(":tag_id"), tagId);
  if (!find.exec()) {
    qWarning() << "Failed to re-query manual project after insert:"
               << find.lastError().text();
    return -1;
  }

  return find.next() ? find.value(0).toInt() : -1;
}

QVariantList ManualProjectRepository::getActiveProjects() {
  QVariantList projects;
  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return projects;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    p.id,
    p.name,
    p.description,
    p.tag_id,
    p.color,
    p.total_duration_sec,
    p.is_archived,
    p.created_at,
    p.updated_at,
    COALESCE(t.name, '') AS tag_name
FROM manual_projects p
LEFT JOIN tags t ON t.id = p.tag_id
WHERE p.is_archived = 0
ORDER BY p.updated_at DESC, p.created_at DESC;
)SQL"))) {
    qWarning() << "Failed to prepare getActiveProjects:"
               << query.lastError().text();
    return projects;
  }

  if (!query.exec()) {
    qWarning() << "Failed to query active manual projects:"
               << query.lastError().text();
    return projects;
  }

  while (query.next()) {
    projects.append(projectMapFromQuery(query));
  }

  return projects;
}

QVariantMap ManualProjectRepository::getProjectById(int projectId) {
  if (!validateProjectId(projectId)) return QVariantMap();

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return QVariantMap();

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    p.id,
    p.name,
    p.description,
    p.tag_id,
    p.color,
    p.total_duration_sec,
    p.is_archived,
    p.created_at,
    p.updated_at,
    COALESCE(t.name, '') AS tag_name
FROM manual_projects p
LEFT JOIN tags t ON t.id = p.tag_id
WHERE p.id = :id
LIMIT 1;
)SQL"))) {
    qWarning() << "Failed to prepare getProjectById:"
               << query.lastError().text();
    return QVariantMap();
  }

  query.bindValue(QStringLiteral(":id"), projectId);

  if (!query.exec()) {
    qWarning() << "Failed to query manual project by id:"
               << query.lastError().text();
    return QVariantMap();
  }

  if (!query.next()) return QVariantMap();
  return projectMapFromQuery(query);
}

QVariantMap ManualProjectRepository::getActiveProjectByName(
    const QString& name) {
  const QString normalizedName = name.trimmed();
  if (normalizedName.isEmpty()) return QVariantMap();

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return QVariantMap();

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    p.id,
    p.name,
    p.description,
    p.tag_id,
    p.color,
    p.total_duration_sec,
    p.is_archived,
    p.created_at,
    p.updated_at,
    COALESCE(t.name, '') AS tag_name
FROM manual_projects p
LEFT JOIN tags t ON t.id = p.tag_id
WHERE p.name = :name
  AND p.is_archived = 0
ORDER BY p.updated_at DESC, p.created_at DESC
LIMIT 1;
)SQL"))) {
    qWarning() << "Failed to prepare getActiveProjectByName:"
               << query.lastError().text();
    return QVariantMap();
  }

  query.bindValue(QStringLiteral(":name"), normalizedName);

  if (!query.exec()) {
    qWarning() << "Failed to query active manual project by name:"
               << query.lastError().text();
    return QVariantMap();
  }

  if (!query.next()) return QVariantMap();
  return projectMapFromQuery(query);
}

bool ManualProjectRepository::archiveProject(int projectId) {
  if (!validateProjectId(projectId)) return false;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;

  const qint64 now = QDateTime::currentSecsSinceEpoch();

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
UPDATE manual_projects
SET is_archived = 1,
    updated_at = :updated_at
WHERE id = :id;
)SQL"))) {
    qWarning() << "Failed to prepare archiveProject:"
               << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":id"), projectId);
  query.bindValue(QStringLiteral(":updated_at"), now);

  if (!query.exec()) {
    qWarning() << "Failed to archive manual project:"
               << query.lastError().text();
    return false;
  }

  if (query.numRowsAffected() <= 0) {
    qWarning() << "No manual project archived for id:" << projectId;
    return false;
  }

  return true;
}

bool ManualProjectRepository::addManualSession(int projectId,
                                               qint64 startUnixSec,
                                               qint64 endUnixSec,
                                               int durationSec,
                                               const QString& note) {
  Q_UNUSED(durationSec)

  if (!validateProjectId(projectId)) return false;
  if (!validateRange(startUnixSec, endUnixSec)) return false;
  if (endUnixSec - startUnixSec > std::numeric_limits<int>::max()) {
    qWarning() << "Manual session duration is too large:" << startUnixSec
               << endUnixSec;
    return false;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;
  if (!projectExists(db, projectId)) return false;
  if (sessionExists(db, projectId, startUnixSec, endUnixSec, note)) {
    return true;
  }

  const int correctedDurationSec =
      static_cast<int>(endUnixSec - startUnixSec);
  const qint64 now = QDateTime::currentSecsSinceEpoch();

  if (!db.transaction()) {
    qWarning() << "Failed to start manual session transaction:"
               << db.lastError().text();
    return false;
  }

  QSqlQuery insertSession(db);
  if (!insertSession.prepare(QStringLiteral(R"SQL(
INSERT INTO manual_sessions (
    project_id,
    start_unix_sec,
    end_unix_sec,
    duration_sec,
    note,
    created_at
) VALUES (
    :project_id,
    :start_unix_sec,
    :end_unix_sec,
    :duration_sec,
    :note,
    :created_at
);
)SQL"))) {
    qWarning() << "Failed to prepare addManualSession:"
               << insertSession.lastError().text();
    db.rollback();
    return false;
  }

  insertSession.bindValue(QStringLiteral(":project_id"), projectId);
  insertSession.bindValue(QStringLiteral(":start_unix_sec"), startUnixSec);
  insertSession.bindValue(QStringLiteral(":end_unix_sec"), endUnixSec);
  insertSession.bindValue(QStringLiteral(":duration_sec"),
                          correctedDurationSec);
  insertSession.bindValue(QStringLiteral(":note"), note);
  insertSession.bindValue(QStringLiteral(":created_at"), now);

  if (!insertSession.exec()) {
    qWarning() << "Failed to insert manual session:"
               << insertSession.lastError().text();
    db.rollback();
    return false;
  }

  QSqlQuery updateProject(db);
  if (!updateProject.prepare(QStringLiteral(R"SQL(
UPDATE manual_projects
SET total_duration_sec = total_duration_sec + :duration_sec,
    updated_at = :updated_at
WHERE id = :project_id;
)SQL"))) {
    qWarning() << "Failed to prepare manual project duration update:"
               << updateProject.lastError().text();
    db.rollback();
    return false;
  }

  updateProject.bindValue(QStringLiteral(":duration_sec"),
                          correctedDurationSec);
  updateProject.bindValue(QStringLiteral(":updated_at"), now);
  updateProject.bindValue(QStringLiteral(":project_id"), projectId);

  if (!updateProject.exec()) {
    qWarning() << "Failed to update manual project duration:"
               << updateProject.lastError().text();
    db.rollback();
    return false;
  }

  if (updateProject.numRowsAffected() <= 0) {
    qWarning() << "No manual project updated for session:" << projectId;
    db.rollback();
    return false;
  }

  if (!db.commit()) {
    qWarning() << "Failed to commit manual session transaction:"
               << db.lastError().text();
    db.rollback();
    return false;
  }

  return true;
}

bool ManualProjectRepository::addManualSessionEntry(
    int projectId,
    qint64 startUnixSec,
    qint64 endUnixSec,
    int durationSec,
    const QString& displayName,
    const QString& source,
    const QString& linkedProjectName) {
  return addManualSession(projectId, startUnixSec, endUnixSec, durationSec,
                          metadataNote(displayName, source, linkedProjectName));
}

QVariantList ManualProjectRepository::getSessionsByProject(int projectId) {
  QVariantList sessions;
  if (!validateProjectId(projectId)) return sessions;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return sessions;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    id,
    project_id,
    start_unix_sec,
    end_unix_sec,
    duration_sec,
    note,
    created_at
FROM manual_sessions
WHERE project_id = :project_id
ORDER BY start_unix_sec DESC;
)SQL"))) {
    qWarning() << "Failed to prepare getSessionsByProject:"
               << query.lastError().text();
    return sessions;
  }

  query.bindValue(QStringLiteral(":project_id"), projectId);

  if (!query.exec()) {
    qWarning() << "Failed to query manual sessions by project:"
               << query.lastError().text();
    return sessions;
  }

  while (query.next()) {
    QVariantMap session;
    const int durationSec = query.value(4).toInt();
    session.insert(QStringLiteral("id"), query.value(0).toInt());
    session.insert(QStringLiteral("projectId"), query.value(1).toInt());
    session.insert(QStringLiteral("startUnixSec"), query.value(2).toLongLong());
    session.insert(QStringLiteral("endUnixSec"), query.value(3).toLongLong());
    session.insert(QStringLiteral("durationSec"), durationSec);
    session.insert(QStringLiteral("durationText"), formatDuration(durationSec));
    session.insert(QStringLiteral("note"), query.value(5).toString());
    session.insert(QStringLiteral("createdAt"), query.value(6).toLongLong());
    sessions.append(session);
  }

  return sessions;
}

QVariantList ManualProjectRepository::getSessionsByRange(qint64 startUnixSec,
                                                         qint64 endUnixSec) {
  QVariantList sessions;
  if (!validateRange(startUnixSec, endUnixSec)) return sessions;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return sessions;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    s.id,
    s.project_id,
    s.start_unix_sec,
    s.end_unix_sec,
    s.duration_sec,
    s.note,
    s.created_at,
    p.name,
    COALESCE(t.name, '') AS tag_name
FROM manual_sessions s
JOIN manual_projects p ON p.id = s.project_id
LEFT JOIN tags t ON t.id = p.tag_id
WHERE s.start_unix_sec < :end_unix_sec
  AND s.end_unix_sec > :start_unix_sec
ORDER BY s.start_unix_sec DESC;
)SQL"))) {
    qWarning() << "Failed to prepare getSessionsByRange:"
               << query.lastError().text();
    return sessions;
  }

  query.bindValue(QStringLiteral(":start_unix_sec"), startUnixSec);
  query.bindValue(QStringLiteral(":end_unix_sec"), endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query manual sessions by range:"
               << query.lastError().text();
    return sessions;
  }

  while (query.next()) {
    sessions.append(sessionMapFromQuery(query));
  }

  return sessions;
}

QVariantList ManualProjectRepository::getProjectRankingByRange(
    qint64 startUnixSec,
    qint64 endUnixSec) {
  QVariantList ranking;
  if (!validateRange(startUnixSec, endUnixSec)) return ranking;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return ranking;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    p.id,
    p.name,
    p.description,
    p.tag_id,
    p.color,
    SUM(s.duration_sec) AS total_duration_sec,
    p.is_archived,
    p.created_at,
    p.updated_at,
    COALESCE(t.name, '') AS tag_name
FROM manual_sessions s
JOIN manual_projects p ON p.id = s.project_id
LEFT JOIN tags t ON t.id = p.tag_id
WHERE s.start_unix_sec < :end_unix_sec
  AND s.end_unix_sec > :start_unix_sec
GROUP BY
    p.id,
    p.name,
    p.description,
    p.tag_id,
    p.color,
    p.is_archived,
    p.created_at,
    p.updated_at,
    t.name
HAVING total_duration_sec > 0
ORDER BY total_duration_sec DESC;
)SQL"))) {
    qWarning() << "Failed to prepare getProjectRankingByRange:"
               << query.lastError().text();
    return ranking;
  }

  query.bindValue(QStringLiteral(":start_unix_sec"), startUnixSec);
  query.bindValue(QStringLiteral(":end_unix_sec"), endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query project ranking by range:"
               << query.lastError().text();
    return ranking;
  }

  while (query.next()) {
    ranking.append(projectMapFromQuery(query));
  }

  return ranking;
}

int ManualProjectRepository::getTotalManualSecondsByRange(qint64 startUnixSec,
                                                          qint64 endUnixSec) {
  if (!validateRange(startUnixSec, endUnixSec)) return 0;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return 0;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT COALESCE(SUM(duration_sec), 0)
FROM manual_sessions
WHERE start_unix_sec < :end_unix_sec
  AND end_unix_sec > :start_unix_sec;
)SQL"))) {
    qWarning() << "Failed to prepare getTotalManualSecondsByRange:"
               << query.lastError().text();
    return 0;
  }

  query.bindValue(QStringLiteral(":start_unix_sec"), startUnixSec);
  query.bindValue(QStringLiteral(":end_unix_sec"), endUnixSec);

  if (!query.exec()) {
    qWarning() << "Failed to query total manual project seconds:"
               << query.lastError().text();
    return 0;
  }

  if (!query.next()) return 0;
  return query.value(0).toInt();
}

QVariantList ManualProjectRepository::getTodayProjectRanking() {
  const qint64 startUnixSec =
      QDateTime::currentDateTime().date().startOfDay().toSecsSinceEpoch();
  const qint64 endUnixSec = startUnixSec + 24 * 60 * 60;
  return getProjectRankingByRange(startUnixSec, endUnixSec);
}
