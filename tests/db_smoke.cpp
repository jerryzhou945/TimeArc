#include <QCoreApplication>
#include <QDate>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QStringList>
#include <QSettings>
#include <QTimeZone>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

#include <algorithm>
#include <iterator>

#include "services/app_repository.h"
#include "services/app_identity_policy.h"
#include "services/autostart_default_policy.h"
#include "services/database_manager.h"
#include "services/frontmost_session_repository.h"
#include "services/manual_project_repository.h"
#include "services/media_session_repository.h"
#include "services/mobile/mobile_usage_repository.h"
#include "services/mobile/mobile_usage_insight_engine.h"
#include "services/mobile/mobile_usage_service.h"
#include "services/settings_repository.h"
#include "services/stats_service.h"
#include "services/calendar_manager.h"
#include "services/project_manager.h"
#include "services/categorization/default_rules.h"
#include "services/categorization/matcher.h"
#include "services/categorization/rule_set_json.h"
#include "services/categorization_manager.h"

namespace {

int fail(const QString& message) {
  qCritical().noquote() << message;
  return 1;
}

bool tableExists(const QSqlDatabase& db, const QString& tableName) {
  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = :name"))) {
    qCritical() << "Failed to prepare table lookup:" << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":name"), tableName);
  if (!query.exec()) {
    qCritical() << "Failed to query sqlite_master:" << query.lastError().text();
    return false;
  }

  return query.next();
}

// Schema-parity guard. Service history DDL is owned by
// src/service/shared/database_storage.c; this read-only UI fixture mirrors it.
struct ExpectedColumn {
  const char* name;
  const char* type;  // declared type, upper-cased
  int notNull;       // 1 = NOT NULL, 0 = nullable (PRAGMA notnull)
};

bool columnsMatch(const QSqlDatabase& db, const QString& tableName,
                  const ExpectedColumn* expected, int expectedCount,
                  QString* mismatch) {
  QSqlQuery query(db);
  if (!query.exec(
          QStringLiteral("PRAGMA table_xinfo(%1);").arg(tableName))) {
    *mismatch = QStringLiteral("PRAGMA table_xinfo(%1) failed: %2")
                    .arg(tableName, query.lastError().text());
    return false;
  }

  int index = 0;
  while (query.next()) {
    const QString name = query.value(1).toString();
    const QString type = query.value(2).toString().toUpper();
    const int notNull = query.value(3).toInt();
    if (index >= expectedCount) {
      *mismatch = QStringLiteral("%1 has more columns than expected (extra: %2)")
                      .arg(tableName, name);
      return false;
    }
    const ExpectedColumn& want = expected[index];
    if (name != QString::fromUtf8(want.name) ||
        type != QString::fromUtf8(want.type).toUpper() ||
        notNull != want.notNull) {
      *mismatch =
          QStringLiteral(
              "%1 column %2: got (%3 %4 notnull=%5) expected (%6 %7 notnull=%8)")
              .arg(tableName)
              .arg(index)
              .arg(name, type)
              .arg(notNull)
              .arg(QString::fromUtf8(want.name), QString::fromUtf8(want.type))
              .arg(want.notNull);
      return false;
    }
    ++index;
  }

  if (index != expectedCount) {
    *mismatch = QStringLiteral("%1 has %2 columns, expected %3")
                    .arg(tableName)
                    .arg(index)
                    .arg(expectedCount);
    return false;
  }

  return true;
}

bool execSql(QSqlDatabase db, const QString& sql, QString* error) {
  QSqlQuery query(db);
  if (!query.exec(sql)) {
    *error = query.lastError().text();
    return false;
  }
  return true;
}

bool createServiceHistoryDatabase(const QString& path, QString* error) {
  QDir dir(QFileInfo(path).absolutePath());
  if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
    *error = QStringLiteral("could not create parent dir");
    return false;
  }

  static int counter = 0;
  const QString conn =
      QStringLiteral("service_seed_") + QString::number(++counter);
  bool ok = true;
  {
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), conn);
    db.setDatabaseName(path);
    if (!db.open()) {
      *error = db.lastError().text();
      ok = false;
    }
    if (ok)
      ok = execSql(db,
                   QStringLiteral(
                       "CREATE TABLE IF NOT EXISTS apps ("
                       "app_id TEXT NOT NULL PRIMARY KEY,"
                       "platform TEXT NOT NULL,"
                       "display_name TEXT NOT NULL DEFAULT '',"
                       "icon_path TEXT NOT NULL DEFAULT '',"
                       "executable_path TEXT NOT NULL DEFAULT '',"
                       "created_at INTEGER NOT NULL,"
                       "updated_at INTEGER NOT NULL"
                       ");"),
                   error);
    if (ok)
      ok = execSql(db,
                   QStringLiteral(
                       "CREATE TABLE IF NOT EXISTS frontmost_sessions ("
                       "app_id TEXT NOT NULL,"
                       "window_title TEXT NOT NULL DEFAULT '',"
                       "start_unix_sec INTEGER NOT NULL,"
                       "end_unix_sec INTEGER NOT NULL,"
                       "duration_sec INTEGER GENERATED ALWAYS AS "
                       "(end_unix_sec - start_unix_sec) STORED,"
                       "active_sec INTEGER NOT NULL,"
                       "idle_sec INTEGER GENERATED ALWAYS AS "
                       "((end_unix_sec - start_unix_sec) - active_sec) STORED"
                       ");"),
                   error);
    if (ok)
      ok = execSql(db,
                   QStringLiteral(
                       "CREATE TABLE IF NOT EXISTS media_sessions ("
                       "app_id TEXT NOT NULL,"
                       "media_type TEXT NOT NULL,"
                       "media_title TEXT NOT NULL DEFAULT '',"
                       "start_unix_sec INTEGER NOT NULL,"
                       "end_unix_sec INTEGER NOT NULL,"
                       "duration_sec INTEGER GENERATED ALWAYS AS "
                       "(end_unix_sec - start_unix_sec) STORED"
                       ");"),
                   error);
    db.close();
  }
  QSqlDatabase::removeDatabase(conn);
  return ok;
}

bool seedServiceApp(QSqlDatabase db,
                    const QString& appIdentifier,
                    const QString& appName,
                    const QString& displayName,
                    const QString& executablePath,
                    const QString& platform,
                    QString* error) {
  QSqlQuery query(db);
  query.prepare(QStringLiteral(
      "INSERT OR IGNORE INTO apps (app_id, platform, display_name, icon_path, "
      "executable_path, created_at, updated_at) "
      "VALUES (:id, :platform, :display, '', :path, :now, :now);"));
  query.bindValue(QStringLiteral(":id"), appIdentifier);
  query.bindValue(QStringLiteral(":display"),
                  displayName.isEmpty() ? appName : displayName);
  query.bindValue(QStringLiteral(":path"), executablePath);
  query.bindValue(QStringLiteral(":platform"), platform);
  query.bindValue(QStringLiteral(":now"), QDateTime::currentSecsSinceEpoch());
  if (!query.exec()) {
    *error = query.lastError().text();
    return false;
  }
  return true;
}

bool seedServiceFrontmost(QSqlDatabase db,
                          const QString& appIdentifier,
                          const QString& windowTitle,
                          qint64 startUnixSec,
                          qint64 endUnixSec,
                          QString* error) {
  QSqlQuery query(db);
  query.prepare(QStringLiteral(
      "INSERT OR IGNORE INTO frontmost_sessions (app_id, window_title, "
      "start_unix_sec, end_unix_sec, active_sec) "
      "VALUES (:id, :title, :start, :end, :dur);"));
  query.bindValue(QStringLiteral(":id"), appIdentifier);
  query.bindValue(QStringLiteral(":title"), windowTitle);
  query.bindValue(QStringLiteral(":start"), startUnixSec);
  query.bindValue(QStringLiteral(":end"), endUnixSec);
  query.bindValue(QStringLiteral(":dur"),
                  static_cast<int>(endUnixSec - startUnixSec));
  if (!query.exec()) {
    *error = query.lastError().text();
    return false;
  }
  return true;
}

bool seedServiceMedia(QSqlDatabase db,
                      const QString& appIdentifier,
                      const QString& mediaType,
                      const QString& mediaTitle,
                      qint64 startUnixSec,
                      qint64 endUnixSec,
                      QString* error) {
  QSqlQuery query(db);
  query.prepare(QStringLiteral(
      "INSERT OR IGNORE INTO media_sessions (app_id, media_type, media_title, "
      "start_unix_sec, end_unix_sec) "
      "VALUES (:id, :type, :title, :start, :end);"));
  query.bindValue(QStringLiteral(":id"), appIdentifier);
  query.bindValue(QStringLiteral(":type"), mediaType);
  query.bindValue(QStringLiteral(":title"), mediaTitle);
  query.bindValue(QStringLiteral(":start"), startUnixSec);
  query.bindValue(QStringLiteral(":end"), endUnixSec);
  if (!query.exec()) {
    *error = query.lastError().text();
    return false;
  }
  return true;
}

bool hasInsertedSession(const QVariantList& sessions,
                        const QString& appIdentifier,
                        qint64 startUnixSec,
                        qint64 endUnixSec) {
  for (const QVariant& item : sessions) {
    const QVariantMap session = item.toMap();
    if (session.value(QStringLiteral("appIdentifier")).toString() ==
            appIdentifier &&
        session.value(QStringLiteral("startUnixSec")).toLongLong() ==
            startUnixSec &&
        session.value(QStringLiteral("endUnixSec")).toLongLong() ==
            endUnixSec) {
      return true;
    }
  }

  return false;
}

void seedLegacyQSettings() {
  QSettings projectSettings(QSettings::defaultFormat(), QSettings::UserScope,
                            QStringLiteral("TimeArc"),
                            QStringLiteral("ProjectManagerData"));
  QVariantMap legacyProject;
  legacyProject.insert(QStringLiteral("name"), QStringLiteral("Legacy Project"));
  legacyProject.insert(QStringLiteral("tag"), QStringLiteral("工作"));
  legacyProject.insert(QStringLiteral("seconds"), 300);
  legacyProject.insert(QStringLiteral("time"), QStringLiteral("0h 5m"));
  projectSettings.setValue(QStringLiteral("projects"),
                           QVariantList{legacyProject});

  QVariantMap legacySession;
  legacySession.insert(QStringLiteral("projectName"),
                       QStringLiteral("Legacy Project"));
  legacySession.insert(QStringLiteral("displayName"),
                       QStringLiteral("Legacy Project"));
  legacySession.insert(QStringLiteral("tag"), QStringLiteral("工作"));
  legacySession.insert(QStringLiteral("seconds"), 300);
  legacySession.insert(QStringLiteral("date"),
                       QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd")));
  legacySession.insert(QStringLiteral("source"),
                       QStringLiteral("manual_project"));
  legacySession.insert(QStringLiteral("linkedProjectName"),
                       QStringLiteral("Legacy Project"));
  projectSettings.setValue(QStringLiteral("sessions"),
                           QVariantList{legacySession});
  projectSettings.sync();

  QJsonObject todosRoot;
  QJsonArray todos;
  QJsonObject todo;
  todo.insert(QStringLiteral("text"), QStringLiteral("Legacy Todo"));
  todo.insert(QStringLiteral("done"), false);
  todo.insert(QStringLiteral("tag"), QStringLiteral("工作"));
  todo.insert(QStringLiteral("linkedProject"), QString());
  todos.append(todo);
  todosRoot.insert(QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd")),
                   todos);

  QSettings calendarSettings(QSettings::defaultFormat(), QSettings::UserScope,
                             QStringLiteral("TimeArc"),
                             QStringLiteral("CalendarManagerData"));
  calendarSettings.setValue(
      QStringLiteral("savedTodos"),
      QString::fromUtf8(QJsonDocument(todosRoot).toJson(QJsonDocument::Compact)));
  calendarSettings.sync();

  QSettings appSettings;
  appSettings.setValue(QStringLiteral("night_mode"), true);
  appSettings.beginGroup(QStringLiteral("DesktopChatPageData"));
  appSettings.setValue(
      QStringLiteral("savedChats"),
      QStringLiteral("[{\"sender\":\"me\",\"message\":\"legacy memo\","
                     "\"imagePath\":\"\",\"timeText\":\"2026-05-21 14:00\"}]"));
  appSettings.endGroup();
  appSettings.sync();

  QSettings namedAppSettings(QSettings::defaultFormat(), QSettings::UserScope,
                             QStringLiteral("TimeArc"),
                             QStringLiteral("TimeArc"));
  namedAppSettings.setValue(QStringLiteral("night_mode"), true);
  namedAppSettings.beginGroup(QStringLiteral("DesktopChatPageData"));
  namedAppSettings.setValue(
      QStringLiteral("savedChats"),
      QStringLiteral("[{\"sender\":\"me\",\"message\":\"legacy memo\","
                     "\"imagePath\":\"\",\"timeText\":\"2026-05-21 14:00\"}]"));
  namedAppSettings.endGroup();
  namedAppSettings.sync();
}

int countProjectsByName(const QVariantList& projects, const QString& name) {
  int count = 0;
  for (const QVariant& item : projects) {
    if (item.toMap().value(QStringLiteral("name")).toString() == name) ++count;
  }
  return count;
}

int countSessionsByDisplayName(const QVariantList& sessions,
                               const QString& displayName) {
  int count = 0;
  for (const QVariant& item : sessions) {
    if (item.toMap().value(QStringLiteral("displayName")).toString() ==
        displayName) {
      ++count;
    }
  }
  return count;
}

bool containsProjectWithSeconds(const QVariantList& projects,
                                const QString& name,
                                int minimumSeconds) {
  for (const QVariant& item : projects) {
    const QVariantMap project = item.toMap();
    if (project.value(QStringLiteral("name")).toString() == name &&
        project.value(QStringLiteral("seconds")).toInt() >= minimumSeconds) {
      return true;
    }
  }
  return false;
}

QStringList memoMessagesSortedByTime(const QString& messagesJson) {
  const QJsonDocument document = QJsonDocument::fromJson(messagesJson.toUtf8());
  QJsonArray messages = document.array();
  QList<QJsonObject> objects;
  for (const QJsonValue& value : messages) {
    if (!value.isObject()) continue;
    const QJsonObject object = value.toObject();
    if (object.value(QStringLiteral("message")).toString().trimmed().isEmpty())
      continue;
    objects.append(object);
  }

  std::sort(objects.begin(), objects.end(),
            [](const QJsonObject& left, const QJsonObject& right) {
              return left.value(QStringLiteral("timeText")).toString() <
                     right.value(QStringLiteral("timeText")).toString();
            });

  QStringList result;
  for (const QJsonObject& object : objects) {
    result.append(object.value(QStringLiteral("message")).toString().trimmed());
  }
  return result;
}

QString normalizedMemoMessagesJson(const QString& messagesJson) {
  const QJsonDocument document = QJsonDocument::fromJson(messagesJson.toUtf8());
  QJsonArray messages = document.array();
  QList<QJsonObject> objects;
  for (const QJsonValue& value : messages) {
    if (!value.isObject()) continue;
    QJsonObject object = value.toObject();
    const QString message =
        object.value(QStringLiteral("message")).toString().trimmed();
    if (message.isEmpty()) continue;
    object.insert(QStringLiteral("sender"),
                  object.value(QStringLiteral("sender"))
                          .toString(QStringLiteral("me")));
    object.insert(QStringLiteral("message"), message);
    object.insert(QStringLiteral("imagePath"),
                  object.value(QStringLiteral("imagePath")).toString());
    object.insert(QStringLiteral("timeText"),
                  object.value(QStringLiteral("timeText")).toString());
    objects.append(object);
  }

  std::sort(objects.begin(), objects.end(),
            [](const QJsonObject& left, const QJsonObject& right) {
              return left.value(QStringLiteral("timeText")).toString() <
                     right.value(QStringLiteral("timeText")).toString();
            });

  QJsonArray normalized;
  for (const QJsonObject& object : objects) {
    normalized.append(object);
  }
  return QString::fromUtf8(
      QJsonDocument(normalized).toJson(QJsonDocument::Compact));
}

}  // namespace

int main(int argc, char* argv[]) {
  QCoreApplication app(argc, argv);
  QCoreApplication::setOrganizationName(QStringLiteral("TimeArc"));
  QCoreApplication::setApplicationName(QStringLiteral("TimeArc"));
  QStandardPaths::setTestModeEnabled(true);
  const QString testDataOverride =
      QDir::temp().filePath(QStringLiteral("timearc-db-smoke-appdata"));
  qputenv("TIMEARC_TEST_APPDATA", testDataOverride.toUtf8());

  // Installed primary executables must remain ahead of helper/updater paths
  // so default system icons stay stable after process or version churn.
  const QString wechatPrimary = QStringLiteral("D:/Weixin/Weixin.exe");
  const QString wechatHelper =
      QStringLiteral("D:/Weixin/XPlugin/WeChatAppEx.exe");
  const QString wechatUpdater = QStringLiteral("D:/Weixin/WeixinUpdate.exe");
  if (TimeArc::AppIdentityPolicy::representativePathScore(
          QStringLiteral("app:wechat"), wechatPrimary, true, 1) <=
          TimeArc::AppIdentityPolicy::representativePathScore(
              QStringLiteral("app:wechat"), wechatHelper, true, 100) ||
      TimeArc::AppIdentityPolicy::representativePathScore(
          QStringLiteral("app:wechat"), wechatPrimary, true, 1) <=
          TimeArc::AppIdentityPolicy::representativePathScore(
              QStringLiteral("app:wechat"), wechatUpdater, true, 100)) {
    return fail(QStringLiteral(
        "App identity: WeChat helper/updater outranked the primary executable."));
  }
  if (TimeArc::AppIdentityPolicy::representativePathScore(
          QStringLiteral("app:codex"),
          QStringLiteral("D:/Apps/Codex/current/Codex.exe"), true, 1) <=
      TimeArc::AppIdentityPolicy::representativePathScore(
          QStringLiteral("app:codex"),
          QStringLiteral("D:/Apps/Codex/old/Codex.exe"), false, 100)) {
    return fail(QStringLiteral(
        "App identity: an obsolete executable path outranked an installed one."));
  }

  const auto renamedChrome = TimeArc::AppIdentityPolicy::applyDisplayName(
      QStringLiteral("app:google-chrome"), QStringLiteral("Chrome"),
      QStringLiteral("  谷歌浏览器  "));
  if (renamedChrome.groupKey != QStringLiteral("app:google-chrome") ||
      renamedChrome.displayName != QStringLiteral("谷歌浏览器")) {
    return fail(QStringLiteral(
        "App display name: Unicode override changed identity or was not trimmed."));
  }
  const auto defaultChrome = TimeArc::AppIdentityPolicy::applyDisplayName(
      QStringLiteral("app:google-chrome"), QStringLiteral("Chrome"), QString());
  if (defaultChrome.groupKey != QStringLiteral("app:google-chrome") ||
      defaultChrome.displayName != QStringLiteral("Chrome")) {
    return fail(QStringLiteral(
        "App display name: empty override did not restore the default name."));
  }

  using TimeArc::AutostartDefaultPolicy::Action;
  if (TimeArc::AutostartDefaultPolicy::decide(false, false) !=
          Action::EnableAndRemember ||
      TimeArc::AutostartDefaultPolicy::decide(false, true) !=
          Action::RememberExisting ||
      TimeArc::AutostartDefaultPolicy::decide(true, false) !=
          Action::NoChange) {
    return fail(QStringLiteral(
        "Autostart default: first-run enable or durable opt-out policy failed."));
  }

  const QString testDataPath = testDataOverride;
  if (testDataPath.isEmpty()) {
    return fail(QStringLiteral("Qt test AppDataLocation is empty."));
  }

  QDir testDataDir(testDataPath);
  if (testDataDir.exists() && !testDataDir.removeRecursively()) {
    return fail(QStringLiteral("Unable to clear test database directory: %1")
                    .arg(testDataPath));
  }

  QSettings::setDefaultFormat(QSettings::IniFormat);
  QSettings::setPath(QSettings::IniFormat, QSettings::UserScope,
                     QDir(testDataPath).filePath(QStringLiteral("settings")));
  seedLegacyQSettings();

  const QString serviceDatabasePath =
      QDir(testDataPath).filePath(QStringLiteral("timearc_service.db"));
  QString serviceSeedError;
  if (!createServiceHistoryDatabase(serviceDatabasePath, &serviceSeedError)) {
    return fail(QStringLiteral("Could not create service history database: %1")
                    .arg(serviceSeedError));
  }

  DatabaseManager databaseManager;
  if (!databaseManager.initialize()) {
    return fail(QStringLiteral("DatabaseManager failed to initialize."));
  }

  const QString databasePath = databaseManager.getDatabasePath();
  if (!QFileInfo::exists(databasePath)) {
    return fail(QStringLiteral("Smoke database was not created: %1")
                    .arg(databasePath));
  }

  QSqlDatabase db = databaseManager.database();
  if (!db.isValid() || !db.isOpen()) {
    return fail(QStringLiteral("Smoke database connection is not open."));
  }

  if (QDir::cleanPath(databasePath) ==
      QDir::cleanPath(databaseManager.getServiceDatabasePath())) {
    return fail(QStringLiteral("GUI and service databases resolved to the same path."));
  }

  const QStringList guiTables = {
      QStringLiteral("apps"),
      QStringLiteral("device_usage_summaries"),
      QStringLiteral("device_usage_sessions"),
      QStringLiteral("manual_projects"),
      QStringLiteral("manual_sessions"),
      QStringLiteral("tags"),
      QStringLiteral("settings"),
      QStringLiteral("schema_migrations"),
  };

  for (const QString& tableName : guiTables) {
    if (!tableExists(db, tableName)) {
      return fail(QStringLiteral("GUI table is missing: %1").arg(tableName));
    }
  }
  if (tableExists(db, QStringLiteral("frontmost_sessions")) ||
      tableExists(db, QStringLiteral("media_sessions"))) {
    return fail(QStringLiteral("GUI database unexpectedly owns service history tables."));
  }

  QSqlDatabase serviceDb = databaseManager.serviceDatabase();
  if (!serviceDb.isValid() || !serviceDb.isOpen()) {
    return fail(QStringLiteral("Service history database connection is not open."));
  }
  const QStringList serviceTables = {
      QStringLiteral("apps"),
      QStringLiteral("frontmost_sessions"),
      QStringLiteral("media_sessions"),
  };
  for (const QString& tableName : serviceTables) {
    if (!tableExists(serviceDb, tableName)) {
      return fail(QStringLiteral("Service table is missing: %1").arg(tableName));
    }
  }
  {
    QSqlQuery tableQuery(serviceDb);
    if (!tableQuery.exec(QStringLiteral(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name;"))) {
      return fail(QStringLiteral("Could not enumerate service DB tables: %1")
                      .arg(tableQuery.lastError().text()));
    }
    QStringList names;
    while (tableQuery.next()) names << tableQuery.value(0).toString();
    if (names != serviceTables) {
      return fail(QStringLiteral("Service DB has unexpected user tables: %1")
                      .arg(names.join(QStringLiteral(","))));
    }
  }

  // Assert both DB contracts: service-owned history tables in the service DB,
  // GUI-owned app/mobile tables in the GUI DB.
  const ExpectedColumn guiAppsColumns[] = {
      {"id", "INTEGER", 0},          {"app_identifier", "TEXT", 1},
      {"app_name", "TEXT", 1},       {"display_name", "TEXT", 0},
      {"app_icon_path", "TEXT", 0},  {"executable_path", "TEXT", 0},
      {"platform", "TEXT", 0},       {"created_at", "INTEGER", 1},
      {"updated_at", "INTEGER", 1},
  };
  const ExpectedColumn frontmostColumns[] = {
      {"app_id", "TEXT", 1},         {"window_title", "TEXT", 1},
      {"start_unix_sec", "INTEGER", 1}, {"end_unix_sec", "INTEGER", 1},
      {"duration_sec", "INTEGER", 0}, {"active_sec", "INTEGER", 1},
      {"idle_sec", "INTEGER", 0},
  };
  const ExpectedColumn mediaColumns[] = {
      {"app_id", "TEXT", 1},          {"media_type", "TEXT", 1},
      {"media_title", "TEXT", 1},
      {"start_unix_sec", "INTEGER", 1}, {"end_unix_sec", "INTEGER", 1},
      {"duration_sec", "INTEGER", 0},
  };
  const ExpectedColumn serviceAppsColumns[] = {
      {"app_id", "TEXT", 1},          {"platform", "TEXT", 1},
      {"display_name", "TEXT", 1},    {"icon_path", "TEXT", 1},
      {"executable_path", "TEXT", 1}, {"created_at", "INTEGER", 1},
      {"updated_at", "INTEGER", 1},
  };
  const ExpectedColumn deviceUsageColumns[] = {
      {"id", "INTEGER", 0},
      {"platform", "TEXT", 1},
      {"device_id", "TEXT", 1},
      {"app_identifier", "TEXT", 1},
      {"package_name", "TEXT", 1},
      {"date_local", "TEXT", 1},
      {"range_start_unix_sec", "INTEGER", 1},
      {"range_end_unix_sec", "INTEGER", 1},
      {"foreground_sec", "INTEGER", 1},
      {"source", "TEXT", 1},
      {"first_synced_at", "INTEGER", 1},
      {"last_synced_at", "INTEGER", 1},
      {"created_at", "INTEGER", 1},
      {"updated_at", "INTEGER", 1},
  };
  const ExpectedColumn deviceUsageSessionColumns[] = {
      {"id", "INTEGER", 0},
      {"platform", "TEXT", 1},
      {"device_id", "TEXT", 1},
      {"app_identifier", "TEXT", 1},
      {"package_name", "TEXT", 1},
      {"session_start_unix_sec", "INTEGER", 1},
      {"session_end_unix_sec", "INTEGER", 1},
      {"duration_sec", "INTEGER", 1},
      {"source", "TEXT", 1},
      {"confidence", "TEXT", 1},
      {"created_at", "INTEGER", 1},
  };
  struct TableSchema {
    QString name;
    const ExpectedColumn* columns;
    int count;
  };
  const TableSchema schemaParityTables[] = {
      {QStringLiteral("apps"), guiAppsColumns,
       static_cast<int>(std::size(guiAppsColumns))},
      {QStringLiteral("device_usage_summaries"), deviceUsageColumns,
       static_cast<int>(std::size(deviceUsageColumns))},
      {QStringLiteral("device_usage_sessions"), deviceUsageSessionColumns,
       static_cast<int>(std::size(deviceUsageSessionColumns))},
  };
  for (const TableSchema& table : schemaParityTables) {
    QString mismatch;
    if (!columnsMatch(db, table.name, table.columns, table.count, &mismatch)) {
      return fail(QStringLiteral("GUI schema drift: %1").arg(mismatch));
    }
  }
  const TableSchema serviceSchemaTables[] = {
      {QStringLiteral("apps"), serviceAppsColumns,
       static_cast<int>(std::size(serviceAppsColumns))},
      {QStringLiteral("frontmost_sessions"), frontmostColumns,
       static_cast<int>(std::size(frontmostColumns))},
      {QStringLiteral("media_sessions"), mediaColumns,
       static_cast<int>(std::size(mediaColumns))},
  };
  for (const TableSchema& table : serviceSchemaTables) {
    QString mismatch;
    if (!columnsMatch(serviceDb, table.name, table.columns, table.count,
                      &mismatch)) {
      return fail(QStringLiteral("Service schema drift: %1").arg(mismatch));
    }
  }

  AppRepository appRepository;
  FrontmostSessionRepository frontmostRepository;
  MediaSessionRepository mediaRepository;
  MobileUsageRepository mobileUsageRepository;
  ManualProjectRepository manualProjectRepository;
  SettingsRepository settingsRepository;
  if (!manualProjectRepository.getActiveProjects().isEmpty()) {
    return fail(QStringLiteral("Empty database unexpectedly has projects."));
  }
  if (!settingsRepository
           .getValue(QStringLiteral("calendar_saved_todos"), QString())
           .isEmpty()) {
    return fail(QStringLiteral("Empty database unexpectedly has todos."));
  }
  if (settingsRepository.getBool(QStringLiteral("night_mode"), false)) {
    return fail(QStringLiteral("Empty database unexpectedly has night_mode."));
  }
  if (!settingsRepository.migrateLegacyQSettings(&manualProjectRepository)) {
    return fail(QStringLiteral("Legacy QSettings migration failed."));
  }
  if (!settingsRepository.migrateLegacyQSettings(&manualProjectRepository)) {
    return fail(QStringLiteral("Repeated legacy migration failed."));
  }

  StatsService statsService(&frontmostRepository, &mediaRepository,
                            &manualProjectRepository);
  CalendarManager calendarManager(&settingsRepository);
  ProjectManager projectManager(&manualProjectRepository);

  if (MobileUsageRepository::androidAppIdentifierForPackage(
          QStringLiteral(" com.spotify.music ")) !=
      QStringLiteral("android:com.spotify.music")) {
    return fail(QStringLiteral("Android app identifier normalization failed."));
  }
  if (MobileUsageRepository::androidPackageForIdentifier(
          QStringLiteral("android:com.spotify.music")) !=
      QStringLiteral("com.spotify.music")) {
    return fail(QStringLiteral("Android package normalization failed."));
  }
  const QString spotifyIconPath = QStringLiteral(
      "/data/user/0/com.timearc.app/files/app-icons/com.spotify.music.png");
  const QString youtubeIconPath = QStringLiteral(
      "/data/user/0/com.timearc.app/files/app-icons/com.google.android.youtube.png");
  if (!mobileUsageRepository.upsertDailyUsageSummary(
          QStringLiteral("pixel-usage-smoke"),
          QStringLiteral("com.spotify.music"),
          QStringLiteral("Spotify"),
          QStringLiteral("Spotify"),
          QStringLiteral("2026-06-29"),
          1782662400,
          1782748800,
          120,
          QStringLiteral("android_usage_stats_aggregate"),
          spotifyIconPath)) {
    return fail(QStringLiteral("Mobile usage summary insert failed."));
  }
  const QVariantMap spotifyAppAfterIconInsert = appRepository.getAppByIdentifier(
      QStringLiteral("android:com.spotify.music"));
  if (spotifyAppAfterIconInsert.value(QStringLiteral("appIconPath")).toString() !=
      spotifyIconPath) {
    return fail(QStringLiteral("Mobile usage first icon insert failed: %1")
                    .arg(spotifyAppAfterIconInsert
                             .value(QStringLiteral("appIconPath"))
                             .toString()));
  }
  if (!mobileUsageRepository.upsertDailyUsageSummary(
          QStringLiteral("pixel-usage-smoke"),
          QStringLiteral("com.spotify.music"),
          QStringLiteral("Spotify"),
          QStringLiteral("Spotify"),
          QStringLiteral("2026-06-29"),
          1782662400,
          1782748800,
          150,
          QStringLiteral("android_usage_stats_aggregate"),
          QString())) {
    return fail(QStringLiteral("Mobile usage summary upsert failed."));
  }
  const QVariantList mobileRows = mobileUsageRepository.getUsageByDateRange(
      QStringLiteral("2026-06-29"), QStringLiteral("2026-06-29"),
      QStringLiteral("android"));
  if (mobileRows.size() != 1) {
    return fail(QStringLiteral("Mobile usage summary was not upserted."));
  }
  const QVariantMap mobileRow = mobileRows.first().toMap();
  if (mobileRow.value(QStringLiteral("appIdentifier")).toString() !=
          QStringLiteral("android:com.spotify.music") ||
      mobileRow.value(QStringLiteral("packageName")).toString() !=
          QStringLiteral("com.spotify.music") ||
      mobileRow.value(QStringLiteral("foregroundSec")).toInt() != 150 ||
      mobileRow.value(QStringLiteral("source")).toString() !=
          QStringLiteral("android_usage_stats_aggregate") ||
      mobileRow.value(QStringLiteral("displayName")).toString() !=
          QStringLiteral("Spotify") ||
      mobileRow.value(QStringLiteral("appIconPath")).toString() !=
          spotifyIconPath) {
    return fail(QStringLiteral(
                    "Mobile usage summary fields are incorrect: id=%1 package=%2 "
                    "foreground=%3 source=%4 display=%5 icon=%6")
                    .arg(mobileRow.value(QStringLiteral("appIdentifier")).toString(),
                         mobileRow.value(QStringLiteral("packageName")).toString())
                    .arg(mobileRow.value(QStringLiteral("foregroundSec")).toInt())
                    .arg(mobileRow.value(QStringLiteral("source")).toString(),
                         mobileRow.value(QStringLiteral("displayName")).toString(),
                         mobileRow.value(QStringLiteral("appIconPath")).toString()));
  }
  if (mobileUsageRepository.getTotalForegroundSecondsByDateRange(
          QStringLiteral("2026-06-29"), QStringLiteral("2026-06-29"),
          QStringLiteral("android")) != 150) {
    return fail(QStringLiteral("Mobile usage total aggregation failed."));
  }
  if (!mobileUsageRepository.upsertDailyUsageSummary(
          QStringLiteral("pixel-usage-smoke"),
          QStringLiteral("com.google.android.youtube"),
          QStringLiteral("YouTube"),
          QStringLiteral("YouTube"),
          QStringLiteral("2026-06-29"),
          1782662400,
          1782748800,
          3700,
          QStringLiteral("android_usage_stats_aggregate"),
          youtubeIconPath)) {
    return fail(QStringLiteral("Second mobile usage summary insert failed."));
  }
  MobileUsageService mobileUsageService(&mobileUsageRepository);
  const QVariantMap mobileDashboard = mobileUsageService.getUsageDashboard(
      QStringLiteral("2026-06-29"), QStringLiteral("2026-06-29"));
  if (mobileDashboard.value(QStringLiteral("totalSec")).toInt() != 3850 ||
      mobileDashboard.value(QStringLiteral("totalText")).toString() !=
          QStringLiteral("1h 4m")) {
    return fail(QStringLiteral("Mobile usage dashboard total failed."));
  }
  const QVariantList dashboardApps =
      mobileDashboard.value(QStringLiteral("topApps")).toList();
  if (dashboardApps.size() != 2) {
    return fail(QStringLiteral("Mobile usage dashboard top app count failed."));
  }
  const QVariantMap firstDashboardApp = dashboardApps.first().toMap();
  if (firstDashboardApp.value(QStringLiteral("displayName")).toString() !=
          QStringLiteral("YouTube") ||
      firstDashboardApp.value(QStringLiteral("durationText")).toString() !=
          QStringLiteral("1h 1m") ||
      firstDashboardApp.value(QStringLiteral("sharePct")).toInt() != 96 ||
      firstDashboardApp.value(QStringLiteral("appIconPath")).toString() !=
          youtubeIconPath) {
    return fail(QStringLiteral("Mobile usage dashboard top app fields failed."));
  }
  if (!mobileUsageRepository.upsertDailyUsageSummary(
          QStringLiteral("pixel-usage-smoke"),
          QStringLiteral("com.spotify.music"),
          QStringLiteral("Spotify"),
          QStringLiteral("Spotify"),
          QStringLiteral("2026-06-30"),
          1782748800,
          1782835200,
          60,
          QStringLiteral("android_usage_stats_aggregate"),
          QString())) {
    return fail(QStringLiteral("Mobile usage second-day summary insert failed."));
  }
  const QVariantMap mobileMultiDayDashboard =
      mobileUsageService.getUsageDashboard(QStringLiteral("2026-06-29"),
                                           QStringLiteral("2026-06-30"));
  const QVariantList multiDayApps =
      mobileMultiDayDashboard.value(QStringLiteral("topApps")).toList();
  if (mobileMultiDayDashboard.value(QStringLiteral("activeDays")).toInt() != 2 ||
      mobileMultiDayDashboard.value(QStringLiteral("appCount")).toInt() != 2 ||
      multiDayApps.size() != 2) {
    return fail(QStringLiteral("Mobile dashboard app/day aggregation failed."));
  }
  const QVariantMap secondDashboardApp = multiDayApps.at(1).toMap();
  if (secondDashboardApp.value(QStringLiteral("displayName")).toString() !=
          QStringLiteral("Spotify") ||
      secondDashboardApp.value(QStringLiteral("foregroundSec")).toInt() != 210 ||
      secondDashboardApp.value(QStringLiteral("durationText")).toString() !=
          QStringLiteral("3m")) {
    return fail(QStringLiteral("Mobile dashboard did not merge app rows."));
  }
  if (MobileUsageService::startDateForRange(
          QStringLiteral("week"), QDate(2026, 7, 19)) != QDate(2026, 7, 13) ||
      MobileUsageService::startDateForRange(
          QStringLiteral("month"), QDate(2026, 7, 19)) != QDate(2026, 7, 1) ||
      MobileUsageService::startDateForRange(
          QStringLiteral("year"), QDate(2026, 7, 19)) != QDate(2026, 1, 1)) {
    return fail(QStringLiteral("Mobile calendar range semantics failed."));
  }
  // The fallback table holds the ENGLISH name, because that is the source
  // language; I18n translates it at the render site, so a Chinese reader still
  // sees 小红书. The table used to hold the Chinese name directly, which was
  // not language-aware in either direction: an English reader saw 小红书 and,
  // after the names were romanised, a Chinese reader would have seen "RED".
  //
  // A label the device itself supplied still wins over the table and is
  // returned untouched — that is what the com.tencent.mm case pins.
  if (MobileUsageService::friendlyDisplayName(
          QStringLiteral("com.xingin.xhs"), QString()) !=
          QStringLiteral("RED") ||
      MobileUsageService::friendlyDisplayName(
          QStringLiteral("com.tencent.mm"), QStringLiteral("微信")) !=
          QStringLiteral("微信") ||
      MobileUsageService::friendlyDisplayName(
          QStringLiteral("com.huawei.android.launcher.LauncherApplication"),
          QStringLiteral("com.huawei.android.launcher.LauncherApplication")) !=
          QStringLiteral("Huawei Home")) {
    return fail(QStringLiteral("Mobile friendly app naming failed."));
  }
  if (secondDashboardApp.value(QStringLiteral("firstDateLocal")).toString() !=
          QStringLiteral("2026-06-29") ||
      secondDashboardApp.value(QStringLiteral("recordedDays")).toInt() != 2 ||
      secondDashboardApp.value(QStringLiteral("spanDays")).toInt() != 2 ||
      secondDashboardApp.value(QStringLiteral("relativePct")).toInt() <= 0) {
    return fail(QStringLiteral("Mobile app evidence aggregation failed."));
  }
  const QVariantMap firstMultiDayApp = multiDayApps.at(0).toMap();
  const QString firstConversion =
      firstMultiDayApp.value(QStringLiteral("conversionText")).toString();
  const QString secondConversion =
      secondDashboardApp.value(QStringLiteral("conversionText")).toString();
  const QString firstConversionKind =
      firstMultiDayApp.value(QStringLiteral("conversionKind")).toString();
  const QString secondConversionKind =
      secondDashboardApp.value(QStringLiteral("conversionKind")).toString();
  if (firstConversion.isEmpty() || secondConversion.isEmpty() ||
      firstConversionKind.isEmpty() || secondConversionKind.isEmpty() ||
      firstConversionKind == secondConversionKind ||
      secondDashboardApp.value(QStringLiteral("storyText"))
          .toString()
          .isEmpty()) {
    return fail(QStringLiteral("Mobile share copy variety failed."));
  }
  const QVariantMap androidApp = appRepository.getAppByIdentifier(
      QStringLiteral("android:com.spotify.music"));
  if (androidApp.value(QStringLiteral("platform")).toString() !=
      QStringLiteral("android")) {
    return fail(QStringLiteral("Mobile usage did not upsert Android app row."));
  }
  if (androidApp.value(QStringLiteral("appIconPath")).toString() !=
      spotifyIconPath) {
    return fail(QStringLiteral("Mobile usage did not persist Android app icon."));
  }
  if (!mobileUsageRepository.addUsageSession(
          QStringLiteral("pixel-usage-smoke"),
          QStringLiteral("com.spotify.music"),
          QStringLiteral("Spotify"),
          QStringLiteral("Spotify"),
          1782700000,
          1782700125,
          QStringLiteral("android_usage_events"))) {
    return fail(QStringLiteral("Mobile usage session insert failed."));
  }
  if (!mobileUsageRepository.addUsageSession(
          QStringLiteral("pixel-usage-smoke"),
          QStringLiteral("com.spotify.music"),
          QStringLiteral("Spotify"),
          QStringLiteral("Spotify"),
          1782700200,
          1782700300,
          QStringLiteral("android_usage_events"),
          QStringLiteral("estimated"))) {
    return fail(QStringLiteral("Estimated mobile usage session insert failed."));
  }
  if (!mobileUsageRepository.addUsageSession(
          QStringLiteral("pixel-usage-smoke"),
          QStringLiteral("com.spotify.music"),
          QStringLiteral("Spotify"),
          QStringLiteral("Spotify"),
          1782700000,
          1782700125,
          QStringLiteral("android_usage_events"))) {
    return fail(QStringLiteral("Mobile duplicate session insert failed."));
  }
  const QVariantList mobileSessions = mobileUsageRepository.getSessionsByRange(
      1782700000, 1782700400, QStringLiteral("android"));
  if (mobileSessions.size() != 2) {
    return fail(QStringLiteral("Mobile usage session was not deduplicated."));
  }
  const QVariantMap mobileSession = mobileSessions.first().toMap();
  if (mobileSession.value(QStringLiteral("durationSec")).toInt() != 125 ||
      mobileSession.value(QStringLiteral("appIdentifier")).toString() !=
          QStringLiteral("android:com.spotify.music") ||
      mobileSession.value(QStringLiteral("source")).toString() !=
          QStringLiteral("android_usage_events") ||
      mobileSession.value(QStringLiteral("confidence")).toString() !=
          QStringLiteral("observed")) {
    return fail(QStringLiteral("Mobile usage session fields are incorrect."));
  }
  const QVariantMap estimatedMobileSession = mobileSessions.last().toMap();
  if (estimatedMobileSession.value(QStringLiteral("durationSec")).toInt() !=
          100 ||
      estimatedMobileSession.value(QStringLiteral("confidence")).toString() !=
          QStringLiteral("estimated")) {
    return fail(QStringLiteral("Estimated mobile usage session fields failed."));
  }

  const QString repairDate = QStringLiteral("2026-07-02");
  const QString aggregateSource =
      QStringLiteral("android_usage_stats_aggregate");
  if (!mobileUsageRepository.upsertDailyUsageSummary(
          QStringLiteral("pixel-usage-smoke"),
          QStringLiteral("com.example.stale"), QStringLiteral("Stale"),
          QStringLiteral("Stale"), repairDate, 1782950400, 1783036800,
          7200, aggregateSource) ||
      !mobileUsageRepository.upsertDailyUsageSummary(
          QStringLiteral("pixel-usage-smoke"),
          QStringLiteral("com.example.keep"), QStringLiteral("Keep"),
          QStringLiteral("Keep"), repairDate, 1782950400, 1783036800,
          90, QStringLiteral("manual_import")) ||
      !mobileUsageRepository.addUsageSession(
          QStringLiteral("pixel-usage-smoke"),
          QStringLiteral("com.example.stale"), QStringLiteral("Stale"),
          QStringLiteral("Stale"), 1783000000, 1783000060,
          QStringLiteral("android_usage_events"))) {
    return fail(QStringLiteral("Mobile daily repair fixture insert failed."));
  }
  if (!mobileUsageRepository.clearDailyUsageSummaries(
          QStringLiteral("pixel-usage-smoke"), repairDate,
          aggregateSource)) {
    return fail(QStringLiteral("Mobile daily aggregate clear failed."));
  }
  const QVariantList repairedRows = mobileUsageRepository.getUsageByDateRange(
      repairDate, repairDate, QStringLiteral("android"));
  if (repairedRows.size() != 1 ||
      repairedRows.first().toMap().value(QStringLiteral("source")).toString() !=
          QStringLiteral("manual_import")) {
    return fail(QStringLiteral(
        "Daily repair removed unrelated source or retained stale aggregate."));
  }
  const QVariantList preservedRepairSessions =
      mobileUsageRepository.getSessionsByRange(
          1783000000, 1783000100, QStringLiteral("android"));
  if (preservedRepairSessions.size() != 1) {
    return fail(QStringLiteral("Daily repair removed usage sessions."));
  }

  QVariantList insightDailyRows;
  for (int day = 11; day <= 17; ++day) {
    QVariantMap row;
    row.insert(QStringLiteral("dateLocal"),
               QStringLiteral("2026-03-%1").arg(day, 2, 10, QLatin1Char('0')));
    row.insert(QStringLiteral("foregroundSec"), 3600 + day * 10);
    row.insert(QStringLiteral("appIdentifier"),
               QStringLiteral("android:com.microsoft.vscode"));
    row.insert(QStringLiteral("packageName"),
               QStringLiteral("com.microsoft.vscode"));
    row.insert(QStringLiteral("displayName"),
               QStringLiteral("Visual Studio Code"));
    insightDailyRows.append(row);

    if (day >= 12) {
      QVariantMap companionRow;
      companionRow.insert(
          QStringLiteral("dateLocal"),
          QStringLiteral("2026-03-%1").arg(day, 2, 10, QLatin1Char('0')));
      companionRow.insert(QStringLiteral("foregroundSec"), 1800);
      companionRow.insert(QStringLiteral("appIdentifier"),
                          QStringLiteral("android:com.netease.cloudmusic"));
      companionRow.insert(QStringLiteral("packageName"),
                          QStringLiteral("com.netease.cloudmusic"));
      companionRow.insert(QStringLiteral("displayName"),
                          QStringLiteral("网易云音乐"));
      insightDailyRows.append(companionRow);
    }
  }

  const QDateTime longestStart(QDate(2026, 3, 18), QTime(18, 42),
                               QTimeZone::systemTimeZone());
  QVariantList insightSessions;
  QVariantMap observedSession;
  observedSession.insert(QStringLiteral("sessionStartUnixSec"),
                         longestStart.toSecsSinceEpoch());
  observedSession.insert(QStringLiteral("sessionEndUnixSec"),
                         longestStart.addSecs(2 * 3600 + 14 * 60)
                             .toSecsSinceEpoch());
  observedSession.insert(QStringLiteral("durationSec"),
                         2 * 3600 + 14 * 60);
  observedSession.insert(QStringLiteral("confidence"),
                         QStringLiteral("observed"));
  observedSession.insert(QStringLiteral("displayName"),
                         QStringLiteral("Visual Studio Code"));
  observedSession.insert(QStringLiteral("appIdentifier"),
                         QStringLiteral("android:com.microsoft.vscode"));
  insightSessions.append(observedSession);

  QVariantMap lateSession = observedSession;
  const QDateTime lateStart(QDate(2026, 3, 20), QTime(23, 42),
                            QTimeZone::systemTimeZone());
  lateSession.insert(QStringLiteral("sessionStartUnixSec"),
                     lateStart.toSecsSinceEpoch());
  lateSession.insert(QStringLiteral("sessionEndUnixSec"),
                     lateStart.addSecs(38 * 60).toSecsSinceEpoch());
  lateSession.insert(QStringLiteral("durationSec"), 38 * 60);
  insightSessions.append(lateSession);

  QVariantList previousRows;
  QVariantMap previousRow;
  previousRow.insert(QStringLiteral("dateLocal"),
                     QStringLiteral("2026-02-16"));
  previousRow.insert(QStringLiteral("foregroundSec"), 4 * 3600);
  previousRow.insert(QStringLiteral("appIdentifier"),
                     QStringLiteral("android:com.microsoft.vscode"));
  previousRow.insert(QStringLiteral("displayName"),
                     QStringLiteral("Visual Studio Code"));
  previousRows.append(previousRow);

  const QVariantMap insightReport =
      MobileUsageInsightEngine::buildMonthlyReport(
          QDate(2026, 3, 1), insightDailyRows, insightSessions, previousRows);
  if (insightReport.value(QStringLiteral("monthKey")).toString() !=
          QStringLiteral("2026-03") ||
      insightReport.value(QStringLiteral("activeDays")).toInt() != 7 ||
      insightReport.value(QStringLiteral("longestStreakDays")).toInt() != 7) {
    return fail(QStringLiteral("Monthly insight calendar facts failed."));
  }
  const QVariantMap longestInsight =
      insightReport.value(QStringLiteral("longestSession")).toMap();
  if (longestInsight.value(QStringLiteral("durationSec")).toInt() !=
          2 * 3600 + 14 * 60 ||
      longestInsight.value(QStringLiteral("confidence")).toString() !=
          QStringLiteral("observed")) {
    return fail(QStringLiteral("Monthly observed longest session failed."));
  }
  const QVariantList selectedInsights =
      insightReport.value(QStringLiteral("insights")).toList();
  if (selectedInsights.size() < 2 ||
      selectedInsights.first()
          .toMap()
          .value(QStringLiteral("kind"))
          .toString()
          .isEmpty()) {
    return fail(QStringLiteral("Monthly insight candidates were not selected."));
  }
  const QVariantMap companion =
      insightReport.value(QStringLiteral("companion")).toMap();
  if (companion.value(QStringLiteral("daysTogether")).toInt() != 6) {
    return fail(QStringLiteral("Monthly app companion detection failed."));
  }

  const QVariantMap serviceMonthlyReport =
      mobileUsageService.getMonthlyReport(QStringLiteral("2026-06"));
  if (serviceMonthlyReport.value(QStringLiteral("monthKey")).toString() !=
          QStringLiteral("2026-06") ||
      !serviceMonthlyReport.contains(QStringLiteral("profile")) ||
      serviceMonthlyReport.value(QStringLiteral("pages")).toList().size() != 6) {
    return fail(QStringLiteral("Monthly report service model failed."));
  }
  const QVariantMap memoryLake =
      mobileUsageService.getMemoryLakeForCurrentMonth();
  const QVariantMap memoryReport =
      memoryLake.value(QStringLiteral("report")).toMap();
  if (!memoryReport.contains(QStringLiteral("profile")) ||
      memoryReport.value(QStringLiteral("pages")).toList().size() != 6) {
    return fail(QStringLiteral("Memory Lake did not reuse monthly report."));
  }

  int projectChangedCount = 0;
  QObject::connect(&projectManager, &ProjectManager::projectsChanged, [&]() {
    ++projectChangedCount;
  });
  int calendarChangedCount = 0;
  QObject::connect(&calendarManager, &CalendarManager::calendarDataChanged,
                   [&]() { ++calendarChangedCount; });
  const qint64 now = QDateTime::currentSecsSinceEpoch();
  const qint64 todayStart =
      QDateTime::currentDateTime().date().startOfDay().toSecsSinceEpoch();

  if (countProjectsByName(manualProjectRepository.getActiveProjects(),
                          QStringLiteral("Legacy Project")) != 1) {
    return fail(QStringLiteral("Legacy project migration was not idempotent."));
  }

  const QVariantList migratedLegacySessions =
      manualProjectRepository.getSessionsByRange(todayStart, now + 24 * 60 * 60);
  int legacySessionCount = 0;
  for (const QVariant& item : migratedLegacySessions) {
    const QVariantMap session = item.toMap();
    if (session.value(QStringLiteral("displayName")).toString() ==
        QStringLiteral("Legacy Project")) {
      ++legacySessionCount;
    }
  }
  if (legacySessionCount != 1) {
    return fail(QStringLiteral("Legacy session migration was not idempotent."));
  }

  if (!calendarManager.savedTodos().contains(QStringLiteral("Legacy Todo"))) {
    return fail(QStringLiteral("Legacy todo was not migrated."));
  }

  if (!settingsRepository.getBool(QStringLiteral("night_mode"), false)) {
    return fail(QStringLiteral("Legacy night_mode was not migrated."));
  }

  if (!settingsRepository
           .getValue(QStringLiteral("local_memo_chat_messages"), QString())
           .contains(QStringLiteral("legacy memo"))) {
    return fail(QStringLiteral("Legacy memo chat was not migrated."));
  }

  const QString sqliteTodoJson =
      QStringLiteral("{\"2026-05-22\":[{\"text\":\"SQLite Todo\","
                     "\"done\":false,\"tag\":\"宸ヤ綔\","
                     "\"linkedProject\":\"\"}]}");
  const QString sqliteMemoJson =
      QStringLiteral("[{\"sender\":\"me\",\"message\":\"sqlite memo\","
                     "\"imagePath\":\"\",\"timeText\":\"2026-05-21 16:00\"}]");
  if (!settingsRepository.setValue(QStringLiteral("calendar_saved_todos"),
                                   sqliteTodoJson) ||
      !settingsRepository.setValue(QStringLiteral("local_memo_chat_messages"),
                                   sqliteMemoJson) ||
      !settingsRepository.setBool(QStringLiteral("night_mode"), false) ||
      !settingsRepository.setBool(
          QStringLiteral("legacy_qsettings_migration_v1_done"), false)) {
    return fail(QStringLiteral("Failed to seed SQLite overwrite guard values."));
  }
  if (!settingsRepository.migrateLegacyQSettings(&manualProjectRepository)) {
    return fail(QStringLiteral("Overwrite guard migration failed."));
  }
  if (settingsRepository
          .getValue(QStringLiteral("calendar_saved_todos"), QString()) !=
      sqliteTodoJson) {
    return fail(QStringLiteral("Legacy todo overwrote existing SQLite todo."));
  }
  if (settingsRepository
          .getValue(QStringLiteral("local_memo_chat_messages"), QString()) !=
      sqliteMemoJson) {
    return fail(QStringLiteral("Legacy memo overwrote existing SQLite memo."));
  }
  if (settingsRepository.getBool(QStringLiteral("night_mode"), true)) {
    return fail(QStringLiteral("Legacy night_mode overwrote SQLite value."));
  }
  if (countProjectsByName(manualProjectRepository.getActiveProjects(),
                          QStringLiteral("Legacy Project")) != 1) {
    return fail(QStringLiteral("Forced migration duplicated legacy project."));
  }

  const QString appIdentifier =
      QStringLiteral("C:/TimeArcSmoke/SmokeApp.exe");
  if (!appRepository.upsertApp(appIdentifier, QStringLiteral("SmokeApp.exe"),
                               QStringLiteral("Smoke App"), QString(),
                               appIdentifier, QStringLiteral("windows"))) {
    return fail(QStringLiteral("Failed to insert smoke app."));
  }

  const QVariantMap insertedApp =
      appRepository.getAppByIdentifier(appIdentifier);
  if (insertedApp.value(QStringLiteral("appIdentifier")).toString() !=
          appIdentifier ||
      insertedApp.value(QStringLiteral("displayName")).toString() !=
          QStringLiteral("Smoke App")) {
    return fail(QStringLiteral("Inserted app was not returned by repository."));
  }

  const qint64 startUnixSec = qMax(todayStart, now - 90);
  const qint64 endUnixSec = now;
  const int expectedDuration = static_cast<int>(endUnixSec - startUnixSec);
  if (expectedDuration <= 0) {
    return fail(QStringLiteral("Unable to create a positive smoke interval."));
  }

  {
    const QString conn = QStringLiteral("service_seed_live");
    {
      QSqlDatabase writer =
          QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), conn);
      writer.setDatabaseName(serviceDatabasePath);
      if (!writer.open()) {
        return fail(QStringLiteral("Could not open service writer fixture: %1")
                        .arg(writer.lastError().text()));
      }
      QString error;
      if (!seedServiceApp(writer, appIdentifier,
                          QStringLiteral("SmokeApp.exe"),
                          QStringLiteral("Smoke App"), appIdentifier,
                          QStringLiteral("windows"), &error) ||
          !seedServiceFrontmost(writer, appIdentifier,
                                QStringLiteral("Smoke Window"), startUnixSec,
                                endUnixSec, &error)) {
        return fail(QStringLiteral("Failed to seed service frontmost row: %1")
                        .arg(error));
      }
      writer.close();
    }
    QSqlDatabase::removeDatabase(conn);
  }

  const QVariantList sessions =
      frontmostRepository.getSessionsByRange(startUnixSec - 1, endUnixSec + 1);
  if (!hasInsertedSession(sessions, appIdentifier, startUnixSec, endUnixSec)) {
    return fail(QStringLiteral("Inserted session was not returned by range query."));
  }

  const int aggregateSeconds =
      frontmostRepository.getTotalActiveSecondsByRange(startUnixSec - 1,
                                                       endUnixSec + 1);
  if (aggregateSeconds != expectedDuration) {
    return fail(QStringLiteral("Aggregate mismatch. Expected %1, got %2.")
                    .arg(expectedDuration)
                    .arg(aggregateSeconds));
  }

  const QVariantMap summary = statsService.getHomeSummary();
  if (summary.value(QStringLiteral("frontmostActiveSec")).toInt() !=
      expectedDuration) {
    return fail(QStringLiteral("StatsService summary did not reflect the "
                               "inserted session."));
  }

  const QString mediaTitle =
      QStringLiteral("lofi study beats - Bilibili - Google Chrome");
  const qint64 mediaStart = startUnixSec + 1;
  const qint64 mediaEnd = qMax(mediaStart + 1, endUnixSec);
  const int mediaDuration = static_cast<int>(mediaEnd - mediaStart);
  Q_UNUSED(mediaDuration);
  {
    const QString conn = QStringLiteral("service_seed_media");
    {
      QSqlDatabase writer =
          QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), conn);
      writer.setDatabaseName(serviceDatabasePath);
      if (!writer.open()) {
        return fail(QStringLiteral("Could not open service media fixture: %1")
                        .arg(writer.lastError().text()));
      }
      QString error;
      if (!seedServiceMedia(writer, appIdentifier, QStringLiteral("audio"),
                            mediaTitle, mediaStart, mediaEnd, &error)) {
        return fail(QStringLiteral("Failed to seed service media row: %1")
                        .arg(error));
      }
      writer.close();
    }
    QSqlDatabase::removeDatabase(conn);
  }
  const QVariantList mediaSessions =
      mediaRepository.getSessionsByRange(mediaStart - 1, mediaEnd + 1);
  bool sawMediaTitle = false;
  for (const QVariant& item : mediaSessions) {
    const QVariantMap session = item.toMap();
    if (session.value(QStringLiteral("appIdentifier")).toString() ==
            appIdentifier &&
        session.value(QStringLiteral("mediaTitle")).toString() == mediaTitle) {
      sawMediaTitle = true;
    }
  }
  if (!sawMediaTitle) {
    return fail(QStringLiteral("Media title was not persisted."));
  }

  bool sawRankingMediaTitle = false;
  for (const QVariant& item : mediaRepository.getTodayMediaRanking()) {
    const QVariantMap ranking = item.toMap();
    if (ranking.value(QStringLiteral("appIdentifier")).toString() ==
            appIdentifier &&
        ranking.value(QStringLiteral("mediaTitle")).toString() == mediaTitle) {
      sawRankingMediaTitle = true;
    }
  }
  if (!sawRankingMediaTitle) {
    return fail(QStringLiteral("Media title was not exposed in ranking."));
  }

  const int projectSignalsBeforeAdd = projectChangedCount;
  const QString projectName = QStringLiteral("Smoke Project");
  projectManager.addProject(projectName, QStringLiteral("工作"));
  const QVariantList activeProjects = projectManager.projects();
  if (projectChangedCount <= projectSignalsBeforeAdd) {
    return fail(QStringLiteral("Project add did not emit projectsChanged."));
  }
  if (activeProjects.isEmpty()) {
    return fail(QStringLiteral("ProjectManager did not expose inserted project."));
  }

  const int projectSignalsBeforeTimer = projectChangedCount;
  projectManager.addElapsedTimeForTagOnDate(
      projectName, QStringLiteral("工作"), 600,
      QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd")));
  if (projectChangedCount <= projectSignalsBeforeTimer) {
    return fail(QStringLiteral("Timer commit did not emit projectsChanged."));
  }
  if (projectManager.todayProjectMinutes() < 10) {
    return fail(QStringLiteral("Timer/manual project session was not aggregated."));
  }
  if (statsService.getTodayManualProjectSeconds() < 600) {
    return fail(QStringLiteral("StatsService manual total missed timer session."));
  }

  const QVariantList todayProjects = projectManager.projectsForRange("day");
  if (!containsProjectWithSeconds(todayProjects, projectName, 600)) {
    return fail(QStringLiteral("Manual session was not returned in day ranking."));
  }
  int smokeProjectId = -1;
  for (const QVariant& item : projectManager.projects()) {
    const QVariantMap project = item.toMap();
    if (project.value(QStringLiteral("name")).toString() == projectName) {
      smokeProjectId = project.value(QStringLiteral("id")).toInt();
    }
  }
  if (smokeProjectId <= 0) {
    return fail(QStringLiteral("Smoke project id was not exposed."));
  }

  const int duplicateProjectId = manualProjectRepository.ensureProject(
      QStringLiteral("Duplicate Session Project"), QStringLiteral("宸ヤ綔"));
  const qint64 duplicateStart = todayStart + 2 * 60 * 60;
  const qint64 duplicateEnd = duplicateStart + 300;
  if (!manualProjectRepository.addManualSessionEntry(
          duplicateProjectId, duplicateStart, duplicateEnd, 300,
          QStringLiteral("Duplicate Smoke Session"),
          QStringLiteral("manual_project"), QString()) ||
      !manualProjectRepository.addManualSessionEntry(
          duplicateProjectId, duplicateStart, duplicateEnd, 300,
          QStringLiteral("Duplicate Smoke Session"),
          QStringLiteral("manual_project"), QString())) {
    return fail(QStringLiteral("Duplicate session insert returned failure."));
  }
  if (countSessionsByDisplayName(
          manualProjectRepository.getSessionsByRange(duplicateStart - 1,
                                                     duplicateEnd + 1),
          QStringLiteral("Duplicate Smoke Session")) != 1) {
    return fail(QStringLiteral("Duplicate timer session was inserted twice."));
  }
  if (manualProjectRepository.getProjectById(duplicateProjectId)
          .value(QStringLiteral("totalDurationSec"))
          .toInt() != 300) {
    return fail(QStringLiteral("Duplicate session double-counted project total."));
  }

  const int crossDayProjectId = manualProjectRepository.ensureProject(
      QStringLiteral("Cross Day Project"), QStringLiteral("宸ヤ綔"));
  const qint64 crossDayStart = todayStart - 5 * 60;
  const qint64 crossDayEnd = todayStart + 5 * 60;
  if (!manualProjectRepository.addManualSessionEntry(
          crossDayProjectId, crossDayStart, crossDayEnd, 600,
          QStringLiteral("Cross Day Session"),
          QStringLiteral("manual_project"), QString())) {
    return fail(QStringLiteral("Cross-day manual session insert failed."));
  }
  if (countSessionsByDisplayName(
          manualProjectRepository.getSessionsByRange(todayStart - 24 * 60 * 60,
                                                     todayStart),
          QStringLiteral("Cross Day Session")) != 1 ||
      countSessionsByDisplayName(
          manualProjectRepository.getSessionsByRange(todayStart,
                                                     todayStart + 24 * 60 * 60),
          QStringLiteral("Cross Day Session")) != 1) {
    return fail(QStringLiteral("Cross-day session was dropped by range query."));
  }
  if (!containsProjectWithSeconds(
          manualProjectRepository.getProjectRankingByRange(
              todayStart - 24 * 60 * 60, todayStart),
          QStringLiteral("Cross Day Project"), 600) ||
      !containsProjectWithSeconds(
          manualProjectRepository.getProjectRankingByRange(
              todayStart, todayStart + 24 * 60 * 60),
          QStringLiteral("Cross Day Project"), 600)) {
    return fail(QStringLiteral("Cross-day project stats were not retained."));
  }

  const int projectSignalsBeforeRemove = projectChangedCount;
  projectManager.removeProject(projectName);
  if (projectChangedCount <= projectSignalsBeforeRemove) {
    return fail(QStringLiteral("Project archive did not emit projectsChanged."));
  }
  for (const QVariant& item : projectManager.projects()) {
    if (item.toMap().value(QStringLiteral("name")).toString() == projectName) {
      return fail(QStringLiteral("Archived project is still active."));
    }
  }
  if (projectManager.projectsForRange("day").isEmpty()) {
    return fail(QStringLiteral("Archived project history disappeared from stats."));
  }
  ProjectManager restartedProjectManager(&manualProjectRepository);
  for (const QVariant& item : restartedProjectManager.projects()) {
    if (item.toMap().value(QStringLiteral("name")).toString() == projectName) {
      return fail(QStringLiteral("Archived project reappeared after reload."));
    }
  }
  if (restartedProjectManager.projectsForRange("day").isEmpty()) {
    return fail(QStringLiteral("Archived project stats disappeared after reload."));
  }
  const QVariantMap archivedProject =
      manualProjectRepository.getProjectById(smokeProjectId);
  if (!archivedProject.value(QStringLiteral("isArchived")).toBool()) {
    return fail(QStringLiteral("Project archive flag was not persisted."));
  }
  const int archivedTotalBeforeNewSession =
      archivedProject.value(QStringLiteral("totalDurationSec")).toInt();
  projectManager.addElapsedTimeForTagOnDate(
      projectName, QStringLiteral("宸ヤ綔"), 120,
      QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd")));
  if (manualProjectRepository.getProjectById(smokeProjectId)
          .value(QStringLiteral("totalDurationSec"))
          .toInt() != archivedTotalBeforeNewSession) {
    return fail(QStringLiteral("New session was written into archived project."));
  }
  bool sawReplacementActiveProject = false;
  for (const QVariant& item : projectManager.projects()) {
    const QVariantMap project = item.toMap();
    if (project.value(QStringLiteral("name")).toString() == projectName &&
        project.value(QStringLiteral("id")).toInt() != smokeProjectId &&
        project.value(QStringLiteral("seconds")).toInt() >= 120) {
      sawReplacementActiveProject = true;
    }
  }
  if (!sawReplacementActiveProject) {
    return fail(QStringLiteral("Archived project did not stay hidden from new session target."));
  }

  QJsonObject todosRoot;
  QJsonArray todos;
  QJsonObject todo;
  todo.insert(QStringLiteral("text"), QStringLiteral("Smoke Todo"));
  todo.insert(QStringLiteral("done"), false);
  todo.insert(QStringLiteral("tag"), QStringLiteral("工作"));
  todo.insert(QStringLiteral("linkedProject"), QString());
  todos.append(todo);
  const QString todayKey = QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd"));
  todosRoot.insert(todayKey, todos);
  const int calendarSignalsBeforeSave = calendarChangedCount;
  calendarManager.setSavedTodos(
      QString::fromUtf8(QJsonDocument(todosRoot).toJson(QJsonDocument::Compact)));
  if (calendarChangedCount <= calendarSignalsBeforeSave) {
    return fail(QStringLiteral("Todo save did not emit calendarDataChanged."));
  }
  const int calendarSignalsBeforeComplete = calendarChangedCount;
  calendarManager.completeTodo(todayKey, QStringLiteral("Smoke Todo"));
  if (calendarChangedCount <= calendarSignalsBeforeComplete) {
    return fail(QStringLiteral("Todo completion did not emit calendarDataChanged."));
  }
  const QJsonDocument completedDoc =
      QJsonDocument::fromJson(calendarManager.savedTodos().toUtf8());
  if (!completedDoc.object()
           .value(todayKey)
           .toArray()
           .first()
           .toObject()
           .value(QStringLiteral("done"))
           .toBool()) {
    return fail(QStringLiteral("Calendar todo completion was not persisted."));
  }
  todosRoot.insert(todayKey, QJsonArray());
  calendarManager.setSavedTodos(
      QString::fromUtf8(QJsonDocument(todosRoot).toJson(QJsonDocument::Compact)));
  CalendarManager restartedCalendarManager(&settingsRepository);
  const QJsonDocument deletedTodoDoc =
      QJsonDocument::fromJson(restartedCalendarManager.savedTodos().toUtf8());
  if (!deletedTodoDoc.object().value(todayKey).toArray().isEmpty()) {
    return fail(QStringLiteral("Deleted todo reappeared after reload."));
  }

  if (!settingsRepository.setBool(QStringLiteral("night_mode"), true) ||
      !settingsRepository.getBool(QStringLiteral("night_mode"), false)) {
    return fail(QStringLiteral("Night mode setting did not persist."));
  }
  SettingsRepository restartedSettingsRepository;
  if (!restartedSettingsRepository.getBool(QStringLiteral("night_mode"), false)) {
    return fail(QStringLiteral("Night mode setting did not reload."));
  }

  const QString rawMemoJson =
      QStringLiteral("[{\"sender\":\"me\",\"message\":\"smoke memo\","
                     "\"imagePath\":\"\",\"timeText\":\"2026-05-21 15:00\"},"
                     "{\"sender\":\"me\",\"message\":\"   \","
                     "\"imagePath\":\"\",\"timeText\":\"2026-05-21 14:30\"},"
                     "{\"sender\":\"me\",\"message\":\"older smoke memo\","
                     "\"imagePath\":\"\",\"timeText\":\"2026-05-21 14:00\"}]");
  const QString memoJson = normalizedMemoMessagesJson(rawMemoJson);
  if (memoJson.contains(QStringLiteral("\"message\":\"   \""))) {
    return fail(QStringLiteral("Blank local memo message was saved."));
  }
  if (!settingsRepository.setValue(QStringLiteral("local_memo_chat_messages"),
                                   memoJson) ||
      settingsRepository
              .getValue(QStringLiteral("local_memo_chat_messages"), QString()) !=
          memoJson) {
    return fail(QStringLiteral("Local memo chat message did not persist."));
  }
  if (restartedSettingsRepository
          .getValue(QStringLiteral("local_memo_chat_messages"), QString()) !=
      memoJson) {
    return fail(QStringLiteral("Local memo chat message did not reload."));
  }
  const QStringList sortedMemoMessages = memoMessagesSortedByTime(
      restartedSettingsRepository.getValue(
          QStringLiteral("local_memo_chat_messages"), QString()));
  if (sortedMemoMessages !=
      QStringList({QStringLiteral("older smoke memo"),
                   QStringLiteral("smoke memo")})) {
    return fail(QStringLiteral("Local memo chat messages did not sort by time."));
  }
  if (!settingsRepository.setValue(QStringLiteral("local_memo_chat_messages"),
                                   QStringLiteral("[]"))) {
    return fail(QStringLiteral("Local memo clear did not persist."));
  }
  SettingsRepository clearedMemoSettingsRepository;
  if (!memoMessagesSortedByTime(clearedMemoSettingsRepository.getValue(
           QStringLiteral("local_memo_chat_messages"), QString()))
           .isEmpty()) {
    return fail(QStringLiteral("Local memo clear did not reload as empty."));
  }

  // ---- GUI DB backup / inspect / restore round-trip --------------------------
  // Exercises DatabaseManager::backupDatabase / inspectBackup / restoreDatabase
  // (folded into the already-linked database_manager.cpp; no USM symbols).
  {
    const QString d1Bak =
        QDir::temp().filePath(QStringLiteral("timearc-d1-roundtrip.db"));
    const QString d1Bad =
        QDir::temp().filePath(QStringLiteral("timearc-d1-bad.db"));
    const QString d1Empty =
        QDir::temp().filePath(QStringLiteral("timearc-d1-empty.db"));
    QFile::remove(d1Bak);
    QFile::remove(d1Bad);
    QFile::remove(d1Empty);

    const QString backupKey = QStringLiteral("d1_backup_restore_marker");
    // Release main()'s long-lived handle so restoreDatabase can fully close the
    // connection (else Windows keeps the file locked and the swap fails).
    db = QSqlDatabase();
    {
      QSqlDatabase live = databaseManager.database();
      if (!live.isValid() || !live.isOpen())
        return fail(QStringLiteral("D1: live connection unavailable."));

      QSqlQuery seed(live);
      seed.prepare(QStringLiteral(
          "INSERT INTO settings (key, value, updated_at) "
          "VALUES (:key, 'before-backup', 1700000000) "
          "ON CONFLICT(key) DO UPDATE SET value='before-backup', "
          "updated_at=1700000000;"));
      seed.bindValue(QStringLiteral(":key"), backupKey);
      if (!seed.exec())
        return fail(QStringLiteral("D1: seed setting failed: %1")
                        .arg(seed.lastError().text()));

      // Backup to an explicit temp path.
      const QString written = databaseManager.backupDatabase(d1Bak);
      if (written.isEmpty() || !QFileInfo::exists(d1Bak))
        return fail(QStringLiteral("D1: backupDatabase produced no file."));

      // Inspect: must validate and report matching counts.
      const QVariantMap insp = databaseManager.inspectBackup(d1Bak);
      if (!insp.value(QStringLiteral("ok")).toBool())
        return fail(
            QStringLiteral("D1: inspectBackup rejected a valid backup: %1")
                .arg(insp.value(QStringLiteral("error")).toString()));
      if (insp.value(QStringLiteral("integrity")).toString() !=
          QStringLiteral("ok"))
        return fail(QStringLiteral("D1: inspectBackup integrity != ok."));
      if (insp.value(QStringLiteral("settingsRows")).toLongLong() <= 0)
        return fail(QStringLiteral("D1: inspectBackup did not report GUI rows."));

      // Mutate the live DB, confirm the loss.
      QSqlQuery mutate(live);
      mutate.prepare(QStringLiteral(
          "UPDATE settings SET value='after-backup' WHERE key=:key;"));
      mutate.bindValue(QStringLiteral(":key"), backupKey);
      if (!mutate.exec())
        return fail(QStringLiteral("D1: setting mutation failed."));
    }  // 'live' destroyed -> no lingering reference for the swap

    // Restore: the backed-up setting value must recover.
    if (!databaseManager.restoreDatabase(d1Bak))
      return fail(QStringLiteral("D1: restoreDatabase returned false."));
    QSqlDatabase restored = databaseManager.database();
    if (!restored.isValid() || !restored.isOpen())
      return fail(QStringLiteral("D1: connection not reopened after restore."));
    QSqlQuery restoredValue(restored);
    restoredValue.prepare(QStringLiteral(
        "SELECT value FROM settings WHERE key=:key LIMIT 1;"));
    restoredValue.bindValue(QStringLiteral(":key"), backupKey);
    if (!restoredValue.exec() || !restoredValue.next() ||
        restoredValue.value(0).toString() != QStringLiteral("before-backup")) {
      return fail(QStringLiteral("D1: restore did not recover GUI setting."));
    }

    // Bad-file rejection: a non-sqlite file must be refused.
    {
      QFile bad(d1Bad);
      if (!bad.open(QIODevice::WriteOnly))
        return fail(QStringLiteral("D1: could not write bad-file fixture."));
      bad.write("this is definitely not a sqlite database");
      bad.close();
    }
    if (databaseManager.inspectBackup(d1Bad)
            .value(QStringLiteral("ok"))
            .toBool())
      return fail(
          QStringLiteral("D1: inspectBackup accepted a non-sqlite file."));

    // Missing-tables rejection: a valid sqlite db without the GUI contract tables.
    {
      QSqlDatabase ed = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"),
                                                  QStringLiteral("d1_empty"));
      ed.setDatabaseName(d1Empty);
      if (ed.open()) {
        QSqlQuery eq(ed);
        eq.exec(QStringLiteral("CREATE TABLE foo (x INTEGER);"));
        ed.close();
      }
    }
    QSqlDatabase::removeDatabase(QStringLiteral("d1_empty"));
    if (databaseManager.inspectBackup(d1Empty)
            .value(QStringLiteral("ok"))
            .toBool())
      return fail(QStringLiteral(
          "D1: inspectBackup accepted a sqlite file without contract tables."));

    // Cleanup fixtures + the pre-restore backup the restore left behind.
    QFile::remove(d1Bak);
    QFile::remove(d1Bad);
    QFile::remove(d1Empty);
    QFile::remove(databasePath + QStringLiteral(".pre-restore.bak"));
    qInfo().noquote()
        << QStringLiteral("D1 backup/inspect/restore round-trip ok.");
  }

  // ---- D2: cross-process database.dir pointer + UI relocation round-trip ----
  // S1: getServiceDatabasePath() honors service_config.json database.dir
  // (resolve / absent / corrupt -> default; configured dir wins). The retired
  // flat db_dir is never consulted. S2: relocateDatabaseTo writes only the
  // pointer; restoreDefaultDatabaseLocation clears it. In test mode the control
  // file lives under the test-mode AppData (testDataPath), so this never
  // touches the real user's config dir. Pure QtCore + QtSql (no USM).
  {
    const QString configPath =
        QDir(testDataPath).filePath(QStringLiteral("service_config.json"));
    const QString legacyPath =
        QDir(testDataPath).filePath(QStringLiteral("usage_config.json"));
    auto writeFile = [&](const QString& path, const QByteArray& content) -> bool {
      QDir().mkpath(testDataPath);
      QFile f(path);
      if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
      const bool ok = f.write(content) == content.size();
      f.close();
      return ok;
    };
    auto writeConfig = [&](const QByteArray& content) {
      return writeFile(configPath, content);
    };
    auto removeConfig = [&]() {
      QFile::remove(configPath);
      QFile::remove(legacyPath);
    };
    // v1 document carrying only database.dir.
    auto v1Doc = [](const QString& dir) -> QByteArray {
      QJsonObject db;
      db.insert(QStringLiteral("dir"), dir);
      QJsonObject o;
      o.insert(QStringLiteral("schema_version"), 1);
      o.insert(QStringLiteral("database"), db);
      return QJsonDocument(o).toJson();
    };
    auto configDbDir = [&]() -> QString {
      QFile f(configPath);
      if (!f.exists() || !f.open(QIODevice::ReadOnly)) return QString();
      const QByteArray b = f.readAll();
      f.close();
      const QJsonDocument d = QJsonDocument::fromJson(b);
      if (!d.isObject()) return QString();
      return d.object()
          .value(QStringLiteral("database"))
          .toObject()
          .value(QStringLiteral("dir"))
          .toString();
    };
    auto cleaned = [](const QString& p) { return QDir::cleanPath(p); };

    removeConfig();
    const QString defaultDbPath = databaseManager.getServiceDatabasePath();
    if (cleaned(defaultDbPath) != cleaned(serviceDatabasePath)) {
      return fail(QStringLiteral("D2 S1: service default path drifted from the original."));
    }

    // S1 state 1: a usable redirect wins.
    const QString customDir = QDir::temp().filePath(QStringLiteral("timearc-d2-custom"));
    QDir(customDir).removeRecursively();
    QDir().mkpath(customDir);
    const QString customDb =
        QDir::cleanPath(QDir(customDir).filePath(QStringLiteral("timearc_service.db")));
    if (!writeConfig(v1Doc(customDir)))
      return fail(QStringLiteral("D2 S1: could not write redirect config."));
    if (cleaned(databaseManager.getServiceDatabasePath()) != customDb)
      return fail(QStringLiteral("D2 S1: redirect database.dir was not honored."));

    // S1 state 2: key absent -> default. A v1 file that parses decides on its
    // own, so an unrelated tracking key must not resurrect the default lookup.
    if (!writeConfig(QByteArrayLiteral(
            "{\"schema_version\":1,\"tracking\":{\"enabled\":true}}")))
      return fail(QStringLiteral("D2 S1: could not write absent-key config."));
    if (cleaned(databaseManager.getServiceDatabasePath()) != cleaned(defaultDbPath))
      return fail(QStringLiteral("D2 S1: absent database.dir did not fall back."));

    // S1 state 3: corrupt JSON -> default (no legacy file present).
    if (!writeConfig(QByteArrayLiteral("{ this is not valid json ")))
      return fail(QStringLiteral("D2 S1: could not write corrupt config."));
    if (cleaned(databaseManager.getServiceDatabasePath()) != cleaned(defaultDbPath))
      return fail(QStringLiteral("D2 S1: corrupt config did not fall back."));

    // S1 state 4: database.dir wins even before its path is opened/created.
    const QString blocker =
        QDir::temp().filePath(QStringLiteral("timearc-d2-blocker"));
    QFile::remove(blocker);
    {
      QFile bf(blocker);
      if (!bf.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return fail(QStringLiteral("D2 S1: could not write blocker file."));
      bf.write("x");
      bf.close();
    }
    if (!writeConfig(v1Doc(QDir(blocker).filePath(QStringLiteral("sub")))))
      return fail(QStringLiteral("D2 S1: could not write unusable config."));
    const QString unusableDb =
        QDir::cleanPath(QDir(blocker).filePath(QStringLiteral("sub/timearc_service.db")));
    if (cleaned(databaseManager.getServiceDatabasePath()) != unusableDb)
      return fail(QStringLiteral("D2 S1: configured database.dir was not prioritized."));
    QFile::remove(blocker);
    removeConfig();

    // S1 state 5 (legacy retirement): the retired flat db_dir is never read.
    // Even as the ONLY control file present, it must not redirect anything --
    // this is what makes an old relocated install fall back to the default
    // until the user re-selects the directory. Must match database_path.c.
    {
      QJsonObject legacy;
      legacy.insert(QStringLiteral("db_dir"), customDir);
      if (!writeFile(legacyPath, QJsonDocument(legacy).toJson()))
        return fail(QStringLiteral("D2 S1: could not write legacy config."));
    }
    if (cleaned(databaseManager.getServiceDatabasePath()) != cleaned(defaultDbPath))
      return fail(QStringLiteral("D2 S1: retired db_dir was still honored."));
    removeConfig();

    // S2: pointer round-trip. The GUI no longer moves or writes the service DB
    // file; it only updates the config the service reads at startup.
    if (cleaned(databaseManager.getServiceDatabasePath()) != cleaned(defaultDbPath))
      return fail(QStringLiteral("D2 S2: not at default before relocate."));

    const QString d2Dir = QDir::temp().filePath(QStringLiteral("timearc-d2-reloc"));
    QDir(d2Dir).removeRecursively();
    QDir().mkpath(d2Dir);
    const QString movedDb =
        QDir::cleanPath(QDir(d2Dir).filePath(QStringLiteral("timearc_service.db")));

    // Pass the file:// URL form the QML FolderDialog actually hands back (NOT a
    // plain path), so this exercises the toLocalPath URL->path conversion the
    // settings 迁移到… button relies on -- the one seam between the dialog and
    // the migration engine.
    const QString d2DirUrl = QUrl::fromLocalFile(d2Dir).toString();
    const QVariantMap mv = databaseManager.relocateDatabaseTo(d2DirUrl);
    if (!mv.value(QStringLiteral("ok")).toBool())
      return fail(QStringLiteral("D2 S2: relocate failed: %1")
                      .arg(mv.value(QStringLiteral("error")).toString()));
    if (cleaned(databaseManager.getServiceDatabasePath()) != movedDb)
      return fail(QStringLiteral("D2 S2: service path did not follow database.dir."));
    if (cleaned(configDbDir()) != cleaned(d2Dir))
      return fail(QStringLiteral("D2 S2: pointer was not written to the new dir."));
    if (QFileInfo::exists(movedDb))
      return fail(QStringLiteral("D2 S2: GUI unexpectedly created service DB."));

    // Round-trip: restore default (clears the pointer).
    const QVariantMap rv = databaseManager.restoreDefaultDatabaseLocation();
    if (!rv.value(QStringLiteral("ok")).toBool())
      return fail(QStringLiteral("D2 S2: restore-default failed: %1")
                      .arg(rv.value(QStringLiteral("error")).toString()));
    if (cleaned(databaseManager.getServiceDatabasePath()) != cleaned(defaultDbPath))
      return fail(QStringLiteral("D2 S2: service path did not return to default."));
    if (!QFileInfo::exists(defaultDbPath))
      return fail(QStringLiteral("D2 S2: default DB missing after restore."));
    if (!configDbDir().isEmpty())
      return fail(QStringLiteral("D2 S2: pointer was not cleared on restore."));

    QDir(d2Dir).removeRecursively();
    QDir(customDir).removeRecursively();
    removeConfig();
    qInfo().noquote()
        << QStringLiteral("D2 database.dir pointer + relocate round-trip ok.");
  }

  // ---- UI->service config channel (idle / track) ----------------------------
  // DatabaseManager::writeServiceConfig writes tracking.frontmost.
  // idle_threshold_sec + tracking.enabled into the SAME service_config.json the
  // database.dir pointer lives in, through the shared patchServiceConfig RMW
  // helper. Asserts: values land nested with the right types and in SECONDS,
  // idleSec<0 omits the key while 0 is a real "never idle" value, the retired
  // usage_config.json is never written, and -- the headline invariant (#3) --
  // the two writers preserve each other's keys in BOTH directions. Test mode
  // keeps the file under testDataPath.
  {
    const QString configPath =
        QDir(testDataPath).filePath(QStringLiteral("service_config.json"));
    const QString legacyPath =
        QDir(testDataPath).filePath(QStringLiteral("usage_config.json"));
    auto readObj = [&](const QString& path) -> QJsonObject {
      QFile f(path);
      if (!f.exists() || !f.open(QIODevice::ReadOnly)) return QJsonObject();
      const QByteArray b = f.readAll();
      f.close();
      const QJsonDocument d = QJsonDocument::fromJson(b);
      return d.isObject() ? d.object() : QJsonObject();
    };
    auto readConfigObj = [&]() { return readObj(configPath); };
    auto idleValue = [&]() -> QJsonValue {
      return readConfigObj()
          .value(QStringLiteral("tracking"))
          .toObject()
          .value(QStringLiteral("frontmost"))
          .toObject()
          .value(QStringLiteral("idle_threshold_sec"));
    };
    auto trackValue = [&]() -> QJsonValue {
      return readConfigObj()
          .value(QStringLiteral("tracking"))
          .toObject()
          .value(QStringLiteral("enabled"));
    };
    auto dbDirValue = [&]() -> QString {
      return readConfigObj()
          .value(QStringLiteral("database"))
          .toObject()
          .value(QStringLiteral("dir"))
          .toString();
    };
    QFile::remove(configPath);
    QFile::remove(legacyPath);

    // 1. Basic write: both keys land nested, with the right values + JSON types,
    //    and the document is stamped as v1.
    if (!databaseManager.writeServiceConfig(300, false))
      return fail(QStringLiteral("config: writeServiceConfig returned false."));
    {
      if (readConfigObj().value(QStringLiteral("schema_version")).toInt() != 1)
        return fail(QStringLiteral("config: schema_version was not stamped."));
      if (!idleValue().isDouble() || idleValue().toInt() != 300)
        return fail(QStringLiteral("config: idle_threshold_sec not written as 300."));
      if (!trackValue().isBool() || trackValue().toBool() != false)
        return fail(QStringLiteral("config: tracking.enabled not written as false."));
    }

    // 1b. Legacy retirement: the retired file is never created or touched.
    if (QFileInfo::exists(legacyPath))
      return fail(QStringLiteral("config: writer resurrected usage_config.json."));

    // 2. idleSec < 0 omits the key (service keeps its compile-time default);
    //    tracking.enabled is still written (the user's explicit choice).
    if (!databaseManager.writeServiceConfig(-1, true))
      return fail(QStringLiteral("config: writeServiceConfig(-1,true) returned false."));
    {
      if (!idleValue().isUndefined())
        return fail(QStringLiteral("config: idleSec<0 did not omit the idle key."));
      if (trackValue().toBool() != true)
        return fail(QStringLiteral("config: tracking.enabled not updated to true."));
    }

    // 2b. 0 is a REAL value in v1 ("never idle"), not a request for the default.
    if (!databaseManager.writeServiceConfig(0, true))
      return fail(QStringLiteral("config: writeServiceConfig(0,true) returned false."));
    if (!idleValue().isDouble() || idleValue().toInt() != 0)
      return fail(QStringLiteral("config: idleSec==0 was not written as 0."));

    // 3. Invariant #3 forward: the tracking writer preserves database.dir.
    {
      QJsonObject db;
      db.insert(QStringLiteral("dir"), QStringLiteral("D:/somewhere"));
      QJsonObject seed;
      seed.insert(QStringLiteral("schema_version"), 1);
      seed.insert(QStringLiteral("database"), db);
      QFile f(configPath);
      if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate) ||
          f.write(QJsonDocument(seed).toJson()) < 0)
        return fail(QStringLiteral("config: could not seed database.dir before write."));
      f.close();
    }
    if (!databaseManager.writeServiceConfig(600, false))
      return fail(QStringLiteral("config: writeServiceConfig over database.dir failed."));
    {
      if (dbDirValue() != QStringLiteral("D:/somewhere"))
        return fail(QStringLiteral("config: writer clobbered the database.dir key."));
      if (idleValue().toInt() != 600 || trackValue().toBool() != false)
        return fail(QStringLiteral("config: idle/track not co-written with database.dir."));
    }
    QFile::remove(configPath);

    // 3b. Unknown sections survive a write untouched: an older UI must not be
    //     able to delete a newer service's settings.
    {
      const QByteArray future = QByteArrayLiteral(
          "{\"schema_version\":1,\"future\":{\"kept\":true}}");
      QFile f(configPath);
      if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate) ||
          f.write(future) != future.size())
        return fail(QStringLiteral("config: could not seed a future section."));
      f.close();
    }
    if (!databaseManager.writeServiceConfig(60, true))
      return fail(QStringLiteral("config: write over a future section failed."));
    if (!readConfigObj()
             .value(QStringLiteral("future"))
             .toObject()
             .value(QStringLiteral("kept"))
             .toBool())
      return fail(QStringLiteral("config: writer dropped an unknown section."));
    QFile::remove(configPath);

    // 4. Invariant #3 reverse: the pointer writer (relocate / restore-default,
    //    which funnel through the same helper) preserves the tracking keys. Set
    //    idle/track, relocate (writes database.dir) and assert idle/track survive
    //    next to it, then restore-default (clears the pointer) and assert
    //    idle/track STILL survive -- only database.dir is removed.
    if (!databaseManager.writeServiceConfig(900, false))
      return fail(QStringLiteral("config: pre-relocate writeServiceConfig failed."));
    const QString h5Dir = QDir::temp().filePath(QStringLiteral("timearc-h5-reloc"));
    QDir(h5Dir).removeRecursively();
    QDir().mkpath(h5Dir);
    const QVariantMap h5mv =
        databaseManager.relocateDatabaseTo(QUrl::fromLocalFile(h5Dir).toString());
    if (!h5mv.value(QStringLiteral("ok")).toBool())
      return fail(QStringLiteral("config: relocate (pointer writer) failed: %1")
                      .arg(h5mv.value(QStringLiteral("error")).toString()));
    {
      if (dbDirValue().isEmpty())
        return fail(QStringLiteral("config: relocate did not write database.dir."));
      if (idleValue().toInt() != 900 || trackValue().toBool() != false)
        return fail(QStringLiteral("config: pointer writer clobbered the tracking keys."));
    }
    const QVariantMap h5rv = databaseManager.restoreDefaultDatabaseLocation();
    if (!h5rv.value(QStringLiteral("ok")).toBool())
      return fail(QStringLiteral("config: restore-default failed: %1")
                      .arg(h5rv.value(QStringLiteral("error")).toString()));
    {
      const QJsonObject o = readConfigObj();
      if (o.contains(QStringLiteral("database")))
        return fail(QStringLiteral("config: restore-default left an empty database section."));
      if (idleValue().toInt() != 900 || trackValue().toBool() != false)
        return fail(QStringLiteral("config: restore-default clobbered the tracking keys."));
    }
    QDir(h5Dir).removeRecursively();
    QFile::remove(configPath);
    QFile::remove(legacyPath);

    // 5. Corrupt-existing-file guard: a non-empty UNPARSEABLE service_config.json
    //    must NOT be silently overwritten (that would truncate the other
    //    writer's key). writeServiceConfig refuses (returns false) and leaves the
    //    file byte-intact.
    {
      const QByteArray garbage = QByteArrayLiteral("{ not valid json :: database");
      QFile f(configPath);
      if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate) ||
          f.write(garbage) != garbage.size())
        return fail(QStringLiteral("config: could not seed corrupt config."));
      f.close();
      if (databaseManager.writeServiceConfig(120, true))
        return fail(QStringLiteral("config: writeServiceConfig overwrote a corrupt config."));
      QFile rf(configPath);
      if (!rf.open(QIODevice::ReadOnly))
        return fail(QStringLiteral("config: corrupt config vanished after refused write."));
      const QByteArray after = rf.readAll();
      rf.close();
      if (after != garbage)
        return fail(QStringLiteral("config: corrupt config was mutated instead of preserved."));
      QFile::remove(configPath);
    }
    qInfo().noquote()
        << QStringLiteral("service-config write + key-preservation ok.");
  }


  // ------------------------------------------------------------------
  // Categorization rule engine (docs/categorization-redesign.md step 1).
  // The table is data; these cases are the spec.
  // ------------------------------------------------------------------
  {
    using namespace TimeArc::Categorization;

    // --- normalization -------------------------------------------------
    struct NormalizeCase {
      QString raw;
      QString expected;
    };
    const QVector<NormalizeCase> normalizeCases = {
        {QStringLiteral("Chrome.exe"), QStringLiteral("chrome")},
        {QStringLiteral("Google Chrome.app"), QStringLiteral("google chrome")},
        {QStringLiteral("com.google.Chrome"), QStringLiteral("com.google.chrome")},
        {QStringLiteral("Caf\u00E9"), QStringLiteral("cafe")},
        {QStringLiteral("STRASSE"), QStringLiteral("strasse")},
        {QStringLiteral("\uFF59\uFF4F\uFF55\uFF54\uFF55\uFF42\uFF45"),
         QStringLiteral("youtube")},
        {QStringLiteral("  spaced   out  "), QStringLiteral("spaced out")},
        {QStringLiteral("a \u2014 b"), QStringLiteral("a - b")},
    };
    for (const NormalizeCase& item : normalizeCases) {
      if (normalize(item.raw) != item.expected) {
        return fail(QStringLiteral("normalize(%1) = '%2', expected '%3'")
                        .arg(item.raw, normalize(item.raw), item.expected));
      }
    }

    // --- shipped table is clean ----------------------------------------
    const RuleSet defaults = defaultRuleSet();
    const QStringList defaultProblems = lint(defaults);
    if (!defaultProblems.isEmpty()) {
      return fail(QStringLiteral("default rule table failed lint: %1")
                      .arg(defaultProblems.join(QStringLiteral("; "))));
    }
    // Every shipped rule names an app. Nothing is bound to an abstract group
    // like "all browsers", so a rule's binding is always something the user has.
    for (const Rule& shipped : defaults.rules) {
      if (shipped.app.isEmpty()) {
        return fail(QStringLiteral("shipped rule %1 is not bound to an app")
                        .arg(shipped.id));
      }
    }
    if (defaults.rules.size() < 100) {
      return fail(QStringLiteral("default rule table looks truncated: %1 rules")
                      .arg(defaults.rules.size()));
    }

    const Matcher matcher(defaults);

    // --- golden fixture -------------------------------------------------
    struct ClassifyCase {
      QString appId;
      QString displayName;
      QString windowTitle;
      QString expectedRule;
      QString expectedCategory;
    };
    const QVector<ClassifyCase> classifyCases = {
        // Windows identities: display_name is the executable basename.
        {QStringLiteral("C:/Program Files/Microsoft VS Code/Code.exe"),
         QStringLiteral("Code.exe"), QStringLiteral("db_smoke.cpp - TimeArc"),
         QStringLiteral("app:vscode"), QStringLiteral("dev")},
        {QStringLiteral("C:/Program Files/Google/Chrome/chrome.exe"),
         QStringLiteral("chrome.exe"), QStringLiteral("Inbox - Gmail"),
         QStringLiteral("app:chrome"), QStringLiteral("browse")},
        {QStringLiteral("C:/Windows/System32/svchost.exe"),
         QStringLiteral("svchost.exe"), QString(),
         QStringLiteral("app:windows-service-host"), QStringLiteral("system")},
        {QStringLiteral("D:/Games/Genshin Impact Game/YuanShen.exe"),
         QStringLiteral("YuanShen.exe"), QString(),
         QStringLiteral("app:genshin-impact"), QStringLiteral("game")},
        // The generic Unreal executable: only the install path disambiguates,
        // and on Windows app_id IS the path.
        {QStringLiteral("D:/Games/Wuthering Waves/Client/Binaries/Win64/"
                        "Client-Win64-Shipping.exe"),
         QStringLiteral("Client-Win64-Shipping.exe"), QString(),
         QStringLiteral("app:wuthering-waves"), QStringLiteral("game")},

        // macOS identities: bundle id plus a localized display name. Both of
        // these are misclassified by the system this replaces.
        {QStringLiteral("com.google.Chrome"), QStringLiteral("Google Chrome"),
         QStringLiteral("Inbox"), QStringLiteral("app:chrome"),
         QStringLiteral("browse")},
        {QStringLiteral("com.apple.finder"), QStringLiteral("\u8BBF\u8FBE"),
         QString(), QStringLiteral("app:finder"), QStringLiteral("system")},
        {QStringLiteral("com.microsoft.VSCode"),
         QStringLiteral("Visual Studio Code"), QString(),
         QStringLiteral("app:vscode"), QStringLiteral("dev")},
        {QStringLiteral("com.apple.dt.Xcode"), QStringLiteral("Xcode"),
         QString(), QStringLiteral("app:xcode"), QStringLiteral("dev")},

        // Title refinement inside a browser must outrank the browser itself.
        {QStringLiteral("com.google.Chrome"), QStringLiteral("Google Chrome"),
         QStringLiteral("lofi hip hop radio - YouTube"),
         QStringLiteral("site:youtube.chrome"), QStringLiteral("video")},
        {QStringLiteral("C:/Program Files/Google/Chrome/chrome.exe"),
         QStringLiteral("chrome.exe"),
         QStringLiteral("\u54D4\u54E9\u54D4\u54E9 (\u309C-\u309C)\u3064\u30ED"),
         QStringLiteral("site:bilibili.chrome"), QStringLiteral("video")},
        {QStringLiteral("com.apple.Safari"), QStringLiteral("Safari"),
         QStringLiteral("arXiv.org e-Print archive"),
         QStringLiteral("site:arxiv.safari"), QStringLiteral("read")},

        // The false-positive class the old ladder was rewritten to avoid: a
        // generic word in a page title must not reclassify the browser.
        {QStringLiteral("C:/Program Files/Google/Chrome/chrome.exe"),
         QStringLiteral("chrome.exe"),
         QStringLiteral("How to make a game in 5 minutes"),
         QStringLiteral("app:chrome"), QStringLiteral("browse")},
        // ... and a title needle must not fire outside its scope.
        {QStringLiteral("C:/Program Files/Microsoft VS Code/Code.exe"),
         QStringLiteral("Code.exe"), QStringLiteral("youtube_dl.py - TimeArc"),
         QStringLiteral("app:vscode"), QStringLiteral("dev")},

        // Longest-needle specificity, no ordering discipline required.
        {QStringLiteral("C:/Apps/QQMusic/QQMusic.exe"),
         QStringLiteral("QQMusic.exe"), QString(),
         QStringLiteral("app:qq-music"), QStringLiteral("music")},
        {QStringLiteral("C:/Program Files/Tencent/QQ/QQ.exe"),
         QStringLiteral("QQ.exe"), QString(), QStringLiteral("app:qq"),
         QStringLiteral("social")},

        // Audio rows carry the media title in the window_title column.
        {QStringLiteral("com.spotify.client"), QStringLiteral("Spotify"),
         QStringLiteral("Weightless - Marconi Union"),
         QStringLiteral("app:spotify"), QStringLiteral("music")},

        // Nothing matched.
        {QStringLiteral("C:/Tools/veryobscuretool.exe"),
         QStringLiteral("veryobscuretool.exe"), QString(), QString(),
         QStringLiteral("other")},
    };

    for (const ClassifyCase& item : classifyCases) {
      const Resolution resolution =
          matcher.resolve(item.appId, item.displayName, item.windowTitle);
      if (resolution.ruleId != item.expectedRule ||
          resolution.category != item.expectedCategory) {
        return fail(
            QStringLiteral("classify('%1', '%2') = %3/%4, expected %5/%6")
                .arg(item.displayName, item.windowTitle,
                     resolution.ruleId.isEmpty() ? QStringLiteral("<none>")
                                                 : resolution.ruleId,
                     resolution.category,
                     item.expectedRule.isEmpty() ? QStringLiteral("<none>")
                                                 : item.expectedRule,
                     item.expectedCategory));
      }
    }

    // An unmatched activity still gets a stable identity to group by.
    const Resolution unmatched =
        matcher.resolve(QStringLiteral("C:/Tools/veryobscuretool.exe"),
                        QStringLiteral("veryobscuretool.exe"), QString());
    if (unmatched.matched ||
        unmatched.identity != QStringLiteral("exe:veryobscuretool")) {
      return fail(QStringLiteral("unmatched fallback identity was '%1'")
                      .arg(unmatched.identity));
    }

    // --- scoring shape ---------------------------------------------------
    {
      const Resolution browsing = matcher.resolve(
          QStringLiteral("com.google.Chrome"), QStringLiteral("Google Chrome"),
          QStringLiteral("Inbox"));
      const Resolution refined = matcher.resolve(
          QStringLiteral("com.google.Chrome"), QStringLiteral("Google Chrome"),
          QStringLiteral("lofi - YouTube"));
      if (browsing.conditions != 1 || refined.conditions != 2 ||
          refined.score <= browsing.score) {
        return fail(QStringLiteral("title refinement did not outrank the app "
                                   "match: %1 vs %2")
                        .arg(refined.score)
                        .arg(browsing.score));
      }
    }

    // --- English-first labels with locale fallback ------------------------
    if (matcher.labelFor(QStringLiteral("app:wechat"), QStringLiteral("en")) !=
            QStringLiteral("WeChat") ||
        matcher.labelFor(QStringLiteral("app:wechat"), QStringLiteral("zh")) !=
            QStringLiteral("\u5FAE\u4FE1") ||
        matcher.labelFor(QStringLiteral("app:wechat"), QStringLiteral("ja")) !=
            QStringLiteral("WeChat")) {
      return fail(QStringLiteral("English-first label fallback failed."));
    }

    // --- store and reload -------------------------------------------------
    // A stored set is the shipped table with every entry carrying a `ref`;
    // built here rather than in production code, because seeding derives its
    // sets from tracking data and no longer copies the table wholesale.
    RuleSet owned = defaults;
    for (Rule& rule : owned.rules) rule.ref = rule.id;
    for (CategoryDef& category : owned.categories) category.ref = category.id;

    const QJsonObject stored = ruleSetToJson(owned);
    // The stored form must be simpler than the built-in one.
    for (const QJsonValue& value :
         stored.value(QStringLiteral("rules")).toArray()) {
      const QJsonObject entry = value.toObject();
      if (entry.contains(QStringLiteral("label")) ||
          entry.contains(QStringLiteral("icon")) ||
          entry.contains(QStringLiteral("name"))) {
        return fail(QStringLiteral("stored rule %1 carried presentation data")
                        .arg(entry.value(QStringLiteral("id")).toString()));
      }
    }

    QStringList reloadProblems;
    const RuleSet reloaded = ruleSetFromJson(stored, defaults, &reloadProblems);
    if (!reloadProblems.isEmpty()) {
      return fail(QStringLiteral("reload reported problems: %1")
                      .arg(reloadProblems.join(QStringLiteral("; "))));
    }
    if (reloaded.rules.size() != owned.rules.size() ||
        reloaded.categories.size() != owned.categories.size()) {
      return fail(QStringLiteral("round-trip lost entries."));
    }

    // Round-trip must resolve identically over the whole fixture, and labels
    // must come back through `ref` even though they were never stored.
    const Matcher reloadedMatcher(reloaded);
    for (const ClassifyCase& item : classifyCases) {
      const Resolution before =
          matcher.resolve(item.appId, item.displayName, item.windowTitle);
      const Resolution after = reloadedMatcher.resolve(
          item.appId, item.displayName, item.windowTitle);
      if (before.ruleId != after.ruleId || before.category != after.category) {
        return fail(QStringLiteral("round-trip changed '%1' from %2 to %3")
                        .arg(item.displayName, before.category, after.category));
      }
    }
    if (reloadedMatcher.labelFor(QStringLiteral("app:wechat"),
                                 QStringLiteral("zh")) !=
        QStringLiteral("\u5FAE\u4FE1")) {
      return fail(QStringLiteral("rehydration by ref lost the localized name."));
    }

    // --- user edits -------------------------------------------------------
    {
      RuleSet edited = owned;
      for (Rule& rule : edited.rules) {
        if (rule.id != QStringLiteral("site:youtube.chrome")) continue;
        rule.name = QStringLiteral("Study videos");
        rule.category = QStringLiteral("dev");
        rule.userTouched = true;
      }
      const Matcher editedMatcher(edited);
      const Resolution resolution = editedMatcher.resolve(
          QStringLiteral("com.google.Chrome"), QStringLiteral("Google Chrome"),
          QStringLiteral("lecture - YouTube"));
      if (resolution.category != QStringLiteral("dev")) {
        return fail(QStringLiteral("user category edit was not applied."));
      }
      // A renamed rule stops localizing; the user's word wins in every UI
      // language.
      if (editedMatcher.labelFor(QStringLiteral("site:youtube.chrome"),
                                 QStringLiteral("zh")) !=
          QStringLiteral("Study videos")) {
        return fail(QStringLiteral("user rename did not override the label."));
      }

      // auto_classify: off stops inference but keeps user-touched rules.
      MatchOptions inferenceOff;
      inferenceOff.autoClassify = false;
      const Resolution touched = editedMatcher.resolve(
          QStringLiteral("com.google.Chrome"), QStringLiteral("Google Chrome"),
          QStringLiteral("lecture - YouTube"), inferenceOff);
      const Resolution inferred = editedMatcher.resolve(
          QStringLiteral("com.microsoft.VSCode"),
          QStringLiteral("Visual Studio Code"), QString(), inferenceOff);
      if (touched.category != QStringLiteral("dev") ||
          inferred.category != QStringLiteral("other")) {
        return fail(QStringLiteral("auto_classify gating is wrong: %1 / %2")
                        .arg(touched.category, inferred.category));
      }
    }

    // A disabled category collapses to "other" - this is game_mode: off,
    // generalized.
    {
      RuleSet edited = owned;
      for (CategoryDef& category : edited.categories) {
        if (category.id == QStringLiteral("game")) category.enabled = false;
      }
      const Matcher editedMatcher(edited);
      const Resolution resolution = editedMatcher.resolve(
          QStringLiteral("D:/Games/Genshin Impact Game/YuanShen.exe"),
          QStringLiteral("YuanShen.exe"), QString());
      if (resolution.ruleId != QStringLiteral("app:genshin-impact") ||
          resolution.category != QStringLiteral("other")) {
        return fail(QStringLiteral("disabled category did not collapse."));
      }
    }

    // A deleted rule falls through to whatever else matches.
    {
      RuleSet edited = owned;
      for (Rule& rule : edited.rules) {
        if (rule.id == QStringLiteral("site:youtube.chrome")) rule.enabled = false;
      }
      const Matcher editedMatcher(edited);
      const Resolution resolution = editedMatcher.resolve(
          QStringLiteral("com.google.Chrome"), QStringLiteral("Google Chrome"),
          QStringLiteral("lofi - YouTube"));
      if (resolution.ruleId != QStringLiteral("app:chrome") ||
          resolution.category != QStringLiteral("browse")) {
        return fail(QStringLiteral("disabling a rule did not fall through."));
      }
    }

    // --- lint rejects the dangerous shapes --------------------------------
    {
      RuleSet broken = defaults;
      Rule unscoped;
      unscoped.id = QStringLiteral("user.bad");
      unscoped.category = QStringLiteral("game");
      unscoped.title = {QStringLiteral("game")};
      broken.rules.append(unscoped);
      const QStringList problems = lint(broken);
      bool sawScopeProblem = false;
      for (const QString& problem : problems) {
        if (problem.contains(QStringLiteral("title match with no app")))
          sawScopeProblem = true;
      }
      if (!sawScopeProblem) {
        return fail(QStringLiteral("lint accepted an app-less title rule."));
      }
    }
    {
      RuleSet broken = defaults;
      Rule unknown;
      unknown.id = QStringLiteral("user.unknown-category");
      unknown.category = QStringLiteral("nope");
      unknown.app = {QStringLiteral("something")};
      broken.rules.append(unknown);
      if (lint(broken).isEmpty()) {
        return fail(QStringLiteral("lint accepted an unknown category."));
      }
    }
    {
      RuleSet broken = defaults;
      Rule shortNeedle;
      shortNeedle.id = QStringLiteral("user.short");
      shortNeedle.category = QStringLiteral("other");
      shortNeedle.app = {QStringLiteral("qq")};
      broken.rules.append(shortNeedle);
      if (lint(broken).isEmpty()) {
        return fail(QStringLiteral("lint accepted a two-character substring."));
      }
    }

    qInfo().noquote()
        << QStringLiteral("categorization ok: %1 rules, %2 categories, "
                          "%3 fixture cases.")
               .arg(defaults.rules.size())
               .arg(defaults.categories.size())
               .arg(classifyCases.size());
  }


  // ------------------------------------------------------------------
  // CategorizationManager: the stored set is derived from the apps the
  // service actually recorded, and bound to the names it recorded them under
  // (docs/categorization-redesign.md).
  // ------------------------------------------------------------------
  {
    using namespace TimeArc::Categorization;

    const auto clearStore = [&settingsRepository]() {
      settingsRepository.setValue(QStringLiteral("categorization"),
                                  QStringLiteral(""));
    };
    const auto recorded = [](const QString& appId, const QString& displayName) {
      QVariantMap app;
      app.insert(QStringLiteral("appId"), appId);
      app.insert(QStringLiteral("displayName"), displayName);
      return QVariant(app);
    };

    // A brand-new install has recorded nothing, so it gets no rules at all -
    // only the category palette.
    clearStore();
    {
      CategorizationManager fresh;
      fresh.setRecordedAppsProvider([]() { return QVariantList(); });
      fresh.setSettingsRepository(&settingsRepository);
      if (!fresh.matcher().ruleSet().rules.isEmpty()) {
        return fail(QStringLiteral("a new install seeded %1 rules; expected 0.")
                        .arg(fresh.matcher().ruleSet().rules.size()));
      }
      if (fresh.matcher().ruleSet().categories.isEmpty()) {
        return fail(QStringLiteral("seeding dropped the category palette."));
      }
      // ...and the row must exist, because seeding is eager, not lazy.
      if (settingsRepository.getValue(QStringLiteral("categorization"))
              .trimmed()
              .isEmpty()) {
        return fail(QStringLiteral("eager seeding wrote nothing."));
      }
    }

    // Now with tracking data. Only the recorded apps get rules, and each rule
    // binds to the name the service reported.
    QVariantList records;
    records << recorded(QStringLiteral("com.google.Chrome"),
                        QStringLiteral("Google Chrome.app"))
            << recorded(QStringLiteral("com.microsoft.VSCode"),
                        QStringLiteral("Visual Studio Code"))
            << recorded(QStringLiteral("C:/Tools/nothing-known.exe"),
                        QStringLiteral("nothing-known.exe"));

    clearStore();
    CategorizationManager manager;
    manager.setRecordedAppsProvider([&records]() { return records; });
    manager.setSettingsRepository(&settingsRepository);

    const RuleSet& seeded = manager.matcher().ruleSet();
    if (seeded.rules.isEmpty()) {
      return fail(QStringLiteral("seeding from records produced no rules."));
    }

    bool sawChrome = false;
    bool sawYouTubeForChrome = false;
    for (const Rule& rule : seeded.rules) {
      // Nothing for a browser this machine does not have.
      if (rule.id.endsWith(QStringLiteral(".firefox")) ||
          rule.id.endsWith(QStringLiteral(".safari")) ||
          rule.id.endsWith(QStringLiteral(".edge"))) {
        return fail(QStringLiteral("seeded %1 for a browser with no records.")
                        .arg(rule.id));
      }
      if (rule.id == QStringLiteral("app:chrome")) {
        sawChrome = true;
        if (rule.app != QStringList{QStringLiteral("=Google Chrome.app")}) {
          return fail(QStringLiteral("chrome rule bound to %1, not the "
                                     "recorded name.")
                          .arg(rule.app.join(QStringLiteral(","))));
        }
      }
      if (rule.id == QStringLiteral("site:youtube.chrome")) {
        sawYouTubeForChrome = true;
      }
    }
    if (!sawChrome || !sawYouTubeForChrome) {
      return fail(QStringLiteral("seeding missed a recorded app's rules."));
    }
    // Genshin is in the shipped table but not in these records.
    for (const Rule& rule : seeded.rules) {
      if (rule.id == QStringLiteral("app:genshin-impact")) {
        return fail(QStringLiteral("seeded a rule for an unrecorded app."));
      }
    }

    // Every recorded app gets exactly one app-level rule bound to it - the
    // same shape the UI produces when you pick an app - and an app the shipped
    // table has never heard of is written too, so nothing is missing from the
    // list. One rule never speaks for several apps.
    for (const QVariant& value : records) {
      const QVariantMap app = value.toMap();
      const QString needle =
          QStringLiteral("=") + app.value(QStringLiteral("displayName")).toString();
      int owners = 0;
      for (const Rule& rule : seeded.rules) {
        if (!rule.title.isEmpty()) continue;
        if (rule.app == QStringList{needle}) ++owners;
      }
      if (owners != 1) {
        return fail(QStringLiteral("%1 has %2 app-level rules; expected 1.")
                        .arg(needle)
                        .arg(owners));
      }
    }
    for (const Rule& rule : seeded.rules) {
      if (rule.app.size() != 1) {
        return fail(QStringLiteral("rule %1 binds %2 apps; expected exactly 1.")
                        .arg(rule.id)
                        .arg(rule.app.size()));
      }
    }

    // Classification still works through the recorded binding.
    const Resolution chrome = manager.matcher().resolve(
        QStringLiteral("com.google.Chrome"),
        QStringLiteral("Google Chrome.app"), QStringLiteral("Inbox"),
        manager.options());
    const Resolution youtube = manager.matcher().resolve(
        QStringLiteral("com.google.Chrome"),
        QStringLiteral("Google Chrome.app"),
        QStringLiteral("lofi - YouTube"), manager.options());
    const Resolution unknown = manager.matcher().resolve(
        QStringLiteral("C:/Tools/nothing-known.exe"),
        QStringLiteral("nothing-known.exe"), QString(), manager.options());
    if (chrome.category != QStringLiteral("browse") ||
        youtube.category != QStringLiteral("video") ||
        unknown.category != QStringLiteral("other")) {
      return fail(QStringLiteral("seeded set classified wrongly: %1/%2/%3")
                      .arg(chrome.category, youtube.category,
                           unknown.category));
    }

    // Editing works and survives a reload.
    if (!manager.setRuleCategory(QStringLiteral("site:youtube.chrome"),
                                 QStringLiteral("dev"))) {
      return fail(QStringLiteral("setRuleCategory failed."));
    }
    {
      CategorizationManager reloaded;
      reloaded.setRecordedAppsProvider([&records]() { return records; });
      reloaded.setSettingsRepository(&settingsRepository);
      if (!reloaded.loadError().isEmpty()) {
        return fail(QStringLiteral("reload failed: %1").arg(reloaded.loadError()));
      }
      const Resolution after = reloaded.matcher().resolve(
          QStringLiteral("com.google.Chrome"),
          QStringLiteral("Google Chrome.app"),
          QStringLiteral("lecture - YouTube"), reloaded.options());
      if (after.category != QStringLiteral("dev")) {
        return fail(QStringLiteral("an edit did not survive reload."));
      }
      // A user-edited set must not be silently re-seeded.
      if (reloaded.matcher()
              .ruleSet()
              .rules.size() != manager.matcher().ruleSet().rules.size()) {
        return fail(QStringLiteral("reload re-seeded over a user edit."));
      }
    }

    // Reset re-derives from *current* tracking data rather than restoring a
    // fixed table: teach it about a new app and the reset picks it up.
    records << recorded(QStringLiteral("D:/Games/Genshin Impact Game/YuanShen.exe"),
                        QStringLiteral("YuanShen.exe"));
    if (!manager.restoreAllDefaults()) {
      return fail(QStringLiteral("restoreAllDefaults failed."));
    }
    bool sawGenshin = false;
    for (const Rule& rule : manager.matcher().ruleSet().rules) {
      if (rule.id == QStringLiteral("app:genshin-impact")) sawGenshin = true;
    }
    if (!sawGenshin) {
      return fail(QStringLiteral("reset did not re-evaluate tracking data."));
    }
    // ...and it discarded the edit.
    if (manager.matcher()
            .resolve(QStringLiteral("com.google.Chrome"),
                     QStringLiteral("Google Chrome.app"),
                     QStringLiteral("lecture - YouTube"), manager.options())
            .category != QStringLiteral("video")) {
      return fail(QStringLiteral("reset kept a user edit."));
    }

    // Per-app browsing: one rule owns the app, title rules list under it.
    {
      const QVariantMap chromeRule =
          manager.appRuleFor(QStringLiteral("com.google.Chrome"),
                             QStringLiteral("Google Chrome.app"));
      if (chromeRule.value(QStringLiteral("id")).toString() !=
          QStringLiteral("app:chrome")) {
        return fail(QStringLiteral("appRuleFor did not ignore window titles."));
      }
      bool listed = false;
      for (const QVariant& value :
           manager.titleRulesForApp(QStringLiteral("com.google.Chrome"),
                                    QStringLiteral("Google Chrome.app"))) {
        if (value.toMap().value(QStringLiteral("id")).toString() ==
            QStringLiteral("site:youtube.chrome")) {
          listed = true;
        }
      }
      if (!listed) {
        return fail(QStringLiteral("title rules were not listed under the app."));
      }
      for (const QVariant& value :
           manager.titleRulesForApp(QStringLiteral("com.microsoft.VSCode"),
                                    QStringLiteral("Visual Studio Code"))) {
        if (value.toMap().value(QStringLiteral("id")).toString() ==
            QStringLiteral("site:youtube.chrome")) {
          return fail(QStringLiteral("a browser rule leaked to an editor."));
        }
      }
    }

    // A title rule is bound to one app, which is why no scope control exists.
    {
      const QString created = manager.addTitleRuleForApp(
          QStringLiteral("com.microsoft.VSCode"),
          QStringLiteral("Visual Studio Code"), QStringLiteral("Docs"),
          QStringList{QStringLiteral("readme")}, QStringLiteral("notes"));
      if (created.isEmpty()) {
        return fail(QStringLiteral("addTitleRuleForApp failed."));
      }
      const Resolution docs = manager.matcher().resolve(
          QStringLiteral("com.microsoft.VSCode"),
          QStringLiteral("Visual Studio Code"), QStringLiteral("README.md"),
          manager.options());
      const Resolution elsewhere = manager.matcher().resolve(
          QStringLiteral("com.google.Chrome"),
          QStringLiteral("Google Chrome.app"), QStringLiteral("README.md"),
          manager.options());
      if (docs.category != QStringLiteral("notes") ||
          elsewhere.ruleId == created) {
        return fail(QStringLiteral("app-bound title rule misfired."));
      }
      if (!manager.deleteRule(created)) {
        return fail(QStringLiteral("could not delete the created rule."));
      }
    }

    // Deleting a category re-homes its rules; "other" is not deletable.
    {
      const QString custom =
          manager.addCategory(QStringLiteral("Study"), QStringLiteral(""));
      if (custom.isEmpty()) return fail(QStringLiteral("addCategory failed."));
      if (!manager.setRuleCategory(QStringLiteral("app:vscode"), custom)) {
        return fail(QStringLiteral("could not move a rule to a new category."));
      }
      if (manager.deleteCategory(QStringLiteral("other"))) {
        return fail(QStringLiteral("'other' must not be deletable."));
      }
      if (!manager.deleteCategory(custom)) {
        return fail(QStringLiteral("deleteCategory failed."));
      }
      if (manager.matcher()
              .resolve(QStringLiteral("com.microsoft.VSCode"),
                       QStringLiteral("Visual Studio Code"), QString(),
                       manager.options())
              .category != QStringLiteral("other")) {
        return fail(QStringLiteral("deleted category did not re-home rules."));
      }
    }

    // The needle the editor binds keeps the recorded spelling.
    if (manager.appNeedleFor(QStringLiteral("com.google.Chrome"),
                             QStringLiteral("Google Chrome.app")) !=
        QStringLiteral("=Google Chrome.app")) {
      return fail(QStringLiteral("appNeedleFor lost the recorded spelling."));
    }

    // A corrupt document falls back loudly, never silently.
    settingsRepository.setValue(QStringLiteral("categorization"),
                                QStringLiteral("{ not json"));
    {
      CategorizationManager broken;
      broken.setRecordedAppsProvider([&records]() { return records; });
      broken.setSettingsRepository(&settingsRepository);
      if (broken.loadError().isEmpty()) {
        return fail(QStringLiteral("corrupt config did not report an error."));
      }
    }
    clearStore();

    qInfo().noquote()
        << QStringLiteral("categorization manager ok: eager seed from records, "
                          "recorded bindings, reload, reset re-derives.");
  }

  qInfo().noquote() << QStringLiteral("database smoke ok: %1").arg(databasePath);
  return 0;
}
