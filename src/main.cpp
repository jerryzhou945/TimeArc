#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "services/projectmanager.h"
#include "services/timermanager.h"

int main(int argc, char* argv[]) {
  QGuiApplication app(argc, argv);

  QQmlApplicationEngine engine;

  TimerManager timerManager;
  ProjectManager projectManager;

  engine.rootContext()->setContextProperty("timerManager", &timerManager);
  engine.rootContext()->setContextProperty("projectManager", &projectManager);

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  engine.loadFromModule("time_arc", "Main");

  if (engine.rootObjects().isEmpty()) return -1;

  return app.exec();
}
