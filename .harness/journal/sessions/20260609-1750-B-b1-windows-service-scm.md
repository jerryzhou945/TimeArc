# Session — B1 Windows 服务化（SCM / 后台自启）· Kickoff（计划 + 路线决策）

本 session 只产出**计划文档 + 路线决策**（不改代码、不动冻结文件）。详细计划见
`docs/b1-windows-service-scm-kickoff.md`。本文＝Track B session log（含 Track-B 必填的两侧设计段对）。

## Metadata
- Author: Claude Code (Opus 4.8, ultracode)
- Track: **B (Feature)** — B1 是新能力（Windows 服务化 / 登录自启）。
- Date: 2026-06-09 17:50 (local)
- Branch: `feat/b1-windows-service-scm`（基于 `dev`，PR 进 `dev`；与 A1 并行、不碰 I2）。
- Related: `docs/implementation-backlog.md §B1`、`docs/b1-windows-service-scm-kickoff.md`、
  `tracks/B-feature.md` queue「Windows SCM registration」、`20260609-0150-B-service-config-proposal.md`（H5）。

## 路线决策（决策门已拍板）
- **维护者确认：先采用 Route A（用户会话登录自启，无管理员、零冻结改动）作为 MVP。**
- Route B（SCM session-broker 真服务）**暂缓**：仅当产品明确要 `services.msc` 级、跨注销/多用户守护才启动；
  届时需管理员 + 链 `advapi32/wtsapi32/userenv`（动冻结 `src/service/CMakeLists.txt`）+ 修订 CHARTER I1（走变更提案）。

## 设计：Service 侧 / UI 侧（Track B 必填，详见 kickoff §1.4）
- **Service 侧（producer）**：`time-arc-service.exe` 加生命周期动词分派（`main.c` 改 `main(argc,argv)`）+ 注册逻辑
  （`win_service.c`）。**核心契约：真正采集的进程恒在交互式用户会话、以用户身份运行**（Route A 天然如此）。
  **不改任何记录格式/落盘路径/schema**——对磁盘契约的产出逐字节不变，只改「谁在何时把它启停」。新增
  `Local\TimeArcStop` 具名事件作停采集通道（停机仍走既有 flush `usage_tracker.c:136-142`）。
- **UI 侧（consumer）**：设置页加「开机自启」开关，经 `QProcess` 调 service `--install/--uninstall/--status`
  （UI→子进程命令，**非磁盘契约、非 socket/shm**，守 I1）。UI 对数据读取完全不变。
- **接缝结论**：UI↔service 数据面**零变化**；唯一新增＝「UI→service 生命周期控制命令」（命令行参数 + 具名事件），
  二者均非 I2 数据契约变更 → **B1 不需 I2 修订**（对比 service-config 提案新增的是 UI→service 数据方向）。

## 现状校正（读码 2026-06-09，证据见 kickoff §0）
- `win_service.c:3-16` 三个 TODO stub 全 `return -1`；当前是前台 console exe，UI `startUsageService`（`startDetached`）
  在用户会话拉起；单实例 `Local\TimeArcUsageService`（`main.c:33`）。
- **核心陷阱**：采集全链路（`GetForegroundWindow`/`GetLastInputInfo`/WASAPI/GSMTC + `getenv(LOCALAPPDATA/APPDATA)`）
  均**会话亲和 + 用户 profile**；朴素 SCM+LocalSystem 落 Session 0 → 采集全空、数据写 systemprofile（§0.3 实证 6 行）。

## 1. 冻结文件（本 session 触碰：无；Route A 全弧：无）
- 本 commit 改的全是 `docs/*` + 本 session log。**无冻结改动。**
- **Route A 全弧零冻结改动**：动词用 shell-out `schtasks/reg`（已链 kernel32），逻辑折进非冻结
  `win_service.{c,h}` / `main.c`（已登记进 CMake，无新翻译单元）→ 不动冻结 `src/service/CMakeLists.txt`。
- Route B 才有冻结改动（CMake 链接库 + CHARTER I1）——暂缓，不在本弧。

## 2. Motivation
backlog §B1 是 Windows 专属硬化项；当前 console exe 依赖 UI 存活、无登录自启。不做：服务不能独立后台常驻；
且若有人按「真 SCM」朴素实现会静默打碎采集（Session 0）——本 kickoff 先把该错误线路挡在门外并选定正确 Route A。

## 3. Impact on the other process
| Side | Effect |
|------|--------|
| Producer (service) | 加动词分派 + Route A 自启注册 + `Local\TimeArcStop` 停采集事件；**采集/落盘行为与契约不变**。 |
| Consumer (UI) | 设置页加「开机自启」开关（`QProcess` 调动词，非磁盘/IPC）；数据读取不变；S2 收口与 auto-spawn 的去重（靠单例幂等）。 |

## 4. Migration plan
**无 on-disk impact**：B1 纯进程生命周期，不动 `usage_record.schema.json` / 记录字段 / `usage_paths` 路径 /
JSONL/current/SQLite 写法，不新增 UI↔service 数据方向。向后兼容（无参仍走今天的 tracker 路径）。

## 5. Rollback plan
Route A 注册项可由 `--uninstall` 干净移除（Task Scheduler 任务 / HKCU 值）；代码 revert 即回今天的 UI-spawn 模型。
无数据需恢复（不删历史、不改记录）。

## 6. Test plan
- 真机（**不在 UI qml 构建循环内**，须能 build service 者执行）：`--install`→重启/注销重登→`query session` 确认
  tracker 在**登录用户会话**（非 Session 0）；新记录落**用户** `%LOCALAPPDATA%\TimeArc\usage\` 与
  `%APPDATA%\TimeArc\TimeArc\timearc.db`（两处分别核，§0.3）；`--stop` 优雅 flush 尾段（非 /F）；`--uninstall` 无残留。
- 两侧齐活（Track-B Exit）：service 动词 + UI 开关一起 build&run，抓图设置页开关与 `--status` 回显一致。

## 7. Sign-off（S1/S2 实现 session 据实勾选）
- [ ] `README.md`（§TimeArc Service / 状态表 / §Roadmap「SCM」）改写为 Route A 实际机制（S2，用户可见）。
- [ ] `.harness/rules/02-platform-boundaries.md §3` Windows `win_service.c` 条目从「TODO SCM stubs」改实况（S2）。
- [ ] `.harness/state/open-issues.md`「Windows service is not a real service」移除/改写（S2）。
- [x] 无冻结改动（Route A 全弧）→ `state/frozen-files.json` 无需重生成。
- 决策：**Route A（用户会话自启）**；Route B（真 SCM session-broker）暂缓、留作产品要机器级守护时的门控 arc。

## 本 session 收尾
- 产出：`docs/b1-windows-service-scm-kickoff.md`（新）、`docs/implementation-backlog.md §B1`（指针 + 决策）、本 log。
- 无 build / 无 Qt 运行 / 无冻结改动 → 无 L1/L2 错误。`harness_check` exit 0 后提交。
