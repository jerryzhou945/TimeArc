# Windows 服务系统媒体查询去 PowerShell 修复

## 目标

解决用户反馈的"常驻后台占用高"：Windows 采集服务在浏览器持有音频会话时，约每秒派生一次 `cmd.exe` → `powershell.exe` 去读取系统媒体（GSMTC）标题与播放状态。

## 现象与测量（修复前，已安装 v0.1.0）

- 打开 Chrome 时 30 秒内派生 40 个 `cmd.exe` 子进程。
- 单次 PowerShell 查询约 550 ms CPU、665 ms 墙钟、峰值 89 MB 内存，合计约 0.7 核持续占用；该开销不计入服务自身 CPU，任务管理器里不易察觉。
- `-ExecutionPolicy Bypass -EncodedCommand` 是杀软常见的拦截特征，可能导致服务被拦或被杀。

## 范围

- `src/service/windows/platform/audio_win.c`：用手写的最小 WinRT ABI 在进程内调用 `Windows.Media.Control`；`combase.dll` 运行时加载，接口 IID 与方法顺序取自系统元数据。会话匹配、标题合并、播放状态合并与缓存逻辑不变；删除两段 PowerShell 脚本与旧的"仅标题"兜底（原生路径在拿不到播放状态时保持 UNKNOWN，等价于该兜底）。
- `src/service/windows/main.c`：采集启动时进入 EcoQoS（Windows 11 "效率模式"）并设为低于正常优先级；时长按墙钟计算，不受调度快慢影响。
- 未改动 CMake、冻结文件、SQLite 表结构、`data_bridge.h`、QML 与 macOS/Linux。

## 验证

- 构建包装器 `build.py` 通过且无新警告；CTest 6/6 通过；`harness_check.py` clean。
- 探针程序直接调用原生查询：返回与 PowerShell 相同的 Chrome 标题，Paused 映射为 NOT_PLAYING；单次 0.27 ms CPU、15–47 ms 墙钟。
- 实机替换运行 2 分钟：0 个 cmd/PowerShell 子进程，优先级 BelowNormal，工作集 19.9 MB，自身 CPU 约 1.4 s/分钟；数据库会话在替换前后连续，标题与 60 秒 checkpoint 一致。

## 已知边界

- 剩余自身 CPU 主要来自每秒 WASAPI 会话枚举（约 8 ms/次）与进程树快照（约 10 ms/次，最多每秒两次），列为 backlog B8。
- 安装器本身仍使用 `powershell -ExecutionPolicy Bypass`，属于独立问题。

## 回滚

还原本修复提交（`Fix service media query without PowerShell`）即可；无数据迁移，数据库无需处理。
