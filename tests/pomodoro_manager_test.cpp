// PomodoroManager / TimerManager 的状态机与墙钟行为。
//
// 这个文件存在的理由就是漂移那件事：旧实现按 tick 计数，睡眠 / 阻塞漏掉的每一拍都
// 变成丢掉的一秒，而这偏差**只少不多**。丢秒本身没法在单测里"等出来"，于是两个管理器
// 都留了一个 protected 的 currentMs()，这里注入一个手拧的时钟——把表往前拨一小时，
// 就等价于合上盖子睡了一小时。
// 信号计数用普通 connect 而不是 QSignalSpy：后者要 Qt6::Test，而顶层 CMakeLists
// 是冻结文件，能少动一处就少动一处。
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QString>
#include <QtGlobal>

#include <QDir>

#include <cstdio>

#include "services/database_manager.h"
#include "services/pomodoro_manager.h"
#include "services/settings_repository.h"
#include "services/timer_manager.h"

namespace {

int g_failures = 0;

void check(bool ok, const char* what) {
  if (!ok) {
    std::fprintf(stderr, "FAIL: %s\n", what);
    ++g_failures;
  }
}

void checkEqual(int actual, int expected, const char* what) {
  if (actual != expected) {
    std::fprintf(stderr, "FAIL: %s (expected %d, got %d)\n", what, expected,
                 actual);
    ++g_failures;
  }
}

// 可手拧的时钟。advance() 之后调用 tick()，等价于「过了这么久，然后 QTimer 醒了」。
class FakeClockPomodoro : public PomodoroManager {
 public:
  explicit FakeClockPomodoro(SettingsRepository* settings)
      : PomodoroManager(settings) {}

  void advanceMs(qint64 ms) { m_nowMs += ms; }
  void setNowMs(qint64 ms) { m_nowMs = ms; }
  // QTimer 在测试里不会真的响；直接调用槽等价于「那一拍到了」。
  void tick() { QMetaObject::invokeMethod(this, "onTick"); }

 protected:
  qint64 currentMs() const override { return m_nowMs; }

 private:
  qint64 m_nowMs = 1'700'000'000'000LL;
};

class FakeClockTimer : public TimerManager {
 public:
  void advanceMs(qint64 ms) { m_nowMs += ms; }
  void setNowMs(qint64 ms) { m_nowMs = ms; }
  void tick() { QMetaObject::invokeMethod(this, "onTick"); }

 protected:
  qint64 currentMs() const override { return m_nowMs; }

 private:
  qint64 m_nowMs = 1'700'000'000'000LL;
};

void testPomodoroCountsWallClockNotTicks(SettingsRepository* settings) {
  FakeClockPomodoro pomo(settings);
  pomo.setMinutes(25);
  pomo.setSeconds(0);
  checkEqual(pomo.total(), 25 * 60, "25 分钟 = 1500 秒");

  pomo.startTimer();
  check(pomo.running(), "开始后处于运行态");

  // 一次 tick 只走一秒，和旧实现一致。
  pomo.advanceMs(1000);
  pomo.tick();
  checkEqual(pomo.remain(), 25 * 60 - 1, "一拍走一秒");

  // 漏拍：时间过了 10 秒但只醒来一次（事件循环被阻塞的情形）。旧实现在这里只会减 1。
  pomo.advanceMs(10'000);
  pomo.tick();
  checkEqual(pomo.remain(), 25 * 60 - 11, "漏掉的拍不丢秒");

  // 睡眠：合盖 5 分钟，其间一次也没醒。
  pomo.advanceMs(5 * 60 * 1000);
  pomo.tick();
  checkEqual(pomo.remain(), 25 * 60 - 11 - 5 * 60, "睡眠期间的时间照算");
}

void testPomodoroFinishesAcrossSleep(SettingsRepository* settings) {
  FakeClockPomodoro pomo(settings);
  pomo.setMinutes(1);
  pomo.setSeconds(0);
  pomo.startTimer();

  int finishedCount = 0;
  QObject::connect(&pomo, &PomodoroManager::finished,
                   [&finishedCount]() { ++finishedCount; });

  // 睡过了整整一程还多。醒来第一拍就该判完成，而不是傻等剩下的秒数走完。
  pomo.advanceMs(10 * 60 * 1000);
  pomo.tick();

  checkEqual(pomo.remain(), 0, "跨睡眠归零");
  check(!pomo.running(), "完成后停表");
  checkEqual(finishedCount, 1, "finished 只发一次");

  // 归零后再醒也不该重复发信号。
  pomo.advanceMs(60'000);
  pomo.tick();
  checkEqual(finishedCount, 1, "归零后不重复触发");
}

void testPomodoroPauseKeepsPartialSecond(SettingsRepository* settings) {
  FakeClockPomodoro pomo(settings);
  pomo.setMinutes(10);
  pomo.setSeconds(0);
  pomo.startTimer();

  pomo.advanceMs(7'000);
  pomo.pauseTimer();   // 不经 tick 直接暂停：结账也要发生
  checkEqual(pomo.remain(), 10 * 60 - 7, "暂停时按墙钟结账");
  check(!pomo.running(), "暂停后停表");

  // 暂停期间时间流逝不算数。
  pomo.advanceMs(60'000);
  pomo.tick();
  checkEqual(pomo.remain(), 10 * 60 - 7, "暂停期间不走表");

  pomo.startTimer();
  pomo.advanceMs(3'000);
  pomo.tick();
  checkEqual(pomo.remain(), 10 * 60 - 10, "继续后从暂停处接着走");
}

void testPomodoroClockJumpBackward(SettingsRepository* settings) {
  FakeClockPomodoro pomo(settings);
  pomo.setMinutes(5);
  pomo.setSeconds(0);
  pomo.startTimer();

  pomo.advanceMs(30'000);
  pomo.tick();
  checkEqual(pomo.remain(), 5 * 60 - 30, "先正常走 30 秒");

  // NTP 把表往回拨一小时：剩余时间既不能倒着涨，也不能冻住一小时。
  pomo.advanceMs(-3600'000);
  pomo.tick();
  checkEqual(pomo.remain(), 5 * 60 - 30, "回拨瞬间保持不变");

  pomo.advanceMs(5'000);
  pomo.tick();
  checkEqual(pomo.remain(), 5 * 60 - 35, "回拨后继续正常走");
}

// 高层行为不变：这些语义逐条照搬自原 QML 实现。
void testPomodoroPreservedSemantics(SettingsRepository* settings) {
  FakeClockPomodoro pomo(settings);

  // 分 [0,180] / 秒 [0,59] 钳制。
  pomo.setMinutes(999);
  checkEqual(pomo.total() / 60, 180, "分钟上限 180");
  pomo.setMinutes(-5);
  checkEqual(pomo.total() / 60, 0, "分钟下限 0");
  pomo.setSeconds(99);
  checkEqual(pomo.total() % 60, 59, "秒上限 59");

  // 0 分 0 秒拒绝开始，否则秒针刚跑就判完成。
  pomo.setMinutes(0);
  pomo.setSeconds(0);
  checkEqual(pomo.total(), 0, "总时长可为 0");
  pomo.startTimer();
  check(!pomo.running(), "0 分 0 秒不可开始");

  // timeText 补零。
  pomo.setMinutes(5);
  pomo.setSeconds(7);
  check(pomo.timeText() == QStringLiteral("05:07"), "timeText 两位补零");

  // progress 由 remain / total 派生。
  pomo.setMinutes(10);
  pomo.setSeconds(0);
  check(qFuzzyIsNull(pomo.progress()), "未开始时进度为 0");
  pomo.startTimer();
  pomo.advanceMs(5 * 60 * 1000);
  pomo.tick();
  check(qAbs(pomo.progress() - 0.5) < 0.001, "走一半时进度 0.5");
}

// 存档格式与 QML 时代逐字段一致——升级不能把用户在途的那一程丢掉。
void testPomodoroPersistenceCompatibility(SettingsRepository* settings) {
  const QString storeKey = QStringLiteral("memoryLakeMemoPomodoro");

  // 1) 读：喂一份 QML 版 JSON.stringify 会写出的存档（键序 total/remain/title）。
  settings->setValue(
      storeKey,
      QStringLiteral("{\"total\":900,\"remain\":300,\"title\":\"写周报\"}"));
  {
    FakeClockPomodoro pomo(settings);
    checkEqual(pomo.total(), 900, "读旧存档的 total");
    checkEqual(pomo.remain(), 300, "读旧存档的 remain");
    check(pomo.title() == QStringLiteral("写周报"), "读旧存档的 title");
    check(!pomo.running(), "重启一律恢复为暂停态");
  }

  // 2) 写：字段名与取值必须还是老样子（键序可不同，JSON 对象无序）。
  {
    FakeClockPomodoro pomo(settings);
    pomo.setMinutes(15);
    pomo.setSeconds(0);
    pomo.startTimer();
    pomo.advanceMs(60'000);
    pomo.pauseTimer();   // pauseTimer 会落盘

    const QJsonObject o =
        QJsonDocument::fromJson(settings->getValue(storeKey).toUtf8()).object();
    checkEqual(o.value(QStringLiteral("total")).toInt(), 900, "写回 total");
    checkEqual(o.value(QStringLiteral("remain")).toInt(), 840, "写回 remain");
    check(o.value(QStringLiteral("title")).isString(), "写回 title");
  }

  // 3) 损坏的存档不该炸，退回默认。
  settings->setValue(storeKey, QStringLiteral("{not json at all"));
  {
    FakeClockPomodoro pomo(settings);
    checkEqual(pomo.total(), 25 * 60, "存档损坏时退回 25 分钟默认");
  }
  settings->setValue(storeKey, QStringLiteral(""));   // 收尾清干净，供重复运行
}

void testManualTimerCountsWallClockNotTicks() {
  FakeClockTimer timer;
  timer.startProject(QStringLiteral("写周报"));
  check(timer.running(), "开始后处于运行态");

  timer.advanceMs(1000);
  timer.tick();
  checkEqual(timer.elapsedSeconds(), 1, "一拍走一秒");

  // 漏拍 + 睡眠：旧实现在这里只会 +1，少算的秒数会被 stopAndCommit 写进项目历史。
  timer.advanceMs(9'000);
  timer.tick();
  checkEqual(timer.elapsedSeconds(), 10, "漏掉的拍不丢秒");

  timer.advanceMs(3600'000);
  timer.tick();
  checkEqual(timer.elapsedSeconds(), 10 + 3600, "睡眠一小时照算");
}

void testManualTimerPauseResumeAccumulates() {
  FakeClockTimer timer;
  timer.startProject(QStringLiteral("读论文"));

  timer.advanceMs(30'000);
  timer.pauseTimer();
  checkEqual(timer.elapsedSeconds(), 30, "暂停时按墙钟结账");

  timer.advanceMs(600'000);   // 暂停期间不算
  timer.tick();
  checkEqual(timer.elapsedSeconds(), 30, "暂停期间不走表");

  timer.resumeTimer();
  timer.advanceMs(20'000);
  timer.tick();
  checkEqual(timer.elapsedSeconds(), 50, "继续后累加而非重来");

  int stoppedCount = 0;
  QString committedProject;
  int committedSeconds = -1;
  QObject::connect(&timer, &TimerManager::timerStopped,
                   [&](const QString& project, int seconds) {
                     ++stoppedCount;
                     committedProject = project;
                     committedSeconds = seconds;
                   });

  timer.advanceMs(5'000);
  timer.stopAndCommit();   // 收尾也要结账：最后 5 秒必须算数
  checkEqual(stoppedCount, 1, "timerStopped 发一次");
  checkEqual(committedSeconds, 55, "提交的秒数含收尾那一段");
  check(committedProject == QStringLiteral("读论文"), "提交的项目名正确");
}

void testManualTimerPreservedSemantics() {
  FakeClockTimer timer;

  // 没有项目时 resume 是空操作（原实现如此）。
  timer.resumeTimer();
  check(!timer.running(), "无项目时不可继续");

  // 开始新项目会清零已有秒数——当前 UI 一次只允许一个手动计时。
  timer.startProject(QStringLiteral("甲"));
  timer.advanceMs(120'000);
  timer.tick();
  checkEqual(timer.elapsedSeconds(), 120, "甲走了 120 秒");
  timer.startProject(QStringLiteral("乙"));
  checkEqual(timer.elapsedSeconds(), 0, "换项目清零");
  check(timer.currentProject() == QStringLiteral("乙"), "当前项目已切换");
}

}  // namespace

int main(int argc, char** argv) {
  QCoreApplication app(argc, argv);
  QCoreApplication::setOrganizationName(QStringLiteral("TimeArc"));
  QCoreApplication::setApplicationName(QStringLiteral("TimeArc"));
  QStandardPaths::setTestModeEnabled(true);
  // 与 db_smoke 同样的沙箱：KV 落在临时目录的库里，不碰用户真实数据。
  qputenv("TIMEARC_TEST_APPDATA",
          QDir::temp()
              .filePath(QStringLiteral("timearc-pomodoro-test-appdata"))
              .toUtf8());

  DatabaseManager databaseManager;
  if (!databaseManager.initialize()) {
    std::fprintf(stderr, "FAIL: DatabaseManager 初始化失败\n");
    return 1;
  }

  SettingsRepository settings;

  testPomodoroCountsWallClockNotTicks(&settings);
  testPomodoroFinishesAcrossSleep(&settings);
  testPomodoroPauseKeepsPartialSecond(&settings);
  testPomodoroClockJumpBackward(&settings);
  testPomodoroPreservedSemantics(&settings);
  testPomodoroPersistenceCompatibility(&settings);

  testManualTimerCountsWallClockNotTicks();
  testManualTimerPauseResumeAccumulates();
  testManualTimerPreservedSemantics();

  if (g_failures > 0) {
    std::fprintf(stderr, "pomodoro_manager_test: %d failure(s)\n", g_failures);
    return 1;
  }
  std::printf("pomodoro_manager_test: ok\n");
  return 0;
}
