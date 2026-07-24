# TimeArc 跨端同步执行进度

**状态：** E0 交付规则实施中

**目标分支：** `dev`

**首版范围：** 二次元游戏、社交、音乐/视频/直播

**设计规格：** `docs/superpowers/specs/2026-07-24-cross-device-sync-design.md`

## 使用规则

- `[ ]` 未开始，`[-]` 进行中，`[x]` 已完成，`[!]` 阻塞。
- 一个可独立验证的子项完成后更新本文件并 commit。
- 一个 Epic 完成后 PR 到 `dev`，通过检查后 merge，再清理本地/远端分支。
- 每个 Epic 开始前生成自己的逐文件实施计划，一次只激活一个 Epic。
- 每次更新必须填写完成、未完成、验证证据、下一步和风险。
- 不允许以“代码已写完”代替测试、运行或云端验证。

## 总览

| Epic | 内容 | 状态 | 分支 | PR | Merge |
|---|---|---|---|---|---|
| E0 | Harness 交付规则 | `[-]` | `codex/cross-sync-e0-delivery-rules` | [PR #68](https://github.com/jerryzhou945/TimeArc/pull/68) | — |
| E1 | 云端基础设施与 Auth | `[ ]` | `codex/cross-sync-e1-cloud-auth` | — | — |
| E2 | 应用目录与统一映射 | `[ ]` | `codex/cross-sync-e2-app-catalog` | — | — |
| E3 | 云端数据库与 Sync API | `[ ]` | `codex/cross-sync-e3-sync-api` | — | — |
| E4 | Qt 账号与安全存储 | `[ ]` | `codex/cross-sync-e4-client-auth` | — | — |
| E5 | 本机聚合与 outbox | `[ ]` | `codex/cross-sync-e5-local-sync` | — | — |
| E6 | Push/Pull 同步引擎 | `[ ]` | `codex/cross-sync-e6-sync-engine` | — | — |
| E7 | 桌面端跨端 UI | `[ ]` | `codex/cross-sync-e7-desktop-ui` | — | — |
| E8 | Android 跨端 UI 与调度 | `[ ]` | `codex/cross-sync-e8-android-ui` | — | — |
| E9 | 隐私、迁移与发布验收 | `[ ]` | `codex/cross-sync-e9-release` | — | — |

## E0 — Harness 交付规则

- [x] 创建 Feature Track change proposal。
- [x] 补强现有 `.harness/rules/08-git-workflow.md`。
- [x] 更新冻结的 `.harness/AGENTS.md` 规则路由。
- [x] 定义小功能 commit 和 Epic PR 的验收边界。
- [x] 要求 session log 写完成、未完成、验证、下一步和风险。
- [x] 更新 frozen file hash。
- [x] `harness_check.py` 通过。
- [ ] PR 合并到 `dev` 并清理分支。

## E1 — 云端基础设施与 Auth

- [ ] 创建中国大陆 CloudBase 环境。
- [ ] 创建开发、测试、生产三套配置。
- [ ] 配置 CloudBase Auth 邮箱注册与验证。
- [ ] 选择并配置国内 SMTP。
- [ ] 创建 CloudBase MySQL。
- [ ] 创建云托管 Sync API 服务。
- [ ] 配置密钥管理与环境变量。
- [ ] 配置开发域名。
- [ ] 准备备案生产域名和 HTTPS。
- [ ] 验证注册、登录、刷新和退出。
- [ ] PR 合并到 `dev` 并清理分支。

## E2 — 应用目录与统一映射

- [ ] 定义 canonical app JSON/schema。
- [ ] 实现 catalog version 和 hash。
- [ ] 实现 Android package 精确匹配。
- [ ] 实现 Windows exe/app ID 精确匹配。
- [ ] 接入已有 browser site catalog。
- [ ] 实现二次元游戏 seed mappings。
- [ ] 实现社交 seed mappings。
- [ ] 实现音乐/视频/直播 seed mappings。
- [ ] 建立真实设备 alias 验证清单。
- [ ] 禁止通用 exe 单条件匹配。
- [ ] 完成误匹配、冲突和回滚测试。
- [ ] PR 合并到 `dev` 并清理分支。

## E3 — 云端数据库与 Sync API

- [ ] 创建 schema migration 工具。
- [ ] 创建 `user_profiles`。
- [ ] 创建 `devices`。
- [ ] 创建 `canonical_apps` 和 `app_aliases`。
- [ ] 创建 `sync_batches`。
- [ ] 创建 `daily_usage`。
- [ ] 创建 `usage_change_log`。
- [ ] 创建 `account_audit_events`。
- [ ] 实现 Auth token 验证 middleware。
- [ ] 实现设备注册、列表、改名、撤销。
- [ ] 实现 catalog endpoint。
- [ ] 实现 push endpoint。
- [ ] 实现 pull endpoint。
- [ ] 实现 usage query endpoints。
- [ ] 实现导出与云端删除 endpoints。
- [ ] 完成用户越权、设备越权和限流测试。
- [ ] PR 合并到 `dev` 并清理分支。

## E4 — Qt 账号与安全存储

- [ ] 新增 `AuthManager`。
- [ ] 使用 Qt Network 调用 Auth/API。
- [ ] Windows Credential Manager 保存令牌。
- [ ] Android Keystore 保存令牌。
- [ ] 实现 access token 刷新。
- [ ] 实现登录态恢复。
- [ ] 实现单设备与全部退出。
- [ ] 确认日志不会输出 token。
- [ ] 完成错误码和离线状态测试。
- [ ] PR 合并到 `dev` 并清理分支。

## E5 — 本机聚合与 outbox

- [ ] 创建本地 sync migrations。
- [ ] 创建 `sync_state` 和 `sync_devices`。
- [ ] 创建 `sync_outbox`。
- [ ] 创建 catalog cache。
- [ ] 创建 remote daily cache。
- [ ] 创建 app sync preferences。
- [ ] 桌面只读聚合 `frontmost_sessions.active_sec`。
- [ ] Android 聚合前台使用会话。
- [ ] 按本地午夜拆分跨日会话。
- [ ] 只输出 canonical allowlist。
- [ ] 原始标题、路径和媒体内容隐私测试。
- [ ] 行 hash 和 source revision 测试。
- [ ] 90 天与全部历史回填。
- [ ] PR 合并到 `dev` 并清理分支。

## E6 — Push/Pull 同步引擎

- [ ] 新增 `SyncManager` 和 `SyncRepository`。
- [ ] 实现状态机。
- [ ] 实现绝对值批量 push。
- [ ] 实现 batch 幂等。
- [ ] 实现 change sequence pull。
- [ ] 实现事务式 cursor 推进。
- [ ] 实现指数退避与随机抖动。
- [ ] 实现 401 单次刷新。
- [ ] 实现 429/5xx/断网恢复。
- [ ] 实现 catalog 过旧恢复。
- [ ] 实现 tombstone。
- [ ] 实现全量 resync。
- [ ] 桌面 15 分钟周期与跨日同步。
- [ ] 重复上传不增加时长的集成测试。
- [ ] PR 合并到 `dev` 并清理分支。

## E7 — 桌面端跨端 UI

- [ ] 设置页账号入口。
- [ ] 登录、注册和验证状态。
- [ ] 同步总开关与隐私预览。
- [ ] 三类与单应用开关。
- [ ] 历史范围选择。
- [ ] 设备管理。
- [ ] 同步状态与立即同步。
- [ ] 桌面/手机占比分段条。
- [ ] 每应用跨端明细。
- [ ] 本机缓存与过期提示。
- [ ] 导出/删除云端数据。
- [ ] 日夜主题、运行时语言和键盘访问验证。
- [ ] PR 合并到 `dev` 并清理分支。

## E8 — Android 跨端 UI 与调度

- [ ] 移动设置页账号入口。
- [ ] 移动登录/注册流程。
- [ ] 移动同步范围与设备管理。
- [ ] 移动跨端统计卡片。
- [ ] 应用恢复前台时同步。
- [ ] WorkManager 周期任务。
- [ ] Android 网络与电池限制状态。
- [ ] Keystore 失效和重装处理。
- [ ] 真机弱网、断网、锁屏和后台验证。
- [ ] PR 合并到 `dev` 并清理分支。

## E9 — 隐私、迁移与发布验收

- [ ] 新用户同步默认关闭。
- [ ] 首次同步显示数据预览。
- [ ] 默认回填最近 90 天。
- [ ] 云端数据导出验证。
- [ ] 单应用云端删除验证。
- [ ] 单设备撤销验证。
- [ ] 全部云端数据与账号删除验证。
- [ ] 完成 Windows + Android 双端真实数据 smoke。
- [ ] 验证 service DB 没有 schema/write path 变化。
- [ ] 运行完整 harness/build/test/Qt 日志扫描。
- [ ] 更新 README、隐私说明和第三方服务说明。
- [ ] 发布前安全检查、备份恢复演练和限流验证。
- [ ] PR 合并到 `dev` 并清理分支。

## 当前记录

### 2026-07-24 — 设计阶段

**完成**

- 确认首发地区为中国大陆。
- 确认首版应用类别。
- 确认采用 TimeArc Sync API + CloudBase Auth + CloudBase MySQL。
- 完成应用映射、数据库、同步协议和交付流程设计草案。
- 完成 E0 交付规则的逐文件、逐测试实施计划。

**未完成**

- 尚未修改 harness 交付规则。
- 尚未创建 CloudBase 环境或编写功能代码。

**验证证据**

- 已核对 TimeArc 的双数据库与 service DB 单写者约束。
- 已核对 CloudBase Auth、MySQL、云托管和 HTTP 服务能力。

**下一步**

- 用户选择执行方式。
- 按 E0 计划实施 Rule 08 补强。

**风险**

- 部分游戏和客户端 alias 必须在真实设备上验证。
- Android 首版只能统一比较前台使用时长，不能准确覆盖后台听歌。
- 生产自定义域名需要备案和国内 SMTP 配置。

### 2026-07-24 — E0 Harness 交付规则

**完成**

- 已补强 Rule 08、AGENTS 规则路由、冻结哈希和静态验证。
- 已在编码前清单加入活跃进度表门禁。
- 已在提交前清单加入五段式状态记录门禁。
- 已创建 E0 中文完成报告和 [draft PR #68](https://github.com/jerryzhou945/TimeArc/pull/68)。

**未完成**

- PR 审查、合并到 `dev` 和本地/远端分支清理仍未完成。

**验证证据**

- Task 1：`tests/harness_git_workflow_static_test.py` 通过。
- Task 1：`.harness/tools/harness_check.py` 通过。
- Task 2：清单门禁扩展后的 `tests/harness_git_workflow_static_test.py` 通过。
- Task 3：workflow 静态测试、完整 harness 审计和 `git diff --check` 通过。

**下一步**

- 审查并合并 PR #68，确认 `dev` 包含 merge 后清理本地/远端分支。

**风险**

- GitHub 分支保护仍是外部仓库设置；规则不能代替平台级强制检查。
