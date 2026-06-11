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
#include <QSaveFile>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QStringList>
#include <QUrl>
#include <QVariant>
#include <QVector>

namespace {

const QString kConnectionName = QStringLiteral("timearc");
const QString kDatabaseFileName = QStringLiteral("timearc.db");

// D2 (CHARTER I2 v0.3): the cross-process db-path pointer lives in
// usage_config.json in the FIXED usage dir (NOT inside the movable DB). The
// service half (usage_storage.c make_db_path) and this UI half MUST resolve the
// same file, so this mirrors the service's usage-dir construction (env-based,
// %LOCALAPPDATA%\TimeArc\usage; same base as backfillJsonlPath), NOT
// QStandardPaths. In test mode there is no service, so we keep the pointer under
// the test-mode AppData to isolate db_smoke from the real user's usage dir.
QString usageConfigDir() {
  if (QStandardPaths::isTestModeEnabled()) {
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
  }
  QString base = qEnvironmentVariable("LOCALAPPDATA");
  if (base.trimmed().isEmpty()) base = qEnvironmentVariable("APPDATA");
  if (base.trimmed().isEmpty()) base = QDir::homePath();
  return QDir(base).filePath(QStringLiteral("TimeArc/usage"));
}

QString usageConfigPath() {
  return QDir(usageConfigDir()).filePath(QStringLiteral("usage_config.json"));
}

// D2/H5: atomic read-modify-write of usage_config.json. Inserts/overwrites every
// key in `updates`, removes every key in `removeKeys`, and PRESERVES all other
// keys. Both the D2 db_path writer and the H5 idle/track writer funnel through
// this one helper, so neither can clobber the other's keys (the kickoff's #1
// risk -- made structurally impossible rather than guarded by convention).
// QSaveFile gives the atomic tmp-write + rename the disk contract requires.
// Returns false on any failure (G6 honest -- caller must not assume success).
bool mergeUsageConfig(const QJsonObject& updates, const QStringList& removeKeys) {
  const QString cfgPath = usageConfigPath();
  const QString cfgDir = QFileInfo(cfgPath).absolutePath();
  if (!QDir().mkpath(cfgDir)) {
    qWarning() << "mergeUsageConfig: cannot create usage dir:" << cfgDir;
    return false;
  }

  // Read-modify: preserve every existing key. A genuinely absent/empty file means
  // "start fresh"; a non-empty-but-UNPARSEABLE file must NOT be treated as empty,
  // or overwriting it would silently destroy the other writer's co-resident key
  // (db_path vs idle/track -- the kickoff's #1 risk). Refuse honestly (G6) so the
  // corrupt file + its keys survive for recovery; the caller (e.g. relocate) sees
  // the failure and rolls back instead of split-braining.
  QJsonObject obj;
  {
    QFile in(cfgPath);
    if (in.exists() && in.open(QIODevice::ReadOnly)) {
      const QByteArray raw = in.readAll();
      in.close();
      if (!raw.trimmed().isEmpty()) {
        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(raw, &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) {
          qWarning() << "mergeUsageConfig: refusing to overwrite unparseable "
                        "usage_config.json (preserving sibling keys for "
                        "recovery):"
                     << cfgPath;
          return false;
        }
        obj = doc.object();
      }
    }
  }
  for (const QString& k : removeKeys) obj.remove(k);
  for (auto it = updates.begin(); it != updates.end(); ++it)
    obj.insert(it.key(), it.value());

  const QByteArray bytes = QJsonDocument(obj).toJson(QJsonDocument::Indented);
  QSaveFile out(cfgPath);
  if (!out.open(QIODevice::WriteOnly)) {
    qWarning() << "mergeUsageConfig: cannot open for write:" << cfgPath;
    return false;
  }
  if (out.write(bytes) != bytes.size()) {
    out.cancelWriting();
    qWarning() << "mergeUsageConfig: short write:" << cfgPath;
    return false;
  }
  if (!out.commit()) {
    qWarning() << "mergeUsageConfig: commit failed:" << cfgPath;
    return false;
  }
  return true;
}

// Raw db_path string from usage_config.json (empty when absent / unreadable /
// malformed). No validation here -- callers decide what to do with it.
QString readConfigDbPathRaw() {
  QFile f(usageConfigPath());
  if (!f.exists() || !f.open(QIODevice::ReadOnly)) return QString();
  const QByteArray bytes = f.readAll();
  f.close();
  QJsonParseError err;
  const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
  if (err.error != QJsonParseError::NoError || !doc.isObject()) return QString();
  return doc.object().value(QStringLiteral("db_path")).toString();
}

// A directory is usable when it exists (or can be created) and a probe write
// succeeds. This is the UI mirror of the service's dir_is_writable: a vanished
// network/removable drive fails the probe and we fall back to the default path.
bool dirIsUsable(const QString& dir) {
  if (dir.trimmed().isEmpty()) return false;
  QDir d(dir);
  if (!d.exists() && !d.mkpath(QStringLiteral("."))) return false;
  const QString probe = d.filePath(QStringLiteral(".timearc_db_write_test"));
  QFile f(probe);
  if (!f.open(QIODevice::WriteOnly)) return false;
  f.close();
  f.remove();
  return true;
}

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

  // D2: when a usable db_path redirect is configured, BOTH processes read it
  // from the same usage_config.json, so the hardcoded-convention comparison no
  // longer applies -- skip it to avoid a spurious divergence warning.
  const QString raw = readConfigDbPathRaw();
  if (!raw.isEmpty() && dirIsUsable(QFileInfo(raw).absolutePath())) return;

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

QString DatabaseManager::defaultDatabasePath() const {
  const QString appDataLocation =
      QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
  if (appDataLocation.isEmpty()) return QString();

  return QDir(appDataLocation).filePath(kDatabaseFileName);
}

QString DatabaseManager::databasePath() const {
  // D2 (CHARTER I2 v0.3): a usable redirected path in usage_config.json wins;
  // otherwise fall back to the default AppData location. The Windows service
  // (usage_storage.c make_db_path) reads the SAME key with the SAME validation
  // + SAME default fallback, so the two processes never target different DB
  // files. A configured-but-unusable pointer fails safe to the default + warns.
  const QString redirected = readConfigDbPathRaw();
  if (!redirected.isEmpty()) {
    if (dirIsUsable(QFileInfo(redirected).absolutePath()))
      return QDir::cleanPath(redirected);
    qWarning().noquote()
        << "DatabaseManager: usage_config.json db_path is set but its parent is "
           "not writable; falling back to the default location. db_path ="
        << redirected;
  }
  return defaultDatabasePath();
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

// ---------------------------------------------------------------------------
// D2 S2: relocate the live DB to a user-chosen directory + flip the
// cross-process db_path pointer. Reuses the D1 primitives above (VACUUM INTO,
// inspectBackup) and the S1 pointer helpers. No UsageStatManager symbols (this
// file is in the db_smoke link domain). Honest failure + atomic ordering: snap
// + validate the NEW DB, confirm the OLD DB is unlocked, THEN switch the pointer
// and reopen; any failure rolls back to the old pointer + old DB (never
// split-brain, never a faked success -- G6).
// ---------------------------------------------------------------------------

bool DatabaseManager::writeDbPathPointer(const QString& dbPathOrEmpty) {
  // Read-modify-write via the shared helper: an empty path clears the key,
  // otherwise sets it; the H5 idle/track keys in this same file are preserved.
  if (dbPathOrEmpty.isEmpty())
    return mergeUsageConfig(QJsonObject(), {QStringLiteral("db_path")});
  QJsonObject u;
  u.insert(QStringLiteral("db_path"), QDir::cleanPath(dbPathOrEmpty));
  return mergeUsageConfig(u, QStringList());
}

bool DatabaseManager::writeServiceConfig(int idleMs, bool trackEnabled) {
  // H5 S2: write the background collector's idle-timeout (ms) + tracking on/off
  // into usage_config.json. Shares mergeUsageConfig with the D2 db_path writer,
  // so db_path is preserved untouched. idleMs <= 0 omits the key so the service
  // keeps its compile-time default (fail-safe); track_enabled is always written
  // (the user's explicit choice). Takes effect on the next collector startup --
  // restart it via SettingsRepository for immediate effect. G6: false on failure.
  QJsonObject u;
  QStringList remove;
  if (idleMs > 0)
    u.insert(QStringLiteral("idle_threshold_ms"), idleMs);
  else
    remove << QStringLiteral("idle_threshold_ms");
  u.insert(QStringLiteral("track_enabled"), trackEnabled);
  return mergeUsageConfig(u, remove);
}

QVariantMap DatabaseManager::relocateDatabaseImpl(const QString& targetDirOrUrl,
                                                  bool clearPointer) {
  QVariantMap r;
  r[QStringLiteral("ok")] = false;
  r[QStringLiteral("error")] = QString();
  r[QStringLiteral("newPath")] = QString();

  const QString targetDir = toLocalPath(targetDirOrUrl);
  if (targetDir.trimmed().isEmpty()) {
    r[QStringLiteral("error")] = QStringLiteral("目标目录为空");
    return r;
  }

  // 1. Target must be a usable directory.
  QDir td(targetDir);
  if (!td.exists() && !td.mkpath(QStringLiteral("."))) {
    r[QStringLiteral("error")] = QStringLiteral("目标目录不存在且无法创建");
    return r;
  }
  if (!dirIsUsable(targetDir)) {
    r[QStringLiteral("error")] = QStringLiteral("目标目录不可写");
    return r;
  }

  const QString oldDbPath = databasePath();
  if (oldDbPath.isEmpty()) {
    r[QStringLiteral("error")] = QStringLiteral("无法解析当前数据库路径");
    return r;
  }

  const QString newDbPath = QDir::cleanPath(td.filePath(kDatabaseFileName));
  if (QFileInfo(newDbPath).absoluteFilePath() ==
      QFileInfo(oldDbPath).absoluteFilePath()) {
    r[QStringLiteral("error")] = clearPointer
                                     ? QStringLiteral("数据库已在默认位置")
                                     : QStringLiteral("目标与当前位置相同");
    return r;
  }

  // 2. Never clobber an existing db at the target.
  if (QFile::exists(newDbPath)) {
    r[QStringLiteral("error")] =
        QStringLiteral("目标目录已存在 timearc.db，请换一个目录");
    return r;
  }

  // 3. Free-space guard: need at least the current DB size + headroom.
  const qint64 dbSize = QFileInfo(oldDbPath).size();
  const QStorageInfo si(targetDir);
  if (si.isValid() && si.bytesAvailable() >= 0 &&
      si.bytesAvailable() < dbSize + 64LL * 1024 * 1024) {
    r[QStringLiteral("error")] = QStringLiteral("目标磁盘剩余空间不足");
    return r;
  }

  // 4. Snapshot the live DB to the new path (consistent: VACUUM INTO folds WAL).
  {
    QSqlDatabase db = database();
    if (!db.isValid() || !db.isOpen()) {
      r[QStringLiteral("error")] = QStringLiteral("当前数据库未打开");
      return r;
    }
    QString literal = newDbPath;
    literal.replace(QLatin1Char('\''), QStringLiteral("''"));
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("VACUUM INTO '") + literal +
                QStringLiteral("';"))) {
      r[QStringLiteral("error")] =
          QStringLiteral("导出快照失败：") + q.lastError().text();
      QFile::remove(newDbPath);
      return r;
    }
  }

  // 5. Validate the snapshot BEFORE switching anything (reuse D1 inspectBackup).
  const QVariantMap insp = inspectBackup(newDbPath);
  if (!insp.value(QStringLiteral("ok")).toBool()) {
    r[QStringLiteral("error")] = QStringLiteral("新数据库校验未通过：") +
                                 insp.value(QStringLiteral("error")).toString();
    QFile::remove(newDbPath);
    return r;
  }

  // 6. Capture the rollback pointer, then release the UI handle on the old DB.
  const QString originalRaw = readConfigDbPathRaw();
  database().close();
  QSqlDatabase::removeDatabase(kConnectionName);

  // 7. Lock-probe the OLD DB by parking it at a sidecar (mirrors D1 restore's
  //    remove-as-lock-test). If this fails the background service still holds
  //    it -> abort BEFORE touching the pointer, so we never split-brain. The
  //    parked copy is also the rollback source.
  const QString parkedOld = oldDbPath + QStringLiteral(".pre-migrate.bak");
  bool parked = false;
  if (QFile::exists(oldDbPath)) {
    if (QFile::exists(parkedOld) && !QFile::remove(parkedOld)) {
      r[QStringLiteral("error")] = QStringLiteral("无法清理旧的迁移备份");
      QFile::remove(newDbPath);
      openDatabase();
      configureDatabase();
      return r;
    }
    if (!QFile::rename(oldDbPath, parkedOld)) {
      qWarning() << "relocate: old DB is locked (background collection "
                    "running?). Aborting before switching the pointer.";
      r[QStringLiteral("error")] =
          QStringLiteral("迁移失败：数据库被后台采集占用，请先停止后台采集");
      QFile::remove(newDbPath);
      openDatabase();  // pointer unchanged -> reopens the old DB
      configureDatabase();
      return r;
    }
    parked = true;
    QFile::remove(oldDbPath + QStringLiteral("-wal"));
    QFile::remove(oldDbPath + QStringLiteral("-shm"));
  }

  // 8. Atomically switch the cross-process pointer.
  const bool wrote =
      clearPointer ? writeDbPathPointer(QString()) : writeDbPathPointer(newDbPath);
  if (!wrote) {
    r[QStringLiteral("error")] = QStringLiteral("写入数据库位置指针失败，已回滚");
    if (parked) QFile::rename(parkedOld, oldDbPath);
    QFile::remove(newDbPath);
    openDatabase();
    configureDatabase();
    return r;
  }

  // 9. Reopen on the new DB (databasePath() now resolves to newDbPath).
  if (!openDatabase() || !configureDatabase()) {
    qWarning() << "relocate: pointer switched but new DB failed to open; "
                  "rolling back.";
    database().close();
    QSqlDatabase::removeDatabase(kConnectionName);
    writeDbPathPointer(originalRaw);  // restore exact prior pointer
    QFile::remove(newDbPath);
    if (parked) QFile::rename(parkedOld, oldDbPath);
    openDatabase();
    configureDatabase();
    r[QStringLiteral("error")] = QStringLiteral("切换到新数据库失败，已回滚");
    return r;
  }

  // 10. Success: drop the parked old DB (+ stale sidecars). The pointer now
  //     points at the new DB; restart prompts let the service re-read it.
  if (parked) {
    QFile::remove(parkedOld);
    QFile::remove(parkedOld + QStringLiteral("-wal"));
    QFile::remove(parkedOld + QStringLiteral("-shm"));
  }

  qInfo().noquote() << "relocateDatabase: moved DB to" << newDbPath
                    << (clearPointer ? "(pointer cleared -> default)"
                                     : "(pointer set)");
  r[QStringLiteral("ok")] = true;
  r[QStringLiteral("newPath")] = newDbPath;
  r[QStringLiteral("error")] = QString();
  return r;
}

QVariantMap DatabaseManager::relocateDatabaseTo(const QString& targetDirOrUrl) {
  return relocateDatabaseImpl(targetDirOrUrl, /*clearPointer=*/false);
}

QVariantMap DatabaseManager::restoreDefaultDatabaseLocation() {
  const QString def = defaultDatabasePath();
  if (def.isEmpty()) {
    QVariantMap r;
    r[QStringLiteral("ok")] = false;
    r[QStringLiteral("error")] = QStringLiteral("无法解析默认位置");
    r[QStringLiteral("newPath")] = QString();
    return r;
  }
  return relocateDatabaseImpl(QFileInfo(def).absolutePath(),
                              /*clearPointer=*/true);
}

QString DatabaseManager::currentDatabaseLocationDir() const {
  const QString p = databasePath();
  return p.isEmpty() ? QString() : QFileInfo(p).absolutePath();
}

bool DatabaseManager::isUsingCustomDatabaseLocation() const {
  return QDir::cleanPath(databasePath()) !=
         QDir::cleanPath(defaultDatabasePath());
}
