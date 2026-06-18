# TimeArc Windows/macOS 包装前差异对比

更新日期：2026-06-18

## 结论

TimeArc 的桌面 UI 是 Qt/QML，同一套页面在 Windows 和 macOS 上基本一致。真正的差距不在界面，而在后台采集服务、系统权限、服务生命周期和安装包发布链路。

当前建议是：Windows 先进入可用 alpha/beta 包装；macOS 可以同步推进，但应等后台服务能稳定写入同一套磁盘数据后再称为功能追平版本。

## 当前差异快照

| 模块 | Windows | macOS | 差距 |
| --- | --- | --- | --- |
| UI 页面 | 共享 Qt/QML，当前主力验证平台 | 共享 Qt/QML | 低 |
| UI 自动启动服务 | `src/main.cpp` 会启动 `time-arc-service.exe` | 还未从 UI 自动启动 helper | 中 |
| 前台应用采集 | 已有完整轮询、idle 截断、session flush | 已同步最小 Swift 前台采集循环，仍需实机验证 | 中 |
| 存储写入 | 写 SQLite、JSONL、`usage_current.json` | 已接入 shared C bridge 写同一磁盘契约 | 中 |
| 音频/媒体采集 | WASAPI 音频 session 已接入 | 只有 IOPM media assertion 判断，还未写 media session | 高 |
| 单实例 | Windows named mutex | 未实现 | 中 |
| 服务生命周期 | `--install/--uninstall/--start/--stop/--status` | 未实现 LaunchAgent 方案 | 高 |
| 权限 | 常规用户会话 API 为主 | 需要 Accessibility，后续可能需要自动化/媒体相关提示 | 中 |
| 打包 | 更接近可包装，但仍缺一键脚本和 clean-machine QA | 需要 `.app`、helper 放置、签名、公证、权限引导 | 高 |

## 本轮已同步到 macOS 的部分

- `TimeArcService.swift` 从空 RunLoop 改为最小前台采集循环。
- 启动时调用 `ta_storage_init()`，退出路径调用 `ta_clear_current_usage()` 和 `ta_storage_shutdown()`。
- 每秒读取 `AppEnv` 的前台 app、窗口标题、bundle 路径和 idle 秒数。
- app 或窗口标题变化时关闭上一段 foreground session，并写入 shared storage。
- 非 idle 时持续写 `usage_current.json` 对应的当前 session 快照。

这一步让 macOS 从“只有采样工具函数”前进到“有最小 foreground 写入闭环”。但它还不是发布级追平：缺少单实例、LaunchAgent、媒体 session、配置读取、权限恢复和 macOS 实机 smoke。

## 仍需追平的 macOS 工作

1. 实机验证前台采集。
   检查 Accessibility 权限未授权时的行为、窗口标题为空时的 session 分割，以及 bundle path 是否能被 UI 图标 provider 正确显示。

2. 补服务生命周期。
   增加 LaunchAgent 安装/启动/停止/状态查询，并避免多个 helper 同时写同一套文件。

3. 补配置读取。
   对齐 Windows 的启动配置读取，支持 `idle_threshold_ms` 和 `track_enabled`。

4. 补媒体采集。
   将 `AppEnv.getMediaType()` 的判断接到 media session 写入逻辑，行为上对齐 Windows audio tracker。

5. 补 UI 启动 helper。
   `src/main.cpp::startUsageService()` 当前只处理 Windows，macOS 需要定位 app bundle 内 helper 并处理失败提示。

6. 补包装发布链路。
   需要 `.app` bundle 布局、Qt deploy、helper 嵌入、codesign、notarization、权限引导和 clean-machine 回归。

## 包装节奏建议

| 目标 | 预计时间 | 说明 |
| --- | --- | --- |
| Windows 可用 beta 包 | 3-5 天 | 一键部署脚本、带服务 helper、许可证/NOTICE、干净机器验证 |
| macOS 前台采集 MVP | 1-2 周 | 本轮已有最小 loop，还需实机权限、配置、单实例和 UI 启动 |
| macOS 可用 beta | 3-5 周 | 增加 LaunchAgent、媒体采集、权限 UX、打包脚本 |
| macOS 发布级追平 | 5-7 周 | 签名、公证、卸载/升级、clean-machine 和长时间采集 QA |

如果两个人并行，macOS 可用 beta 约可压缩到 2-3 周：一人负责 Swift service/storage/media，另一人负责 LaunchAgent、权限、包装和回归。发布级追平仍建议预留 4-6 周，因为签名、公证和权限边界通常需要多轮实机安装卸载验证。

## 推荐顺序

1. 先把 Windows 包装跑通，作为可交付基线。
2. macOS 先验证 foreground 写入闭环，再做漂亮 DMG。
3. macOS 补 LaunchAgent 和权限引导后再开放 beta。
4. 两端都通过 clean-machine smoke 后，再进入正式发布包装。
