# Agent Harness 对照学习：TimeArc `.harness` vs. Superpowers

> 架构学习笔记。缘起：合作方在用 obra/**Superpowers**（Claude Code 插件 / agent
> 开发方法论）。本文回答两件事：(1) 两套体系各是什么、如何逐条对应；(2) TimeArc
> 是否需要引入 Superpowers，以及若不引入、有哪些思想值得吸收进现有 `.harness`。
>
> **结论先行**：TimeArc 不引入 Superpowers 插件——现有 `.harness` 已是权威、且覆盖
> 同一职责；插件的 worktree/TDD 默认流与本仓的冻结文件、track、disk contract 等硬约束
> 相冲突。可借鉴的是它的**若干 skill 思想**，以"服从现有 harness"的方式吸收（见 §6）。
> 配套 session 记录见 `.harness/journal/sessions/20260609-0335-B-harness-vs-superpowers-study.md`。

## 1. 一句话定位

| | 定位 |
|---|---|
| **TimeArc `.harness`** | 本仓自带的**权威** agent 治理层：按 track 约束改动、五道命令闸、冻结文件 + 变更提案、磁盘契约不变量、错误账本。目标是"让 agent 在这个特定两进程项目里不越界"。 |
| **Superpowers** | obra/Jesse Vincent 的**通用** agent 方法论插件：以 markdown skill 形式装进任意项目，推动 brainstorm→plan→TDD→review 的纪律化流程。目标是"让 agent 在任意项目里按好习惯交付"。 |

两者**同类、互相竞争**——都属于"先立规矩再让 agent 动手"。差别在：harness 是**项目专属、强制、磁盘契约导向**；Superpowers 是**通用、可移植、TDD 导向**。

## 2. Superpowers 是什么（回顾）

- 形态：一组 **markdown skill 文件**（指令 + 清单 + 流程图），agent 动手前先读。可自写新 skill。
- 安装：`/plugin install superpowers@claude-plugins-official`（按用户本地装，**不入库**）。
- 七阶段工作流：`Brainstorm（苏格拉底逼出 spec）→ Git Worktree（隔离工作区）→ Plan（拆成 2–5 分钟小任务）→ Implement（子 agent 执行 + review）→ TDD（RED-GREEN-REFACTOR，测试须先红）→ Code Review（spec 合规 + 质量）→ Finalize（合并/维护分支）`。
- 招牌 skill：systematic debugging（四阶段，先定根因再改）、subagent-driven development、skill authoring。
- 注：本仓 `docs/superpowers/`（plans/ + specs/）是**合作方用 Superpowers 时产出的工件**，不是插件本体，保留不动。

## 3. TimeArc `.harness` 是什么（权威结构）

来源：`AGENTS.md` / `.harness/AGENTS.md` / `.harness/CHARTER.md` / `tracks/*` / `rules/01-07` / `tools/*`。

- **一会一 track**：`A 稳定化`（行为不变、提质）/ `B 功能`（新能力、产品文档）/ `C 调试`（修已知错）。开工前选一个，不许一会两 track。
- **五道命令闸**（非零退出即阻断）：
  1. `preflight.py --track <A|B|C>`（开工，校验漂移 + 打印 session-log 路径）
  2. `build.py`（**禁** 裸 `cmake --build`；失败自动归档 L1）
  3. `scan_qt_log.py`（每次 Qt/QML 运行后）
  4. `record_error.py --level <L1|L2|L3>`（任何错误必入账本）
  5. `harness_check.py`（提交前；非零禁提交）
- **冻结文件 + 变更提案**：`CHARTER.md §3` 列表（数据契约头、`usage_paths.*`、各 `CMakeLists.txt`、harness 自身入口…），hash 锁在 `state/frozen-files.json`。改前须先落 `journal/sessions/YYYYMMDD-HHMM-<track>-<slug>.md` 提案，`harness_check` pass 2 校验。
- **磁盘契约不变量 I1–I6**：两进程只经磁盘通信（无 IPC/socket/shm）；schema 在 `usage_record.schema.json`；C ABI 桥 `data_bridge.h`；平台隔离 `src/service/{windows,macos,linux}`；存储全有或全无；GPL/LGPL 许可姿态。
- **rules 01–07 按需读**：架构 / 平台边界 / 数据契约 / UI 约定 / 构建系统 / 许可 / 产品-AI 卡片。只读 diff 触及的那几条。
- **错误账本**：L1 编译链接 / L2 运行时·QML·错误落盘数据 / L3 **agent 自身判断错**（最有长期价值）。"No error escapes the journal."
- **预算哲学**（`OPTIMIZE.md`）：按需读、不整本读、解析工具 stderr 的 `DRIFT:` 行而非重读源码、按锚点引用 rule 而非粘贴。`.harness/` 内每个 `.md` 硬上限 **100 行**。

## 4. 逐条对照表

| 维度 | TimeArc `.harness` | Superpowers | 谁覆盖 / 评注 |
|---|---|---|---|
| 任务分类 | track A/B/C，一会一 track | 七阶段线性流 | 都有；harness 更强约束（互斥 track） |
| 设计/需求澄清 | track B 要求"服务侧/UI 侧"双段设计 + before-coding 清单 | Brainstorm skill（苏格拉底逼 spec） | **Superpowers 更系统**——可借鉴（§6） |
| 任务拆分 | 无强制粒度，靠 session log | Plan：拆成 2–5 分钟小任务 | Superpowers 更细；harness 留给人 |
| 隔离工作区 | 人工 git worktree（本仓确在 `.claude/worktrees/` 用） | Git Worktree skill 自动化 | 都用 worktree；harness 不自动化 |
| 测试纪律 | **无 TDD**；验证靠 `build.py`+`scan_qt_log`+ PrintWindow 截图视觉核对 | RED-GREEN-REFACTOR 强制 | **根本差异**——见 §5 |
| 代码评审 | `checklists/review.md` + 人工 | subagent code review 内建 | Superpowers 自动化；可借鉴 |
| 调试方法 | track C + `record_error` 账本 | systematic debugging 四阶段 | **互补**——四阶段思想可吸收（§6） |
| 防越界/防乱改 | 冻结文件 + hash 锁 + 变更提案 + I1–I6 不变量 | worktree 隔离（无项目级不变量概念） | **harness 独有且关键**——Superpowers 没有"磁盘契约/冻结文件"这层 |
| 错误/经验沉淀 | L1/L2/L3 账本 + INDEX | skill 文件迭代 | 形态不同；harness 更适合本项目审计 |
| 知识形态 | rules/tracks/checklists（项目专属、入库） | skill markdown（通用、用户本地、不入库） | harness 入库可团队共享；插件个人化 |
| 成本控制 | `OPTIMIZE.md` + 100 行预算 | 无显式 token 预算 | harness 独有 |

## 5. 为什么不能简单叠加（冲突点）

1. **权威冲突**：`CLAUDE.md` 明文"harness 是权威，Claude 记忆/外部建议是 advisory"。再叠一套同样要"立规矩"的 Superpowers，遇到分歧时谁说了算无法判定——徒增混乱。
2. **TDD 假设落不了地**：Superpowers 核心是 RED-GREEN-REFACTOR 快循环；TimeArc 是 Qt6/QML 桌面 + native service，验证主路径是 **build + PrintWindow 截图 + QML 视觉核对**（见 `rules/04`），不是单测快循环。强推 TDD 会和现有验证习惯顶牛。
3. **worktree 流冲突**：Superpowers 默认每任务建 worktree；本仓已有自己的 `.claude/worktrees/` 用法 + 一会一 track 约束，自动化 worktree 会和 track 闸、preflight 路径打架。
4. **缺项目级护栏**：Superpowers 没有"冻结文件 / 磁盘契约 / I1–I6"概念——而这恰是 TimeArc 最需要守的（两进程一磁盘契约）。插件不会帮你守这条，harness 才会。
5. **入库 vs 个人化**：harness 入库、团队共享、可审计；插件按用户本地装、不入库。合作方装了**不约束你**，你不装也不影响协作（无共享依赖）。

## 6. 不引入插件，但值得吸收的思想

以"**服从现有 harness、不另起体系**"的方式，把 Superpowers 的好点子提炼进 `.harness/rules/` 或 checklists（每文件 ≤100 行）：

- **Brainstorm-to-spec**：track B 的"双段设计"可强化为"先把 spec 分块给人确认再写码"，写进 `checklists/before-coding.md`。
- **Systematic debugging 四阶段**：track C 当前靠 `record_error` 账本，可补一条"先复现→定根因→最小改→验证，禁止未定根因就打补丁"的 rule，强化 L3 纪律。
- **Subagent code review**：在 `checklists/review.md` 增一条"提交前用独立子 agent 对照 spec/charter 跑一遍 review"，对应本仓已用 `/code-review` 的习惯。
- **任务拆分粒度**：Plan 的"小任务"思想可作为大范围改动时的 session-log 建议（见 §7），不强制。

这些都是**借思想不借框架**——产物仍是 harness 自己的 rule/checklist，保持单一权威。

## 7. 给"系统级检查 + 大范围改动"的落地提醒

接下来若做系统级、跨多文件的大范围工作，按 harness 这样走最稳：

1. **track 选择**：纯提质重构选 **A**（行为不变）；新增能力选 **B**；修已知错选 **C**。大范围工作最容易踩"一会两 track"——若一次里既重构又加功能，**拆成多个 session**。
2. **冻结文件预警**：系统级改动极可能触及 `CMakeLists.txt`、数据契约头、`usage_paths.*` 等冻结文件——**改前先落变更提案**（范本见 `templates/change-proposal.md`，样例见 service-config 提案）。
3. **守磁盘契约**：任何跨进程协作只能走磁盘（I1）；想加 UI→service 配置通道，已有现成提案 `.harness/journal/sessions/20260609-0150-B-service-config-proposal.md` 可接续，别引 IPC/socket/shm。
4. **服务侧不可在 UI build loop 验证**：service 是独立 native 进程，需单独构建/烟测；UI 的 qml 截图循环验不了它（见上引提案 §6）。
5. **错误必入账本**：大范围改动错误多，每个 build/runtime/判断失误走 `record_error.py`，L3 尤其要记——这是这套 harness 长期价值所在。
6. **分批提交 + harness_check**：每个可独立验证的小切片提交前跑 `harness_check.py`，绿了再提；别攒一个巨型 commit。

## 8. 一句话收尾

> 合作方用 Superpowers 是他个人工具选择，不构成 TimeArc 引入它的理由。TimeArc 已有更贴合
> 两进程磁盘契约的权威 harness；保持单一权威，按 §6 借思想、按 §7 走流程即可。
