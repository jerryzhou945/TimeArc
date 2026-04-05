#ifndef TIMERMANAGER_H
#define TIMERMANAGER_H

#include <QObject>
#include <QTimer>

class TimerManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(
      QString currentProject READ currentProject NOTIFY currentProjectChanged)
  Q_PROPERTY(
      int elapsedSeconds READ elapsedSeconds NOTIFY elapsedSecondsChanged)
  Q_PROPERTY(bool running READ running NOTIFY runningChanged)

 public:
  explicit TimerManager(QObject* parent = nullptr);

  QString currentProject() const;
  int elapsedSeconds() const;
  bool running() const;

  Q_INVOKABLE void startProject(const QString& projectName);
  Q_INVOKABLE void pauseTimer();
  Q_INVOKABLE void resumeTimer();
  Q_INVOKABLE void stopAndCommit();

 signals:
  void currentProjectChanged();
  void elapsedSecondsChanged();
  void runningChanged();

  void timerStarted();
  void timerStopped(const QString& projectName, int elapsedSeconds);

 private slots:
  void onTick();

 private:
  QString m_currentProject;
  int m_elapsedSeconds;
  bool m_running;
  QTimer m_timer;
};

#endif
