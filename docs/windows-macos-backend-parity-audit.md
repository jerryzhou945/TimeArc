# Windows / macOS 后端差异审计

日期：2026-06-19

## 核心结论

Windows 后端目前是 TimeArc 的完整参考实现：它能编译、能启动、能采集前台应用和音频、能写 SQLite + JSONL + current snapshot，并且有用户会话内的自启动、停止和状态查询。

macOS 后端已经写了大量 Swift 侧采集与生命周期代码：前台应用、窗口标题、idle、媒体 assertion、配置读取、单实例、LaunchAgent verbs、UI 自动启动路径都已经有代码。但它还不能算“后端功能完成”，因为当前 `APPLE` 构建目标没有把真正实现 `ta_storage_init` / `ta_write_usage_record*` 的 storage 源文件编进去。

最重要的判断是：

**macOS 目前是“采集逻辑基本写完，但存储 bridge 尚未在 APPLE target 接通并验证”的状态。它还不能被确认实际写入 SQLite。**

## 状态标记

- `已验证`：当前 Windows 环境能编译或已有本机验证路径。
- `代码已实现 / 待 Mac 验证`：源码已有实现，但必须在 Mac 上编译、运行和看磁盘结果。
- `未接通`：源码结构显示关键链路还没连上。
- `未完成`：还没有实现或只停留在计划。

## 总览对比

| 模块 | Windows 当前状态 | macOS 当前状态 | 结论 |
| --- | --- | --- | --- |
| 服务构建目标 | `WIN32` 编译 C tracker、platform、storage、service | `APPLE` 只编 Swift + `usage_paths.c` + headers | macOS storage 实现未接通 |
| Storage bridge | `usage_storage.c` 实现全部 `ta_*` ABI | Swift 调用 `ta_*`，但 APPLE target 没有实现源 | macOS 目前不能确认可链接 |
| SQLite 写入 | 写 `apps`、`frontmost_sessions`、`media_sessions` | 调用层准备写，但实现层未进 APPLE build | macOS 未确认实际写 SQLite |
| JSONL 写入 | 写 `usage_records.jsonl` | 同上，调用层有，链接层未接通 | macOS 未确认实际写 JSONL |
| current snapshot | 写 `usage_current.json` | Swift 调用 `ta_write_current_usage` / `ta_clear_current_usage` | 调用层已实现，待 storage 接通 |
| 前台应用采集 | `GetForegroundWindow` + exe path + window title | `NSWorkspace` + AX focused window title + bundle id | macOS 代码已实现 / 待权限验证 |
| idle 检测 | `GetLastInputInfo` | `CGEventSource.secondsSinceLastEventType` | macOS 代码已实现 / 待实机验证 |
| 音频/媒体 | WASAPI per-process audio sessions | IOPM assertion，主要针对 frontmost app pid | macOS 是 MVP，不等价于 Windows WASAPI 深度 |
| session 切分 | foreground 按 app/title；audio 按静音和 15s flush | foreground/media 均有 Swift 切分逻辑 | macOS 代码已实现 / 待写库验证 |
| 配置读取 | 读 `idle_threshold_ms`、`track_enabled`、`db_path` | Swift 读 `idle_threshold_ms`、`track_enabled`；`db_path` 未完整验证 | macOS 配置部分完成 |
| 单实例 | Windows named mutex | usage 目录 `time-arc-service.lock` + `flock` | macOS 代码已实现 / 待实机验证 |
| 停止通道 | named event 请求 tracker flush 后退出 | LaunchAgent bootout + lock pid `SIGTERM` | macOS 代码已实现 / 待实机验证 |
| 生命周期 verbs | `--install` / `--uninstall` / `--start` / `--stop` / `--status` | 同名 verbs，基于 LaunchAgent | macOS 代码已实现 / 待实机验证 |
| UI 启动 helper | `src/main.cpp` 启动同目录 `time-arc-service.exe` | 探测同目录、`Contents/Helpers`、install bin、dev 路径 | macOS 代码已实现 / 待包装验证 |
| 权限 UX | 基本不需要单独权限引导 | Accessibility 未授权会影响窗口标题 | macOS 未完成 |
| 打包发布 | Windows 已接近可打包 | `.app` helper 嵌入、签名、公证、DMG 未完成 | macOS 未完成 |

## Windows 后端已经具备什么

### 采集与 session

- `src/service/windows/tracker/usage_tracker.c`
  - 1 秒轮询。
  - 前台应用变化时关闭上一段 foreground session。
  - idle 时关闭 foreground session 并清理 current snapshot。
  - stop event / console handler 触发优雅退出，退出前 flush。

- `src/service/windows/tracker/audio_tracker.c`
  - WASAPI audio session 采样。
  - 同一 exe 去重。
  - 静音 grace 后关闭 audio session。
  - 15 秒长段定期 flush，避免长时间播放只在退出时落盘。

### 存储

- `src/service/windows/storage/usage_storage.c`
  - 实现 `data_bridge.h` 里的 `ta_storage_init`、`ta_write_usage_record`、`ta_write_usage_record_with_source`、`ta_write_current_usage`、`ta_clear_current_usage`。
  - 同时写 JSONL 和 SQLite。
  - SQLite 写入 `apps`、`frontmost_sessions`、`media_sessions`。
  - 读取 `usage_config.json` 的 `db_path`，支持数据库迁移后的路径指针。
  - 读取 `idle_threshold_ms` 和 `track_enabled`。

### 生命周期

- `src/service/windows/service/win_service.c`
  - `--install`：注册 schtasks 登录任务，失败时回退 HKCU Run。
  - `--uninstall`：清理 schtasks 和 Run key。
  - `--start`：无窗口启动 tracker。
  - `--stop`：通过 named event 请求优雅停止。
  - `--status`：检查自启动注册和 named mutex 运行态。

### UI 启动

- `src/main.cpp::startUsageService()`
  - Windows 下从 app 同目录启动 `time-arc-service.exe`。

## macOS 已经写入源码的部分

### 采集原语

- `src/service/macos/AppEnv.swift`
  - `NSWorkspace.shared.frontmostApplication` 获取前台 app。
  - bundle id 作为 `app_id`。
  - Accessibility API 获取 focused window title。
  - `CGEventSource.secondsSinceLastEventType` 获取 idle 秒数。
  - `IOPMCopyAssertionsByProcess` 判断 media playback assertion。

### 主循环

- `src/service/macos/TimeArcService.swift`
  - foreground session 按 app id / window title 切分。
  - idle 时关闭 foreground 和 media session。
  - 无 frontmost app id 时清理 current snapshot。
  - `SIGTERM` / `SIGINT` 请求退出，并 flush 当前 session。
  - `track_enabled=false` 时清理 current 并退出。

### 媒体 session

- Swift 侧已经有 `MediaSession`。
- `AppEnv.getMediaType()` 返回 audio/video/null。
- audio/video assertion 当前统一写 `source=audio`。
- 逻辑上有 3 秒静音 grace 和 15 秒长段 flush。

### 单实例

- 使用 `~/.timearc/usage/time-arc-service.lock`。
- `flock(LOCK_EX | LOCK_NB)` 防重复 helper 同时写盘。
- lock 文件写入当前 pid，供 status/stop 查询。

### 生命周期

- `MacServiceLifecycle`
  - `--install` 写 `~/Library/LaunchAgents/com.timearc.usage-service.plist`。
  - `--uninstall` 请求停止并删除 plist。
  - `--start` 优先 LaunchAgent bootstrap/kickstart，失败时 fallback 直接启动 helper。
  - `--stop` bootout LaunchAgent 并对 lock pid 发送 `SIGTERM`。
  - `--status` 输出 `autostart=on/off` 和 `running=yes/no`。

### UI 启动

- `src/main.cpp::findMacUsageServicePath`
  - 探测 app 同目录。
  - 探测 `../Helpers/time-arc-service`。
  - 探测 install prefix / development build 路径。
  - 找到后 `QProcess::startDetached`。

## macOS 当前没有真正闭环的关键点

### 1. Storage bridge 未进 APPLE target

`src/service/CMakeLists.txt` 当前：

- `WIN32` 会编译 `src/service/windows/storage/usage_storage.c`。
- `APPLE` 不会编译这个文件。
- `APPLE` 只编译 Swift 文件、`usage_paths.c` 和 shared headers。

而 `ta_storage_init`、`ta_write_usage_record`、`ta_write_usage_record_with_source`、`ta_write_current_usage` 的实现目前只在 `usage_storage.c` 里。因此 macOS Swift 虽然调用了 bridge，但 APPLE target 目前大概率会在链接阶段暴露未定义符号。

这就是“macOS 不能确认实际写 SQLite”的原因。

### 2. 即使复用 `usage_storage.c`，路径逻辑也要审查

`usage_storage.c::make_db_path` 现在优先读 `APPDATA` / `LOCALAPPDATA`，这是 Windows 语义。文件里虽然有非 Windows 分隔符分支，但环境变量入口仍偏 Windows。

因此 macOS storage 接通时，不能只是把 `usage_storage.c` 粗暴加入 APPLE sources。需要明确 macOS 默认 DB 路径和 UI `QStandardPaths` 是否一致，或者继续通过 `usage_config.json db_path` 保证同源。

### 3. `db_path` 迁移尚未在 macOS 证明

Windows service 会通过 storage 实现读取 `usage_config.json` 里的 `db_path`。macOS Swift 当前只直接读取 `idle_threshold_ms` 和 `track_enabled`。`db_path` 是否生效取决于后续 macOS storage 实现如何接入。

### 4. 媒体能力不是 Windows WASAPI 等价物

Windows 能枚举正在发声的进程。macOS 当前使用的是 power assertion 判断，且从当前 Swift 代码看主要围绕 frontmost app 的 pid 判断。

这可以作为 media MVP，但不能等价理解为“macOS 已拥有 Windows 同级音频采样”。

### 5. 权限和包装尚未实机验证

- Accessibility 未授权时窗口标题可能为空。
- `launchctl bootstrap/kickstart/bootout` 行为必须在真实 macOS 用户 session 验证。
- helper 最终放在 `.app/Contents/MacOS`、`.app/Contents/Helpers` 或 install prefix `bin` 还没有包装定案。

## macOS 下一步建议顺序

1. **先解决 storage bridge 的 APPLE 编译接线。**
   - 这会触碰冻结的 `src/service/CMakeLists.txt`，需要先按 harness 提 change proposal。
   - 更稳的方案是把 storage 实现抽到跨平台 shared storage，而不是继续放在 `windows/storage`。
   - 同时修正 macOS 默认 DB 路径，确保 UI 和 service 指向同一个 `timearc.db`。

2. **在 Mac 上跑 configure/build。**
   - 目标是先让 `time_arc_service` 链接成功。
   - 重点看 Swift/C bridge、SQLite/parson 链接、Foundation/Darwin API 编译问题。

3. **做最小写库 smoke。**
   - 手动运行 helper 60 秒。
   - 检查 SQLite `frontmost_sessions` 是否出现 `platform='macos'`。
   - 检查 `usage_records.jsonl` 是否有 macOS record。
   - 检查 `usage_current.json` 是否随当前 app 更新并在退出后清理。

4. **验证 LaunchAgent 和 UI 启动。**
   - `time-arc-service --install`
   - `time-arc-service --status`
   - `time-arc-service --stop`
   - 从 `TimeArc.app` 启动后确认 helper 只启动一个实例。

5. **再做权限 UX 和包装。**
   - Accessibility 引导。
   - helper 嵌入位置。
   - codesign / notarization / DMG / clean-machine。

## 当前可对外描述的状态

更准确的表述是：

> Windows 后端已经完整可用；macOS 后端的采集、生命周期和 UI 启动代码已经基本补齐，但 storage bridge 在 APPLE 构建目标里尚未接通，仍需 Mac 编译和写库 smoke 才能确认可用。

不建议现在说：

> macOS 已经和 Windows 后端完全同步。

也不建议现在说：

> macOS 已经写入 SQLite。

可以说：

> macOS Swift 层已经调用统一 storage bridge，目标是写同一套 SQLite/JSONL/current 契约；但当前构建配置还需要把 storage 实现接入 APPLE target 并在 Mac 上验证。
