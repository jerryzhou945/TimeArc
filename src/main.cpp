// SPDX-License-Identifier: GPL-3.0-or-later

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStringList>
#include <QUrl>

#include "services/calendarmanager.h"
#include "services/projectmanager.h"
#include "services/timermanager.h"
#include "services/usagestatmanager.h"

namespace {

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
  QGuiApplication app(argc, argv);
  QCoreApplication::setOrganizationName("TimeArc");
  QCoreApplication::setApplicationName("TimeArc");

  startUsageService();

  QQmlApplicationEngine engine;

  CalendarManager calendarManager;
  TimerManager timerManager;
  ProjectManager projectManager;
  UsageStatManager usageStatManager;

  engine.rootContext()->setContextProperty("calendarManager", &calendarManager);
  engine.rootContext()->setContextProperty("timerManager", &timerManager);
  engine.rootContext()->setContextProperty("projectManager", &projectManager);
  engine.rootContext()->setContextProperty("usageStatManager",
                                           &usageStatManager);

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  engine.load(QUrl(QStringLiteral("qrc:/qt/qml/time_arc/qml/main.qml")));

  if (engine.rootObjects().isEmpty()) return -1;

  return app.exec();
}
