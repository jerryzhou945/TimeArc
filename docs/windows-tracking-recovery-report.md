# Windows 计时恢复与平台同步报告

日期：2026-08-20

## 目标与结果

恢复 Windows 打开 TimeArc 后的实时计时，并把当前配置、运行状态和“立即开始”能力
同步到 macOS 合并后的共享接口。结果：真实 `TimeArc.exe` 启动可拉起独立 collector；
关闭追踪会让 collector 正常退出；idle 为 0 时持续视为活动，不会被当作闲置。

## 改动范围

- `src/main.cpp`：恢复 Windows 启动 collector，named mutex 保证幂等。
- `src/service/windows/service_config.*`：改读 `%APPDATA%/TimeArc/config/service_config.json`。
- `src/service/windows/tracker/usage_tracker.c`：支持 idle=0。
- `src/service/windows/service/win_service.*`：新增 `--status --json`。
- `src/services/settings_repository.*`：Windows 接入真实运行态与立即启动。
- `qml/desktop/pages/DesktopProfilePage.qml`：Windows“应用并重启采集”不再依赖登录自启。
- `tests/windows_service_runtime_smoke_test.py`：隔离目录中启动真实 UI/service 验证生命周期。
- `tests/windows_tracking_parity_static_test.py`：守住 Win/mac 共享接口和设置按钮行为。

## 验证

- harness Release/当前配置构建通过。
- CTest 4/4 通过。
- 全部 Python static/smoke 测试通过；macOS 二进制 smoke 在 Windows 上按设计跳过。
- Windows 真实进程 smoke 覆盖：UI 自动启动、tracking=false 退出、JSON 状态与 idle=0。
- 测试 ZIP：`dist/TimeArc-0.1-win64.zip`，SHA-256
  `A68405BC501806A421FF3A1F5A68B9CF78B4FCFBC28185F7CF94E3FBAC68274E`；
  包内主程序与 collector 同样通过真实进程 smoke。该本地测试包未做 Authenticode 签名。

## 已知差距

- Windows 只读取 v1 配置的追踪总开关与前台 idle；高级 sampling/session 和子开关待接线。
- macOS 必须在 Mac 上完成 Accessibility、launchd、签名/公证和安装包实测。
- Windows SCM Session-0 服务仍不采用；collector 保持在交互用户会话，才能正确识别前台应用。

## 回滚

合并后如需回滚，revert 本次 PR 的 merge commit。回滚会重新暴露“打开 Windows UI
但 collector 不启动”的故障，因此只应在发现新的数据正确性问题时执行。
