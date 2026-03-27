#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char* argv[]) {
  QGuiApplication app(argc, argv);

  app.setOrganizationName("TimeArc");
  app.setApplicationName("TimeArc");

  QQmlApplicationEngine engine;
  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  engine.loadFromModule("time-arc", "Main");

  return app.exec();
}
