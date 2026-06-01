#include "services/app_repository.h"

#include <QDateTime>
#include <QDebug>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>

namespace {

const QString kConnectionName = QStringLiteral("timearc");

QSqlDatabase database() {
  QSqlDatabase db = QSqlDatabase::database(kConnectionName);
  if (!db.isValid() || !db.isOpen()) {
    qWarning() << "Database is not open.";
  }
  return db;
}

QVariantMap appMapFromQuery(const QSqlQuery& query) {
  QVariantMap app;
  app.insert(QStringLiteral("id"), query.value(0));
  app.insert(QStringLiteral("appIdentifier"), query.value(1).toString());
  app.insert(QStringLiteral("appName"), query.value(2).toString());
  app.insert(QStringLiteral("displayName"), query.value(3).toString());
  app.insert(QStringLiteral("appIconPath"), query.value(4).toString());
  app.insert(QStringLiteral("executablePath"), query.value(5).toString());
  app.insert(QStringLiteral("platform"), query.value(6).toString());
  app.insert(QStringLiteral("createdAt"), query.value(7).toLongLong());
  app.insert(QStringLiteral("updatedAt"), query.value(8).toLongLong());
  return app;
}

}  // namespace

AppRepository::AppRepository(QObject* parent) : QObject(parent) {}

QVariantMap AppRepository::getAppByIdentifier(const QString& appIdentifier) {
  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return QVariantMap();

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    id,
    app_identifier,
    app_name,
    COALESCE(NULLIF(display_name, ''), app_name) AS display_name,
    app_icon_path,
    executable_path,
    platform,
    created_at,
    updated_at
FROM apps
WHERE app_identifier = :app_identifier
LIMIT 1;
)SQL"))) {
    qWarning() << "Failed to prepare getAppByIdentifier:"
               << query.lastError().text();
    return QVariantMap();
  }

  query.bindValue(QStringLiteral(":app_identifier"), appIdentifier);

  if (!query.exec()) {
    qWarning() << "Failed to query app by identifier:"
               << query.lastError().text();
    return QVariantMap();
  }

  if (!query.next()) return QVariantMap();
  return appMapFromQuery(query);
}

bool AppRepository::upsertApp(const QString& appIdentifier,
                              const QString& appName,
                              const QString& displayName,
                              const QString& iconPath,
                              const QString& executablePath,
                              const QString& platform) {
  const QString normalizedIdentifier = appIdentifier.trimmed();
  if (normalizedIdentifier.isEmpty()) {
    qWarning() << "Cannot upsert app with empty app_identifier.";
    return false;
  }

  const QString normalizedAppName =
      appName.trimmed().isEmpty() ? normalizedIdentifier : appName;
  const QString normalizedDisplayName =
      displayName.trimmed().isEmpty() ? normalizedAppName : displayName;
  const QString normalizedPlatform =
      platform.trimmed().isEmpty() ? QStringLiteral("windows") : platform;
  const qint64 now = QDateTime::currentSecsSinceEpoch();

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
INSERT INTO apps (
    app_identifier,
    app_name,
    display_name,
    app_icon_path,
    executable_path,
    platform,
    created_at,
    updated_at
) VALUES (
    :app_identifier,
    :app_name,
    :display_name,
    :app_icon_path,
    :executable_path,
    :platform,
    :created_at,
    :updated_at
)
ON CONFLICT(app_identifier) DO UPDATE SET
    app_name = excluded.app_name,
    display_name = excluded.display_name,
    app_icon_path = excluded.app_icon_path,
    executable_path = excluded.executable_path,
    platform = excluded.platform,
    updated_at = excluded.updated_at;
)SQL"))) {
    qWarning() << "Failed to prepare upsertApp:" << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":app_identifier"), normalizedIdentifier);
  query.bindValue(QStringLiteral(":app_name"), normalizedAppName);
  query.bindValue(QStringLiteral(":display_name"), normalizedDisplayName);
  query.bindValue(QStringLiteral(":app_icon_path"), iconPath);
  query.bindValue(QStringLiteral(":executable_path"), executablePath);
  query.bindValue(QStringLiteral(":platform"), normalizedPlatform);
  query.bindValue(QStringLiteral(":created_at"), now);
  query.bindValue(QStringLiteral(":updated_at"), now);

  if (!query.exec()) {
    qWarning() << "Failed to upsert app:" << query.lastError().text();
    return false;
  }

  return true;
}

QVariantList AppRepository::getAllApps() {
  QVariantList apps;
  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return apps;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    id,
    app_identifier,
    app_name,
    COALESCE(NULLIF(display_name, ''), app_name) AS display_name,
    app_icon_path,
    executable_path,
    platform,
    created_at,
    updated_at
FROM apps
ORDER BY display_name COLLATE NOCASE ASC;
)SQL"))) {
    qWarning() << "Failed to prepare getAllApps:" << query.lastError().text();
    return apps;
  }

  if (!query.exec()) {
    qWarning() << "Failed to query all apps:" << query.lastError().text();
    return apps;
  }

  while (query.next()) {
    apps.append(appMapFromQuery(query));
  }

  return apps;
}
