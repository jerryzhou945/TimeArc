#ifndef POMODOROMANAGER_H
#define POMODOROMANAGER_H

#include <QObject>
#include <QString>
#include <QTimer>

class SettingsRepository;

// 番茄钟计时引擎（原 PomodoroWidget.qml 的上半部：状态 / 持久化 / 完成判定）。
// QML 那一侧只剩显示与手势——收缩成像素番茄、拖动、发光，都不参与计时。
//
// 计时按**墙钟锚点**而非 tick 计数：QTimer 只是「该刷新了」的提醒，每次醒来都拿
// 当前时间跟开始时刻相减。这样漏掉的 tick（事件循环被阻塞、Qt::CoarseTimer 为省电
// 对齐唤醒、机器睡眠）都不会变成丢掉的秒——旧实现每漏一拍就少一秒，且只少不多。
class PomodoroManager : public QObject {
  Q_OBJECT

  Q_PROPERTY(int total READ total NOTIFY totalChanged)
  Q_PROPERTY(int remain READ remain NOTIFY remainChanged)
  Q_PROPERTY(bool running READ running NOTIFY runningChanged)
  Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
  // 纯派生量，随 remain / total 一起变。
  Q_PROPERTY(QString timeText READ timeText NOTIFY remainChanged)
  Q_PROPERTY(qreal progress READ progress NOTIFY progressChanged)

 public:
  explicit PomodoroManager(SettingsRepository* settings = nullptr,
                           QObject* parent = nullptr);

  int total() const;
  int remain() const;
  bool running() const;
  QString title() const;
  QString timeText() const;
  qreal progress() const;

  Q_INVOKABLE void startTimer();
  Q_INVOKABLE void pauseTimer();
  Q_INVOKABLE void resetTimer();
  // 分 [0,180] / 秒 [0,59]；0 分 0 秒允许存在，但 startTimer() 会拒绝开始。
  Q_INVOKABLE void setMinutes(int minutes);
  Q_INVOKABLE void setSeconds(int seconds);
  Q_INVOKABLE void setTitle(const QString& title);

 signals:
  void totalChanged();
  void remainChanged();
  void runningChanged();
  void titleChanged();
  void progressChanged();

  // 一程走完（remain 归零）。庆祝弹层与系统通知由 QML 侧的 PomodoroLayer 决定。
  void finished();

 protected:
  // 墙钟读数。虚函数只为单测能注入一个可控的时钟；生产实现取
  // QDateTime::currentMSecsSinceEpoch()。
  //
  // 为什么是墙钟而不是 QElapsedTimer：单调钟在 macOS 背后是 mach_absolute_time，
  // 睡眠期间**不走**（走的是 mach_continuous_time），Linux 的 CLOCK_MONOTONIC 同样
  // 不含挂起。睡眠正是这次要修的主要场景，用单调钟等于修了个寂寞。代价是墙钟会被
  // NTP 校正或用户改表往回拨——refreshFromClock() 里就地重锚来兜这一种。
  virtual qint64 currentMs() const;

 private slots:
  void onTick();

 private:
  void load();
  void save();
  void scheduleSave();
  int settingsMinutes() const;
  QString settingsValue(const QString& key) const;
  void recordCompletion();
  void anchorNow();
  void refreshFromClock();
  void finishSession();
  void setTotalSeconds(int seconds);
  void setRemainSeconds(int seconds);

  int m_total;
  int m_remain;
  bool m_running;
  QString m_title;
  bool m_loaded;

  // 墙钟锚点：m_anchorMs 时刻的剩余秒数是 m_remainAtAnchor，之后一律相减得出。
  qint64 m_anchorMs;
  int m_remainAtAnchor;

  QTimer m_timer;
  QTimer m_saveTimer;
  SettingsRepository* m_settings;
};

#endif
