# Windows 测试版发布审计（2026-08-20）

## 结论

本轮定位为 **Windows 小范围测试版**，不是正式稳定版。Codex 自主命令计时已按“有工作证据才覆盖 idle”的原则修复：键鼠无输入时，只有官方 OpenAI Codex 同一进程家族中的命令后端产生有效 CPU/I/O 变化，才续租最多 90 秒；Codex 仅打开但计数器不变化时仍按 idle 处理。

macOS 的对应思路同样是证据驱动：普通前台应用遵守键鼠 idle；音频进程与 `IOPMCopyAssertionsByProcess` 提供的播放/防休眠断言可以覆盖 idle。macOS 当前没有 Windows 这种通用 CPU/I/O 进程树探针，因此两端共享语义，但使用平台原生证据。

## 本轮范围

- 修复 Codex Electron 前台 UI 与 `codex.exe` 命令后端位于同级分支时的漏记。
- 保留其他 Windows 应用原有前台子树检测，不添加“进程存在即活跃”的白名单。
- 修复 Release 构建下 Windows C 测试断言被 `NDEBUG` 完全移除的问题。
- 重新验证 UI 启动采集器、配置关闭采集和 JSON 状态。
- 生成新的便携 ZIP，并记录签名、版本、CI 与平台限制。

## 变更文件

- `src/service/windows/platform/process_activity_win.c/.h`
- `src/service/windows/tracker/usage_tracker.c`
- `tests/windows_foreground_state_test.c`
- 发布审计、后端差异、测试招募和 harness 记录文档

## 验证

- Harness Release 构建：通过。
- CTest：4/4 通过，包含实际启用断言的 Windows foreground/process 测试。
- Python 静态/运行测试：逐脚本执行；Windows 真实 UI/service 隔离 smoke 通过。
- 服务状态：UI 启动后 `running=true`、`enabled=true`，默认 idle 60 秒。
- 真实前台写库：短暂打开当前 TimeArc 构建并干净停止服务后，
  `frontmost_sessions` 从 8,830 增至 8,831，最新结束时间为
  `2026-08-20T15:54:54Z`；验证过程未读取或输出窗口标题。
- Codex 回归夹具：只选择同一官方包进程家族内的 `codex.exe` 子树；非官方路径、其他进程家族均不扩展；多根聚合不重复计数。
- Windows ZIP：`dist/TimeArc-0.1.0-alpha.3-win64.zip`，50,599,816 bytes；
  SHA-256 `82B7DF52F857B6FA318F3080C1801DACB0D84D6DEBC941C7F461EBB088E79304`。
- 对最终打包目录再次执行真实 UI/service 隔离 smoke：通过；随后 Qt 日志扫描无新日志。

## 发布问题分级

### P0 / 阻止本轮测试发布

- 当前无已知 P0；最终打包、隔离 runtime smoke 与真实前台写库均已通过。

### P1 / 测试版必须明确告知

- Windows 可执行文件未做 Authenticode 签名，下载或首次运行可能触发 SmartScreen。
- 仓库没有 build/test CI；GitHub Actions 当前只清理已合并分支，因此本轮依赖本机验证证据。
- 这是便携 ZIP，没有安装器、卸载器和自动更新。
- 窗口标题会写入本地 `timearc_service.db`；测试者不要上传原始数据库。
- 24 小时连续运行和全新 Windows 机器验证仍需首批测试者完成。

### P2 / 不阻止 Windows 小范围测试

- 工程版本为 `0.1`，现有 tag 为 `v0.1.0-alpha.2`，发布命名尚未统一。
- Windows 只读取配置 v1 的总开关和 idle；poll/min/max 与 frontmost/media 子开关仍待接线。
- macOS 必须在 Mac 上完成运行、Accessibility、launchd、签名、公证和干净机器验证，不能用本次 Windows 结果替代。
- Linux tracker 尚未实现。

## 测试重点

1. Codex 前台、停止键鼠操作，运行一个超过 2 分钟的构建或测试：时间应继续增长。
2. Codex 前台但不运行任务，超过 idle + 90 秒：活动时间应停止增长。
3. 普通编辑器/浏览器静置超过 idle：不应因应用仍打开而继续增长。
4. 切换三个应用、关闭/恢复追踪、退出/重开 TimeArc，核对当天记录连续性。

自动化已覆盖不变计数器不续租、命令计数器变化续租和多个 Codex 后端聚合；由于测试
代理本身一运行命令就会制造 Codex 活动，无法在同一自动化会话里完成可信的“真实前台
静置 idle + 90 秒”对照，该项保留给首轮人工 soak。

## 回滚

若出现误记常驻或性能回归，回滚本轮 Codex 活动提交即可；它不修改 SQLite schema、配置格式或历史数据。提交 SHA 在落地后补入。
