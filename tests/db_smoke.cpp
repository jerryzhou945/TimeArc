#include <QCoreApplication>
#include <QDate>
#include <QDateTime>
#include <QDebug>
#include <QDir>
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
#include <QVariantList>
#include <QVariantMap>

#include <algorithm>
#include <iterator>

#include "services/app_repository.h"
#include "services/database_manager.h"
#include "services/frontmost_session_repository.h"
#include "services/manual_project_repository.h"
#include "services/media_session_repository.h"
#include "services/settings_repository.h"
#include "services/stats_service.h"
#include "services/calendar_manager.h"
#include "services/project_manager.h"
#include "services/adapters/activity_adapter_registry.h"

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

// A1 schema-parity guard. The canonical DDL for the shared usage tables is owned
// by DatabaseManager (src/services/database_manager.cpp); the Windows service
// inline DDL (src/service/windows/storage/usage_storage.c) MUST stay
// column-compatible with it. This asserts the table actually created by
// DatabaseManager matches the canonical column shape (name, declared type,
// NOT NULL), so any drift in the UI DDL fails the build. Keep these lists and
// the service DDL in lockstep when amending the schema.
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
          QStringLiteral("PRAGMA table_info(%1);").arg(tableName))) {
    *mismatch = QStringLiteral("PRAGMA table_info(%1) failed: %2")
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
  QSettings projectSettings(QStringLiteral("TimeArc"),
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

  QSettings calendarSettings(QStringLiteral("TimeArc"),
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

  QSettings namedAppSettings(QStringLiteral("TimeArc"),
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

  TimeArcAdapters::AdapterInput unknownWebsite;
  unknownWebsite.url =
      QStringLiteral("https://example.com/private?token=do-not-store");
  unknownWebsite.title = QStringLiteral("Private dashboard");
  TimeArcAdapters::AdapterMetadata unknownWebsiteMeta =
      TimeArcAdapters::resolveActivity(unknownWebsite);
  if (unknownWebsiteMeta.sourceType != QStringLiteral("website") ||
      unknownWebsiteMeta.identifier != QStringLiteral("site:example.com") ||
      unknownWebsiteMeta.displayName != QStringLiteral("example.com") ||
      unknownWebsiteMeta.domain != QStringLiteral("example.com") ||
      unknownWebsiteMeta.confidence < 0.70 ||
      unknownWebsiteMeta.toVariantMap().contains(QStringLiteral("url"))) {
    return fail(QStringLiteral("Generic website adapter fallback failed."));
  }

  TimeArcAdapters::AdapterInput unknownApp;
  unknownApp.appName = QStringLiteral("SmokeApp.exe");
  unknownApp.path = QStringLiteral("C:/TimeArcSmoke/SmokeApp.exe");
  TimeArcAdapters::AdapterMetadata unknownAppMeta =
      TimeArcAdapters::resolveActivity(unknownApp);
  if (unknownAppMeta.sourceType != QStringLiteral("desktopApp") ||
      unknownAppMeta.identifier.trimmed().isEmpty() ||
      unknownAppMeta.displayName != QStringLiteral("SmokeApp") ||
      unknownAppMeta.iconPath != unknownApp.path) {
    return fail(QStringLiteral("Generic desktop adapter fallback failed."));
  }

  struct WebsiteAdapterCase {
    QString url;
    QString title;
    QString expectedIdentifier;
    QString expectedName;
    QString expectedCategory;
    bool expectsIcon;
  };
  const WebsiteAdapterCase websiteAdapterCases[] = {
      {QStringLiteral("https://www.youtube.com/watch?v=secret-token"),
       QStringLiteral("lofi stream - YouTube"),
       QStringLiteral("site:youtube"),
       QStringLiteral("YouTube"),
       QStringLiteral("视频"),
       true},
      {QStringLiteral("https://space.bilibili.com/12345"),
       QStringLiteral("UP 主空间 - 哔哩哔哩"),
       QStringLiteral("site:bilibili"),
       QStringLiteral("哔哩哔哩"),
       QStringLiteral("视频"),
       true},
      {QStringLiteral("https://open.spotify.com/playlist/private-id"),
       QStringLiteral("Daily Mix - Spotify"),
       QStringLiteral("site:spotify-web"),
       QStringLiteral("Spotify Web"),
       QStringLiteral("音乐"),
       false},
      {QStringLiteral("https://y.qq.com/n/ryqq/songDetail/private-id"),
       QStringLiteral("QQ音乐 - song"),
       QStringLiteral("site:qq-music-web"),
       QStringLiteral("QQ Music Web"),
       QStringLiteral("音乐"),
       false},
  };
  for (const WebsiteAdapterCase& siteCase : websiteAdapterCases) {
    TimeArcAdapters::AdapterInput input;
    input.url = siteCase.url;
    input.title = siteCase.title;
    const TimeArcAdapters::AdapterMetadata metadata =
        TimeArcAdapters::resolveActivity(input);
    const QVariantMap map = metadata.toVariantMap();
    if (metadata.sourceType != QStringLiteral("website") ||
        metadata.identifier != siteCase.expectedIdentifier ||
        metadata.displayName != siteCase.expectedName ||
        metadata.category != siteCase.expectedCategory ||
        metadata.confidence < 0.89 ||
        metadata.iconLabel.trimmed().isEmpty() ||
        (siteCase.expectsIcon && metadata.iconPath.trimmed().isEmpty() &&
         metadata.iconUrl.trimmed().isEmpty()) ||
        map.contains(QStringLiteral("url")) ||
        map.values().contains(siteCase.url)) {
      return fail(QStringLiteral("Website adapter match failed: %1")
                      .arg(siteCase.expectedIdentifier));
    }
  }

  TimeArcAdapters::AdapterInput titleOnlyBilibili;
  titleOnlyBilibili.title =
      QStringLiteral("更了300多期视频以后 - 哔哩哔哩 bilibili - Google Chrome");
  const TimeArcAdapters::AdapterMetadata titleOnlySite =
      TimeArcAdapters::resolveWebsite(titleOnlyBilibili);
  if (titleOnlySite.identifier != QStringLiteral("site:bilibili") ||
      titleOnlySite.confidence >= 0.90) {
    return fail(QStringLiteral("Website title fallback confidence failed."));
  }

  struct DesktopAdapterCase {
    QString appId;
    QString appName;
    QString path;
    QString expectedIdentifier;
    QString expectedName;
    QString expectedCategory;
    bool supportsMedia;
  };
  const DesktopAdapterCase desktopAdapterCases[] = {
      {QStringLiteral("com.google.Chrome"),
       QStringLiteral("chrome.exe"),
       QStringLiteral("C:/Program Files/Google/Chrome/Application/chrome.exe"),
       QStringLiteral("app:google-chrome"),
       QStringLiteral("Chrome"),
       QStringLiteral("浏览"),
       false},
      {QStringLiteral("Microsoft.MicrosoftEdge.Stable"),
       QStringLiteral("msedge.exe"),
       QStringLiteral("C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"),
       QStringLiteral("app:microsoft-edge"),
       QStringLiteral("Edge"),
       QStringLiteral("浏览"),
       false},
      {QStringLiteral("com.microsoft.VSCode"),
       QStringLiteral("Code.exe"),
       QStringLiteral("C:/Users/me/AppData/Local/Programs/Microsoft VS Code/Code.exe"),
       QStringLiteral("app:vscode"),
       QStringLiteral("VSCode"),
       QStringLiteral("开发"),
       false},
      {QStringLiteral("com.spotify.client"),
       QStringLiteral("Spotify.exe"),
       QStringLiteral("C:/Users/me/AppData/Roaming/Spotify/Spotify.exe"),
       QStringLiteral("app:spotify"),
       QStringLiteral("Spotify"),
       QStringLiteral("音乐"),
       true},
      {QStringLiteral("com.tencent.xinWeChat"),
       QStringLiteral("WeChat.exe"),
       QStringLiteral("C:/Program Files/Tencent/WeChat/WeChat.exe"),
       QStringLiteral("app:wechat"),
       QStringLiteral("WeChat"),
       QStringLiteral("社交"),
       false},
      {QStringLiteral("com.tencent.qq"),
       QStringLiteral("QQ.exe"),
       QStringLiteral("C:/Program Files/Tencent/QQ/QQ.exe"),
       QStringLiteral("app:qq"),
       QStringLiteral("QQ"),
       QStringLiteral("社交"),
       false},
  };
  for (const DesktopAdapterCase& appCase : desktopAdapterCases) {
    TimeArcAdapters::AdapterInput input;
    input.appId = appCase.appId;
    input.appName = appCase.appName;
    input.path = appCase.path;
    const TimeArcAdapters::AdapterMetadata metadata =
        TimeArcAdapters::resolveActivity(input);
    if (metadata.sourceType != QStringLiteral("desktopApp") ||
        metadata.identifier != appCase.expectedIdentifier ||
        metadata.displayName != appCase.expectedName ||
        metadata.category != appCase.expectedCategory ||
        metadata.iconLabel.trimmed().isEmpty() ||
        metadata.supportsMediaDetection != appCase.supportsMedia ||
        metadata.confidence < 0.90) {
      return fail(QStringLiteral("Desktop app adapter match failed: %1")
                      .arg(appCase.expectedIdentifier));
    }
  }

  const QString testDataPath =
      QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
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

  const QStringList requiredTables = {
      QStringLiteral("apps"),
      QStringLiteral("frontmost_sessions"),
      QStringLiteral("media_sessions"),
      QStringLiteral("manual_projects"),
      QStringLiteral("manual_sessions"),
      QStringLiteral("tags"),
      QStringLiteral("settings"),
      QStringLiteral("schema_migrations"),
  };

  for (const QString& tableName : requiredTables) {
    if (!tableExists(db, tableName)) {
      return fail(QStringLiteral("Required table is missing: %1").arg(tableName));
    }
  }

  // A1: assert the shared usage tables match the canonical column shape so the
  // UI DDL and the service inline DDL cannot silently drift apart.
  const ExpectedColumn appsColumns[] = {
      {"id", "INTEGER", 0},          {"app_identifier", "TEXT", 1},
      {"app_name", "TEXT", 1},       {"display_name", "TEXT", 0},
      {"app_icon_path", "TEXT", 0},  {"executable_path", "TEXT", 0},
      {"platform", "TEXT", 0},       {"created_at", "INTEGER", 1},
      {"updated_at", "INTEGER", 1},
  };
  const ExpectedColumn frontmostColumns[] = {
      {"id", "INTEGER", 0},          {"app_identifier", "TEXT", 1},
      {"window_title", "TEXT", 0},   {"start_unix_sec", "INTEGER", 1},
      {"end_unix_sec", "INTEGER", 1}, {"duration_sec", "INTEGER", 1},
      {"active_sec", "INTEGER", 1},  {"idle_sec", "INTEGER", 0},
      {"created_at", "INTEGER", 1},
  };
  const ExpectedColumn mediaColumns[] = {
      {"id", "INTEGER", 0},           {"app_identifier", "TEXT", 1},
      {"media_type", "TEXT", 1},      {"media_title", "TEXT", 0},
      {"start_unix_sec", "INTEGER", 1}, {"end_unix_sec", "INTEGER", 1},
      {"playback_sec", "INTEGER", 1}, {"created_at", "INTEGER", 1},
  };
  struct TableSchema {
    QString name;
    const ExpectedColumn* columns;
    int count;
  };
  const TableSchema schemaParityTables[] = {
      {QStringLiteral("apps"), appsColumns,
       static_cast<int>(std::size(appsColumns))},
      {QStringLiteral("frontmost_sessions"), frontmostColumns,
       static_cast<int>(std::size(frontmostColumns))},
      {QStringLiteral("media_sessions"), mediaColumns,
       static_cast<int>(std::size(mediaColumns))},
  };
  for (const TableSchema& table : schemaParityTables) {
    QString mismatch;
    if (!columnsMatch(db, table.name, table.columns, table.count, &mismatch)) {
      return fail(QStringLiteral("Schema parity drift: %1").arg(mismatch));
    }
  }

  AppRepository appRepository;
  FrontmostSessionRepository frontmostRepository;
  MediaSessionRepository mediaRepository;
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

  if (!frontmostRepository.addFrontmostSession(
          appIdentifier, QStringLiteral("Smoke Window"), startUnixSec,
          endUnixSec, expectedDuration, expectedDuration, 0)) {
    return fail(QStringLiteral("Failed to insert smoke frontmost session."));
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
  if (!mediaRepository.addMediaSession(appIdentifier, QStringLiteral("audio"),
                                       mediaTitle, mediaStart, mediaEnd,
                                       mediaDuration)) {
    return fail(QStringLiteral("Failed to insert smoke media session."));
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

  qInfo().noquote() << QStringLiteral("database smoke ok: %1").arg(databasePath);
  return 0;
}
