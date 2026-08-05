#include "services/database_manager.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QSaveFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QStringList>
#include <QUrl>
#include <QVariant>

namespace {

const QString kGuiConnectionName = QStringLiteral("timearc");
const QString kServiceConnectionName = QStringLiteral("timearc_service");
const QString kGuiDatabaseFileName = QStringLiteral("timearc.db");
const QString kServiceDatabaseFileName = QStringLiteral("timearc_service.db");

QString testAppDataLocation() {
  if (!QStandardPaths::isTestModeEnabled()) return QString();
  const QString override = qEnvironmentVariable("TIMEARC_TEST_APPDATA");
  if (!override.trimmed().isEmpty()) return QDir::cleanPath(override);
  return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}

// D2/H5: the cross-process pointer lives in the control file in a fixed config
// dir, not beside a movable DB. In test mode there is no service, so the pointer
// stays under the test AppData path to isolate db_smoke from the real user.
// Must mirror build_config_path in database_path.c exactly.
QString controlFileDir() {
  if (QStandardPaths::isTestModeEnabled()) {
    return testAppDataLocation();
  }

  const QString leaf = QStringLiteral("TimeArc/config");

#if defined(Q_OS_WIN)
  QString base = qEnvironmentVariable("APPDATA");
  if (base.trimmed().isEmpty()) return QString();
  return QDir(base).filePath(leaf);
#elif defined(Q_OS_MACOS)
  const QString home = QDir::homePath();
  if (home.trimmed().isEmpty()) return QString();
  return QDir(home).filePath(
      QStringLiteral("Library/Application Support/%1").arg(leaf));
#else
  QString base = qEnvironmentVariable("XDG_CONFIG_HOME");
  if (base.trimmed().isEmpty()) {
    const QString home = QDir::homePath();
    if (home.trimmed().isEmpty()) return QString();
    base = QDir(home).filePath(QStringLiteral(".config"));
  }
  return QDir(base).filePath(leaf);
#endif
}

QString serviceConfigPath() {
  const QString dir = controlFileDir();
  if (dir.isEmpty()) return QString();
  return QDir(dir).filePath(QStringLiteral("service_config.json"));
}

// Dotted-leaf access over the nested v1 document. Reading a missing branch
// yields an undefined value rather than creating anything.
QJsonValue jsonLeaf(const QJsonObject& root, const QString& dotted) {
  const QStringList parts = dotted.split(QLatin1Char('.'));
  QJsonObject cur = root;
  for (int i = 0; i < parts.size() - 1; ++i) {
    const QJsonValue v = cur.value(parts.at(i));
    if (!v.isObject()) return QJsonValue(QJsonValue::Undefined);
    cur = v.toObject();
  }
  return cur.value(parts.last());
}

// Insert a dotted leaf, creating intermediate objects. A non-object sitting on
// the path is replaced: the leaf the caller asked for must exist afterwards.
void setJsonLeaf(QJsonObject& root, const QString& dotted,
                 const QJsonValue& value) {
  const QStringList parts = dotted.split(QLatin1Char('.'));
  if (parts.size() == 1) {
    root.insert(parts.first(), value);
    return;
  }
  const QString head = parts.first();
  QJsonObject child =
      root.value(head).isObject() ? root.value(head).toObject() : QJsonObject();
  setJsonLeaf(child, parts.mid(1).join(QLatin1Char('.')), value);
  root.insert(head, child);
}

// Remove a dotted leaf and prune any object it leaves empty, so clearing the
// last key in a section does not strand `"database": {}` in the file.
void removeJsonLeaf(QJsonObject& root, const QString& dotted) {
  const QStringList parts = dotted.split(QLatin1Char('.'));
  if (parts.size() == 1) {
    root.remove(parts.first());
    return;
  }
  const QString head = parts.first();
  if (!root.value(head).isObject()) return;
  QJsonObject child = root.value(head).toObject();
  removeJsonLeaf(child, parts.mid(1).join(QLatin1Char('.')));
  if (child.isEmpty()) {
    root.remove(head);
  } else {
    root.insert(head, child);
  }
}

// D2/H5: atomic read-modify-write of the control file. Every UI write goes
// through here, version-stamped. Inserts/overwrites every dotted leaf in
// `updates`, removes every leaf in `removeLeaves`, and PRESERVES
// all other keys -- including whole sections this build knows nothing about, so
// an older UI cannot delete a newer service's settings. Both the D2 database.dir
// writer and the H5 tracking writer funnel through this one helper, so neither
// can clobber the other's keys (the kickoff's #1 risk -- made structurally
// impossible rather than guarded by convention).
// QSaveFile gives the atomic tmp-write + rename the disk contract requires.
// Returns false on any failure (G6 honest -- caller must not assume success).
bool patchServiceConfig(const QVariantMap& updates,
                        const QStringList& removeLeaves) {
  const QString cfgPath = serviceConfigPath();
  if (cfgPath.isEmpty()) {
    qWarning() << "patchServiceConfig: cannot resolve control file path.";
    return false;
  }
  const QString cfgDir = QFileInfo(cfgPath).absolutePath();
  if (!QDir().mkpath(cfgDir)) {
    qWarning() << "patchServiceConfig: cannot create config dir:" << cfgDir;
    return false;
  }

  // Read-modify: preserve every existing key. A genuinely absent/empty file means
  // "start fresh"; a non-empty-but-UNPARSEABLE file must NOT be treated as empty,
  // or overwriting it would silently destroy the other writer's co-resident key
  // (database.dir vs tracking.* -- the kickoff's #1 risk). Refuse honestly (G6)
  // so the corrupt file + its keys survive for recovery; the caller (e.g.
  // relocate) sees the failure and rolls back instead of split-braining.
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
          qWarning() << "patchServiceConfig: refusing to overwrite unparseable "
                        "control file (preserving sibling keys for recovery):"
                     << cfgPath;
          return false;
        }
        obj = doc.object();
      }
    }
  }
  for (const QString& leaf : removeLeaves) removeJsonLeaf(obj, leaf);
  for (auto it = updates.begin(); it != updates.end(); ++it)
    setJsonLeaf(obj, it.key(), QJsonValue::fromVariant(it.value()));
  // Stamp the version last so a hand-edited file cannot end up versionless.
  if (!obj.isEmpty()) obj.insert(QStringLiteral("schema_version"), 1);

  const QByteArray bytes = QJsonDocument(obj).toJson(QJsonDocument::Indented);
  QSaveFile out(cfgPath);
  if (!out.open(QIODevice::WriteOnly)) {
    qWarning() << "patchServiceConfig: cannot open for write:" << cfgPath;
    return false;
  }
  if (out.write(bytes) != bytes.size()) {
    out.cancelWriting();
    qWarning() << "patchServiceConfig: short write:" << cfgPath;
    return false;
  }
  if (!out.commit()) {
    qWarning() << "patchServiceConfig: commit failed:" << cfgPath;
    return false;
  }
  return true;
}

// Parse the control file into an object. Empty when absent, unreadable, or
// malformed -- all three mean "no configured pointer" to every caller here.
QJsonObject readConfigObject(const QString& cfgPath) {
  if (cfgPath.isEmpty()) return QJsonObject();
  QFile f(cfgPath);
  if (!f.exists() || !f.open(QIODevice::ReadOnly)) return QJsonObject();
  const QByteArray bytes = f.readAll();
  f.close();
  QJsonParseError err;
  const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
  if (err.error != QJsonParseError::NoError || !doc.isObject())
    return QJsonObject();
  return doc.object();
}

// Raw database directory pointer (empty when absent / unreadable / malformed).
// No validation here -- callers decide what to do with it. Mirrors the
// resolution in database_path.c exactly; the retired flat `db_dir` is never
// read. The two readers must stay in step or the processes split-brain over
// where history lives.
QString readConfigDbDirRaw() {
  return jsonLeaf(readConfigObject(serviceConfigPath()),
                  QStringLiteral("database.dir"))
      .toString();
}

// A directory is usable when it exists (or can be created) and a probe write
// succeeds. Relocation validates this before writing a new directory pointer.
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

bool tableHasColumn(const QString& tableName, const QString& columnName) {
  QSqlDatabase db = QSqlDatabase::database(kGuiConnectionName);
  if (!db.isValid() || !db.isOpen()) return false;

  QSqlQuery query(db);
  if (!query.exec(QStringLiteral("PRAGMA table_info(%1);").arg(tableName))) {
    qWarning() << "tableHasColumn failed:" << query.lastError().text();
    return false;
  }

  while (query.next()) {
    if (query.value(1).toString() == columnName) return true;
  }
  return false;
}

bool ensureDeviceUsageSessionConfidenceColumn() {
  if (tableHasColumn(QStringLiteral("device_usage_sessions"),
                     QStringLiteral("confidence"))) {
    return true;
  }

  QSqlDatabase db = QSqlDatabase::database(kGuiConnectionName);
  QSqlQuery query(db);
  if (!query.exec(QStringLiteral(
          "ALTER TABLE device_usage_sessions "
          "ADD COLUMN confidence TEXT NOT NULL DEFAULT 'observed';"))) {
    qWarning() << "Failed to add device_usage_sessions.confidence:"
               << query.lastError().text();
    return false;
  }
  return true;
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
  if (!openGuiDatabase()) return false;
  if (!configureGuiDatabase()) return false;
  if (!createTables()) return false;
  if (!ensureDeviceUsageSessionConfidenceColumn()) return false;
  if (!insertDefaultTags()) return false;
  if (!insertDefaultSettings()) return false;
  if (!createIndexes()) return false;
  if (!openServiceDatabaseReadOnly()) return false;

  return true;
}

bool DatabaseManager::configureGuiDatabase() {
  return executeQuery(QStringLiteral("PRAGMA foreign_keys = ON;"));
}

QSqlDatabase DatabaseManager::database() const {
  return QSqlDatabase::database(kGuiConnectionName);
}

QSqlDatabase DatabaseManager::serviceDatabase() const {
  if (!QSqlDatabase::contains(kServiceConnectionName)) return QSqlDatabase();
  return QSqlDatabase::database(kServiceConnectionName, false);
}

QString DatabaseManager::getDatabasePath() const { return guiDatabasePath(); }

QString DatabaseManager::getServiceDatabasePath() const {
  return serviceDatabasePath();
}

QString DatabaseManager::defaultGuiDatabasePath() const {
  const QString appDataLocation = QStandardPaths::isTestModeEnabled()
                                      ? testAppDataLocation()
                                      : QStandardPaths::writableLocation(
                                            QStandardPaths::AppDataLocation);
  if (appDataLocation.isEmpty()) return QString();
  return QDir(appDataLocation).filePath(kGuiDatabaseFileName);
}

QString DatabaseManager::guiDatabasePath() const {
  return defaultGuiDatabasePath();
}

QString DatabaseManager::defaultServiceDatabasePath() const {
  QString dbDir;
  if (QStandardPaths::isTestModeEnabled()) {
    dbDir = testAppDataLocation();
  } else {
#if defined(Q_OS_WIN)
    QString base = qEnvironmentVariable("APPDATA");
    if (base.trimmed().isEmpty()) return QString();
    dbDir = QDir(base).filePath(QStringLiteral("TimeArc/service"));
#elif defined(Q_OS_MACOS)
    const QString home = QDir::homePath();
    if (home.trimmed().isEmpty()) return QString();
    dbDir = QDir(home).filePath(
        QStringLiteral("Library/Application Support/TimeArc/service"));
#else
    QString base = qEnvironmentVariable("XDG_DATA_HOME");
    if (base.trimmed().isEmpty()) {
      const QString home = QDir::homePath();
      if (home.trimmed().isEmpty()) return QString();
      base = QDir(home).filePath(QStringLiteral(".local/share"));
    }
    dbDir = QDir(base).filePath(QStringLiteral("TimeArc/service"));
#endif
  }
  if (dbDir.isEmpty()) return QString();

  return QDir(dbDir).filePath(kServiceDatabaseFileName);
}

QString DatabaseManager::serviceDatabasePath() const {
  // D2: a configured database.dir wins; the filename itself is locked.
  const QString redirectedDir = readConfigDbDirRaw();
  if (!redirectedDir.isEmpty())
    return QDir::cleanPath(
        QDir(redirectedDir).filePath(kServiceDatabaseFileName));
  return defaultServiceDatabasePath();
}

bool DatabaseManager::openGuiDatabase() {
  const QString path = guiDatabasePath();
  if (path.isEmpty()) {
    qWarning() << "Unable to resolve GUI database path.";
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
  if (QSqlDatabase::contains(kGuiConnectionName)) {
    db = QSqlDatabase::database(kGuiConnectionName);
  } else {
    db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"),
                                   kGuiConnectionName);
  }

  db.setDatabaseName(path);

  if (!db.open()) {
    qWarning() << "Unable to open GUI SQLite database:" << path
               << db.lastError().text();
    return false;
  }

  return true;
}

bool DatabaseManager::openServiceDatabaseReadOnly() {
  const QString path = serviceDatabasePath();
  if (path.isEmpty()) {
    qWarning() << "Unable to resolve service database path.";
    return true;
  }

  if (!QFileInfo::exists(path)) {
    if (QSqlDatabase::contains(kServiceConnectionName)) {
      QSqlDatabase db = QSqlDatabase::database(kServiceConnectionName, false);
      db.close();
      db.setDatabaseName(path);
      db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
    } else {
      QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"),
                                                  kServiceConnectionName);
      db.setDatabaseName(path);
      db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
    }
    qInfo().noquote() << "Service SQLite database is not present yet:" << path;
    return true;
  }

  QSqlDatabase db;
  if (QSqlDatabase::contains(kServiceConnectionName)) {
    db = QSqlDatabase::database(kServiceConnectionName, false);
    if (db.databaseName() != path) {
      db.close();
      db.setDatabaseName(path);
      db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
    }
  } else {
    db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"),
                                   kServiceConnectionName);
    db.setDatabaseName(path);
    db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
  }

  if (!db.isOpen() && !db.open()) {
    qWarning() << "Unable to open service SQLite database read-only:" << path
               << db.lastError().text();
    return true;
  }

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
CREATE TABLE IF NOT EXISTS device_usage_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    platform TEXT NOT NULL,
    device_id TEXT NOT NULL,
    app_identifier TEXT NOT NULL,
    package_name TEXT NOT NULL,
    date_local TEXT NOT NULL,
    range_start_unix_sec INTEGER NOT NULL,
    range_end_unix_sec INTEGER NOT NULL,
    foreground_sec INTEGER NOT NULL,
    source TEXT NOT NULL,
    first_synced_at INTEGER NOT NULL,
    last_synced_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    UNIQUE(platform, device_id, app_identifier, date_local, source)
);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE TABLE IF NOT EXISTS device_usage_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    platform TEXT NOT NULL,
    device_id TEXT NOT NULL,
    app_identifier TEXT NOT NULL,
    package_name TEXT NOT NULL,
    session_start_unix_sec INTEGER NOT NULL,
    session_end_unix_sec INTEGER NOT NULL,
    duration_sec INTEGER NOT NULL,
    source TEXT NOT NULL,
    confidence TEXT NOT NULL DEFAULT 'observed',
    created_at INTEGER NOT NULL,
    UNIQUE(platform, device_id, app_identifier, session_start_unix_sec, session_end_unix_sec, source)
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
CREATE INDEX IF NOT EXISTS idx_device_usage_date
ON device_usage_summaries(platform, date_local);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_device_usage_app
ON device_usage_summaries(platform, app_identifier, date_local);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_device_usage_sessions_time
ON device_usage_sessions(platform, session_start_unix_sec, session_end_unix_sec);
)SQL")) &&
         executeQuery(QStringLiteral(R"SQL(
CREATE INDEX IF NOT EXISTS idx_device_usage_sessions_app
ON device_usage_sessions(platform, app_identifier);
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

// ---------------------------------------------------------------------------
// GUI-owned database backup / inspect / restore.
// ---------------------------------------------------------------------------

QString DatabaseManager::backupDatabase(const QString& destPath) {
  const QString src = guiDatabasePath();
  if (src.isEmpty()) {
    qWarning() << "backupDatabase: cannot resolve GUI database path.";
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
  result[QStringLiteral("appRows")] = 0;
  result[QStringLiteral("settingsRows")] = 0;
  result[QStringLiteral("manualProjectRows")] = 0;
  result[QStringLiteral("manualSessionRows")] = 0;
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
  qlonglong appRows = 0, settingsRows = 0, manualProjectRows = 0;
  qlonglong manualSessionRows = 0;

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

      // 2. Assert the GUI-owned tables exist (reject random / foreign .db).
      bool hasAll = true;
      const QStringList required = {QStringLiteral("apps"),
                                    QStringLiteral("settings"),
                                    QStringLiteral("tags"),
                                    QStringLiteral("manual_projects"),
                                    QStringLiteral("manual_sessions")};
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
        errorText = QStringLiteral("不是 TimeArc GUI 数据库（缺少契约表）");
      } else {
        // 3. Row counts for the GUI-owned tables.
        QSqlQuery cq(db);
        if (cq.exec(QStringLiteral("SELECT COUNT(*) FROM apps;")) && cq.next())
          appRows = cq.value(0).toLongLong();
        if (cq.exec(QStringLiteral("SELECT COUNT(*) FROM settings;")) &&
            cq.next())
          settingsRows = cq.value(0).toLongLong();
        if (cq.exec(QStringLiteral("SELECT COUNT(*) FROM manual_projects;")) &&
            cq.next())
          manualProjectRows = cq.value(0).toLongLong();
        if (cq.exec(QStringLiteral("SELECT COUNT(*) FROM manual_sessions;")) &&
            cq.next())
          manualSessionRows = cq.value(0).toLongLong();
        ok = true;
      }
      db.close();
    }
  }
  QSqlDatabase::removeDatabase(connName);

  result[QStringLiteral("ok")] = ok;
  result[QStringLiteral("integrity")] = integrity;
  result[QStringLiteral("appRows")] = appRows;
  result[QStringLiteral("settingsRows")] = settingsRows;
  result[QStringLiteral("manualProjectRows")] = manualProjectRows;
  result[QStringLiteral("manualSessionRows")] = manualSessionRows;
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

  const QString dbPath = guiDatabasePath();
  if (dbPath.isEmpty()) {
    qWarning() << "restoreDatabase: cannot resolve GUI database path.";
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
    if (openGuiDatabase()) configureGuiDatabase();
  };

  // 3. Release the UI's handle so the file can be replaced.
  database().close();
  QSqlDatabase::removeDatabase(kGuiConnectionName);

  // 4. Remove the live GUI DB + stale side files.
  bool removed = true;
  if (QFile::exists(dbPath) && !QFile::remove(dbPath)) removed = false;
  if (!removed) {
    qWarning() << "restoreDatabase: live GUI DB is locked. Original kept; "
                  "aborting restore.";
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
  if (!openGuiDatabase() || !configureGuiDatabase()) {
    qWarning() << "restoreDatabase: copied backup but failed to reopen; rolling "
                  "back.";
    database().close();
    QSqlDatabase::removeDatabase(kGuiConnectionName);
    QFile::remove(dbPath);
    if (QFile::exists(preBak)) QFile::copy(preBak, dbPath);
    reopen();
    return false;
  }

  qInfo().noquote() << "restoreDatabase: restored from" << source;
  emit databaseRestored();
  return true;
}

bool DatabaseManager::writeDbDirPointer(const QString& dbDirOrEmpty) {
  // Read-modify-write via the shared helper: an empty dir clears the leaf,
  // otherwise sets it; the tracking.* keys in this same file are preserved.
  // `db_dir`/`db_path` are the retired v0 spellings -- dropped if a v0 file was
  // upgraded in place, so the new pointer can never be shadowed by an old one.
  const QStringList retired = {QStringLiteral("db_dir"),
                               QStringLiteral("db_path")};
  if (dbDirOrEmpty.isEmpty()) {
    return patchServiceConfig({}, QStringList(retired)
                                      << QStringLiteral("database.dir"));
  }
  return patchServiceConfig(
      {{QStringLiteral("database.dir"), QDir::cleanPath(dbDirOrEmpty)}},
      retired);
}

bool DatabaseManager::writeServiceConfig(int idleSec, bool trackEnabled) {
  // Write the collector's idle timeout (SECONDS -- v1 changed the unit; the
  // caller converts at the UI edge) + the tracking master switch. Shares
  // patchServiceConfig with the database.dir writer, so that pointer is
  // preserved untouched. idleSec < 0 omits the key so the service keeps its
  // compile-time default (fail-safe); 0 is a real value meaning "never idle",
  // so it is written. tracking.enabled is always written (an explicit choice).
  // Takes effect on the next collector startup -- restart it via
  // SettingsRepository for immediate effect. G6: false on failure.
  QVariantMap updates;
  QStringList remove;
  const QString idleKey =
      QStringLiteral("tracking.frontmost.idle_threshold_sec");
  if (idleSec >= 0)
    updates.insert(idleKey, idleSec);
  else
    remove << idleKey;
  updates.insert(QStringLiteral("tracking.enabled"), trackEnabled);
  // The retired usage_config.json is never written. Until the collector is
  // taught to read these keys from service_config.json (backlog A3), it keeps
  // its compile-time idle/track defaults -- the settings still persist and
  // still reach the file, they just have no reader yet.
  return patchServiceConfig(updates, remove);
}

QVariantMap DatabaseManager::relocateDatabaseTo(const QString& targetDirOrUrl) {
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

  if (!writeDbDirPointer(targetDir)) {
    r[QStringLiteral("error")] = QStringLiteral("写入数据库位置指针失败");
    return r;
  }

  openServiceDatabaseReadOnly();
  const QString newDbPath =
      QDir::cleanPath(td.filePath(kServiceDatabaseFileName));
  qInfo().noquote() << "relocateDatabase: service database.dir set to"
                    << targetDir;
  r[QStringLiteral("ok")] = true;
  r[QStringLiteral("newPath")] = newDbPath;
  r[QStringLiteral("error")] = QString();
  return r;
}

QVariantMap DatabaseManager::restoreDefaultDatabaseLocation() {
  const QString def = defaultServiceDatabasePath();
  if (def.isEmpty()) {
    QVariantMap r;
    r[QStringLiteral("ok")] = false;
    r[QStringLiteral("error")] = QStringLiteral("无法解析默认位置");
    r[QStringLiteral("newPath")] = QString();
    return r;
  }
  QVariantMap r;
  r[QStringLiteral("ok")] = false;
  r[QStringLiteral("error")] = QString();
  r[QStringLiteral("newPath")] = QString();
  if (!writeDbDirPointer(QString())) {
    r[QStringLiteral("error")] = QStringLiteral("清除数据库位置指针失败");
    return r;
  }
  openServiceDatabaseReadOnly();
  r[QStringLiteral("ok")] = true;
  r[QStringLiteral("newPath")] = def;
  return r;
}

QString DatabaseManager::currentDatabaseLocationDir() const {
  const QString p = serviceDatabasePath();
  return p.isEmpty() ? QString() : QFileInfo(p).absolutePath();
}

bool DatabaseManager::isUsingCustomDatabaseLocation() const {
  return QDir::cleanPath(serviceDatabasePath()) !=
         QDir::cleanPath(defaultServiceDatabasePath());
}
