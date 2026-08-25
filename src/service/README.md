# TimeArc Native Collector

`src/service/` 是 TimeArc 的原生后台采集器。它与 Qt GUI 分进程运行，是使用历史的
**唯一写入者**；GUI 通过 C++ service 只读同一份 SQLite。

```text
platform APIs -> native collector -> timearc_service.db -> Qt/C++ read services -> QML
```

## 平台实现

| 平台 | 目录 | 当前能力 |
| --- | --- | --- |
| Windows | `windows/` (C) | 前台、idle、WASAPI/GSMTC 媒体、语音、Agent、游戏、登录自启 |
| macOS | `macos/` (Swift) | 前台、idle、媒体 assertion、配置、单实例、launchd lifecycle；待 Mac 发布验证 |
| Linux | `linux/` | 尚未实现 |
| 共享 | `shared/` | SQLite、路径、协议与无 Qt 的跨平台契约 |

硬边界：本目录不得依赖 Qt；平台 SDK 不得泄漏进 `shared/*.h`。

## 计时模型

采集器以短周期采样形成闭区间，应用身份或活动状态变化时关闭上一段。统计层按区间并集
聚合，因此前台与媒体同时命中不会重复计时。

| 信号 | 使用方式 |
| --- | --- |
| frontmost | 普通应用的主信号；超过 idle 阈值停止 |
| media | 系统状态 `Playing` 优先；无法取得时才回退音量活动 |
| voice | 仅白名单语音应用，Active 且未静音；退出频道停止 |
| agent | 前台 Codex + 相关工作进程 CPU/I/O 变化，短租约防止采样抖动 |
| game | 已识别主进程前台时可跨过键鼠 idle，适配手柄/过场/加载 |
| process exists | 永远不足以单独计时 |

应用、媒体和站点身份在写入前标准化；自定义显示名称属于 UI/设置层，不修改稳定 `app_id`。

## 配置

默认文件：

| 平台 | 路径 |
| --- | --- |
| Windows | `%APPDATA%\TimeArc\config\service_config.json` |
| macOS | `~/Library/Application Support/TimeArc/config/service_config.json` |
| Linux 规划 | `${XDG_CONFIG_HOME:-~/.config}/TimeArc/config/service_config.json` |

核心结构：

```json
{
  "schema_version": 1,
  "tracking": {
    "enabled": true,
    "sampling": {
      "poll_period_sec": 1,
      "min_session_sec": 1,
      "max_session_sec": 300
    },
    "frontmost": {
      "enabled": true,
      "idle_threshold_sec": 60,
      "video_overrides_idle": true
    },
    "media": { "enabled": true }
  },
  "database": { "dir": null }
}
```

Windows 当前发布路径读取总开关与 idle，并实现默认策略；高级 sampling/frontmost/media
叶子在公开 UI 暴露前仍需完全接线。macOS 已有 v1 reader，但必须在 Mac 实机复核路径与权限。

## CLI

### Windows

```text
time-arc-service.exe --install
time-arc-service.exe --uninstall
time-arc-service.exe --start
time-arc-service.exe --stop
time-arc-service.exe --status [--json]
time-arc-service.exe --run-service
```

GUI 正常启动会确保 collector 运行。首次成功启动的当前用户登录自启由 GUI 设置层管理；
用户关闭后通过持久化 opt-out 保持关闭。

### macOS

Swift helper 提供 run、enable/disable、start/stop/restart、status 与 doctor 语义，
并通过内嵌 LaunchAgent 工作。最终命令和 bundle 布局必须以 Mac 构建产物验证。

## 数据库契约

默认数据库：

| 平台 | 路径 |
| --- | --- |
| Windows | `%APPDATA%\TimeArc\service\timearc_service.db` |
| macOS | `~/Library/Application Support/TimeArc/service/timearc_service.db` |
| Linux 规划 | `${XDG_DATA_HOME:-~/.local/share}/TimeArc/service/timearc_service.db` |

主要表：

- `apps`：稳定应用身份、展示名称、图标/可执行路径。
- `app_sessions`：前台应用区间。
- `media_sessions`：媒体/音频区间和归因。
- schema 版本与迁移由 shared storage 管理。

`duration_sec` 由 `end_unix_sec - start_unix_sec` 得出。不要由 GUI 直接插入或修改历史，
也不要恢复已退役的 JSONL 历史作为第二数据源。

## 开发与验证

构建必须从仓库根目录经过 harness：

```powershell
python .harness/tools/preflight.py --track C
python .harness/tools/build.py --track C
ctest --test-dir build --output-on-failure
python .harness/tools/harness_check.py
```

新增或修改计时策略时先补失败测试，至少覆盖“开始、持续、暂停/退出、普通后台不误记、
多个信号不重复累计”。Windows 相关测试集中在：

- `tests/windows_foreground_state_test.c`
- `tests/windows_audio_title_policy_test.c`
- `tests/windows_service_config_test.c`

发布/平台状态见 [根 README](../../README.md)，适配文档见
[docs/adapter-system.md](../../docs/adapter-system.md)。
