#include "services/database_manager.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QList>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QVariant>
#include <QVector>

#include <limits>

namespace {

const QString kConnectionName = QStringLiteral("timearc");
const QString kDatabaseFileName = QStringLiteral("timearc.db");

// A1 risk guard: the Windows service builds its DB path from raw getenv(APPDATA)
// (usage_storage.c make_db_path -> %APPDATA%\TimeArc\TimeArc\timearc.db) while
// the UI uses QStandardPaths::AppDataLocation. They are two independent
// constructions that only happen to agree by convention. If they ever diverge
// (renamed org/app, redirected env) the UI would silently read a different DB
// than the service writes. Warn once so the split-brain is visible rather than
// a silent "no data" symptom. Test mode deliberately relocates AppData, so this
// is expected to differ there and is skipped.
void warnIfDbPathDivergesFromService(const QString& uiPath) {
  static bool checked = false;
  if (checked) return;
  checked = true;
  if (QStandardPaths::isTestModeEnabled()) return;

  QString base = qEnvironmentVariable("APPDATA");
  if (base.trimmed().isEmpty()) base = qEnvironmentVariable("LOCALAPPDATA");
  if (base.trimmed().isEmpty()) return;

  const QString servicePath = QDir::cleanPath(
      QDir(base).filePath(QStringLiteral("TimeArc/TimeArc/timearc.db")));
  const QString uiClean = QDir::cleanPath(uiPath);
  if (uiClean.compare(servicePath, Qt::CaseInsensitive) != 0) {
    qWarning().noquote()
        << "DatabaseManager: UI DB path differs from the Windows service "
           "convention. UI reads:"
        << uiClean << "; service writes:" << servicePath
        << "- SQLite history reads and service writes may target different "
           "files (A1 path-identity risk).";
  }
}

}  // namespace

DatabaseManager::DatabaseManager(QObject* parent) : QObject(parent) {}

bool DatabaseManager::initialize() {
  if (!openDatabase()) return false;
  if (!configureDatabase()) return false;
  if (!createTables()) return false;
  if (!insertDefaultTags()) return false;
  if (!insertDefaultSettings()) return false;
  if (!createIndexes()) return false;

  return true;
}

bool DatabaseManager::configureDatabase() {
  return executeQuery(QStringLiteral("PRAGMA foreign_keys = ON;")) &&
         executeQuery(QStringLiteral("PRAGMA busy_timeout = 5000;")) &&
         executeQuery(QStringLiteral("PRAGMA journal_mode = WAL;"));
}

QSqlDatabase DatabaseManager::database() const {
  return QSqlDatabase::database(kConnectionName);
}

QString DatabaseManager::getDatabasePath() const { return databasePath(); }

QString DatabaseManager::databasePath() const {
  const QString appDataLocation =
      QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
  if (appDataLocation.isEmpty()) return QString();

  return QDir(appDataLocation).filePath(kDatabaseFileName);
}

bool DatabaseManager::openDatabase() {
  const QString path = databasePath();
  if (path.isEmpty()) {
    qWarning() << "Unable to resolve database path.";
    return false;
  }

  const QFileInfo databaseFile(path);
  QDir databaseDir(databaseFile.absolutePath());
  if (!databaseDir.exists() && !databaseDir.mkpath(QStringLiteral("."))) {
    qWarning() << "Unable to create database directory:"
               << databaseDir.absolutePath();
    return false;
  }

  QSqlDatabase db;
  if (QSqlDatabase::contains(kConnectionName)) {
    db = QSqlDatabase::database(kConnectionName);
  } else {
    db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), kConnectionName);
  }

  db.setDatabaseName(path);

  if (!db.open()) {
    qWarning() << "Unable to open SQLite database:" << path
               << db.lastError().text();
    return false;
  }

  warnIfDbPathDivergesFromService(path);
  return true;
}

bool DatabaseManager::createTables() {
  return executeQuery(QStringLiteral(R"SQL(
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    applied_at INTEGER NOT NULL
);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE TABLE IF NOT EXISTS apps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_identifier TEXT NOT NULL UNIQUE,
    app_name TEXT NOT NULL,
    display_name TEXT,
    app_icon_path TEXT,
    executable_path TEXT,
    platform TEXT DEFAULT 'windows',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE TABLE IF NOT EXISTS frontmost_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_identifier TEXT NOT NULL,
    window_title TEXT,
    start_unix_sec INTEGER NOT NULL,
    end_unix_sec INTEGER NOT NULL,
    duration_sec INTEGER NOT NULL,
    active_sec INTEGER NOT NULL,
    idle_sec INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL
);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE TABLE IF NOT EXISTS media_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_identifier TEXT NOT NULL,
    media_type TEXT NOT NULL,
    media_title TEXT,
    start_unix_sec INTEGER NOT NULL,
    end_unix_sec INTEGER NOT NULL,
    playback_sec INTEGER NOT NULL,
    created_at INTEGER NOT NULL
);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    color TEXT NOT NULL,
    icon TEXT,
    created_at INTEGER NOT NULL
);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER NOT NULL
);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE TABLE IF NOT EXISTS manual_projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    tag_id INTEGER,
    color TEXT,
    total_duration_sec INTEGER DEFAULT 0,
    is_archived INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE TABLE IF NOT EXISTS manual_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    start_unix_sec INTEGER NOT NULL,
    end_unix_sec INTEGER NOT NULL,
    duration_sec INTEGER NOT NULL,
    note TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY(project_id) REFERENCES manual_projects(id)
);
)SQL"));
}

bool DatabaseManager::insertDefaultTags() {
  struct DefaultTag {
    const char* name;
    const char* color;
  };

  const DefaultTag defaultTags[] = {
      {"学习", "#B7A6F0"}, {"工作", "#D7B79A"},
      {"运动", "#B4C986"}, {"娱乐", "#DFA65F"},
      {"阅读", "#A9BFE6"}, {"社交", "#C7ADD9"},
      {"生活", "#E2B6C3"}, {"其他", "#B7AEA6"},
  };

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) {
    qWarning() << "Database is not open.";
    return false;
  }

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
INSERT OR IGNORE INTO tags (
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
    qWarning() << "Failed to prepare default tag insert:"
               << query.lastError().text();
    return false;
  }

  const qint64 now = QDateTime::currentSecsSinceEpoch();
  for (const DefaultTag& tag : defaultTags) {
    query.bindValue(QStringLiteral(":name"), QString::fromUtf8(tag.name));
    query.bindValue(QStringLiteral(":color"), QString::fromUtf8(tag.color));
    query.bindValue(QStringLiteral(":icon"), QVariant());
    query.bindValue(QStringLiteral(":created_at"), now);

    if (!query.exec()) {
      qWarning() << "Failed to insert default tag:" << tag.name
                 << query.lastError().text();
      return false;
    }
  }

  return true;
}

bool DatabaseManager::insertDefaultSettings() {
  struct DefaultSetting {
    const char* key;
    const char* value;
  };

  const DefaultSetting defaultSettings[] = {
      {"current_theme", "warm_pastel"},
      {"first_launch", "true"},
  };

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) {
    qWarning() << "Database is not open.";
    return false;
  }

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
INSERT OR IGNORE INTO settings (
    key,
    value,
    updated_at
) VALUES (
    :key,
    :value,
    :updated_at
);
)SQL"))) {
    qWarning() << "Failed to prepare default setting insert:"
               << query.lastError().text();
    return false;
  }

  const qint64 now = QDateTime::currentSecsSinceEpoch();
  for (const DefaultSetting& setting : defaultSettings) {
    query.bindValue(QStringLiteral(":key"), QString::fromUtf8(setting.key));
    query.bindValue(QStringLiteral(":value"), QString::fromUtf8(setting.value));
    query.bindValue(QStringLiteral(":updated_at"), now);

    if (!query.exec()) {
      qWarning() << "Failed to insert default setting:" << setting.key
                 << query.lastError().text();
      return false;
    }
  }

  return true;
}

bool DatabaseManager::createIndexes() {
  return executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_frontmost_time
ON frontmost_sessions(start_unix_sec, end_unix_sec);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_frontmost_app
ON frontmost_sessions(app_identifier);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE UNIQUE INDEX IF NOT EXISTS idx_frontmost_unique_record
ON frontmost_sessions(app_identifier, window_title, start_unix_sec, end_unix_sec);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_media_time
ON media_sessions(start_unix_sec, end_unix_sec);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_media_app
ON media_sessions(app_identifier);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE UNIQUE INDEX IF NOT EXISTS idx_media_unique_record
ON media_sessions(app_identifier, media_type, media_title, start_unix_sec, end_unix_sec);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_apps_identifier
ON apps(app_identifier);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_manual_sessions_project
ON manual_sessions(project_id);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_manual_sessions_time
ON manual_sessions(start_unix_sec, end_unix_sec);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_manual_projects_archived
ON manual_projects(is_archived);
)SQL"));
}

bool DatabaseManager::executeQuery(const QString& sql) {
  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) {
    qWarning() << "Database is not open.";
    return false;
  }

  QSqlQuery query(db);
  if (!query.exec(sql)) {
    qWarning() << "SQL execution failed:" << query.lastError().text()
               << "SQL:" << sql;
    return false;
  }

  return true;
}

namespace {

// A1 S3 backfill helpers. Kept self-contained in the database layer
// (TIME_ARC_DATABASE_SOURCES) with NO UsageStatManager symbols, so db_smoke
// still links. Field mapping mirrors the service write path
// (usage_storage.c timearc_storage_write_sqlite) so backfilled rows are
// byte-identical to what the dual-write would have produced.

const QString kBackfillFlagKey =
    QStringLiteral("usage_jsonl_backfill_v1_done");

QString backfillJsonlPath() {
  // Must match the service + UsageStatManager usage dir (env-based, NOT
  // QStandardPaths): %LOCALAPPDATA%\TimeArc\usage\usage_records.jsonl.
  QString base = qEnvironmentVariable("LOCALAPPDATA");
  if (base.trimmed().isEmpty()) base = qEnvironmentVariable("APPDATA");
  if (base.trimmed().isEmpty()) base = QDir::homePath();
  return QDir(base).filePath(
      QStringLiteral("TimeArc/usage/usage_records.jsonl"));
}

QJsonObject parseJsonlLine(const QByteArray& line) {
  QJsonParseError error;
  QJsonDocument doc = QJsonDocument::fromJson(line, &error);
  if (error.error != QJsonParseError::NoError) {
    // Tolerate older local-code-page window titles, like UsageStatManager.
    const QByteArray utf8 =
        QString::fromLocal8Bit(line.constData(), line.size()).toUtf8();
    doc = QJsonDocument::fromJson(utf8, &error);
  }
  return doc.isObject() ? doc.object() : QJsonObject();
}

QString nonEmptyOr(const QString& value, const QString& fallback) {
  return value.isEmpty() ? fallback : value;
}

qint64 jsonInt(const QJsonObject& o, const QString& key) {
  const QJsonValue v = o.value(key);
  if (v.isDouble()) return static_cast<qint64>(v.toDouble());
  if (v.isString()) return v.toString().toLongLong();
  return 0;
}

// One tail row staged for import, with the unique-key fields used by both the
// INSERT and the existence-based reconciliation.
struct BackfillRow {
  QString appIdentifier;
  QString appName;
  QString executablePath;
  QString platform;
  QString title;  // window_title (frontmost) or resolved media title (audio)
  bool isAudio = false;
  qint64 start = 0;
  qint64 end = 0;
  qint64 duration = 0;
};

QString uniqueKey(const BackfillRow& r) {
  const QChar sep(QChar(0x1f));
  return r.appIdentifier + sep + (r.isAudio ? QStringLiteral("audio") : QString()) +
         sep + r.title + sep + QString::number(r.start) + sep +
         QString::number(r.end);
}

qint64 minStart(QSqlDatabase& db, const QString& table) {
  QSqlQuery q(db);
  // table is an internal literal (frontmost_sessions/media_sessions): no taint.
  if (q.exec(QStringLiteral("SELECT MIN(start_unix_sec) FROM ") + table) &&
      q.next() && !q.value(0).isNull()) {
    return q.value(0).toLongLong();
  }
  return std::numeric_limits<qint64>::max();  // empty/unknown -> import all
}

}  // namespace

bool DatabaseManager::backfillUsageFromJsonl() {
  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) {
    qWarning() << "Backfill skipped: database is not open.";
    return false;
  }

  // 1. Idempotency: already migrated -> skip.
  {
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "SELECT value FROM settings WHERE key = :key;"));
    q.bindValue(QStringLiteral(":key"), kBackfillFlagKey);
    if (q.exec() && q.next() &&
        q.value(0).toString() == QStringLiteral("true")) {
      return true;  // done in a previous launch
    }
  }

  // 2. Resolve JSONL; nothing on disk -> nothing to backfill, mark done.
  const QString jsonlPath = backfillJsonlPath();
  if (!QFileInfo::exists(jsonlPath)) {
    qInfo() << "Backfill: no JSONL at" << jsonlPath << "- nothing to import.";
    return setBackfillDone();
  }

  // 3. Per-source thresholds: import only the enable-before tail (start <
  //    earliest SQLite row). Empty table -> max -> import all of that source.
  const qint64 frontThreshold = minStart(db, QStringLiteral("frontmost_sessions"));
  const qint64 mediaThreshold = minStart(db, QStringLiteral("media_sessions"));

  // 4. Parse JSONL once, staging the tail (deduped by unique key) + apps.
  QHash<QString, BackfillRow> frontByKey;
  QHash<QString, BackfillRow> mediaByKey;
  struct AppRow {
    QString appName;
    QString executablePath;
    QString platform;
  };
  QHash<QString, AppRow> appsByIdentifier;

  QFile in(jsonlPath);
  if (!in.open(QIODevice::ReadOnly)) {
    qWarning() << "Backfill: cannot open JSONL:" << jsonlPath;
    return false;
  }
  while (!in.atEnd()) {
    const QByteArray raw = in.readLine();
    if (!raw.endsWith('\n')) break;  // half-written tail line
    const QByteArray line = raw.trimmed();
    if (line.isEmpty()) continue;
    const QJsonObject o = parseJsonlLine(line);
    if (o.isEmpty()) continue;

    // Mirror service write_sqlite skip rules exactly.
    const QString source = o.value(QStringLiteral("source")).toString();
    const bool isForeground =
        source.isEmpty() || source == QStringLiteral("foreground");
    const bool isAudio = source == QStringLiteral("audio");
    if (!isForeground && !isAudio) continue;

    const QString appId = o.value(QStringLiteral("app_id")).toString();
    const QString path = o.value(QStringLiteral("path")).toString();
    const QString appIdentifier = nonEmptyOr(appId, path);
    if (appIdentifier.isEmpty()) continue;

    const qint64 start = jsonInt(o, QStringLiteral("start_unix_sec"));
    const qint64 duration = jsonInt(o, QStringLiteral("duration_sec"));
    if (start <= 0 || duration <= 0) continue;
    const qint64 end = start + duration;
    if (end <= start) continue;

    const qint64 threshold = isAudio ? mediaThreshold : frontThreshold;
    if (start >= threshold) continue;  // already covered by the service's rows

    const QString executablePath = nonEmptyOr(path, appIdentifier);
    QString appName = o.value(QStringLiteral("app_name")).toString();
    if (appName.isEmpty()) appName = QFileInfo(executablePath).fileName();
    if (appName.isEmpty()) appName = appIdentifier;
    const QString platform =
        nonEmptyOr(o.value(QStringLiteral("platform")).toString(),
                   QStringLiteral("windows"));
    const QString windowTitle = o.value(QStringLiteral("window_title")).toString();

    BackfillRow row;
    row.appIdentifier = appIdentifier;
    row.appName = appName;
    row.executablePath = executablePath;
    row.platform = platform;
    row.isAudio = isAudio;
    row.start = start;
    row.end = end;
    row.duration = duration;
    row.title = isAudio
                    ? (windowTitle.isEmpty() ? QStringLiteral("Audio playback")
                                             : windowTitle)
                    : windowTitle;
    (isAudio ? mediaByKey : frontByKey).insert(uniqueKey(row), row);

    if (!appsByIdentifier.contains(appIdentifier)) {
      appsByIdentifier.insert(appIdentifier,
                              {appName, executablePath, platform});
    }
  }
  in.close();

  if (frontByKey.isEmpty() && mediaByKey.isEmpty()) {
    qInfo() << "Backfill: no enable-before tail to import (heads aligned).";
    return setBackfillDone();
  }

  // 5. Backup JSONL before touching anything (rules/03 D1).
  const QString bakPath = jsonlPath + QStringLiteral(".bak");
  if (QFile::exists(bakPath)) QFile::remove(bakPath);
  if (!QFile::copy(jsonlPath, bakPath)) {
    qWarning() << "Backfill aborted: failed to write backup" << bakPath;
    return false;
  }

  // 6. Import inside a transaction (BEGIN IMMEDIATE for WAL: take the write
  //    lock up front, busy_timeout already configured). The service may be
  //    dual-writing concurrently, but only ever to start >= its own min, so the
  //    tail range (start < threshold) never collides with new service rows.
  if (!executeQuery(QStringLiteral("BEGIN IMMEDIATE;"))) {
    qWarning() << "Backfill aborted: could not begin transaction.";
    return false;
  }

  QSqlQuery appStmt(db);
  appStmt.prepare(QStringLiteral(
      "INSERT OR IGNORE INTO apps (app_identifier, app_name, display_name, "
      "app_icon_path, executable_path, platform, created_at, updated_at) "
      "VALUES (:id, :name, :name, '', :exe, :platform, :now, :now);"));
  QSqlQuery frontStmt(db);
  frontStmt.prepare(QStringLiteral(
      "INSERT OR IGNORE INTO frontmost_sessions (app_identifier, window_title, "
      "start_unix_sec, end_unix_sec, duration_sec, active_sec, idle_sec, "
      "created_at) VALUES (:id, :title, :start, :end, :dur, :dur, 0, :now);"));
  QSqlQuery mediaStmt(db);
  mediaStmt.prepare(QStringLiteral(
      "INSERT OR IGNORE INTO media_sessions (app_identifier, media_type, "
      "media_title, start_unix_sec, end_unix_sec, playback_sec, created_at) "
      "VALUES (:id, 'audio', :title, :start, :end, :dur, :now);"));

  const qint64 now = QDateTime::currentSecsSinceEpoch();
  bool ok = true;
  int insertedFront = 0;
  int insertedMedia = 0;

  for (auto it = appsByIdentifier.constBegin();
       ok && it != appsByIdentifier.constEnd(); ++it) {
    appStmt.bindValue(QStringLiteral(":id"), it.key());
    appStmt.bindValue(QStringLiteral(":name"), it.value().appName);
    appStmt.bindValue(QStringLiteral(":exe"), it.value().executablePath);
    appStmt.bindValue(QStringLiteral(":platform"), it.value().platform);
    appStmt.bindValue(QStringLiteral(":now"), now);
    if (!appStmt.exec()) {
      qWarning() << "Backfill app upsert failed:" << appStmt.lastError().text();
      ok = false;
    }
  }
  for (auto it = frontByKey.constBegin();
       ok && it != frontByKey.constEnd(); ++it) {
    const BackfillRow& r = it.value();
    frontStmt.bindValue(QStringLiteral(":id"), r.appIdentifier);
    frontStmt.bindValue(QStringLiteral(":title"), r.title);
    frontStmt.bindValue(QStringLiteral(":start"), r.start);
    frontStmt.bindValue(QStringLiteral(":end"), r.end);
    frontStmt.bindValue(QStringLiteral(":dur"), r.duration);
    frontStmt.bindValue(QStringLiteral(":now"), now);
    if (!frontStmt.exec()) {
      qWarning() << "Backfill frontmost insert failed:"
                 << frontStmt.lastError().text();
      ok = false;
    } else {
      insertedFront += frontStmt.numRowsAffected() > 0 ? 1 : 0;
    }
  }
  for (auto it = mediaByKey.constBegin();
       ok && it != mediaByKey.constEnd(); ++it) {
    const BackfillRow& r = it.value();
    mediaStmt.bindValue(QStringLiteral(":id"), r.appIdentifier);
    mediaStmt.bindValue(QStringLiteral(":title"), r.title);
    mediaStmt.bindValue(QStringLiteral(":start"), r.start);
    mediaStmt.bindValue(QStringLiteral(":end"), r.end);
    mediaStmt.bindValue(QStringLiteral(":dur"), r.duration);
    mediaStmt.bindValue(QStringLiteral(":now"), now);
    if (!mediaStmt.exec()) {
      qWarning() << "Backfill media insert failed:"
                 << mediaStmt.lastError().text();
      ok = false;
    } else {
      insertedMedia += mediaStmt.numRowsAffected() > 0 ? 1 : 0;
    }
  }

  // 7. Reconcile by unique-key EXISTENCE (never row-count: INSERT OR IGNORE
  //    dedup makes counts legitimately differ). Every staged tail record must
  //    now resolve to a row; a single miss aborts the whole migration.
  int missing = 0;
  if (ok) {
    QSqlQuery frontCheck(db);
    frontCheck.prepare(QStringLiteral(
        "SELECT 1 FROM frontmost_sessions WHERE app_identifier = :id AND "
        "window_title = :title AND start_unix_sec = :start AND "
        "end_unix_sec = :end LIMIT 1;"));
    for (auto it = frontByKey.constBegin();
         it != frontByKey.constEnd(); ++it) {
      const BackfillRow& r = it.value();
      frontCheck.bindValue(QStringLiteral(":id"), r.appIdentifier);
      frontCheck.bindValue(QStringLiteral(":title"), r.title);
      frontCheck.bindValue(QStringLiteral(":start"), r.start);
      frontCheck.bindValue(QStringLiteral(":end"), r.end);
      if (!frontCheck.exec() || !frontCheck.next()) ++missing;
    }
    QSqlQuery mediaCheck(db);
    mediaCheck.prepare(QStringLiteral(
        "SELECT 1 FROM media_sessions WHERE app_identifier = :id AND "
        "media_type = 'audio' AND media_title = :title AND "
        "start_unix_sec = :start AND end_unix_sec = :end LIMIT 1;"));
    for (auto it = mediaByKey.constBegin();
         it != mediaByKey.constEnd(); ++it) {
      const BackfillRow& r = it.value();
      mediaCheck.bindValue(QStringLiteral(":id"), r.appIdentifier);
      mediaCheck.bindValue(QStringLiteral(":title"), r.title);
      mediaCheck.bindValue(QStringLiteral(":start"), r.start);
      mediaCheck.bindValue(QStringLiteral(":end"), r.end);
      if (!mediaCheck.exec() || !mediaCheck.next()) ++missing;
    }
  }

  if (!ok || missing > 0) {
    executeQuery(QStringLiteral("ROLLBACK;"));
    qWarning() << "Backfill rolled back: ok=" << ok << "missing=" << missing
               << "- JSONL kept, flag unset, .bak retained at" << bakPath;
    return false;
  }

  if (!executeQuery(QStringLiteral("COMMIT;"))) {
    executeQuery(QStringLiteral("ROLLBACK;"));
    qWarning() << "Backfill commit failed; rolled back.";
    return false;
  }

  qInfo() << "Backfill complete: imported" << insertedFront
          << "frontmost +" << insertedMedia << "media tail rows ("
          << frontByKey.size() << "/" << mediaByKey.size()
          << "unique keys reconciled). Backup at" << bakPath;
  return setBackfillDone();
}

bool DatabaseManager::setBackfillDone() {
  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;
  QSqlQuery q(db);
  q.prepare(QStringLiteral(
      "INSERT INTO settings (key, value, updated_at) "
      "VALUES (:key, 'true', :now) "
      "ON CONFLICT(key) DO UPDATE SET value = 'true', updated_at = :now;"));
  q.bindValue(QStringLiteral(":key"), kBackfillFlagKey);
  q.bindValue(QStringLiteral(":now"), QDateTime::currentSecsSinceEpoch());
  if (!q.exec()) {
    qWarning() << "Backfill: failed to set done flag:" << q.lastError().text();
    return false;
  }
  return true;
}
