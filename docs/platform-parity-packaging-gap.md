# TimeArc Windows/macOS 包装前差异对比

更新日期：2026-06-19

## 结论

TimeArc 桌面 UI 使用同一套 Qt/QML 页面，Windows 和 macOS 的界面目标基本一致。当前差距主要在后端采集服务、系统权限、服务生命周期、自动启动和打包发布链路。

macOS helper 目前已经推进到“配置读取 + 单实例 + foreground + media MVP + LaunchAgent lifecycle + UI auto-start path”的阶段。它仍然不能直接称为 macOS beta：核心原因是 Swift 编译、Accessibility 权限、IOPM media assertion、LaunchAgent 行为和打包布局都还没有在 Mac 实机上完成 smoke。

## 当前差异快照

| 模块 | Windows | macOS | 状态 |
| --- | --- | --- | --- |
| UI 页面 | 共享 Qt/QML，当前主力验证平台 | 共享 Qt/QML | 基本一致 |
| UI 自动启动服务 | `src/main.cpp` 启动 `time-arc-service.exe` | 已补 macOS helper 路径探测和 detached 启动 | 已完成代码，待 Mac 验证 |
| 前台应用采集 | 1 秒轮询、idle 截断、session flush | Swift helper 已写同一套存储 | 已完成代码，待 Mac 验证 |
| 存储写入 | 写 SQLite、JSONL、`usage_current.json` | 通过 shared C bridge 写同一套磁盘契约 | 已完成代码，待 Mac 验证 |
| 配置读取 | 读取 `idle_threshold_ms`、`track_enabled`、`db_path` | 已读 `idle_threshold_ms`、`track_enabled`；`db_path` 仍需 Mac 实机确认 | 部分完成 |
| 音频/媒体采集 | WASAPI audio session | 已用 IOPM media assertion 写 `source=audio` session MVP | 已完成代码，待 Mac 验证 |
| 单实例 | Windows named mutex | 已加 usage 目录非阻塞文件锁 | 已完成代码，待 Mac 验证 |
| 服务生命周期 | `--install/--uninstall/--start/--stop/--status` | 已补 LaunchAgent verbs | 已完成代码，待 Mac 验证 |
| 权限 | 主要依赖用户会话 API | 需要 Accessibility；后续可能需要自动化/媒体相关提示 | 未完成 |
| 打包 | 外置 GUI RCC 已接入，仍需 clean-machine QA | helper 已嵌入 `Contents/MacOS`；待 Qt deploy、签名、公证、权限引导、DMG | 部分完成 |

## 已同步到 macOS 的部分

- [x] foreground session loop：app id 或 window title 变化时关闭上一段并写入 shared storage。
- [x] live snapshot：非 idle 时写 `usage_current.json`，idle/退出/无 app id 时清理。
- [x] service config：读取 `usage_config.json` 的 `idle_threshold_ms` 和 `track_enabled`。
- [x] single-instance：在 usage 目录下创建 `time-arc-service.lock`，避免多个 helper 同时写库。
- [x] media session：使用 `AppEnv.getMediaType()` 写 `source=audio` session，包含 3 秒静音 grace 和 15 秒长段切分。
- [x] graceful shutdown：收到 `SIGTERM` / `SIGINT` 时 flush foreground/media session。
- [x] LaunchAgent lifecycle：支持 `--install`、`--uninstall`、`--start`、`--stop`、`--status`。
- [x] UI auto-start：`src/main.cpp::startUsageService()` 已支持 macOS helper 路径探测和 detached 启动。

## 仍需追平的 macOS 工作

1. **Mac 实机编译与 smoke**
   - 检查 Swift helper 是否在 Apple toolchain 下编译通过。
   - 验证 foreground/media session 是否进入 SQLite、JSONL、current 三条路径。
   - 验证 `--install` / `--start` / `--stop` / `--status` 的 LaunchAgent 行为。

2. **权限引导**
   - 检查 Accessibility 未授权时窗口标题、frontmost app 和 fallback 行为。
   - 给 UI 增加清晰的权限状态或引导入口，避免用户误以为采集坏了。

3. **配置完全对齐**
   - `idle_threshold_ms` 和 `track_enabled` 已接线。
   - `db_path` 迁移配置仍需在 Mac 上验证 helper 与 UI 是否读写同一位置。

4. **包装发布链路**
   - [x] UI/helper 同置 `Contents/MacOS`，背景/站点图标/月度回顾三个 RCC 置于 `Contents/Resources/assets`。
   - [ ] 完成 Qt deploy、codesign、notarization、DMG 和 clean-machine 回归。

## 追平时间估算

| 目标 | 预计时间 | 说明 |
| --- | --- | --- |
| macOS 后端 MVP 实机可用 | 1-3 天 | 主要剩 Swift 编译、权限、LaunchAgent、foreground/media 写库 smoke |
| macOS 可用 beta | 1-2 周 | 权限 UX、基础打包、长时间采集 QA、clean-machine 验证 |
| macOS 发布级追平 | 3-5 周 | 签名、公证、卸载/升级、异常恢复和发行流程 |

如果两个人并行，macOS 可用 beta 可压缩到约 1 周：一人负责 service/storage/media 实机闭环，另一人负责权限、打包和回归。发布级追平仍建议保留 3-5 周，因为签名、公证、权限边界和 clean-machine 安装卸载通常需要多轮实机验证。

## 推荐顺序

1. 在 Mac 上跑通 helper 编译和 30-60 分钟采集 smoke。
2. 验证 LaunchAgent verbs 和 UI auto-start 是否能稳定启动同一个 helper。
3. 补 Accessibility 权限提示，保证用户能理解为什么没有采集。
4. 进入 `.app` / DMG / 签名 / 公证和 clean-machine 包装回归。
