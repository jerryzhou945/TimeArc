#include "services/settings_repository.h"

#include <QDate>
#include <QDateTime>
#include <QDebug>
#include <QFile>
#include <QMetaType>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
#include <QTime>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

#include "services/manual_project_repository.h"

namespace {

const QString kConnectionName = QStringLiteral("timearc");
const QString kMigrationFlag =
    QStringLiteral("legacy_qsettings_migration_v1_done");
const QString kCalendarTodosKey = QStringLiteral("calendar_saved_todos");
const QString kCalendarPhotosKey = QStringLiteral("calendar_day_photos");
const QString kCalendarSelectedDateKey =
    QStringLiteral("calendar_selected_date");
const QString kMemoMessagesKey = QStringLiteral("local_memo_chat_messages");
const QString kNightModeKey = QStringLiteral("night_mode");
const QString kDefaultTagName = QStringLiteral("其他");

QSqlDatabase database() {
  QSqlDatabase db = QSqlDatabase::database(kConnectionName);
  if (!db.isValid() || !db.isOpen()) {
    qWarning() << "Database is not open.";
  }
  return db;
}

QDate legacySessionDate(const QVariantMap& session) {
  const QDate parsed =
      QDate::fromString(session.value(QStringLiteral("date")).toString(),
                        QStringLiteral("yyyy-MM-dd"));
  if (parsed.isValid()) return parsed;

  const int year = session.value(QStringLiteral("year")).toInt();
  const int month = session.value(QStringLiteral("month")).toInt();
  const int day = session.value(QStringLiteral("day")).toInt();
  const QDate fromParts(year, month, day);
  return fromParts.isValid() ? fromParts : QDate::currentDate();
}

qint64 legacySessionEndUnix(const QDate& date, int seconds) {
  const int secondsIntoDay =
      qBound(0, 12 * 60 * 60 + qMax(0, seconds), 24 * 60 * 60 - 1);
  return QDateTime(date, QTime(0, 0, 0).addSecs(secondsIntoDay))
      .toSecsSinceEpoch();
}

QString legacyChatMessages() {
  QSettings appSettings;
  appSettings.beginGroup(QStringLiteral("DesktopChatPageData"));
  const QString grouped = appSettings.value(QStringLiteral("savedChats")).toString();
  appSettings.endGroup();
  if (!grouped.trimmed().isEmpty()) return grouped;

  QSettings namedSettings(QStringLiteral("TimeArc"), QStringLiteral("TimeArc"));
  namedSettings.beginGroup(QStringLiteral("DesktopChatPageData"));
  const QString named =
      namedSettings.value(QStringLiteral("savedChats")).toString();
  namedSettings.endGroup();
  return named;
}

QVariant legacyNightModeValue() {
  QSettings appSettings;
  const QStringList keys = {
      QStringLiteral("night_mode"),
      QStringLiteral("nightMode"),
      QStringLiteral("DesktopAppShell/night_mode"),
      QStringLiteral("DesktopAppShell/nightMode"),
      QStringLiteral("DesktopProfilePage/night_mode"),
      QStringLiteral("DesktopProfilePage/nightMode"),
  };

  for (const QString& key : keys) {
    if (appSettings.contains(key)) return appSettings.value(key);
  }

  QSettings namedSettings(QStringLiteral("TimeArc"), QStringLiteral("TimeArc"));
  for (const QString& key : keys) {
    if (namedSettings.contains(key)) return namedSettings.value(key);
  }

  return QVariant();
}

bool truthySetting(const QVariant& value) {
  if (!value.isValid()) return false;
  if (value.typeId() == QMetaType::Bool) return value.toBool();

  const QString text = value.toString().trimmed().toLower();
  return text == QStringLiteral("true") || text == QStringLiteral("1") ||
         text == QStringLiteral("yes") || text == QStringLiteral("on");
}

}  // namespace

SettingsRepository::SettingsRepository(QObject* parent) : QObject(parent) {}

QString SettingsRepository::getValue(const QString& key,
                                     const QString& defaultValue) {
  const QString normalizedKey = key.trimmed();
  if (normalizedKey.isEmpty()) {
    qWarning() << "Cannot get setting with empty key.";
    return defaultValue;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return defaultValue;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT value
FROM settings
WHERE key = :key
LIMIT 1;
)SQL"))) {
    qWarning() << "Failed to prepare getValue:" << query.lastError().text();
    return defaultValue;
  }

  query.bindValue(QStringLiteral(":key"), normalizedKey);

  if (!query.exec()) {
    qWarning() << "Failed to query setting:" << query.lastError().text();
    return defaultValue;
  }

  if (!query.next()) return defaultValue;
  return query.value(0).toString();
}

bool SettingsRepository::setValue(const QString& key, const QString& value) {
  const QString normalizedKey = key.trimmed();
  if (normalizedKey.isEmpty()) {
    qWarning() << "Cannot set setting with empty key.";
    return false;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
INSERT INTO settings (
    key,
    value,
    updated_at
) VALUES (
    :key,
    :value,
    :updated_at
)
ON CONFLICT(key) DO UPDATE SET
    value = excluded.value,
    updated_at = excluded.updated_at;
)SQL"))) {
    qWarning() << "Failed to prepare setValue:" << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":key"), normalizedKey);
  query.bindValue(QStringLiteral(":value"), value);
  query.bindValue(QStringLiteral(":updated_at"),
                  QDateTime::currentSecsSinceEpoch());

  if (!query.exec()) {
    qWarning() << "Failed to set setting:" << query.lastError().text();
    return false;
  }

  return true;
}

bool SettingsRepository::getBool(const QString& key, bool defaultValue) {
  const QString value =
      getValue(key, defaultValue ? QStringLiteral("true")
                                 : QStringLiteral("false"))
          .trimmed()
          .toLower();

  if (value == QStringLiteral("true")) return true;
  if (value == QStringLiteral("false")) return false;

  return defaultValue;
}

bool SettingsRepository::setBool(const QString& key, bool value) {
  return setValue(key, value ? QStringLiteral("true")
                             : QStringLiteral("false"));
}

bool SettingsRepository::migrateLegacyQSettings(
    ManualProjectRepository* manualProjectRepository) {
  if (getBool(kMigrationFlag, false)) return true;

  bool ok = true;

  if (manualProjectRepository) {
    QSettings projectSettings(QStringLiteral("TimeArc"),
                              QStringLiteral("ProjectManagerData"));
    const QVariantList projects =
        projectSettings.value(QStringLiteral("projects")).toList();
    for (const QVariant& item : projects) {
      const QVariantMap project = item.toMap();
      const QString name = project.value(QStringLiteral("name")).toString();
      const QString tag =
          project.value(QStringLiteral("tag"), kDefaultTagName).toString();
      if (!name.trimmed().isEmpty() &&
          manualProjectRepository->ensureProject(name, tag) <= 0) {
        ok = false;
      }
    }

    const QVariantList sessions =
        projectSettings.value(QStringLiteral("sessions")).toList();
    for (const QVariant& item : sessions) {
      const QVariantMap session = item.toMap();
      const int seconds = session.value(QStringLiteral("seconds")).toInt();
      if (seconds <= 0) continue;

      const QString displayName =
          session
              .value(QStringLiteral("displayName"),
                     session.value(QStringLiteral("projectName")).toString())
              .toString()
              .trimmed();
      const QString linkedProjectName =
          session.value(QStringLiteral("linkedProjectName")).toString().trimmed();
      const QString projectName =
          linkedProjectName.isEmpty()
              ? session.value(QStringLiteral("projectName"), displayName)
                    .toString()
                    .trimmed()
              : linkedProjectName;
      if (projectName.isEmpty()) continue;

      const QString tag =
          session.value(QStringLiteral("tag"), kDefaultTagName).toString();
      const int projectId =
          manualProjectRepository->ensureProject(projectName, tag);
      if (projectId <= 0) {
        ok = false;
        continue;
      }

      const QDate date = legacySessionDate(session);
      const qint64 endUnixSec = legacySessionEndUnix(date, seconds);
      const qint64 startUnixSec = qMax<qint64>(0, endUnixSec - seconds);
      const QString source =
          session.value(QStringLiteral("source"), QStringLiteral("manual_project"))
              .toString();

      if (!manualProjectRepository->addManualSessionEntry(
              projectId, startUnixSec, endUnixSec, seconds,
              displayName.isEmpty() ? projectName : displayName, source,
              linkedProjectName)) {
        ok = false;
      }
    }
  }

  QSettings calendarSettings(QStringLiteral("TimeArc"),
                             QStringLiteral("CalendarManagerData"));
  const QString legacyTodos =
      calendarSettings.value(QStringLiteral("savedTodos")).toString();
  if (!legacyTodos.trimmed().isEmpty() &&
      getValue(kCalendarTodosKey, QString()).trimmed().isEmpty()) {
    ok = setValue(kCalendarTodosKey, legacyTodos) && ok;
  }

  const QString legacyPhotos =
      calendarSettings.value(QStringLiteral("dayPhotos")).toString();
  if (!legacyPhotos.trimmed().isEmpty() &&
      getValue(kCalendarPhotosKey, QString()).trimmed().isEmpty()) {
    ok = setValue(kCalendarPhotosKey, legacyPhotos) && ok;
  }

  const QString legacySelectedDate =
      calendarSettings.value(QStringLiteral("selectedDateKey")).toString();
  if (!legacySelectedDate.trimmed().isEmpty() &&
      getValue(kCalendarSelectedDateKey, QString()).trimmed().isEmpty()) {
    ok = setValue(kCalendarSelectedDateKey, legacySelectedDate) && ok;
  }

  const QString chatJson = legacyChatMessages();
  if (!chatJson.trimmed().isEmpty() &&
      getValue(kMemoMessagesKey, QString()).trimmed().isEmpty()) {
    ok = setValue(kMemoMessagesKey, chatJson) && ok;
  }

  const QVariant legacyNightMode = legacyNightModeValue();
  if (legacyNightMode.isValid() &&
      getValue(kNightModeKey, QString()).trimmed().isEmpty()) {
    ok = setBool(kNightModeKey, truthySetting(legacyNightMode)) && ok;
  }

  if (ok) ok = setBool(kMigrationFlag, true);
  return ok;
}

QVariantMap SettingsRepository::getAllSettings() {
  QVariantMap out;

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return out;

  QSqlQuery query(db);
  if (!query.exec(QStringLiteral("SELECT key, value FROM settings;"))) {
    qWarning() << "Failed to query all settings:" << query.lastError().text();
    return out;
  }

  while (query.next()) {
    out.insert(query.value(0).toString(), query.value(1).toString());
  }
  return out;
}

QString SettingsRepository::readTextFile(const QString& path) {
  QString localPath = path;
  const QUrl url(path);
  if (url.isLocalFile()) localPath = url.toLocalFile();

  if (localPath.trimmed().isEmpty()) return QString();

  QFile file(localPath);
  if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
    qWarning() << "Failed to open file for read:" << localPath
               << file.errorString();
    return QString();
  }

  const QByteArray data = file.readAll();
  file.close();
  return QString::fromUtf8(data);
}
