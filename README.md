<div align="center">
  <img src="resources/bundle/android/timearc-launcher-master.png" width="116" alt="TimeArc icon">

# TimeArc

**把分散在应用、网页和设备里的时间，整理成一条只属于你的本地时间线。**

Private by default · Local-first · Windows / macOS / Android

[功能概览](#功能概览) · [下载安装](#下载安装) · [计时规则](#计时规则) · [开发构建](#开发构建) · [文档](#文档)
</div>

> [!IMPORTANT]
> TimeArc `0.1` 目前是测试版。Windows 测试包尚未签名，请只从本仓库发布页下载；
> macOS 仍需实机签名、公证与权限回归，Android/HarmonyOS 仍需更多机型测试。

## TimeArc 是什么

TimeArc 在本机采集前台应用、媒体播放和少数明确的后台活动，把原始记录整理为应用时钟、
日/周/月/年趋势、分类分布和完整应用时长。它不做效率打分，也不会把原始窗口标题上传到云端。

| 你能看到 | TimeArc 的做法 |
| --- | --- |
| 今天的时间落在哪里 | 用应用时钟呈现真实时间段，悬停或点击聚焦某个应用 |
| 周、月、年的变化 | 时间趋势与分类分布并排，减少重复卡片和无效留白 |
| 每个软件到底用了多久 | “所有应用”展示本期时长、累计时长和最近记录，不只显示 Top App |
| 哪些活动值得后台继续计时 | 只有媒体、语音频道和正在执行任务的 Agent 使用专用策略 |
| 数据保存在哪里 | 记录写入本机 SQLite；UI 只读，分享默认匿名化 |

## 功能概览

- **应用时钟**：按真实发生时间绘制应用弧段；繁忙的一天也能聚焦具体应用。
- **完整统计**：日、周、月、年统一信息架构，包含总时长、趋势、分类和全部应用。
- **媒体识别**：Windows 浏览器视频优先读取系统媒体状态；B 站等站点可归因到站点身份。
- **语音频道**：Discord、KOOK、Oopz 在有效音频会话存在时记录，退出频道后停止。
- **Agent 任务**：Codex 前台执行任务时，可用相关工作进程的 CPU/I/O 活动跨越键鼠闲置。
- **游戏计时**：原神、崩坏：星穹铁道、绝区零、鸣潮等主进程在前台时持续记录，
  不因手柄操作、过场或加载期间的键鼠闲置被截断。
- **应用身份**：稳定显示名称、图标与站点身份；设置页可自定义显示名称，不修改底层 ID。
- **本地与可撤销**：首次成功启动可启用当前用户登录自启，用户关闭后保持关闭。

## 平台状态

| 平台 | 可用程度 | 当前说明 |
| --- | --- | --- |
| Windows 10/11 | **主要测试平台** | 前台、idle、媒体、语音、Agent、游戏策略及登录自启已接通；公开包未签名 |
| macOS | **代码已同步，待发布验证** | 共享 Qt/QML UI 与原生采集服务已实现；仍需 Mac 实机权限、签名、公证、DMG 与长时间回归 |
| Android | **功能预览** | Usage Access、实时同步、应用图标、统计与分享已实现；不同 ROM 仍需验证 |
| HarmonyOS + 卓易通 | **兼容性测试** | 已在部分华为设备运行，但并非原生 HarmonyOS 应用，不保证所有系统版本兼容 |
| Linux | **尚未开始** | X11/Wayland 与 PipeWire 采集仍在 backlog |

## 下载安装

### Windows 测试包

发布产物包含：

| 文件 | 适合谁 | 使用方法 |
| --- | --- | --- |
| `TimeArc-0.1-beta-<date>-win64-setup.exe` | 普通测试者 | 运行安装程序，按提示安装 |
| `TimeArc-0.1-beta-<date>-win64.zip` | 便携测试/排障 | 解压后运行 `TimeArc.exe`，不要只复制单个 exe |

安装后首次启动会尝试启用**当前 Windows 用户**的登录自启；在设置中关闭后不会被下次启动重新打开。
未签名测试包可能触发 SmartScreen，请先核对发布页提供的 SHA-256。

### Android / HarmonyOS

安装 ARM64 APK 后，在系统设置中授予“使用情况访问权限”，重新进入 TimeArc 会立即同步最近记录。
HarmonyOS 通过卓易通运行属于兼容层方案；详细权限、ABI 和排障见 [Android README](android/README.md)。

### macOS

当前仓库提供构建脚本，但公开发布前仍需要在 Mac 上完成 Accessibility 权限引导、签名、公证和
clean-machine 验证。请勿把未经验证的本地 `.app` 当作正式发行版。

## 计时规则

TimeArc 计算的是**有效活动区间的并集**，同一时段同时满足“前台”和“媒体”不会重复累计。

| 场景 | 何时继续记录 | 何时停止 |
| --- | --- | --- |
| 普通桌面应用 / 普通网页 | 应用处于前台，且未超过 idle 阈值 | 切走应用或超过 idle 阈值 |
| 浏览器视频（含 B 站） | Windows 媒体状态为 `Playing`；媒体状态不可用时才回退到音量活动 | 暂停、关闭或会话消失 |
| 网易云音乐等播放器 | 有效媒体/音频会话处于播放状态 | 暂停或会话结束 |
| Discord / KOOK / Oopz | 专用音频会话处于 Active 且未静音，不要求有人讲话 | 退出频道、静音或会话变为 Inactive/消失 |
| Codex | Codex 在前台，且官方相关工作进程 CPU/I/O 有实质变化 | 任务结束后，经过短租约并达到 idle 条件 |
| 二次元游戏 | 已识别的游戏主进程处于前台 | 切出游戏或主进程退出 |
| 其他后台进程 | **不记录**；仅凭进程存在不能证明正在使用 | — |

更完整的采集边界、配置与数据库契约见 [采集服务 README](src/service/README.md)。

## 隐私与数据

- 原始记录默认保存在本机，不要求账号或云服务。
- GUI 不直接写采集历史；原生 service 是唯一写入者，双方通过 SQLite 契约协作。
- 分享卡默认移除原始标题、联系人、网址和包名等敏感信息。
- 测试反馈不要上传 `timearc_service.db`；它可能包含应用与窗口标题。

常用数据目录：

| 平台 | 目录 |
| --- | --- |
| Windows | `%APPDATA%\TimeArc\service\timearc_service.db` |
| macOS | `~/Library/Application Support/TimeArc/service/timearc_service.db` |
| Linux 规划 | `${XDG_DATA_HOME:-~/.local/share}/TimeArc/service/timearc_service.db` |

## 架构

```mermaid
flowchart LR
    OS[Platform APIs] --> Collector[Native collector]
    Collector --> DB[(timearc_service.db)]
    DB --> Services[C++ read services]
    Services --> UI[Qt 6 / QML UI]
    UI --> Cards[Clock · trends · reports · sharing]
```

- `src/service/`：Windows C / macOS Swift / Linux 占位采集器与共享磁盘契约。
- `src/services/`：Qt/C++ 只读统计、设置、应用身份和移动端桥接。
- `qml/desktop/`、`qml/mobile/`：共享产品语言下的桌面与移动界面。
- `android/`：UsageStats、WorkManager、图标与 Android 生命周期适配。
- `resources/`：背景、站点图标、月报、许可证与发行资源。

## 开发构建

### Windows

要求：Qt `6.11.0` MinGW 64-bit、CMake、Python 3、Node.js（统计 JS 测试）。

```powershell
python .harness/tools/preflight.py --track B
cmake -S . -B build -G "MinGW Makefiles" `
  -DCMAKE_PREFIX_PATH="D:/TimeArc/QT/6.11.0/mingw_64"
python .harness/tools/build.py --track B
ctest --test-dir build --output-on-failure
```

开发运行：

```powershell
.\run.cmd
```

发行打包：

```powershell
pwsh tools/package-release.ps1 -Version 0.1-beta-20260825
pwsh tools/package-installer.ps1 -Version 0.1-beta-20260825
```

第一条命令会动态验证 Qt DLL 链接、收集 GUI/service、RCC、Qt/MinGW 运行库和许可证，
并生成便携 ZIP；第二条命令用 7-Zip 官方 LZMA SDK 的 SFX 模块把同一份已验证 ZIP
包成当前用户安装器。安装器脚本默认从被 Git 忽略的 `.local-toolchains/7zip-26.02/`
读取官方 `7za.exe` 与 `7zS2.sfx`，也可通过参数传入其他本地路径。

### macOS

```bash
./tools/build-macos.sh
```

脚本负责构建 `.app` 的基础布局；签名、公证、权限和 clean-machine QA 仍是发布门槛。

### Android

Android 由 Qt Android 工具链与 `android/` Gradle 包装共同构建。详细结构和设备要求见
[android/README.md](android/README.md)。

## 验证

所有构建必须通过 harness wrapper；提交前必须执行：

```powershell
python .harness/tools/build.py --track B
ctest --test-dir build --output-on-failure
node tests/stats_view_model_test.js
python .harness/tools/harness_check.py
```

运行 Qt/QML 后还需执行 `python .harness/tools/scan_qt_log.py`。详细开发规则见
[AGENTS.md](AGENTS.md) 与 [.harness/README.md](.harness/README.md)。

## 文档

| 入口 | 内容 |
| --- | --- |
| [docs/README.md](docs/README.md) | 按产品、统计、计时、移动端、发布分类的文档地图 |
| [docs/implementation-backlog.md](docs/implementation-backlog.md) | 当前可执行 backlog |
| [docs/beta-tester-release-kit.md](docs/beta-tester-release-kit.md) | 测试招募、视频脚本与反馈模板 |
| [src/service/README.md](src/service/README.md) | 采集服务、配置、CLI 与数据库契约 |
| [android/README.md](android/README.md) | Android/HarmonyOS 权限、同步、构建与排障 |
| [.harness/README.md](.harness/README.md) | Agent/human 工程质量门禁 |

## 参与贡献

1. 先阅读 [AGENTS.md](AGENTS.md) 和对应平台边界。
2. 一次提交只解决一个可验证的问题，新增计时策略必须先写失败测试。
3. 不改变 SQLite 磁盘契约、不把 Qt 引入原生 service、不提交机器专用启动脚本。
4. PR 中写明实际验证命令、平台、已知限制和隐私影响。

## 路线图

- [x] Windows 前台、idle、媒体、语音、Agent 与游戏计时。
- [x] 日/周/月/年统计重构与全部应用时长。
- [x] Android UsageStats、实时同步、图标和分享预览。
- [ ] Windows 代码签名、安装器/升级路径与 clean-machine QA。
- [ ] macOS 实机权限、签名、公证、DMG 与长期运行验证。
- [ ] Android/HarmonyOS 多 ROM 回归。
- [ ] Linux X11/Wayland + PipeWire 采集。
- [ ] 可选的端到端加密跨设备同步。

## License

TimeArc is licensed under **GPL-3.0-or-later**. See [LICENSE](LICENSE).
Qt is dynamically linked under LGPL/GPL terms. SQLite, Parson and MinGW runtime notices are bundled under
`resources/licenses/` and included in release packages.
