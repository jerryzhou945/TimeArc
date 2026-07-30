# Change Proposal — pomodoro-cpp-wall-clock

## Metadata

- Author: Claude Code (Opus 5)
- Track: **B (Feature)** — new QObject manager (`rules/01`), plus the wall-clock
  correction to `TimerManager` that the port makes cheap to do twice.
- Date: 2026-07-30 23:58 (local)
- Session goal: 番茄钟计时引擎移入 C++，两个计时器都改为墙钟锚点，去掉按 tick 计数的漂移。
- Branch: `development/macos-support`
- Related: 承接 `20260730-2312-B-pomodoro-global-layer`（番茄钟解耦为窗口级层）。

## 1. Frozen files touched

- `src/CMakeLists.txt` — 在 `TIME_ARC_APP_SOURCES` 里加两行
  `services/pomodoro_manager.cpp/.h`。纯新增，不动既有条目、不动目标/链接结构。
  该表是显式文件清单（无 glob），新增管理器无法绕开它。
- `CMakeLists.txt`（顶层）— 新增测试目标 `timearc_pomodoro_test` + 一条 `add_test`，
  照 `timearc_db_smoke` 的写法。同样纯新增，既有目标一行不动。C++ 单测本就是这次
  端口的主要收益之一（现状只能 grep QML），不接进 CTest 等于没做。

## 2. Motivation

两个计时器都**数回调、不测时间**：`TimerManager::onTick()` 是 `++m_elapsedSeconds`，
番茄钟是 `remain = max(0, remain - 1)`。回调少一次就少一秒，且只会少不会多：

- `Qt::CoarseTimer`（QTimer 默认）为省电对齐唤醒，容差约为间隔的 5%；
- 事件循环被阻塞时 Qt **不补发**堆积的 timeout——卡住 5 秒只得到 1 次回调，丢 4 秒；
- 睡眠 / 挂起期间根本不触发，醒来当无事发生。

代价不对称。番茄钟只是一程 25 分钟走成 26 分钟，用户看得见；`TimerManager` 的少算
经 `addElapsedTime` / `addTodoElapsedTimeOnDate` **写进项目历史**，再进统计页与导出，
下游无从分辨。一个记录时间去向的应用，把午休那段睡眠悄悄抹掉，是最不该有的错。

番茄钟侧的注释（`PomodoroWidget.qml:24`）已写明「无跨重启墙钟锚点」——作者意识到了
重启这一种情形，没有意识到睡眠是同一个缺口。

C++ 化本身不是目的，而是：①状态机可被 C++ 单测覆盖（现状只能 grep QML）；
②状态栏图标可像 `TimerManager` 一样直接持指针；③墙钟改造两处同源，一次做完更省。

## 3. Impact on the other process

| Side     | Effect                                                          |
|----------|-----------------------------------------------------------------|
| Producer | 无。不碰采样源、schema、`data_bridge.h`、DB，服务侧一行不改、不重建。 |
| Consumer | 番茄钟引擎从 QML 移入 UI 进程内的新 QObject；仍只读写 KV，不新增 IPC。 |

`src/CMakeLists.txt` 只挂 UI 端目标，服务端目标在 `src/service/CMakeLists.txt`，未触及。

## 4. Migration plan

- **旧记录：** `memoryLakeMemoPomodoro` = `{"total":N,"remain":N,"title":"…"}`（QML
  `JSON.stringify` 写入的 KV 字符串）。另有 `pomodoro_today` =
  `{"d":"yyyy-MM-dd","n":N}`、`pomodoro_duration`、`pomodoro_title`、`pomodoro_celebrate`。
- **新记录：** 字段名、字段值、KV 键名**逐项相同**，唯一差别是 JSON 的键序：
  `QJsonObject` 按字典序输出 `{"remain":…,"title":…,"total":…}`，QML 的
  `JSON.stringify` 按插入序输出 `{"total":…,"remain":…,"title":…}`。JSON 对象本就无序，
  两边都按键取值，互相都读得动——**但"逐字节不变"是不成立的说法，故在此更正**。
- **共存：** 无需迁移器。老版本写的存档新版本照读，新版本写的存档老版本也照读，
  已由 `tests/pomodoro_manager_test.cpp` 的「喂一份 QML 版存档」用例覆盖。
  升级不丢用户在途的那一程——这正是不改键名、不改字段的原因。
- 无 `timearc_service.db` 影响。

## 5. Rollback plan

代码 revert 即可，无数据需要恢复：字段与键名不变（仅 JSON 键序不同，不影响解析），
回退后老代码读的还是同样的 KV，包括本版本写下的那一份。

## 6. Test plan

- **改前复现：** 起一程番茄或手动计时 → 合上盖子/睡眠 N 分钟 → 唤醒。计数只走了睡前
  那点，少掉整个 N 分钟；`结束` 会把少算的秒数写进项目历史。
- **改后验证：** 同一路径，唤醒后第一拍即按墙钟重算，少掉的时间补回；番茄若在睡眠中
  到点，唤醒即判完成。
- **新测试件：** `tests/pomodoro_manager_test.cpp` + 顶层 `CMakeLists.txt` 里的
  `timearc_pomodoro_test` 目标。两个管理器都开了 protected 的 `currentMs()`，测试子类
  注入手拧时钟——把表往前拨一小时等价于合盖睡一小时，这是"丢秒"在单测里唯一的表达方式。
  `tests/pomodoro_global_static_test.py` 同步扩充（视图不得再持有计时状态、两处均不得
  回到 tick 计数、存档键与字段不得改名）。

**实跑结果：** `ctest` 3/3 通过（新增的 `timearc_pomodoro_test` 含 9 组、40 余条断言：
漏拍 / 睡眠 / 跨睡眠完成 / 暂停结账 / 时钟回拨 / 钳制 / 0 分 0 秒拒开始 / timeText 补零 /
存档三向兼容 / 手动计时的累加与提交秒数）。全量静态测试 19 项中 3 项失败，`git stash -u`
在干净树上复跑同样失败——既有失败，与本次无关。应用起得来，QML 零报错；把视图里的
`pomodoroManager` 改成直接引用（而非 `typeof` 兜底）正是为了让"名字对不上"当场报错，
否则日志干净也证明不了绑定真的连上了。

**未跑：** 屏幕验收（GUI 自动化未授权，`osascript` → `-1743`）。真机仍欠：合盖再唤醒，
肉眼确认秒数补回；跑一程到完成看庆祝与通知；分/秒输入框与标题回写；设置页数据概览的
今日完成数。

## 7. Sign-off

- [x] `rules/*.md`：无断言受影响（`rules/01` 已允许新增 QObject 管理器）。
- [ ] `CHARTER.md` 版本号：不涉及（非章程修订）。
- [x] `state/frozen-files.json` 待本次落地后重新生成。
- [x] 主 `README.md` 用户可见项已更新（番茄钟条目 + 计时精度说明）。
