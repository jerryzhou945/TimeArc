#include "services/DatabaseManager.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QVariant>

namespace {

const QString kConnectionName = QStringLiteral("timearc");
const QString kDatabaseFileName = QStringLiteral("timearc.db");

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
