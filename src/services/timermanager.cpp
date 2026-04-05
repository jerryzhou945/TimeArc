#include "services/timermanager.h"

TimerManager::TimerManager(QObject* parent)
    : QObject(parent), m_elapsedSeconds(0), m_running(false) {
  m_timer.setInterval(1000);
  connect(&m_timer, &QTimer::timeout, this, &TimerManager::onTick);
}

QString TimerManager::currentProject() const { return m_currentProject; }

int TimerManager::elapsedSeconds() const { return m_elapsedSeconds; }

bool TimerManager::running() const { return m_running; }

void TimerManager::startProject(const QString& projectName) {
  m_currentProject = projectName;
  m_elapsedSeconds = 0;
  m_running = true;

  emit currentProjectChanged();
  emit elapsedSecondsChanged();
  emit runningChanged();

  m_timer.start();
  emit timerStarted();
}

void TimerManager::pauseTimer() {
  if (!m_running) return;

  m_running = false;
  m_timer.stop();
  emit runningChanged();
}

void TimerManager::resumeTimer() {
  if (m_running || m_currentProject.isEmpty()) return;

  m_running = true;
  m_timer.start();
  emit runningChanged();
}

void TimerManager::stopAndCommit() {
  m_timer.stop();

  QString finishedProject = m_currentProject;
  int finishedSeconds = m_elapsedSeconds;

  m_running = false;
  m_currentProject.clear();
  m_elapsedSeconds = 0;

  emit runningChanged();
  emit currentProjectChanged();
  emit elapsedSecondsChanged();

  emit timerStopped(finishedProject, finishedSeconds);
}

void TimerManager::onTick() {
  ++m_elapsedSeconds;
  emit elapsedSecondsChanged();
}
