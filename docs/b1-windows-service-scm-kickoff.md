# B1 · Windows 服务化（SCM / 后台自启）· 实现启动（Kickoff / 多 session 拆分）

> **状态（2026-06-10）：✅ Route A 已实装并合并（PR #37 → dev）。** S1（生命周期动词 install/uninstall/start/stop/status + 用户会话登录自启 schtasks／Run 退路 + 停采集事件）+ S2（设置「开机自动在后台采集」开关）完成；Route B（SCM session-broker 真服务）暂缓。下文 §0「现状校正」描述的是**实装前起点**，非当前状态——当前状态见 `docs/implementation-backlog.md §B1` 与 `.harness/state/open-issues.md`。

> 用途：把 `docs/implementation-backlog.md` §B1（「注册为真正的 Windows 服务（SCM）」）从「三个 TODO
> stub」展开成**带依赖、可逐 session 落地**的执行计划。B1 是 Track **B**、Windows 专属、与 A1 **可并行**
> （两者磁盘契约不冲突：A1 动**读/写存储**，B1 只动**进程生命周期/启动方式**）。本文先把**真实现状**钉死，
> 再点出 B1 最大的技术陷阱（**Session 0 隔离**），给出**产品路线决策门**、拆分、文件红线、变更提案边界、
> 必须保留的语义、风险与验收口径。
>
> **体例**参照 `docs/a1-sqlite-storage-migration-kickoff.md`（每 session 一张可粘贴的范围卡；现状先用实测/读码钉死）。
> **配套权威**：`.harness/CHARTER.md`（I1 两进程分离 / I4 平台隔离 / I6 许可 / §3 冻结表 / §4 修订流程）、
> `.harness/rules/02-platform-boundaries.md`（§2 每平台义务 / §3 Windows 参考实现）、
> `.harness/tracks/B-feature.md`（B1 在「Concrete feature queue」里；Required = 两侧设计 + 同提交改 rules/README）、
> `.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`（H5 idle/track 的 `usage_config.json` 通道——B1 的 worker 仍须读它）。
>
> 维护：完成一个 sub-session → 勾掉下表 + 移进 session log，并同步 `README.md §Roadmap`（line 547-548）/
> `.harness/state/open-issues.md`（Platform「Windows service is not a real service」）/ `docs/implementation-backlog.md §B1`。
>
> **本文是计划，不是代码。** 每个 sub-session 仍须独立走 harness（preflight → 纵切 → build/scan → harness_check）。

---

## 0. 现状校正（这是 B1 的起点）

### 0.1 SCM 接口——**三个 TODO stub，零实装**
- `src/service/windows/service/win_service.c:3-16`：`timearc_win_service_run()` / `_install()` / `_uninstall()`
  三个函数**全部 `return -1`**，正文只有中文 TODO 注释（「注册 SERVICE_MAIN_FUNCTION」「OpenSCManager/CreateService」
  「先停止运行中的服务，再删除」）。`win_service.h:10-12` 声明对应三入口、注释明说是「预留接口 / placeholders」。
- 这三个函数**已登记进** `src/service/CMakeLists.txt:57`（`service/win_service.c` 在 `TIME_ARC_SERVICE_PLATFORM_SOURCES`
  里；`.h` 不入源列表、靠 include dir `:83` 拾取），即**编译进 `time-arc-service.exe` 但从无调用方**（`main.c` 从不
  `#include "win_service.h"`、全仓无调用点）——是死路径。这点对 B1 是利好：**实装可全部折进
  `win_service.{c,h}` + `main.c`（均非冻结、均已登记），不必新增翻译单元、不必动冻结 CMake**（见 §3 避让技巧）。
- ⚠️ 但 `win_service.h:10-12` **只声明 3 个函数**（run/install/uninstall）；§1.1 的 5-6 动词面（多出 `--start/--stop/
  --status/--run-service`）需在 `win_service.{c,h}`（**非冻结**）**新增声明+定义**——仍是「无新翻译单元、无冻结 CMake 改动」，
  但**不等于「只填 3 个现成 stub」**：`--start/--stop` 今天连 stub 都没有，须从零写（含 §4.4 的停采集通道）。

### 0.2 当前真实启动链路——**UI 在「用户会话」里 detached-spawn service（这是 capture 能工作的根因）**
- `src/main.cpp:72-80` `startUsageService()`：UI 启动时 `QProcess::startDetached("time-arc-service.exe", …)`
  （`:102` 调用）。即**今天 service 是 UI 的脱离子进程，跑在登录用户的交互式会话里**。README 明述（line 343-344）：
  「On Windows it will auto-spawn `time-arc-service` from the same directory (detached)」。
- service 进程入口 `src/service/windows/main.c:28-61`：`SetConsoleCtrlHandler` → **单实例 `CreateMutexA(NULL,TRUE,
  "Local\\TimeArcUsageService")`**（`:33`，`Local\` 命名空间＝**每会话一份**）→ `ta_storage_init()` →
  `timearc_usage_tracker_run()` → 收尾 `ta_storage_shutdown()` + 释放 mutex。
- 关闭路径是**优雅的**：`console_handler`（`main.c:14-26`）对 `CTRL_C/CLOSE/LOGOFF/SHUTDOWN` 调
  `timearc_usage_tracker_request_stop()`；tracker 主循环每轮查标记（`usage_tracker.c:16-22, 92`），退出前
  **flush 当前 session + audio**（`usage_tracker.c:136-142`）。**这条优雅收尾链是 B1 不能破坏的**（见 §4.4）。
- README line 160 状态表：「service runs as a foreground console binary (**SCM registration is a TODO**)」；
  CHARTER **I1**（line 19-22）把当前事实写成不变量：「UI **may start** the service (`src/main.cpp::startUsageService`)
  but must not link its code. A single service is guaranteed by `Local\TimeArcUsageService`」。

### 0.3 采集全链路依赖「交互式会话 + 用户 profile」——**Session 0 一旦介入即全盘失效**（B1 的核心陷阱）
backlog 把 B1 写成「注册为**真正的 Windows 服务（SCM）**」。**最朴素的读法（`CreateService` + LocalSystem，
进程落在 Session 0）会彻底打碎采集**。原因是 tracker 用的全是**会话亲和（per-session）**的 Win32/COM API +
**用户 profile** 环境变量——它们在 Vista 以来被隔离的「服务专用 Session 0」里失效。**注意两种失效模式不同**：
`GetForegroundWindow` 这类**返回 NULL/空**（显式失败）；`GetLastInputInfo` / `getenv` 这类**调用成功、却返回错误的
值**（静默误读，更隐蔽、更危险——没有报错可抓）。逐条：

| 采集能力 | 调用点（文件:行） | 会话/账户亲和性 | LocalSystem@Session 0 的后果（失效模式） |
|---|---|---|---|
| 前台窗口 | `active_app_win.c:115` `GetForegroundWindow()` | 绑定调用线程的 window station；服务默认在非交互 `Service-0x0-…$` | **返回 NULL/空**：永远拿不到用户前台窗 → **前台采集全空** |
| 空闲检测 | `idle_win.c:12` `GetLastInputInfo()` | 报告**调用会话**的最后输入 | **成功但值错**：Session 0 无输入、`dwTime` 停在会话起点不更新 → idle_ms 无限增大 → **永远判为 idle** → 连前台 session 都不开 |
| 音频会话 | `audio_win.c:599-619` `GetDefaultAudioEndpoint(eRender,…)` → `IAudioSessionManager2` → `IAudioSessionEnumerator` | **默认渲染端点解析本身**就会话亲和；会话列表 per-endpoint | 非交互 Session 0 **要么 `GetDefaultAudioEndpoint` 直接 FAILED→return -1，要么**端点枚举不到用户渲染会话 → **audio 采集全空**（D5 并集音频侧塌掉） |
| 媒体标题 | `audio_win.c:336` `_popen("powershell … GSMTC …")` | GSMTC 是用户态 WinRT；`_popen` 还会在**服务会话**里拉起 PowerShell | SYSTEM 下 GSMTC 通常**返回空会话列表**（确定性为空，非偶发错） → 媒体标题列**稳定为空**；且**从 Session 0 SYSTEM 拉 PowerShell**＝错会话 + AV/安全异味 |
| 数据落盘①（JSONL/live） | `usage_paths.c:55,57` `getenv("LOCALAPPDATA")` 优先、回退 `("APPDATA")` → `%LOCALAPPDATA%\TimeArc\usage\` | 解析**调用账户**的 profile | **成功但路径错**：LocalSystem → `C:\Windows\System32\config\systemprofile\AppData\Local\…` → 写错目录 |
| 数据落盘②（SQLite db） | `usage_storage.c:59-67` `make_db_path`：`getenv("APPDATA")` **优先**、回退 `("LOCALAPPDATA")` → `%APPDATA%\TimeArc\TimeArc\timearc.db` | 解析**调用账户**的 profile，**且 env 优先级与①相反、子路径也不同** | **成功但路径错**：systemprofile\AppData\Roaming\…；与①不同盘段＋不同子目录（见 `database_manager.cpp:17-46` 运行时 split-brain 告警） |
| UI 读取目录 | `usage_stat_manager.cpp:48-51` `QProcessEnvironment.value("LOCALAPPDATA"/"APPDATA")` | 解析**当前用户**（UI 是用户进程） | UI 读用户 profile、service 写 systemprofile → **读写分裂、UI 看到空库** |

> ⚠️ 服务侧**有两处独立的写路径构造**（① `usage_paths.c` LOCALAPPDATA-优先；② `usage_storage.c:make_db_path`
> APPDATA-优先），二者本机靠约定相等（A1 关注点），但在 Session 0 下**双双**指向 `systemprofile`、且互不同目录——
> 即「真服务跑错会话」会同时打碎 JSONL 与 SQLite 两条写盘。`timearc.db` **不在** `…\TimeArc\usage\` 旁，而在
> `…\TimeArc\TimeArc\`（§6 验收据此分别核对两处目录）。

**关键推论**：
1. **B1 真正的不变量不是「变成 SCM 服务」，而是「tracker 必须继续跑在交互式用户会话、以用户身份运行」**
   （否则 §0.3 六条全废）。任何实现路线都要满足这条（§4.1 / §4.2）。
2. backlog 的「真正的 Windows 服务（SCM）」其实**混了两个意图**：①「**开机/登录自启 + 后台常驻**」（产品要的）
   与 ②「**注册进 SCM、`services.msc` 可见、跨注销/多用户**」（机制选择）。Session 0 现实下，②的朴素实现
   **会牺牲①背后的采集正确性**——除非用「服务做 session 代理、把 worker 投进用户会话」（Route B，复杂）。
3. 因此 B1 落地前需要一次**产品/维护者路线决策**（§1 决策门）：到底要「用户级自启」还是「机器级 SCM 守护」。
   这正是本 kickoff「保证后续 implementation 法规与正确线路」的核心交付——**先把错误的朴素 SCM 读法挡在门外**。

### 0.4 与 A1 的并行关系（为何「可并行」成立）
- A1 改的是**存储读写**（JSONL→SQLite 升主源），B1 改的是**进程怎么起/停/常驻**。两者唯一交点是
  「service 进程仍按既有契约写盘、UI 仍按既有契约读盘」——B1 **不碰记录格式/路径/schema**（§4.5），
  所以与 A1 任意 sub-session **无冻结点冲突**（A1 的冻结点在 `CHARTER` I2；B1 的潜在冻结点在
  `src/service/CMakeLists.txt` 链接库，二者不同文件，见 §3）。可独立开 session、独立合并。

---

## 1. 真实范围、产品路线决策门与落地顺序

### 1.1 B1 的稳定对外契约 = 四个生命周期动词（与路线无关）
无论选哪条路线，对外暴露面建议固定为 **service.exe 的命令行动词**（backlog「先 install/start/stop 三动作打通」）：

```
time-arc-service.exe                  # 无参 = 今天的前台/会话内 tracker（保持向后兼容，UI auto-spawn 仍可用）
time-arc-service.exe --install        # 注册「登录自启 / SCM 服务」（路线决定底层机制）
time-arc-service.exe --uninstall      # 反注册（先停后删）
time-arc-service.exe --start / --stop # 启停当前注册项
time-arc-service.exe --status         # 查询注册/运行态（给 UI 设置页回显）
time-arc-service.exe --run-service    # 仅 Route B：被 SCM 拉起时的入口（StartServiceCtrlDispatcher）
```
> 动词是**稳定 CLI 契约**；「底层用 Task Scheduler/注册表 还是 SCM」是路线实现细节，藏在动词后面。
> `main.c` 据 `argc/argv` 分派（今天 `int main(void)` 无参，需改成 `int main(int argc,char**argv)`——非冻结）。

### 1.2 三条路线（决策门 · 须产品/维护者拍板）

**Route A — 用户会话自启（推荐 MVP · 不需管理员 · 采集天然正确）**
- 机制：在**当前用户**上下文注册一个登录自启项，让 tracker 仍在用户会话里以用户身份运行。优先级：
  ① **Task Scheduler 登录触发任务**（`schtasks /create /sc onlogon /tr "…\time-arc-service.exe"`，"仅在用户登录时运行"，
  可勾「最高权限」但默认不需要）——最贴近「后台服务」体感、可被 UI 管理；
  ② 退路 **HKCU `…\CurrentVersion\Run`**（零依赖、无 UAC、但无「服务」语义）；
  ③ 最次 **Startup 文件夹快捷方式**。
- 为什么是 MVP 正解：**①保采集正确（在用户会话，§0.3 六条全活）②无 UAC 摩擦（HKCU/per-user task 不需管理员）
  ③最小可运行纵切（CLAUDE.md 硬规则）④与同类时间追踪器（RescueTime / ActivityWatch）一致的工程姿态**。
- 代价：不是 `services.msc` 里的「真服务」；用户注销后不常驻（对「记录我的用时」恰好是想要的语义）。

**Route B — SCM session-broker 真服务（门控 · 需管理员 · 复杂但「真 SCM」）**
- 机制：服务**确实**注册进 SCM（`CreateService`，`SERVICE_WIN32_OWN_PROCESS` + `SERVICE_AUTO_START`，LocalSystem），
  但服务进程**只当 session 代理（supervisor）**：用 `WTSGetActiveConsoleSessionId` → `WTSQueryUserToken`
  （需 `SeTcbPrivilege`/SYSTEM）→ `DuplicateTokenEx` → `CreateEnvironmentBlock` → **`CreateProcessAsUser`**
  把**真正的 tracker worker 投进活动用户会话、以用户身份 + 用户 env 运行**。服务侧处理 `SERVICE_CONTROL_STOP`
  与 **`SERVICE_CONTROL_SESSIONCHANGE`**（登录/解锁/快速用户切换时重新投放 worker）。
- 何时才选：产品明确要「`services.msc` 可见、跨注销常驻、机器级/多用户」守护。**否则不要选**——它把
  「采集正确」的责任全压在 broker 正确性上（token/会话/desktop/env 任一处错就静默丢数）。
- 代价：需管理员安装（SCM + 可能 HKLM）；`SeTcbPrivilege`；会话切换逻辑；AV/SmartScreen 对「自启 + 读他进程音频/标题」更敏感（接 F1/F2 签名）。

**Route C — per-user service 模板（`SERVICE_USER_OWN_PROCESS`）· 不推荐**
- Win10+ 的「用户服务」模板（带 `_xxxxx` 后缀、svchost 分组、注册表驱动）确实在用户会话跑，但**对第三方独立 exe
  无干净的官方创建路径、脆弱、难卸载**。仅作备案，**不建议**作为实现路线。

### 1.3 落地顺序（依赖图 + 推荐）
```
S0 本文 kickoff + 路线决策门(无代码) ──> 产品/维护者选 Route A 或 Route B
        │
   [Route A 推荐]                         [Route B 若产品坚持「真 SCM」]
   S1 verbs+自启注册+与UI spawn/mutex收口   SB1 ServiceMain+session-broker(投 worker 进用户会话)
        └─> S2 UI 设置「开机自启」开关        SB2 install/uninstall(SCM)+SESSIONCHANGE 重投
            + README/rules/open-issues 同步    └─> SB3 UI 开关 + README/rules + I1 修订(变更提案)
```
**推荐**：S0 → 选 **Route A** → S1 → S2。把 Route B 作为「产品要真服务」时的备选 arc（SB1–SB3），
不要默认实现。理由见 §1.2 与 §0.3。

> 提醒（CLAUDE.md / AGENTS §2 硬规则）：每个 sub-session **只走一条 track（全程 B）+ 最小可运行纵切**；
> 不要把 S1+S2 或 SB1+SB2 混进一个 session。

### 1.4 两侧设计段对（Track-B Required · 须誊进 S0 的 session log）
> `tracks/B-feature.md:17-19` 要求功能跨 UI/service 接缝时，编码前在 session log 各写一段。B1 虽以 service 侧为主，
> 仍有 UI 侧（设置开关 + 状态回显），故照写：

- **Service 侧（producer）**：`time-arc-service.exe` 新增生命周期动词分派（`main.c` 改 `main(argc,argv)`）与注册逻辑
  （`win_service.c`）。**核心契约：真正采集的进程恒在交互式用户会话、以用户身份运行**（Route A 天然如此；Route B 由
  session-broker 投放保证）。**不改任何记录格式/落盘路径/schema**（§4.5）——service 对**磁盘契约的产出保持逐字节不变**，
  只改「谁在何时把它启停」。新增 `Local\TimeArcStop` 具名事件作停采集通道（§4.4），停机仍走既有 flush（`usage_tracker.c:136-142`）。
- **UI 侧（consumer）**：设置页新增「开机自启」开关，经 `QProcess` 调 service 的 `--install/--uninstall/--status`
  （UI→子进程命令，**非磁盘契约、非 socket/shm**，守 I1）；`--status` 回显当前注册/运行态。UI **对数据的读取完全不变**
  （仍读同样的 JSONL/live/SQLite）。`src/main.cpp::startUsageService` 的 auto-spawn 与自启的关系在 S2 收口（靠单例幂等去重）。
- **接缝结论**：B1 的 UI↔service 数据面**零变化**，唯一新增的是「UI→service 的生命周期控制命令」（命令行参数 + 具名事件），
  二者都不构成 I2 数据契约变更，故 B1 不需 I2 修订（对比：service-config 提案新增的是 UI→service **数据**方向，那才需签核）。

---

## 2. 多 session 拆分（逐张范围卡）

### S0 — Kickoff + 路线决策门（本文 · 无代码 · 与 A1 并行）
**目标**：产出本设计文档；把 §0.3 的 Session 0 陷阱与 §1.2 三路线交给产品/维护者拍板，记一次决策进 session log。
- 交付①：`docs/b1-windows-service-scm-kickoff.md`（本文）+ backlog §B1 指针更新（指向本文，仿 A1）。
- 交付②（**Track-B Required**：B-feature.md:17-19/:29 要求「Service 侧 / UI 侧」设计段对 + 决策入 journal）：建
  `.harness/journal/sessions/YYYYMMDD-HHMM-B-b1-windows-service-scm-kickoff.md`（仿 A1 的同名 session log），内含
  (a) **§1.4 的「Service 侧 / UI 侧」两侧设计段对**，(b) **路线决策**「Route A / Route B / 暂缓 + 一句话理由」。
  开 session 时先 `python .harness/tools/preflight.py --track B`（它会打印该 log 路径）。
- **决策权归属**：路线选择是**产品/维护者**的（像 AI arc 与 H5 一样门控）——本 kickoff **不替其拍板**，只把正确/
  错误后果摆清。决策落 log 后，据此决定开哪些卡（Route A: S1→S2 / Route B: SB1→SB3）。
- 文件红线：🟢 仅 `docs/`、`docs/implementation-backlog.md`、`README.md §Roadmap`、`.harness/journal/sessions/*`（文档）。
  ⛔ 不碰任何 `src/`、不碰冻结表。
- 变更提案：**否**。验收：本文 + session log 落库；backlog/roadmap 指针同步；`harness_check` exit 0。

---
#### Route A 卡（推荐 MVP）

### S1 — 生命周期动词 + 用户会话自启注册 + 与 UI spawn/单例收口（Track B · Windows）
**目标**：在 `win_service.c` + `main.c` 内实装 `--install/--uninstall/--start/--stop/--status`，底层用
**用户级自启**（Task Scheduler 登录任务优先，HKCU Run 退路），保证 tracker 仍在用户会话运行；并**收口与 UI
auto-spawn / 单实例 mutex 的关系**，杜绝双开。
- `main.c`：`int main(void)` → `int main(int argc,char**argv)`，按动词分派；无参仍走今天的 tracker 路径（向后兼容）。
- `win_service.c`：实装动词。`--install/--uninstall/--status` **避让技巧（首选）**：注册/反注册经
  `CreateProcess`/`_wsystem` 调 `schtasks.exe`（或 `reg.exe`）——**不链接新库、不动冻结 CMake**（见 §3）。若改用 API
  （`RegSetValueEx` / Task Scheduler COM `taskschd`）则需链 `advapi32`/COM → 落入 §3 冻结提案。
- **`--stop` 需新建停采集通道（不能靠 console_handler，§4.4）**：tracker 主循环额外等待具名事件
  `Local\TimeArcStop`（每轮非阻塞 `WaitForSingleObject`，置位即 `request_stop()`→走既有 flush）；`--stop` 进程
  `OpenEvent`+`SetEvent`。这是 `usage_tracker.c`/`main.c`（非冻结）内的小改，**不引第三方依赖、不动磁盘契约**。`--start`
  ＝确保自启项已注册并拉起一个用户会话 tracker（命中既有 `Local\` 单例则幂等）。
- **与 I1 收口（必须）**：今天 UI `startUsageService` 会 detached-spawn；自启注册后存在「UI 再 spawn + 自启已拉起」
  双触发风险。处置：① 依赖既有 `Local\TimeArcUsageService` 单例——第二个实例命中 `ERROR_ALREADY_EXISTS` 即
  `return 0` 静默退出（`main.c:38-41`，**今天已具备**，B1 须保此语义）；② 文档化「自启 ON 时 UI spawn 变为冗余安全网」。
  **不**在本卡改 `src/main.cpp`（留给 S2 的 UI 侧；本卡只保证 service 侧幂等）。
- 文件红线：🟢 `src/service/windows/service/win_service.{c,h}`、`src/service/windows/main.c`。
  ⛔ 不新增 `.c/.h`（否则动冻结 `src/service/CMakeLists.txt`）；不链新库（用 shell-out 避让）；不碰 `src/main.cpp`。
- 变更提案：**否**（若坚持用 API 链 `advapi32` 则**是**，见 §3）。验收：见 §6（注册→注销→重登录→单实例→优雅停）。

### S2 — UI 设置「开机自启」开关 + 文档同步（Track B · 两侧设计）
**目标**：满足 Track-B「两侧设计 + 用户可见即更 README」要求——设置页加「开机自启」开关，调 S1 的
`--install/--uninstall/--status`；同步 README/rules/open-issues。
- UI 侧：设置页（`qml/desktop/settings/…` + 一个非冻结 `*.cpp` 管理器或复用现有）加开关；`QProcess` 调
  service 动词；`--status` 回显当前态。**纯 UI→子进程调用，不经磁盘契约、不加 IPC/socket/shm（守 I1）**。
- 收口 `src/main.cpp`（如需）：自启 ON 时是否仍 auto-spawn——二选一并文档化（推荐保留 spawn 当安全网，靠单例去重）。
- 文档（**按 §名定位，行号会漂移**；以下行号为现状参考、引用前 grep 复核）：`README.md` 状态表（现 ~line 160「console
  binary / SCM TODO」）、§TimeArc Service（~377）、启动说明（~343-344「auto-spawn detached」）、§Roadmap（~547-548
  「Register the Windows service with the SCM」）逐处改写为实际机制；`.harness/rules/02-platform-boundaries.md §3`
  Windows 条目 `service/win_service.c:`「**TODO** SCM stubs」改为实况；`.harness/state/open-issues.md` Platform
  「Windows service is not a real service」移除/改写。
- 文件红线：🟢 `qml/desktop/settings/*`、一个非冻结 UI `*.cpp`、`src/main.cpp`（敏感、慎改）、`README.md`、
  `.harness/rules/02-*.md`、`.harness/state/open-issues.md`、`docs/*`。⛔ 不碰冻结表任何文件。
- 变更提案：**否**（无冻结改动）。验收：UI 开/关自启→`--status` 回显一致；抓图设置页；README/rules 无残留 stale 引用。

---
#### Route B 卡（门控 · 仅当产品选「真 SCM 守护」才开）

### SB1 — ServiceMain + session-broker（把 worker 投进用户会话 · Track B · Windows）
**目标**：实装 `--run-service`：`StartServiceCtrlDispatcher` → `ServiceMain` → `RegisterServiceCtrlHandlerEx`
（接 STOP + **SESSIONCHANGE**）→ `SetServiceStatus` 全状态机（START_PENDING→RUNNING→STOP_PENDING→STOPPED）；
服务自身**不直接采集**，而是 `WTSGetActiveConsoleSessionId`→`WTSQueryUserToken`→`DuplicateTokenEx`→
`CreateEnvironmentBlock`→`CreateProcessAsUser` 把 tracker worker 投进活动用户会话（桌面 `winsta0\default`、
带用户 env）。STOP 时给 worker 发优雅停（不 `/F`），并报足够 wait-hint 让其 flush（§4.4）。
- 关键正确性：worker 进程内仍是今天的 `usage_tracker_run`，**env/会话由 broker 保证为用户**（§4.1/4.2）。
- 链接：`advapi32`（SCM/CreateProcessAsUser/Token）+ `wtsapi32`（WTSQueryUserToken）+ `userenv`（CreateEnvironmentBlock）
  → **动冻结 `src/service/CMakeLists.txt:91-99` → 变更提案（§3）**。
- 文件红线：🟢 `win_service.{c,h}`、`main.c`；🧊 `src/service/CMakeLists.txt`（**须提案**）。验收：服务以 SYSTEM 跑、
  worker 以用户跑、`query session` 见 worker 在用户会话；停服 worker 优雅 flush。

### SB2 — SCM install/uninstall + 会话切换重投（Track B · 需管理员）
**目标**：`--install`＝`OpenSCManager(SC_MANAGER_CREATE_SERVICE)`+`CreateService(AUTO_START,LocalSystem,binPath
" --run-service")`；`--uninstall`＝`OpenService`+`ControlService(STOP)`+`DeleteService`；登录/解锁/快速用户切换
（`SERVICE_CONTROL_SESSIONCHANGE`：`WTS_SESSION_LOGON`/`UNLOCK`/`CONSOLE_CONNECT`）时重投 worker；处理 UAC 提权
（install/uninstall 需管理员令牌——动词内自检 + 文档化「右键管理员运行」或 UI 触发 `runas`）。
- 文件红线：🟢 `win_service.{c,h}`；🧊 CMake（若 SB1 已链则不复链）。变更提案：随 SB1 同一提案覆盖。
- 验收：`services.msc` 见 `time-arc-service`（Automatic）；重启后自启、worker 落用户会话；锁屏解锁 worker 仍在；卸载干净。

### SB3 — UI 集成 + 文档 + **I1 修订（变更提案落地）**
**目标**：UI 设置「随系统启动（服务）」开关调 SB2 动词（带提权）；README/rules 同步；**修订 CHARTER I1**——
I1 现把「UI may start the service via `startUsageService` + `Local\` mutex」写成不变量；Route B 引入「SCM 以 SYSTEM
拉起 + broker 投 worker（worker 用 `Local\`、supervisor 用 `Global\` 单例）」是对 I1 启动模型与单例机制的实质变更。
- **变更提案落地**：填 `templates/change-proposal.md` 进 `journal/sessions/`，§1 列 `CHARTER.md`（I1 修订）+
  `src/service/CMakeLists.txt`（链接库），§3 两进程影响，§5 回滚（卸载→回 Route A/UI-spawn），§7 bump CHARTER 版本 +
  重生成 `state/frozen-files.json`。**提案须在改冻结文件前已落库**。
- 验收：抓图 UI 开关；`harness_check` exit 0；冻结改动有提案 + 哈希更新；README/rules/open-issues 同步。

---

## 3. 冻结文件与变更提案边界

**非冻结（可直接改）**：`src/service/windows/service/win_service.{c,h}`、`src/service/windows/main.c`、
`src/main.cpp`（UI 入口，敏感但非冻结，慎改）、`qml/**`、`README.md`、`.harness/rules/*.md`、
`.harness/state/open-issues.md`、`docs/**`。

**冻结（改前须先填 `templates/change-proposal.md` 进 `journal/sessions/` + 更新 `state/frozen-files.json`；
`harness_check` pass 2 按哈希拦）**：`src/service/CMakeLists.txt`（CHARTER §3 line 64）、`.harness/CHARTER.md`、
`.harness/AGENTS.md`、`AGENTS.md`，以及 `src/service/shared/*`、`src/CMakeLists.txt`、顶层 `CMakeLists.txt`。

**关键事实 / 红线判断**：
- **win_service.c / main.c 已登记进 CMake（`CMakeLists.txt:49,57`）、且非冻结** → **三/五动词与 ServiceMain 全部可在
  这两文件内实装，不新增翻译单元、不动冻结 CMake**（与 A1「折进已登记 .cpp」同款避让技巧）。
- **唯一可能必然的冻结改动 = 链接系统库**：现 service 链 `user32 psapi ole32 uuid`（`CMakeLists.txt:91-99`），
  **未链 `advapi32`**。一旦用 API 实现：
  - Route A 用 `RegSetValueEx`（HKCU Run）或 Task Scheduler COM → 需 `advapi32`/`ole32`(已链)；
  - Route B 的符号→库映射（实装者按此加链、勿漏）：
    - `OpenSCManager/CreateService/OpenService/ControlService/DeleteService/QueryServiceStatus`、
      `RegisterServiceCtrlHandlerEx/SetServiceStatus/StartServiceCtrlDispatcher`、
      `CreateProcessAsUser/DuplicateTokenEx/ImpersonateLoggedOnUser/RevertToSelf` → **`advapi32`**；
    - `WTSQueryUserToken`、`WTSRegisterSessionNotification`、`WTSFreeMemory` → **`wtsapi32`**；
    - `CreateEnvironmentBlock/DestroyEnvironmentBlock` → **`userenv`**；
    - ⚠️ `WTSGetActiveConsoleSessionId`（活动会话来源，§4.1）**在 `kernel32`、隐式可用**——别误以为所有 `WTS*`
      都来自 `wtsapi32`；它不强制加链。
  MinGW（`run.cmd`：mingw1310 + Ninja）当前链接集（`CMakeLists.txt:91-99`）只有 `user32 psapi ole32 uuid`，
  **不含 `advapi32/wtsapi32/userenv`**；今天能编过只因现有代码不引这些符号。Route B 一旦引用上述符号即须在冻结
  `src/service/CMakeLists.txt` 显式加链 → **变更提案**（这是 B1 在 backlog 标「提案：若新增源/动 service CMake 则需」的所在）。
- **MVP 避让（推荐）**：Route A S1 用 **`CreateProcess` 调 `schtasks.exe`/`reg.exe`**（kernel32 已隐式可用），
  **完全不链新库、不动冻结 CMake、不需提案**——把首个纵切的治理成本压到零。Route B 因 token/会话 API 无法 shell-out
  规避，**必然**走链接 + 提案。
- **I1 修订的触发条件**：仅当**启动模型/单例机制实质改变**才需改 CHARTER I1（→ 提案 + bump 版本）。
  - Route A（S1/S2）：tracker 仍在用户会话、仍 `Local\` 单例、UI 仍可 spawn → **I1 语义未变，默认不改 CHARTER**
    （只是新增一个「自启」旁路；在 README/rules/02 描述即可）。**保守默认：不动 I1。** 论据：schtasks/HKCU 自启只是
    「**换个东西去 spawn 同一个用户会话二进制**」，启动后仍受同一 `Local\TimeArcUsageService` 单例约束——I1 三条
    （UI 可启服务 / UI 不链服务码 / `Local\` 单例）**无一被违反**，新增非 UI 启动方不等于启动模型变更。
  - Route B（SB3）：SYSTEM 拉起 + broker + `Global\` supervisor 单例 → **改 I1 → 提案（SB3）**。
- **I2 数据契约：B1 全程不改**（无 schema/记录/路径/新数据方向变更，§4.5）→ **B1 不触发 I2 修订**，治理面比 A1 轻：
  A1 必然改冻结 `CHARTER` I2；B1 只在 Route B 才改 `CHARTER` I1 + service CMake，Route A 可零冻结改动落地。
- **许可 I6（CHARTER line 42-45）**：`advapi32/wtsapi32/userenv/taskschd` 均为 **Windows 系统库**（系统库例外，
  GPL 兼容），`schtasks/reg/sc` 是系统自带 exe → **无新第三方依赖、不改 `rules/06`**。

---

## 4. 必须保留的语义（B1 的不变量，违反即用户可见回归 / 静默丢数）

1. **tracker 必须跑在交互式用户会话**（§0.3 主不变量）：`GetForegroundWindow`/`GetLastInputInfo`/WASAPI 枚举/
   GSMTC 全是 per-session API。任何路线下，**真正采集的进程不得落在 Session 0**。Route A 天然满足；Route B 须靠
   broker 把 worker 投进 `WTSGetActiveConsoleSessionId` 的活动会话（投错/投空 = 静默全空）。
2. **用户 profile env 解析一致**：写侧 `usage_paths.c:55-58` 与读侧 `usage_stat_manager.cpp:48-50` 都靠
   `LOCALAPPDATA`/`APPDATA`。worker **必须以用户身份 + 用户 env 运行**，否则写 systemprofile、UI 读用户 profile →
   **读写分裂、UI 空库**。Route B 的 `CreateProcessAsUser` 必须配 `CreateEnvironmentBlock`（不能只传 token 不传 env）。
3. **单实例（CHARTER I1）+ mutex 命名空间**：恰好一个 tracker per 会话。
   - 既有 `Local\TimeArcUsageService`（`main.c:33`）＝每会话一份，**正是用户会话模型要的**；第二实例命中
     `ERROR_ALREADY_EXISTS` 静默退（`main.c:38-41`）——B1 须**保此幂等**，用它消化「UI spawn + 自启」双触发。
   - Route B 若引入 session-0 supervisor，则 **supervisor 用 `Global\` 单例、worker 仍用 `Local\`**（命名空间不可混）。
   - ⚠️ Route B 陷阱：SYSTEM 建的 `Global\` 对象默认 DACL 可能**拒绝标准用户 `OpenMutex`**——若 UI/`--status`（用户上下文）
     要观测 supervisor 单例态，须给该 mutex 显式 DACL 授予交互用户 `SYNCHRONIZE`/`QUERY`，否则跨会话单例检查会以
     `ERROR_ACCESS_DENIED`（而非 `ERROR_ALREADY_EXISTS`）静默失败、误判「没在跑」。
4. **有序 flush 于停机**（rules/02 §2.6 + `usage_tracker.c:136-142`）：停止必须经
   `timearc_usage_tracker_request_stop()` 让主循环退出前 flush 当前 session + audio，**不得 `taskkill /F` 硬杀**
   （/F 不投递 CTRL → 跳过 `console_handler` → 丢当前 open session）。
   - ⚠️ **Route A 的实现陷阱（必须正视，不能含糊）**：今天 tracker 是 **UI `startDetached` 的脱离进程、且无控制台**
     （Windows 下 `startDetached` 默认不给新控制台）。因此 `console_handler`（`main.c:14-26`）**只在登录注销/系统关机
     时才会触发**；一个**单独的 `--stop` 进程无法**对它投递 CTRL——除非 `AttachConsole`+`GenerateConsoleCtrlEvent`，
     而那要求 tracker 自己拥有控制台（当前没有）。**结论：今天根本没有「兄弟进程优雅停」的通道。** 所以 S1 的 `--stop`
     **必须新建一条信号通道**：推荐 tracker 主循环额外**等待一个具名事件**（`CreateEvent(... "Local\\TimeArcStop")`，
     每轮 `WaitForSingleObject(0)` 轮询，置位即 `request_stop()`），`--stop` 进程 `OpenEvent`+`SetEvent` 即可优雅停；
     具名事件是**进程内同步原语、非数据 IPC**，不碰磁盘契约、不违 I1「无 socket/shm」边界。**不要**用 `taskkill /F`。
   - Route B 的 SCM STOP：`ServiceMain` 收 `SERVICE_CONTROL_STOP` → 报 `SERVICE_STOP_PENDING` + 足够 `dwWaitHint`
     → 给 worker 发优雅停（同上具名事件，跨会话用 `Global\\` 命名 + DACL，见 §4.3）→ 等 worker flush 完再报
     `SERVICE_STOPPED`；wait-hint 太短 SCM 会强杀丢 flush。
5. **磁盘契约零改动**（I2 / rules/03）：B1 是**纯进程生命周期**特性。**不动** SQLite 表契约、记录字段、
   `usage_paths` 路径、`usage_records.jsonl`/`usage_current.json`/`timearc.db` 的写法，**不新增 UI↔service 数据方向**
   （区别于 service-config 提案那种「UI→service 通道」）。这条让 B1 与 A1 无冲突、且无需 I2 提案。
6. **许可姿态（I6）**：只用 Windows 系统库/系统 exe，不引入新第三方依赖（§3）。
7. **H5 idle/track 配置仍须抵达 worker**：若 `usage_config.json` 通道（已填提案
   `20260609-0150-B-service-config-proposal.md`）日后签核，worker 须在**它实际运行的用户会话**读到该文件
   （路径仍由 `usage_paths.c` 决定，回到 §4.2 的 env 一致性）。B1 与 H5 在「worker 跑在何处、以何身份读盘」上耦合，
   设计时交叉引用，勿让 Route B 的 broker 把 worker env 改坏导致 H5 读不到配置。

---

## 5. 风险登记
- **Session 0 隔离（主风险）**：朴素 `CreateService`+LocalSystem 使 §0.3 六条全废——前台/空闲/音频/媒体采集全空、
  数据写错目录。**B1 设计的第一职责就是把这条挡在门外**（§0.3 / §1.2 决策门）。
- **错 profile 数据分裂**：worker 非用户身份运行 → systemprofile 写、用户 profile 读 → UI 静默空库。必须用户身份 + 用户 env（§4.2）。
- **双开 / mutex 命名空间**：UI spawn + 自启同时拉起；或 Route B supervisor/worker 混用 `Local`/`Global`。靠 §4.3 收口。
- **硬杀丢 flush**：`taskkill /F` 或过短 SCM wait-hint → 丢当前 open session。靠 §4.4 优雅停。
- **UAC / 提权**：Route B 的 SCM install/uninstall（+ 可能 HKLM）**需管理员**；Route A 的 HKCU/per-user task/Startup
  **不需**——这是推荐 Route A 的重要产品理由（无安装期 UAC 摩擦）。动词须自检权限并给清晰报错/提权指引。
- **服务构建/测试不在 UI qml loop**（同 service-config 提案 §6 NOTE）：B1 必须**真机**验证（`services.msc` / Task
  Scheduler / **重启 / 注销重登** / `query session` 看会话），**无法**在 Qt 构建循环里 smoke。须由能 build service 的人做。
- **快速用户切换 / 多用户**（仅 Route B）：活动会话变更需 `SESSIONCHANGE` 重投 worker；多用户并发是额外复杂度（SB2）。
- **AV / SmartScreen / 代码签名**：一个「自启 + 读他进程音频/窗口标题 + （Route B）从 SYSTEM 拉子进程」的程序更易被
  AV/SmartScreen 拦。`audio_win.c:336` 的 `_popen("powershell …")` 在 Route B 的服务上下文尤其是安全/会话异味
  （Route A 在用户会话则与今天一致、无新增风险）。落地缓解接 F1/F2 发布/签名 arc。
- **与 A1 时序**：B1 改启动方式可能影响 A1 真机验证的「service 在跑」前提；两者并行时在各自 session log 注明当前
  service 由谁拉起（UI spawn / 自启 / 手动），避免 A1 探针误读「service 没在写」。

---

## 6. 验收口径（贯穿各 session）
- **session 起手**（CLAUDE.md Required Start / AGENTS §4）：`python .harness/tools/preflight.py --track B`（exit≠0 先修
  drift 再动；它打印本 session log 路径）。
- **采集在用户会话**（主验收）：注册自启/服务后，任务管理器「会话」列 / `query session` / `tasklist /fi "imagename eq
  time-arc-service.exe" /v` 确认 tracker（Route B 为 worker）**在登录用户会话**，不在 Session 0。
- **数据落用户 profile**（**两处目录分别核**，§0.3 ⚠️）：确认新记录写进**当前用户**的
  ①`%LOCALAPPDATA%\TimeArc\usage\{usage_records.jsonl, usage_current.json}` **与**
  ②`%APPDATA%\TimeArc\TimeArc\timearc.db`（A1 的 SQLite，**不同盘段、不同子目录，不在 ① 旁**），UI 能读到（非空、
  随采集增长）。**严禁**任一落 `…\systemprofile\…`；若 Route B，留意 `database_manager.cpp:17-46` 的 split-brain 告警是否触发。
- **自启生效**：**重启 / 注销重登**后 tracker 自动起、单实例（无双开：仅一个 `Local\` mutex 持有者）。
- **优雅停**：`--stop`（或 SCM STOP）后当前 open session 被 flush（尾段不丢；对比停前后 JSONL 尾部），非 `/F` 硬杀。
- **注销干净**：`--uninstall` 移除注册项（Task Scheduler 任务 / HKCU 值 / SCM 条目）无残留；再 `--status` 报未注册。
- **两侧齐活**（Track-B Exit）：service 动词 + UI 开关一起 build & run；抓图设置页开关与 `--status` 回显一致。
- **真机端到端**：先 kill 锁 exe → `python .harness/tools/build.py`（**不**只 `db_smoke`，须真 service + 真 UI）；
  Qt 跑后 `python .harness/tools/scan_qt_log.py`。
- **harness**：每 session 收尾 `python .harness/tools/harness_check.py` exit 0；冻结改动（仅 Route B 的 CMake/I1）
  有对应提案 + `state/frozen-files.json` 哈希更新；任何 L1/L2/L3 走 `record_error.py`。
- **文档同步**：完成即更 `README.md`（line 160/343-344/377/547-548）、`.harness/rules/02-*.md §3`、
  `.harness/state/open-issues.md`、`docs/implementation-backlog.md §B1`、`README §Roadmap`，grep 无 stale「SCM TODO/
  console binary」残留。

---

## 7. 与既有文档 / playbook 的关系
- backlog 行动项：`docs/implementation-backlog.md §B1`（本文是其展开；§B1 现状/提案标注与本文一致）。
- 简洁 known gaps：`.harness/state/open-issues.md` Platform「Windows service is not a real service」（完成后改写/移除）。
- 平台义务 / 参考实现：`.harness/rules/02-platform-boundaries.md`（§2 六条义务——尤其 5 单实例、6 flush；§3 Windows
  reference + `service/win_service.c:`「**TODO** SCM stubs」条目）。
- 不变量与冻结：`.harness/CHARTER.md`（I1 两进程分离 + 启动模型 + `Local\` 单例；I4 平台隔离；I6 许可；§3 冻结表含
  `src/service/CMakeLists.txt`；§4 修订流程）。B1 唯一可能的 charter 改动＝Route B 的 I1 修订。
- Track 与提案范式：`.harness/tracks/B-feature.md`（B1 在「Concrete feature queue：Windows SCM registration: fill the
  three TODO stubs」；Required = 两侧设计段 + 同提交改 rules/README + frozen 动则提案）；
  `.harness/templates/change-proposal.md`（Route B 据此填）；范本 `.harness/journal/sessions/
  20260609-0150-B-service-config-proposal.md`（同为「service 侧 + 待签核」体例；其 H5 idle/track 通道与 §4.7 耦合）。
- 姊妹 kickoff（体例/严谨度对照）：`docs/a1-sqlite-storage-migration-kickoff.md`（A1 改存储读写、B1 改进程生命周期，
  二者并行无冲突；本文沿用其「现状校正→范围→范围卡→冻结边界→不变量→风险→验收→关系」结构）。
- 用户/开发者文档：`README.md` §TimeArc Service（line 377）、状态表（line 160）、启动说明（line 343-344）、
  §Roadmap（line 547-548「Register the Windows service with the SCM」）。

> 再次强调（B1 的「正确线路」一句话）：**backlog 说「真正的 Windows 服务」，但 Session 0 隔离使「采集必须在用户
> 会话、以用户身份运行」才是真正的不变量。先过 §1.2 路线决策门，默认走 Route A 用户会话自启；只有产品明确要
> `services.msc` 级守护才走 Route B 的 session-broker，并据 SB3 修订 I1。**
