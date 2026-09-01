# Windows 音频休眠误计修复

## 目标

避免 Windows Codex 在电脑休眠、采样线程长时间停顿或系统时钟回拨时，把未观测时间计入媒体播放；其他媒体应用保持原行为。

## 范围

- Windows 音频追踪状态新增“最后一次轮询时间”。
- 仅官方 `OpenAI.Codex_` 包路径在相邻轮询超过 5 秒或时钟回拨时，于最后一次真实采样点结束旧媒体会话。
- Codex 服务退出 flush 使用相同边界；网易云、浏览器视频等非 Codex 媒体不应用该规则。
- SQLite 表结构、跨平台数据契约、QML 和 macOS/Linux 实现均未改变。

## 数据修正

本机问题记录与 Windows 休眠事件完全重合：Codex `00:00:16–08:58:33`，共 32,297 秒。停止 UI 和服务后，先通过 SQLite backup API 创建完整性为 `ok` 的备份，再仅删除唯一匹配的 rowid 5671。备份位于 `%APPDATA%\TimeArc\service\timearc_service.pre-audio-suspend-fix-20260831-1624.db`。

## 验证

- Codex 的轮询/flush 回归及“非 Codex 保持原行为”范围测试通过；范围测试在全局补丁上先按预期失败。
- 项目构建包装器通过；CTest 6/6 通过。
- Windows 音频静态检查、平台一致性检查与服务运行烟测通过。
- 修正后数据库 `PRAGMA integrity_check` 为 `ok`，异常行剩余 0。
- 新构建的 TimeArc 与 `time-arc-service` 均从项目 `build` 目录运行。

## 已知边界与回滚

当前 Windows 采样周期固定为 1 秒，因此 5 秒阈值为保守空洞界限。未来若开放可配置采样周期，应改为由周期推导。代码回滚时还原 `audio_tracker.{c,h}` 与对应测试；本机数据若需恢复，可在停止两个进程后使用上述备份。
