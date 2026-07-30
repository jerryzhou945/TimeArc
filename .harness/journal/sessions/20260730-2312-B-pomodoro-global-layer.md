# 20260730-2312-B-pomodoro-global-layer

## Metadata

- Author: Claude Code (Opus 5) · Track **B (Feature)** · 2026-07-30 23:12 (local)
- Branch: `development/macos-support`
- Goal: 番茄钟从备忘黑板的子树里搬出来，成为 Shell 的同级层——快捷键 / macOS 菜单行在
  任意页面下都能直接开（不再先掀开黑板），Esc 全平台收起，两者都开时先退番茄。

## 1. Frozen files touched

None. 新增 `qml/desktop/PomodoroLayer.qml`、`tests/pomodoro_global_static_test.py`（+ 一行
非冻结的 `qml/CMakeLists.txt`，依 rule 05）。改动：`DesktopAppShell.qml`、`MacMenuBar.qml`、
`memorylake/MemoOverlay.qml`、`memorylake/PomodoroCompleteOverlay.qml`、`README.md`。

## 2. Two-sided design

- **Service side:** 无。番茄钟自始至终是 UI 私有状态，落在 KV（`memoryLakeMemoPomodoro` /
  `pomodoro_today` / `pomodoro_duration` / `pomodoro_celebrate`），不碰采样源、
  `usage_config.json`、schema、`data_bridge.h`，也不新增 IPC。`time-arc-service` 未重建。
- **UI side:** 新 `PomodoroLayer` 持有 `PomodoroWidget` + `PomodoroCompleteOverlay` 以及
  「完成 → 通知 / 庆祝」这段策略，对外只暴露 `toggle()/show()/hide()/dismiss()`、只读
  `shown/running`、`signal finished(title)`。Shell 在 `MemoOverlay` 之后声明它，
  快捷键、macOS 菜单行 显示 › 番茄钟、黑板工具条上的番茄按钮三个入口都汇到 `toggle()`。

## 3. Decisions

- **为什么是搬走而不是给黑板加个「不打开」参数。** 旧 `MemoOverlay.togglePomodoro()` 是
  `open = true; pomodoro.shown = !pomodoro.shown`，那个 `open = true` 不是顺手写的：浮窗
  长在黑板子树里，黑板不显示它就不可见。父子关系还在，"开番茄但别开黑板"就做不到。
- **z 序靠声明顺序，不靠 z 值。** `PomodoroLayer` 声明在 `memoOverlay` 之后，同 z 下
  后声明的兄弟在上，于是黑板打开时浮窗依旧盖在上面——那是它搬家前唯一能用的场景，
  不能因为搬家反而丢掉。原先的 `z: 4540 / 4560` 是对着黑板工具条 (z4520) 的局部值，
  随父子关系一起废掉。静态测试锁了这个先后顺序。
- **`memoLocked` 不再门控番茄**：它是记忆卡翻面锁，锁的是黑板；番茄是全局专注计时。
  Shell 的 `Shortcut.enabled`、`menuTogglePomodoro()` 与 `MacMenuBar` 都改了——菜单行
  新开 `canTogglePomodoro`（只留 `!capturing`），`canToggleMemo` 留给备忘那一行。
- **持久化键不改名**（仍是 `memoryLakeMemoPomodoro`）：改名等于把用户在途的那一程静默
  丢掉，只为消掉名字里的 Memo。键名从此只是历史，两处注释写明。
- **Esc 收起，用 `Shortcut` 而不是 `Keys.onPressed`。** 需求是「两者都开时先退番茄」。
  黑板打开时是它持焦（`focus: open`），Esc 走它的 `Keys.onPressed`。Qt 的快捷键先于
  按键送到聚焦项（先给聚焦项一次 ShortcutOverride 的机会，黑板没实现该处理器），
  于是番茄开着时这条先吃掉 Esc；一收起 `enabled` 转假，Esc 原样落回黑板。次序自动
  成立，两边都不必知道对方存在，也不必改黑板。不经菜单栏，故三平台一致。
  - 梯级：庆祝弹层 → 浮窗 → （黑板）。**收起不停表**——Esc 太容易误按，不该拿来销毁
    一程专注；与工具条开关一致，再按一次 ⇧⌘P 就把还在跑的那一程调回来。
  - 让出 `hotkeyCapturing`：设置页键帽等按键时 Esc 是「取消捕获」（`DesktopProfilePage`
    2267 行），Shell 用 `escapeEnabled: !root.hotkeyCapturing` 让路。次要影响：月度回顾 /
    统计页也各自吃 Esc，番茄开着时同样被先截住——与「先退番茄」一致，未特办。
- **完成弹层的关闭按钮换中性文案**（`知道了`，zh/en/ja 三语已有词条）。旧文案承诺回到
  黑板，而现在这层可能盖在统计页上，关掉回的是用户原来那一页。

## 4. Migration / leftouts

- `MemoOverlay` 的 `signal pomodoroFinished(string title)` 换成 `signal pomodoroRequested()`：
  黑板不再知道番茄何时结束，只把工具条点击转出去。Shell 的 `Connections` 从
  `target: memoOverlay / onPomodoroFinished` 改成 `target: pomodoroLayer / onFinished`，通知
  逻辑一字未动。设置页只读写上面那几个 KV 键，未受影响，未改。
- **未做（越界）：** `PomodoroWidget` 自身一行未改。它按 tick 计数，睡眠 / 挂起期间
  `Timer` 不走，跨盖上盖子的一程会少算——和 `TimerManager` 同一个毛病，该由一次针对性的
  墙钟改造一起收，不塞进这次搬家。

## 5. Verification

`cmake --build build` 干净通过（QML 全部重新走 qmlcachegen，无警告）。应用起得来，运行
日志只有两行 Loader 记录 + 一条既有的 LaunchAgent 签名报错（与本次无关），QML 树实例化
零报错——新类型解析、`MemoryLakeStyle` 注入、`store` 绑定、`Shortcut` 都成立。
新 `tests/pomodoro_global_static_test.py` 通过：层的 API 与所有权、黑板里四个禁字
（`PomodoroWidget` / `PomodoroCompleteOverlay` / `togglePomodoro` / `pomodoroFinished`）、
三个入口的接线、声明顺序、两处 `memoLocked` 的消失、Esc 的门与梯级（含「不停表」＝禁
`pauseTimer`）、`escapeEnabled` 让位、新文件进 qml 模块、关闭按钮文案与三语词条。写完
先红了一次——我自己注释里留着旧文案字面量，改掉才绿。

全量静态测试：18 项中 4 项失败（`desktop_ux` / `macos_menu_bar` / `macos_build_script` /
`windows_build_script`）。`git stash -u` 后在干净树上复跑，四项同样失败 —— 既有失败，与
本次无关（缺 `AndroidManifest.xml`、缺 `月度记忆湖` 词条、两个构建脚本未走 `build.py`）。

**未跑：** 屏幕验收。GUI 自动化在此环境未授权（`osascript` → `-1743`，与 `20260730-2213`
那次同样的墙），窗口也没出现在 `screencapture` 的主显示器上，因此 ⇧⌘P / Esc 这两下没有真
按下去过。Esc 的梯级尤其欠一次实按：「Shortcut 先于聚焦项」是按 Qt 的分发顺序推的，静态
断言锁得住门与写法，锁不住真实分发。要走的路径：
①任意非黑板页 ⇧⌘P，浮窗出现且黑板不掀开；②番茄单开 Esc 收起；③黑板单开 Esc 仍关
黑板（未回归）；④两者都开，第一下退番茄、黑板还在，第二下才关黑板，且浮窗在板上方；
⑤跑到完成，Esc 先关庆祝再关浮窗，文案为「知道了」；⑥运行中 Esc 收起后再 ⇧⌘P 调回来，
秒数仍在走；⑦设置页捕获键位时 Esc 取消的是捕获；⑧记忆卡翻面锁住时 ⇧⌘P 与菜单行仍可用。

## 6. Rule / doc updates

`README.md`：番茄钟原本只是备忘黑板那条 bullet 里的一个从句，现拆成独立条目，写明窗口级
层、三个入口、Esc 梯级、⇧⌘P / P 可改键、重启恢复为暂停态，并点出与手动计时器
`TimerManager` 是两件事。（本想连同屏幕验收一起押后，是 `harness_check` pass 7 拦下来的
——track B 加源文件必须同时更新 rules/ 或 README，规矩是对的。）

`docs/memory-lake-memo-*-replication.md` 未改：那是 v88 复刻规格，§1.6 / §2.7 明写浮窗属于
黑板，而这次是产品决定改了归属，不是复刻做错了。按惯例（划线 + 「后续撤销」注）改口径
应单独一次落，连同屏幕验收留作待办。无 `rules/0X` 断言受影响。

## 7. Outcome

**Code complete, smoke path + doc 口径 outstanding**——构建与静态断言绿，屏幕未验。
