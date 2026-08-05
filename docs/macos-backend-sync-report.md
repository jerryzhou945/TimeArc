# macOS 后端同步报告

日期：2026-06-19

> **⚠️ 历史报告，已被后续重写取代（复核于 2026-08-05）。** macOS helper 之后被重构为
> `Tracking/` 探针 + 状态机架构（`TrackingCoordinator` / `FrontmostStateMachine` /
> `MediaStateMachine`）。本文记录的以下能力**在当前代码里并不存在**：读取
> `usage_config.json`（`TimeArcService.swift:17-21` 把 `idleThreshold: 60` /
> `enableFrontmost` / `enableMedia` **硬编码**）、`time-arc-service.lock` 文件锁、
> `usage_current.json` live snapshot（`CHARTER` v0.9 已退役）、`source=audio` 写法
> （现为 `media_sessions` 表）。当前事实见 `.harness/rules/02-platform-boundaries.md` §3。
> 配置格式本身也已重新设计：见 [`src/service/README.md`](../src/service/README.md)（`service_config.json` v1，
> `CHARTER` v0.13，设计已批、尚未实装）。

## 目标

按照 `docs/platform-parity-packaging-gap.md` 中的差异，把 macOS 后台 helper 从“能写最小 foreground session”推进到接近 Windows 后端契约的 MVP：配置读取、单实例、防止 stale current、媒体 session 写入和优雅退出 flush。

## 本轮范围

- `src/service/macos/TimeArcService.swift`
  - 启动时创建并使用 `~/.timearc/usage`。
  - 读取 `usage_config.json` 的 `idle_threshold_ms` 和 `track_enabled`。
  - `track_enabled=false` 时清理 current snapshot 并退出。
  - 增加 `time-arc-service.lock` 非阻塞文件锁，避免多 helper 同时写库。
  - 继续使用 shared C bridge 写 foreground session，不改 schema。
  - 使用 `AppEnv.getMediaType()` 将 media assertion 写为 `source=audio` session。
  - 媒体 session 使用 3 秒静音 grace、15 秒长段切分。
  - 收到 `SIGTERM` / `SIGINT` 时 flush 当前 foreground/media session 并 shutdown storage。
  - 取不到 frontmost app id 时关闭 live snapshot，避免旧 current 残留。

- `.harness/rules/02-platform-boundaries.md`
  - 更新 macOS 当前状态：foreground/config/media MVP 已落地，LaunchAgent 和包装仍待做。

- `docs/platform-parity-packaging-gap.md`
  - 改为中文对比当前 Windows/macOS 差异，并更新追平节奏估算。

- `docs/implementation-backlog.md`、`.harness/state/open-issues.md`
  - 将 C1 从“未接线”调整为“后端 MVP 已补，剩余实机/生命周期/包装”。

## 验证

- 已做结构检查：确认 macOS helper 中存在配置读取、单实例锁、媒体写入入口。
- 当前机器是 Windows，无法在本轮验证 Swift/macOS 编译、Accessibility 权限弹窗、IOPM media assertion 实机行为。
- Windows 侧构建与 harness 检查结果见本分支最终提交说明。

## 仍然缺口

1. 在 Mac 主机上跑 Swift helper 编译和 30-60 分钟采集 smoke。
2. 补 LaunchAgent 的安装、启动、停止、状态查询。
3. 补 UI 启动 macOS helper 的 bundle 定位和失败提示。
4. 做 Accessibility 权限引导。
5. 补 `.app` / DMG / codesign / notarization / clean-machine QA。

## 回滚说明

如果本轮 macOS helper 在实机上出现阻塞或写入异常，回滚本分支对应提交即可恢复到上一版 macOS foreground-only helper。共享 schema、C bridge、Windows 服务和 UI 数据读取没有被修改，不需要数据迁移回滚。
