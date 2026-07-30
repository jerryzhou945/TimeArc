#include "services/timer_manager.h"

#include <QDateTime>
#include <QtGlobal>

TimerManager::TimerManager(QObject* parent)
    : QObject(parent),
      m_elapsedSeconds(0),
      m_running(false),
      m_anchorMs(0),
      m_accumulatedSeconds(0) {
  // 手动计时精度按秒。QTimer 只驱动 UI 刷新，秒数由墙钟算出；最终提交时再把秒数
  // 交给 ProjectManager。
  m_timer.setInterval(1000);
  connect(&m_timer, &QTimer::timeout, this, &TimerManager::onTick);
}

qint64 TimerManager::currentMs() const {
  return QDateTime::currentMSecsSinceEpoch();
}

QString TimerManager::currentProject() const { return m_currentProject; }

int TimerManager::elapsedSeconds() const { return m_elapsedSeconds; }

bool TimerManager::running() const { return m_running; }

void TimerManager::anchorNow() { m_anchorMs = currentMs(); }

// 把「累计 + 本段」重新算成 m_elapsedSeconds。漏掉的 tick 不影响结果：下一拍照样
// 从起点相减，睡掉的那段时间自然补回。
void TimerManager::refreshFromClock() {
  if (!m_running) return;

  const qint64 now = currentMs();
  if (now < m_anchorMs) {
    // 墙钟被往回拨（NTP 校正 / 用户改表）：把已走的这一段就地折进累计并重锚，
    // 既不让秒数倒退，也不至于冻到真实时间追上来。
    m_anchorMs = now;
    return;
  }

  const qint64 segment = (now - m_anchorMs) / 1000;
  const int next =
      static_cast<int>(static_cast<qint64>(m_accumulatedSeconds) + segment);
  if (next == m_elapsedSeconds) return;

  m_elapsedSeconds = next;
  emit elapsedSecondsChanged();
}

void TimerManager::startProject(const QString& projectName) {
  // 开始新项目会重置已有秒数；当前 UI 设计一次只允许一个手动计时。
  m_currentProject = projectName;
  m_elapsedSeconds = 0;
  m_accumulatedSeconds = 0;
  m_running = true;
  anchorNow();

  emit currentProjectChanged();
  emit elapsedSecondsChanged();
  emit runningChanged();

  m_timer.start();
  emit timerStarted();
}

void TimerManager::pauseTimer() {
  if (!m_running) return;

  // 先按墙钟结账到此刻再停表，否则最后不足一拍的时间会被抹掉。
  refreshFromClock();
  m_accumulatedSeconds = m_elapsedSeconds;

  m_running = false;
  m_timer.stop();
  emit runningChanged();
}

void TimerManager::resumeTimer() {
  if (m_running || m_currentProject.isEmpty()) return;

  m_running = true;
  anchorNow();   // 新的一段从此刻起算，暂停期间不计时
  m_timer.start();
  emit runningChanged();
}

void TimerManager::stopAndCommit() {
  // 先保存结束信息再清空内部状态，确保 timerStopped 信号携带完整结果。
  refreshFromClock();   // 收尾同样要结账，最后那几秒一样算数
  m_timer.stop();

  QString finishedProject = m_currentProject;
  int finishedSeconds = m_elapsedSeconds;

  m_running = false;
  m_currentProject.clear();
  m_elapsedSeconds = 0;
  m_accumulatedSeconds = 0;

  emit runningChanged();
  emit currentProjectChanged();
  emit elapsedSecondsChanged();

  emit timerStopped(finishedProject, finishedSeconds);
}

void TimerManager::onTick() { refreshFromClock(); }
