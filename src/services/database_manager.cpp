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
#include <QUrl>
#include <QVariant>
#include <QVector>

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

// Accept either a plain filesystem path or a file:// URL (the QML FileDialog
// hands back file:// URLs). Returns a local filesystem path.
QString toLocalPath(const QString& pathOrUrl) {
  const QString trimmed = pathOrUrl.trimmed();
  if (trimmed.isEmpty()) return trimmed;
  const QUrl url(trimmed);
  if (url.isLocalFile()) return url.toLocalFile();
  return trimmed;
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

  // 3. Parse JSONL once, staging EVERY valid record (deduped by unique key) +
  //    apps. We deliberately do NOT pre-filter on a MIN(start) watermark: audio
  //    sessions can finalize out of start order (concurrent apps close at
  //    different times), so a start-based threshold could silently skip a real
  //    enable-before record that straddles the boundary. Instead we stage all,
  //    let INSERT OR IGNORE absorb rows the service already wrote (the unique
  //    indexes dedup them as no-ops), and let the existence-based reconcile in
  //    step 6 be the authoritative "every JSONL record is in the DB" guard
  //    (kickoff §6). Cost is one bounded full-JSONL pass on the single migration.
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
    qInfo() << "Backfill: no usage records to import (empty/absent JSONL).";
    return setBackfillDone();
  }

  // 4. Backup JSONL before touching anything (rules/03 D1).
  const QString bakPath = jsonlPath + QStringLiteral(".bak");
  if (QFile::exists(bakPath)) QFile::remove(bakPath);
  if (!QFile::copy(jsonlPath, bakPath)) {
    qWarning() << "Backfill aborted: failed to write backup" << bakPath;
    return false;
  }

  // 5. Import inside a transaction (BEGIN IMMEDIATE for WAL: take the write
  //    lock up front, busy_timeout already configured). INSERT OR IGNORE makes
  //    rows the service already wrote no-ops; the service may dual-write
  //    concurrently (it only writes new sessions, which either dedup or are
  //    fresh keys), and busy_timeout covers the one-time lock window.
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

  // 6. Reconcile by unique-key EXISTENCE (never row-count: INSERT OR IGNORE
  //    dedup makes counts legitimately differ). Every staged JSONL record must
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

  qInfo() << "Backfill complete: inserted" << insertedFront
          << "new frontmost +" << insertedMedia << "new media rows ("
          << frontByKey.size() << "/" << mediaByKey.size()
          << "unique keys staged & reconciled). Backup at" << bakPath;
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

// ---------------------------------------------------------------------------
// D1: whole-DB backup / inspect / restore. All logic folded into this already
// app-registered translation unit so no frozen CMake / no new .cpp (kickoff §3).
// No UsageStatManager symbols are referenced (db_smoke links this file but not
// USM). Honest failure throughout: empty string / false + qWarning, never a
// faked success (G6).
// ---------------------------------------------------------------------------

QString DatabaseManager::backupDatabase(const QString& destPath) {
  const QString src = databasePath();
  if (src.isEmpty()) {
    qWarning() << "backupDatabase: cannot resolve live database path.";
    return QString();
  }

  // Resolve destination. Empty -> auto-name in the Download->Documents->AppData
  // cascade (mirrors UsageStatManager::exportReport; reimplemented here so this
  // file stays free of USM symbols). Non-empty -> use it verbatim (tests pass a
  // temp path).
  QString dst = toLocalPath(destPath);
  if (dst.isEmpty()) {
    QString dir =
        QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (dir.isEmpty())
      dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (dir.isEmpty())
      dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (dir.isEmpty()) {
      qWarning() << "backupDatabase: no writable target directory.";
      return QString();
    }
    const QString stamp =
        QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss"));
    dst = QDir(dir).filePath(QStringLiteral("timearc-backup-") + stamp +
                             QStringLiteral(".db"));
  }

  // Ensure the parent directory exists.
  const QFileInfo dstInfo(dst);
  QDir dstDir(dstInfo.absolutePath());
  if (!dstDir.exists() && !dstDir.mkpath(QStringLiteral("."))) {
    qWarning() << "backupDatabase: cannot create target directory:"
               << dstDir.absolutePath();
    return QString();
  }

  // VACUUM INTO requires the target file to NOT already exist.
  if (QFile::exists(dst) && !QFile::remove(dst)) {
    qWarning() << "backupDatabase: target exists and cannot be removed:" << dst;
    return QString();
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) {
    qWarning() << "backupDatabase: live database is not open.";
    return QString();
  }

  // VACUUM INTO takes the destination as a SQL string LITERAL (no bind support),
  // so escape single quotes by doubling them. Windows backslashes are literal in
  // a SQLite string literal and need no escaping.
  QString literal = dst;
  literal.replace(QLatin1Char('\''), QStringLiteral("''"));
  QSqlQuery q(db);
  if (!q.exec(QStringLiteral("VACUUM INTO '") + literal + QStringLiteral("';"))) {
    qWarning() << "backupDatabase: VACUUM INTO failed:" << q.lastError().text();
    return QString();
  }

  // Confirm the artifact really landed before claiming success.
  const QFileInfo out(dst);
  if (!out.exists() || out.size() <= 0) {
    qWarning() << "backupDatabase: artifact missing or empty after VACUUM:"
               << dst;
    return QString();
  }
  qInfo().noquote() << "backupDatabase: wrote" << dst;
  return dst;
}

QVariantMap DatabaseManager::inspectBackup(const QString& path) const {
  QVariantMap result;
  result[QStringLiteral("ok")] = false;
  result[QStringLiteral("integrity")] = QString();
  result[QStringLiteral("frontmostRows")] = 0;
  result[QStringLiteral("mediaRows")] = 0;
  result[QStringLiteral("appRows")] = 0;
  result[QStringLiteral("minUnixSec")] = 0;
  result[QStringLiteral("maxUnixSec")] = 0;
  result[QStringLiteral("sizeBytes")] = 0;
  result[QStringLiteral("error")] = QString();

  const QString local = toLocalPath(path);
  if (local.isEmpty()) {
    result[QStringLiteral("error")] = QStringLiteral("空路径");
    return result;
  }
  const QFileInfo info(local);
  if (!info.exists() || info.size() <= 0) {
    result[QStringLiteral("error")] = QStringLiteral("文件不存在或为空");
    return result;
  }
  result[QStringLiteral("sizeBytes")] = static_cast<qlonglong>(info.size());

  // Unique throwaway connection name so concurrent / repeated calls never clash.
  static int counter = 0;
  const QString connName =
      QStringLiteral("timearc_inspect_") + QString::number(++counter);

  bool ok = false;
  QString errorText;
  QString integrity;
  qlonglong frontRows = 0, mediaRows = 0, appRows = 0, minUnix = 0, maxUnix = 0;

  // Scope every QSqlDatabase / QSqlQuery local INSIDE this block so they are all
  // destroyed before removeDatabase(), else Qt warns "connection still in use".
  {
    QSqlDatabase db =
        QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connName);
    db.setDatabaseName(local);
    db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
    if (!db.open()) {
      errorText = QStringLiteral("无法打开数据库：") + db.lastError().text();
    } else {
      // 1. integrity_check — first row must be exactly "ok".
      QSqlQuery iq(db);
      if (iq.exec(QStringLiteral("PRAGMA integrity_check;")) && iq.next()) {
        integrity = iq.value(0).toString();
      } else {
        integrity = QStringLiteral("(检查失败)");
      }

      // 2. assert the three contract tables exist (reject random / foreign .db).
      bool hasAll = true;
      const QStringList required = {QStringLiteral("apps"),
                                    QStringLiteral("frontmost_sessions"),
                                    QStringLiteral("media_sessions")};
      for (const QString& t : required) {
        QSqlQuery tq(db);
        tq.prepare(QStringLiteral("SELECT 1 FROM sqlite_master WHERE "
                                  "type='table' AND name=:n LIMIT 1;"));
        tq.bindValue(QStringLiteral(":n"), t);
        if (!tq.exec() || !tq.next()) {
          hasAll = false;
          break;
        }
      }

      if (integrity != QStringLiteral("ok")) {
        errorText = QStringLiteral("完整性检查未通过：") + integrity;
      } else if (!hasAll) {
        errorText = QStringLiteral("不是 TimeArc 数据库（缺少契约表）");
      } else {
        // 3. row counts + start_unix_sec range across both session tables.
        QSqlQuery cq(db);
        if (cq.exec(QStringLiteral(
                "SELECT COUNT(*) FROM frontmost_sessions;")) &&
            cq.next())
          frontRows = cq.value(0).toLongLong();
        if (cq.exec(QStringLiteral("SELECT COUNT(*) FROM media_sessions;")) &&
            cq.next())
          mediaRows = cq.value(0).toLongLong();
        if (cq.exec(QStringLiteral("SELECT COUNT(*) FROM apps;")) && cq.next())
          appRows = cq.value(0).toLongLong();
        if (cq.exec(QStringLiteral(
                "SELECT MIN(start_unix_sec), MAX(start_unix_sec) FROM "
                "(SELECT start_unix_sec FROM frontmost_sessions "
                "UNION ALL SELECT start_unix_sec FROM media_sessions);")) &&
            cq.next()) {
          minUnix = cq.value(0).toLongLong();
          maxUnix = cq.value(1).toLongLong();
        }
        ok = true;
      }
      db.close();
    }
  }
  QSqlDatabase::removeDatabase(connName);

  result[QStringLiteral("ok")] = ok;
  result[QStringLiteral("integrity")] = integrity;
  result[QStringLiteral("frontmostRows")] = frontRows;
  result[QStringLiteral("mediaRows")] = mediaRows;
  result[QStringLiteral("appRows")] = appRows;
  result[QStringLiteral("minUnixSec")] = minUnix;
  result[QStringLiteral("maxUnixSec")] = maxUnix;
  if (!ok && errorText.isEmpty()) errorText = QStringLiteral("未知错误");
  result[QStringLiteral("error")] = errorText;
  return result;
}

bool DatabaseManager::restoreDatabase(const QString& sourcePath) {
  const QString source = toLocalPath(sourcePath);
  if (source.isEmpty()) {
    qWarning() << "restoreDatabase: empty source path.";
    return false;
  }

  // 1. Validate the candidate first — never overwrite the live DB with junk.
  const QVariantMap info = inspectBackup(source);
  if (!info.value(QStringLiteral("ok")).toBool()) {
    qWarning().noquote() << "restoreDatabase: candidate rejected:"
                         << info.value(QStringLiteral("error")).toString();
    return false;
  }

  const QString dbPath = databasePath();
  if (dbPath.isEmpty()) {
    qWarning() << "restoreDatabase: cannot resolve live database path.";
    return false;
  }
  // Restoring a file onto itself is a no-op error.
  if (QFileInfo(source).absoluteFilePath() ==
      QFileInfo(dbPath).absoluteFilePath()) {
    qWarning() << "restoreDatabase: source is the live database; nothing to do.";
    return false;
  }

  // 2. Back up the current DB so a failed swap can roll back (rules/03 D1).
  const QString preBak = dbPath + QStringLiteral(".pre-restore.bak");
  if (QFile::exists(preBak) && !QFile::remove(preBak)) {
    qWarning() << "restoreDatabase: cannot clear old pre-restore backup:"
               << preBak;
    return false;
  }
  if (QFile::exists(dbPath) && !QFile::copy(dbPath, preBak)) {
    qWarning() << "restoreDatabase: cannot create pre-restore backup; aborting.";
    return false;
  }

  // Reopen + reconfigure the live connection in-process (best effort).
  auto reopen = [this]() {
    if (openDatabase()) configureDatabase();
  };

  // 3. Release the UI's handle so the file can be replaced.
  database().close();
  QSqlDatabase::removeDatabase(kConnectionName);

  // 4. Remove the live DB + stale WAL side files. A remove failure means the
  //    file is still locked (background collection running) -> reopen original,
  //    keep the untouched pre-restore copy, and report honestly.
  bool removed = true;
  if (QFile::exists(dbPath) && !QFile::remove(dbPath)) removed = false;
  if (!removed) {
    qWarning() << "restoreDatabase: live DB is locked (background collection "
                  "running?). Original kept; aborting restore.";
    reopen();
    return false;
  }
  QFile::remove(dbPath + QStringLiteral("-wal"));
  QFile::remove(dbPath + QStringLiteral("-shm"));

  // 5. Copy the validated backup into place. On failure, roll back.
  if (!QFile::copy(source, dbPath)) {
    qWarning() << "restoreDatabase: failed to copy backup into place; rolling "
                  "back to pre-restore copy.";
    QFile::remove(dbPath);
    if (QFile::exists(preBak)) QFile::copy(preBak, dbPath);
    reopen();
    return false;
  }

  // 6. Reopen the freshly restored DB in-process; announce so the UI can prompt
  //    a restart. If reopen fails, roll back to the pre-restore copy.
  if (!openDatabase() || !configureDatabase()) {
    qWarning() << "restoreDatabase: copied backup but failed to reopen; rolling "
                  "back.";
    database().close();
    QSqlDatabase::removeDatabase(kConnectionName);
    QFile::remove(dbPath);
    if (QFile::exists(preBak)) QFile::copy(preBak, dbPath);
    reopen();
    return false;
  }

  qInfo().noquote() << "restoreDatabase: restored from" << source;
  emit databaseRestored();
  return true;
}
