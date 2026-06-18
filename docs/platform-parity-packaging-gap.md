# TimeArc Windows/macOS 包装前差异对比

更新日期：2026-06-19

## 结论

TimeArc 桌面 UI 使用同一套 Qt/QML 页面，Windows 和 macOS 的界面目标基本一致。当前差距主要在后端采集服务、系统权限、服务生命周期、自动启动和打包发布链路。

本轮已把 macOS helper 从“最小 foreground loop”推进到“配置读取 + 单实例 + foreground + media MVP”。它仍然不能直接称为 macOS beta：还缺 LaunchAgent 生命周期、UI 自动启动、权限引导、签名/公证和 Mac 实机长时间 smoke。

## 当前差异快照

| 模块 | Windows | macOS | 差距 |
| --- | --- | --- | --- |
| UI 页面 | 共享 Qt/QML，当前主力验证平台 | 共享 Qt/QML | 低 |
| UI 自动启动服务 | `src/main.cpp` 会启动 `time-arc-service.exe` | 仍未从 UI 自动启动 bundle 内 helper | 中 |
| 前台应用采集 | 1 秒轮询、idle 截断、session flush | Swift helper 已写同一套存储，仍需 Mac 实机验证 | 中 |
| 存储写入 | 写 SQLite、JSONL、`usage_current.json` | 通过 shared C bridge 写同一套磁盘契约 | 低 |
| 配置读取 | 读取 `usage_config.json` 的 `idle_threshold_ms`、`track_enabled`、`db_path` | 本轮已读取 `idle_threshold_ms`、`track_enabled`；`db_path` 仍走 shared storage 默认路径 | 中 |
| 音频/媒体采集 | WASAPI audio session，3 秒静音 grace，15 秒长段切分 | 本轮已用 IOPM media assertion 写 `source=audio` 的 media session MVP | 中 |
| 单实例 | Windows named mutex | 本轮已加 usage 目录下的非阻塞文件锁 | 低 |
| 服务生命周期 | `--install/--uninstall/--start/--stop/--status` | 仍缺 LaunchAgent 安装/启动/停止/状态查询 | 高 |
| 权限 | 主要依赖用户会话 API | 需要 Accessibility；后续可能需要自动化/媒体相关提示 | 中 |
| 打包 | 接近可打包，仍需一键脚本和 clean-machine QA | 需要 `.app`、helper 嵌入、签名、公证、权限引导、DMG | 高 |

## 本轮同步到 macOS 的部分

- `TimeArcService.swift` 启动时创建 `~/.timearc/usage` 并读取 `usage_config.json`。
- 支持 `idle_threshold_ms`，缺失或非法值回退 60 秒默认 idle 阈值。
- 支持 `track_enabled=false`，启动后清理 current snapshot 并退出，不再继续采集。
- 在 usage 目录下创建 `time-arc-service.lock`，避免多个 helper 同时写 SQLite/JSONL/current。
- 保留 foreground session 逻辑：app id 或 window title 变化时关闭上一段并写入 shared storage。
- 使用 `AppEnv.getMediaType()` 判断 audio/video assertion，写 `source=audio` 的 media session。
- 媒体 session 对齐 Windows 的基本节奏：3 秒静音 grace，15 秒长段切分。
- 收到 `SIGTERM`/`SIGINT` 时关闭当前 foreground/media session，清理 live snapshot，再 shutdown storage。
- 当前环境是 Windows，macOS 编译和权限实机 smoke 仍需在 Mac 主机完成。

## 仍需追平的 macOS 工作

1. **Mac 实机编译与 smoke**
   - 检查 Swift helper 是否在 Apple toolchain 下编译通过。
   - 验证 Accessibility 未授权、窗口标题为空、bundle path 图标读取失败时的行为。
   - 验证 foreground/media session 是否进入 SQLite、JSONL、current 三条路径。

2. **服务生命周期**
   - 增加 LaunchAgent 安装、启动、停止、状态查询。
   - 设计 UI 设置页与 LaunchAgent 的同步语义。
   - 保证 stop 时能优雅触发当前 session flush。

3. **UI 启动 helper**
   - `src/main.cpp::startUsageService()` 当前只处理 Windows。
   - macOS 需要定位 `.app` bundle 内 helper，并在失败时给出权限/安装提示。

4. **配置对齐**
   - 本轮只在 Swift 侧读取 `idle_threshold_ms` 和 `track_enabled`。
   - `db_path` 迁移配置目前仍由 shared storage 默认路径承担；要完全追平 Windows，需要把 macOS helper 和 UI 的数据库路径切换行为一起在 Mac 上验证。

5. **权限与包装**
   - 增加 Accessibility 权限引导。
   - 完成 `.app` 布局、Qt deploy、helper 嵌入、codesign、notarization、DMG 和 clean-machine 回归。

## 追平时间估算

| 目标 | 预计时间 | 说明 |
| --- | --- | --- |
| macOS 后端 MVP 实机可用 | 2-4 天 | 编译 Swift helper、验证权限、foreground/media 写库、修正实机边界 |
| macOS 可用 beta | 2-3 周 | LaunchAgent、UI 启动、权限 UX、基础打包、长时间采集 QA |
| macOS 发布级追平 | 4-6 周 | 签名、公证、卸载/升级、clean-machine、异常恢复和发行流程 |

如果两个人并行，macOS 可用 beta 可压缩到约 1-2 周：一人负责 service/storage/media 实机闭环，另一人负责 LaunchAgent、权限、打包和回归。发布级追平仍建议保留 3-5 周，因为签名、公证、权限边界和 clean-machine 安装卸载通常需要多轮实机验证。

## 推荐顺序

1. 先在 Mac 上跑通本轮 helper 编译和 30-60 分钟采集 smoke。
2. 再补 LaunchAgent 生命周期，让 helper 不依赖手动启动。
3. 接 UI 自动启动和权限提示，保证用户能理解为什么没有采集。
4. 最后进入 `.app`/DMG/签名/公证和 clean-machine 包装回归。
