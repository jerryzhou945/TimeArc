# 15 · 测试、Harness、构建与发布 / Testing, Harness, Build, and Release

## 本章目标 / Learning goals

理解 TimeArc 如何验证状态机、数据库、QML、资源和发行包，而不是把“看起来能跑”当作完成。

## 1. 测试层次

| 类型 | 例子 | 价值 |
| --- | --- | --- |
| C 单元测试 | foreground/audio policy | 快速验证状态机和边界 |
| C++ 测试 | database smoke、pomodoro | 验证 QtSql、迁移和计时器 |
| JavaScript 测试 | StatsViewModel | 不启动 GUI 验证视图逻辑 |
| Python static test | QML、Android、打包结构 | 检查易回归的源码/资源约束 |
| Runtime smoke | service、GUI、installer | 验证真实进程和产物 |
| Manual/visual QA | 页面、权限、签名、公证 | 覆盖自动化难判断的系统行为 |

## 2. 状态机测试

采集 bug 往往依赖事件序列。测试应输入 start → continue → idle → resume → identity change → shutdown，再检查导出的 sessions。时间和系统探针应尽量可注入或拆成纯函数，避免真实睡眠和机器状态依赖。

## 3. 数据库与静态测试

`timearc_db_smoke` 使用隔离路径验证 GUI schema 和仓储行为，不能碰用户真实数据库。QML 很多问题只能运行时发现；Python static tests 先守住资源登记、context 名称、平台门控和打包结构等已知回归，但不能替代真实 QML engine 测试。

## 4. Harness 的 A/B/C 轨道

- A Stabilize：质量提升，行为不变。
- B Feature：新增能力。
- C Debug：修复已知错误。

每次会话先 preflight；任何错误必须 record；构建必须走 wrapper；运行 Qt 后 scan log；提交前 harness check。冻结文件变更必须先有 change proposal。

这是 engineering governance：让错误、决策和高风险契约留下可审计证据。

## 5. 推荐验证顺序

```text
preflight
 -> focused unit/static tests
 -> wrapped build
 -> CTest suite
 -> JavaScript/Python tests
 -> GUI/service smoke
 -> scan Qt log
 -> packaging/linkage checks
 -> harness check
```

先跑快速、聚焦测试，最后才做昂贵的完整构建和发行验证。

## 6. Windows 发布

`tools/package-release.ps1` 收集 GUI/service、Qt/MinGW runtime、RCC 和许可证，验证 Qt 动态链接并生成 portable ZIP。`tools/package-installer.ps1` 从同一已验证 ZIP 生成当前用户安装器。

公开 Windows 包未签名时会触发 SmartScreen，因此发布说明需要 SHA-256 和清晰来源。

## 7. macOS、Android 与许可证

macOS 还需要 Accessibility 权限、签名、公证、DMG、clean-machine 和长时间验证。Android 需要 Qt/Gradle 构建、ARM64 APK、Usage Access、后台限制和多 ROM 验证。“build passes”与“release is ready”不是同义词。

项目是 GPL-3.0-or-later。Qt 发布构建保持动态链接；SQLite、Parson、MinGW runtime notices 随发行包可达。新增依赖前要审查 license compatibility。

## 面试表达 / Interview answer

“I test the collector as event-driven state machines, the storage layer with isolated SQLite smoke tests, and the QML/package structure with targeted static tests. A repository harness enforces preflight, wrapped builds, error journals, and frozen-contract review.”

## 源码入口 / Source entry points

- `tests/`
- `.harness/AGENTS.md`
- `.harness/tools/`
- `tools/package-release.ps1`
- `tools/package-installer.ps1`
- `tools/build-macos.sh`

## 复习题 / Review

1. 为什么状态机测试要输入事件序列？——错误通常取决于前后状态。
2. static test 的局限？——不执行完整运行时语义。
3. 构建成功为什么不等于可发布？——还涉及权限、签名、依赖、许可证和 clean-machine QA。
