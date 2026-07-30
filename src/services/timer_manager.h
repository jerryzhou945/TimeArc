#ifndef TIMERMANAGER_H
#define TIMERMANAGER_H

#include <QObject>
#include <QTimer>

// 手动计时器服务。
//
// 它只维护“当前项目 + 已经过秒数 + 是否运行”，真正把时间写入项目历史由
// QML 接收到 timerStopped 后调用 ProjectManager 完成。
//
// 计时按**墙钟锚点**而非 tick 计数：QTimer 只是「该刷新了」的提醒，每次醒来都拿当前
// 时间跟本段起点相减，暂停时把已走的秒数折进 m_accumulatedSeconds。旧实现每拍 ++ 一秒，
// 事件循环被阻塞、Qt::CoarseTimer 对齐唤醒、机器睡眠都会漏拍，而漏掉的秒只少不多——
// 少算的结果经 stopAndCommit → ProjectManager 写进项目历史，下游再无从分辨。
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

 protected:
  // 墙钟读数。虚函数只为单测能注入一个可控的时钟。取墙钟而非 QElapsedTimer：
  // 单调钟在 macOS / Linux 睡眠期间不走，而睡眠正是要修的主要场景。
  virtual qint64 currentMs() const;

 private slots:
  void onTick();

 private:
  void anchorNow();
  void refreshFromClock();

  QString m_currentProject;
  int m_elapsedSeconds;
  bool m_running;

  // 本段起点（墙钟）与此前各段累计。elapsed = 累计 + (now - 本段起点)。
  qint64 m_anchorMs;
  int m_accumulatedSeconds;

  QTimer m_timer;
};

#endif
