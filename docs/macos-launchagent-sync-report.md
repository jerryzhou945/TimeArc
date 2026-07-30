# macOS LaunchAgent 同步报告

日期：2026-06-19

## 目标

继续按照 `docs/platform-parity-packaging-gap.md` 的顺序推进 macOS 后端同步。本轮跳过当前 Windows 环境无法完成的 Mac 实机 smoke，完成下一批可落地项：LaunchAgent 生命周期和 UI 自动启动 helper。

## 本轮范围

- `src/service/macos/TimeArcService.swift`
  - 增加 `--install`、`--uninstall`、`--start`、`--stop`、`--status` verbs。
  - `--install` 写入 `~/Library/LaunchAgents/com.timearc.usage-service.plist` 并 bootstrap 到当前 `gui/<uid>` domain。
  - `--uninstall` 请求停止并删除 LaunchAgent plist。
  - `--start` 优先 kickstart/bootstrap LaunchAgent，失败时 fallback 为直接 detached 启动 helper。
  - `--stop` 通过 LaunchAgent bootout 和 lock file pid 的 `SIGTERM` 请求优雅停止。
  - `--status` 输出 `autostart=on/off` 与 `running=yes/no`。

- `src/main.cpp`
  - 后续实现已替换原 `startUsageService()` 直接启动路径。
  - 发布布局保持 `Contents/MacOS/time-arc-service`，LaunchAgent 内嵌于
    `Contents/Library/LaunchAgents/com.timearc.service.plist`。
  - UI 通过 `SMAppService` 注册，plist 使用 bundle-relative
    `BundleProgram`，不再复制到用户目录或直接启动 helper。

- 文档
  - `docs/platform-parity-packaging-gap.md` 已按顺序标记完成项和待验证项。
  - `.harness/rules/02-platform-boundaries.md`、`.harness/state/open-issues.md`、`docs/implementation-backlog.md` 已同步状态。

## 验证

- RED 结构检查确认旧代码没有 macOS lifecycle verbs 和 UI macOS helper 启动路径。
- GREEN 结构检查确认 `--install` / `--start` / `LaunchAgent` / `launchctl` 和 `Q_OS_MACOS` 路径已存在。
- `python .harness/tools/build.py`：Windows 构建通过。
- macOS Swift 编译、LaunchAgent 行为、权限行为仍需 Mac 主机验证。

## 仍然缺口

1. Mac 主机上编译 `time-arc-service` 并跑 lifecycle verbs。
2. 验证 LaunchAgent plist 是否能稳定 bootstrap/kickstart/bootout。
3. 验证 UI auto-start 找到实际包装后的 helper 路径。
4. 增加 Accessibility 权限 UX。
5. 完成 helper bundle 布局、签名、公证、DMG 和 clean-machine QA。

## 回滚说明

如果本轮 macOS lifecycle 在实机上出现启动异常，回滚本轮提交即可恢复到“foreground/config/media MVP”状态。共享 schema、C bridge 和 Windows service 未修改，不需要数据迁移。
