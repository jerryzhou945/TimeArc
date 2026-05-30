// SPDX-License-Identifier: GPL-3.0-or-later

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStringList>
#include <QUrl>

#include "services/AppRepository.h"
#include "services/DailyCardService.h"
#include "services/DatabaseManager.h"
#include "services/FrontmostSessionRepository.h"
#include "services/ManualProjectRepository.h"
#include "services/MediaSessionRepository.h"
#include "services/SettingsRepository.h"
#include "services/StatsService.h"
#include "services/TagRepository.h"
#include "services/appiconimageprovider.h"
#include "services/calendarmanager.h"
#include "services/harnesslogger.h"
#include "services/projectmanager.h"
#include "services/timermanager.h"
#include "services/usagestatmanager.h"

namespace {

bool hasMobilePreviewArg(int argc, char* argv[]) {
  for (int i = 1; i < argc; ++i) {
    const QString arg = QString::fromLocal8Bit(argv[i]);
    if (arg == QStringLiteral("--mobile") ||
        arg == QStringLiteral("--mobile-preview")) {
      return true;
    }
  }
  return false;
}

void startUsageService() {
#if defined(Q_OS_WIN)
  const QString appDir = QCoreApplication::applicationDirPath();
  const QString servicePath = QDir(appDir).filePath("time-arc-service.exe");
  if (!QFileInfo::exists(servicePath)) return;

  QProcess::startDetached(servicePath, QStringList(), appDir);
#endif
}

}  // namespace

int main(int argc, char* argv[]) {
  const bool mobilePreview =
      hasMobilePreviewArg(argc, argv) ||
      qEnvironmentVariableIsSet("TIMEARC_MOBILE_PREVIEW");

  QGuiApplication app(argc, argv);
  QCoreApplication::setOrganizationName("TimeArc");
  QCoreApplication::setApplicationName("TimeArc");

  // Tee Qt Warning/Critical/Fatal into the harness log. See
  // .harness/tools/scan_qt_log.py for the consumer that converts log
  // lines into L2 error reports.
  installHarnessLogger();

  startUsageService();

  QQmlApplicationEngine engine;

  DatabaseManager databaseManager;
  if (!databaseManager.initialize()) {
    qWarning() << "Database initialization failed.";
  }

  AppRepository appRepository;
  SettingsRepository settingsRepository;
  FrontmostSessionRepository frontmostRepository;
  ManualProjectRepository manualProjectRepository;
  if (!settingsRepository.migrateLegacyQSettings(&manualProjectRepository)) {
    qWarning() << "Legacy QSettings migration did not complete.";
  }

  CalendarManager calendarManager(&settingsRepository);
  MediaSessionRepository mediaRepository;
  StatsService statsService(&frontmostRepository, &mediaRepository,
                            &manualProjectRepository);
  DailyCardService dailyCardService(&statsService);
  TagRepository tagRepository;
  TimerManager timerManager;
  ProjectManager projectManager(&manualProjectRepository);
  UsageStatManager usageStatManager;

  engine.addImageProvider(QStringLiteral("appicon"), new AppIconImageProvider);

  engine.rootContext()->setContextProperty("databaseManager",
                                           &databaseManager);
  engine.rootContext()->setContextProperty("appRepository", &appRepository);
  engine.rootContext()->setContextProperty("calendarManager", &calendarManager);
  engine.rootContext()->setContextProperty("frontmostRepository",
                                           &frontmostRepository);
  engine.rootContext()->setContextProperty("manualProjectRepository",
                                           &manualProjectRepository);
  engine.rootContext()->setContextProperty("mediaRepository",
                                           &mediaRepository);
  engine.rootContext()->setContextProperty("settingsRepository",
                                           &settingsRepository);
  engine.rootContext()->setContextProperty("statsService", &statsService);
  engine.rootContext()->setContextProperty("dailyCardService",
                                           &dailyCardService);
  engine.rootContext()->setContextProperty("tagRepository", &tagRepository);
  engine.rootContext()->setContextProperty("timerManager", &timerManager);
  engine.rootContext()->setContextProperty("projectManager", &projectManager);
  engine.rootContext()->setContextProperty("usageStatManager",
                                           &usageStatManager);
  engine.rootContext()->setContextProperty("mobilePreview", mobilePreview);

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  engine.load(QUrl(QStringLiteral("qrc:/qt/qml/time_arc/qml/main.qml")));

  if (engine.rootObjects().isEmpty()) return -1;

  return app.exec();
}
