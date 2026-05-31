#include "services/timer_manager.h"

TimerManager::TimerManager(QObject* parent)
    : QObject(parent), m_elapsedSeconds(0), m_running(false) {
  // 手动计时精度按秒。QTimer 只驱动 UI 状态，最终提交时再把秒数交给 ProjectManager。
  m_timer.setInterval(1000);
  connect(&m_timer, &QTimer::timeout, this, &TimerManager::onTick);
}

QString TimerManager::currentProject() const { return m_currentProject; }

int TimerManager::elapsedSeconds() const { return m_elapsedSeconds; }

bool TimerManager::running() const { return m_running; }

void TimerManager::startProject(const QString& projectName) {
  // 开始新项目会重置已有秒数；当前 UI 设计一次只允许一个手动计时。
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
  // 先保存结束信息再清空内部状态，确保 timerStopped 信号携带完整结果。
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
