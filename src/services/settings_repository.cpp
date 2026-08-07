#include "services/settings_repository.h"

#include <QDate>
#include <QDateTime>
#include <QDebug>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
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

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QLocale>
#include <QProcess>
#include <QThread>

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

  QSettings namedSettings(QSettings::defaultFormat(), QSettings::UserScope,
                          QStringLiteral("TimeArc"), QStringLiteral("TimeArc"));
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

  QSettings namedSettings(QSettings::defaultFormat(), QSettings::UserScope,
                          QStringLiteral("TimeArc"), QStringLiteral("TimeArc"));
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

namespace {

constexpr char kLanguageModeKey[] = "language_mode";

// TimeArc ships these three. Anything else — including Traditional Chinese,
// which has no Simplified-independent catalog here — is not a match.
QString supportedLanguageFor(const QString& tag) {
  const QString lower = QString(tag).replace(QLatin1Char('_'), QLatin1Char('-')).toLower();
  if (lower.startsWith(QLatin1String("en"))) return QStringLiteral("en");
  if (lower.startsWith(QLatin1String("ja"))) return QStringLiteral("ja");
  if (lower.startsWith(QLatin1String("zh"))) {
    const bool traditional = lower.contains(QLatin1String("hant")) ||
                             lower.startsWith(QLatin1String("zh-tw")) ||
                             lower.startsWith(QLatin1String("zh-hk")) ||
                             lower.startsWith(QLatin1String("zh-mo"));
    if (!traditional) return QStringLiteral("zh");
  }
  return {};
}

// The user's ordered language list. On macOS this must come from the GLOBAL
// domain: TimeArc pins AppleLanguages in its OWN domain so AppKit will speak
// the UI language (see macos_menu_localizer.cpp), and the app domain sits
// above the global one in the defaults chain — asking QLocale::system() here
// would read our own pin back and make the default self-referential.
//
// QSettings maps an organization name containing a dot straight to a
// preferences domain, so ".GlobalPreferences" is the system list System
// Settings writes. Going through QSettings rather than CoreFoundation keeps
// this file linkable in every target that compiles it, including the
// framework-less db smoke test.
QStringList systemLanguageTags() {
#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
  QSettings globals(QSettings::NativeFormat, QSettings::UserScope,
                    QStringLiteral(".GlobalPreferences"));
  const QStringList tags =
      globals.value(QStringLiteral("AppleLanguages")).toStringList();
  if (!tags.isEmpty()) return tags;
#endif
  // Windows/Linux have nothing pinned, so the Qt view is the system's own.
  return QLocale::system().uiLanguages();
}

// First entry that names a language we ship wins, so a system list of
// (zh-Hant-TW, ja-JP) still lands on Japanese rather than skipping to the
// fallback. English is the fallback when nothing matches.
QString systemLanguageMode() {
  const QStringList tags = systemLanguageTags();
  for (const QString& tag : tags) {
    const QString match = supportedLanguageFor(tag);
    if (!match.isEmpty()) return match;
  }
  return QStringLiteral("en");
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
    QSettings projectSettings(QSettings::defaultFormat(),
                              QSettings::UserScope, QStringLiteral("TimeArc"),
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

  QSettings calendarSettings(QSettings::defaultFormat(),
                             QSettings::UserScope, QStringLiteral("TimeArc"),
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

namespace {
#if defined(Q_OS_WIN)
// 解析与 main.cpp::startUsageService 相同的 service exe 路径（同目录）。
QString serviceExePath() {
  return QDir(QCoreApplication::applicationDirPath())
      .filePath(QStringLiteral("time-arc-service.exe"));
}

QString uiAutostartRunKey() {
  return QStringLiteral(
      "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run");
}

QString uiAutostartValueName() { return QStringLiteral("TimeArc"); }

QString quotedNativePath(const QString& path) {
  QString escaped = QDir::toNativeSeparators(path);
  escaped.replace(QStringLiteral("\""), QStringLiteral("\\\""));
  return QStringLiteral("\"") + escaped + QStringLiteral("\"");
}

QString uiAutostartCommand() {
  return quotedNativePath(QCoreApplication::applicationFilePath()) +
         QStringLiteral(" --start-in-tray");
}

QString readUiAutostartCommand() {
  QSettings runKey(uiAutostartRunKey(), QSettings::NativeFormat);
  return runKey.value(uiAutostartValueName()).toString().trimmed();
}

bool writeUiAutostartCommand() {
  QSettings runKey(uiAutostartRunKey(), QSettings::NativeFormat);
  runKey.setValue(uiAutostartValueName(), uiAutostartCommand());
  runKey.sync();
  return runKey.status() == QSettings::NoError;
}

bool removeUiAutostartCommand() {
  QSettings runKey(uiAutostartRunKey(), QSettings::NativeFormat);
  runKey.remove(uiAutostartValueName());
  runKey.sync();
  return runKey.status() == QSettings::NoError;
}

// 同步运行一个 service 动词，捕获 stdout；返回退出码（启动失败 -1）。纯 UI→子进程
// 命令（守 I1），不经磁盘契约。CREATE_NO_WINDOW 隐藏 service（console 程序）窗口。
int runServiceVerb(const QString& verb, QString* out = nullptr) {
  const QString exe = serviceExePath();
  if (!QFileInfo::exists(exe)) return -1;
  QProcess proc;
  proc.setCreateProcessArgumentsModifier(
      [](QProcess::CreateProcessArguments* args) {
        args->flags |= 0x08000000;  // CREATE_NO_WINDOW
      });
  proc.start(exe, QStringList{verb});
  if (!proc.waitForStarted(3000)) return -1;
  if (!proc.waitForFinished(8000)) {
    proc.kill();
    return -1;
  }
  if (out) *out = QString::fromLocal8Bit(proc.readAllStandardOutput());
  return proc.exitCode();
}
#elif defined(Q_OS_MACOS)
// 与 Windows 同形（UI→子进程命令，守 I1，不经磁盘契约），但动词是新 CLI 的裸动词，
// 且 helper 与 UI 同在 Contents/MacOS。CHARTER v0.14：注册/启停归 service 自己，
// UI 只调 CLI。退出码含义见 src/service/README.md。
QString serviceExePath() {
  return QDir(QCoreApplication::applicationDirPath())
      .filePath(QStringLiteral("time-arc-service"));
}

// 同步跑一个动词并返回退出码（启动失败 -1）。enable/disable 要等 launchctl 落定，
// start/stop 要等实例就绪/冲刷完成，故超时给到 15s。
int runServiceVerb(const QString& verb, QString* out = nullptr) {
  const QString exe = serviceExePath();
  if (!QFileInfo::exists(exe)) return -1;
  QProcess proc;
  proc.start(exe, QStringList{verb});
  if (!proc.waitForStarted(3000)) return -1;
  if (!proc.waitForFinished(15000)) {
    proc.kill();
    return -1;
  }
  if (out) *out = QString::fromLocal8Bit(proc.readAllStandardOutput());
  return proc.exitCode();
}

// 跑 `status --json` 并把关心的叶子摊平成 map。退出码 10 表示服务自己也答不准，
// 视为查询失败；其余码都带有效负载（12=没跑但配置开着，等等），照常解析。
bool readServiceStatus(QVariantMap* out) {
  const QString exe = serviceExePath();
  if (!QFileInfo::exists(exe)) return false;
  QProcess proc;
  proc.start(exe, QStringList{QStringLiteral("status"),
                              QStringLiteral("--json")});
  if (!proc.waitForStarted(3000)) return false;
  if (!proc.waitForFinished(15000)) {
    proc.kill();
    return false;
  }
  if (proc.exitCode() == 10) return false;

  const QJsonDocument doc =
      QJsonDocument::fromJson(proc.readAllStandardOutput());
  if (!doc.isObject()) return false;
  const QJsonObject root = doc.object();
  const QJsonObject tracking = root.value(QStringLiteral("tracking")).toObject();
  const QJsonObject autostart =
      root.value(QStringLiteral("autostart")).toObject();

  out->insert(QStringLiteral("tracking.running"),
              tracking.value(QStringLiteral("running")).toBool());
  out->insert(QStringLiteral("tracking.enabled"),
              tracking.value(QStringLiteral("enabled")).toBool());
  out->insert(QStringLiteral("autostart.enabled"),
              autostart.value(QStringLiteral("enabled")).toBool());
  out->insert(QStringLiteral("autostart.backend"),
              autostart.value(QStringLiteral("backend")).toVariant());
  return true;
}
#endif
}  // namespace

bool SettingsRepository::autostartSupported() const {
#if defined(Q_OS_WIN) || defined(Q_OS_MACOS)
  return true;
#else
  return false;
#endif
}

bool SettingsRepository::autostartEnabled() {
#if defined(Q_OS_WIN)
  const QString command = readUiAutostartCommand();
  return command.contains(QCoreApplication::applicationFilePath(),
                          Qt::CaseInsensitive) &&
         command.contains(QStringLiteral("--start-in-tray"),
                          Qt::CaseInsensitive);
#elif defined(Q_OS_MACOS)
  // launchd is the only record of this, and the service owns launchd. Nothing is
  // mirrored here: a stored copy could disagree with the registration, and then
  // neither value would be trustworthy. A query that fails reports "off",
  // because an autostart we cannot confirm is not one the user can rely on.
  QVariantMap state;
  if (!readServiceStatus(&state)) {
    qWarning() << "TimeArc: could not read the service autostart state";
    return false;
  }
  return state.value(QStringLiteral("autostart.enabled")).toBool();
#else
  return false;
#endif
}

bool SettingsRepository::setAutostartEnabled(bool enabled) {
#if defined(Q_OS_WIN)
  // Clear the older service-only registration path. The UI now starts in the
  // tray at logon and then launches the collector through main.cpp, matching
  // user expectation that TimeArc itself is available after reboot.
  runServiceVerb(QStringLiteral("--uninstall"));
  return enabled ? writeUiAutostartCommand() : removeUiAutostartCommand();
#elif defined(Q_OS_MACOS)
  // The verb is the write. There is nothing to record afterwards: the next read
  // asks the service again.
  const QString verb =
      enabled ? QStringLiteral("enable") : QStringLiteral("disable");
  return runServiceVerb(verb) == 0;
#else
  Q_UNUSED(enabled);
  return false;
#endif
}

bool SettingsRepository::isBackgroundCollectionRunning() {
#if defined(Q_OS_WIN)
  QString out;
  if (runServiceVerb(QStringLiteral("--status"), &out) < 0) return false;
  return out.contains(QStringLiteral("running=yes"));
#else
  return false;
#endif
}

bool SettingsRepository::stopBackgroundCollection() {
#if defined(Q_OS_WIN)
  // Graceful stop: set Local\TimeArcStop so the running tracker flushes the open
  // session + audio and exits (NOT taskkill /F). --stop returns as soon as the
  // event is set; the flush + handle release takes up to ~one poll interval, so
  // poll --status until the instance is actually gone (the DB lock is released)
  // before we report success -- a relocation/restore needs an exclusive lock.
  runServiceVerb(QStringLiteral("--stop"));
  for (int i = 0; i < 12; ++i) {
    QString out;
    if (runServiceVerb(QStringLiteral("--status"), &out) >= 0 &&
        out.contains(QStringLiteral("running=no"))) {
      return true;
    }
    QThread::msleep(300);
  }
  QString out;
  return runServiceVerb(QStringLiteral("--status"), &out) >= 0 &&
         out.contains(QStringLiteral("running=no"));
#elif defined(Q_OS_MACOS)
  // `stop` already waits for the instance to flush and release its lock before
  // returning, so no polling loop is needed here.
  return runServiceVerb(QStringLiteral("stop")) == 0;
#else
  return true;  // no background collector to stop on this platform yet
#endif
}

bool SettingsRepository::startBackgroundCollection() {
#if defined(Q_OS_WIN)
  // Launch a tracker now; the single-instance mutex makes a double-start
  // idempotent. --start returns as soon as the launcher fires, so poll --status
  // briefly for the tracker to grab the mutex (tracking on) -- or, when tracking
  // was just turned off, to self-exit -- before reporting the real running state.
  if (runServiceVerb(QStringLiteral("--start")) < 0) return false;
  for (int i = 0; i < 8; ++i) {
    QString out;
    if (runServiceVerb(QStringLiteral("--status"), &out) >= 0 &&
        out.contains(QStringLiteral("running=yes"))) {
      return true;
    }
    QThread::msleep(200);
  }
  QString out;
  return runServiceVerb(QStringLiteral("--status"), &out) >= 0 &&
         out.contains(QStringLiteral("running=yes"));
#elif defined(Q_OS_MACOS)
  // The UI never calls `start`: that would leave a collector this process
  // spawned and launchd does not supervise. `enable` registers the agent, and
  // RunAtLoad means launchd starts it immediately, so collection begins under
  // the supervisor that will also bring it back at login.
  //
  // Only when autostart is already on. Registering here otherwise would install
  // a login item the user never asked for, as a side effect of a button labelled
  // "apply and restart". The Settings button is disabled in that case; this is
  // the same rule enforced on the calling side.
  if (!autostartEnabled()) return false;
  return runServiceVerb(QStringLiteral("enable")) == 0;
#else
  return false;  // no background collector to start on this platform yet
#endif
}

bool SettingsRepository::verifyBackgroundCollection() {
#if defined(Q_OS_MACOS)
  QVariantMap state;
  if (!readServiceStatus(&state)) {
    qWarning() << "TimeArc: could not query the background service state";
    return false;
  }

  const bool registered =
      state.value(QStringLiteral("autostart.enabled")).toBool();
  const bool running = state.value(QStringLiteral("tracking.running")).toBool();
  const bool trackingEnabled =
      state.value(QStringLiteral("tracking.enabled")).toBool();

  // An existing registration is the opt-in. Without one there is nothing to
  // repair and nothing to infer: launching the app must never create a login
  // item the user did not ask for.
  if (!registered) return false;

  // Not running while tracking is switched off in configuration is the correct
  // state, not a fault -- the collector exits on purpose.
  if (running || !trackingEnabled) return running;

  qWarning() << "TimeArc: autostart is registered but nothing is collecting"
             << "-- restarting the service";
  if (runServiceVerb(QStringLiteral("enable")) != 0) {
    qWarning() << "TimeArc: could not restart the background service";
    return false;
  }
  return true;
#else
  return false;  // startup self-check is macOS-only
#endif
}

QString SettingsRepository::languageMode() {
  const QString stored = getValue(QString::fromLatin1(kLanguageModeKey));
  if (stored == QLatin1String("en") || stored == QLatin1String("zh") ||
      stored == QLatin1String("ja")) {
    return stored;
  }

  // Absent (first run) or unrecognized (hand-edited, or written by an older
  // build): adopt the system language and write it down, so every later reader
  // — QML shells, the settings page, the macOS menu bar and status item — sees
  // one agreed value instead of each applying its own default.
  const QString resolved = systemLanguageMode();
  setValue(QString::fromLatin1(kLanguageModeKey), resolved);
  return resolved;
}
