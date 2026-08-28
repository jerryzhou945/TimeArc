# 18｜测试、构建与发布：怎样证明跨平台应用能工作

> 本章目标：理解 TimeArc 的测试金字塔、CMake/Qt 资源、平台构建脚本和 release verification。
> English focus: **unit test, static test, smoke test, integration test, packaging, release evidence**.

## 1. “能编译”只回答了一个问题

跨平台 GUI 应用至少有五类失败：

1. 代码不编译；
2. 逻辑边界错误；
3. QML/resource 找不到；
4. 平台权限/生命周期错误；
5. 安装包缺 DLL、图标、资源或 service。

所以一个 build green 不能等于 release ready。

## 2. C/C++ 单元测试

代表文件：

```text
tests/windows_foreground_state_test.c
tests/windows_audio_tracker_test.c
tests/windows_audio_title_policy_test.c
tests/pomodoro_manager_test.cpp
```

纯状态机测试人工传 timestamps 和 samples，速度快且不依赖真实窗口。Manager test 验证 start/pause/reset 和 persistence contract。

## 3. JavaScript 单元测试

QML 中可复用的纯算法放 `.js`，可用 Node 风格测试：

```text
tests/stats_view_model_test.js
tests/stats_prototype_behavior_test.js
```

这避免为了测排序或百分比计算而启动完整 Qt window。原则是把纯逻辑从视觉 Item 中提取。

## 4. Python 静态测试

项目有大量 `*_static_test.py`，它们检查：

- 某资源是否列入 manifest；
- Android Java/JNI wiring 是否存在；
- macOS CLI/control/autostart 源结构；
- Windows build/installer flags；
- QML 是否保留关键属性和组件。

静态测试便宜，适合保护“构建脚本必须包含某文件”这类不必启动程序的 contract。它不能替代运行时测试。

## 5. smoke tests

```text
tests/db_smoke.cpp
tests/resource_bundle_smoke.cpp
tests/windows_service_runtime_smoke_test.py
```

Smoke test（冒烟测试）回答“核心路径能不能真正走通”：打开 isolated DB、加载 resource、启动 service 再查询状态等。

它通常覆盖广但断言较浅。

## 6. QML 资源系统

QML module 的 URI 是 `time_arc`，CMake 把 QML、JS、SVG 等打入资源。运行时路径是：

```text
qrc:/qt/qml/time_arc/qml/main.qml
```

文件存在于源码树不代表已打进 binary。资源测试要保护 source list/manifest 与实际文件一致。

## 7. 构建目标

重要区分：

```text
CMake target: time-arc
output name:  TimeArc

CMake target: time_arc_service
output name:  time-arc-service
```

target name 服务于 build graph，output name 服务于用户和 packaging。面试中若把二者混用，会显得没有真正读过构建系统。

## 8. 为什么必须使用 harness build

项目规定：

```powershell
python .harness/tools/build.py
```

它统一配置、构建和必要检查。任何手工 `cmake --build some-old-dir` 可能使用错误 cache 或漏掉项目约束。

## 9. Qt runtime log

QML 很多错误只在运行时出现：

- component not found；
- binding loop；
- undefined context property；
- image/provider load failure；
- signal handler 参数错误。

GUI 运行后要执行 `.harness/tools/scan_qt_log.py`。日志检查是验证的一部分，不是“页面看起来差不多”后的可选动作。

## 10. 平台构建与安装包

Windows release 还要验证：

- Qt DLL/plugins deployment；
- service executable 同包；
- native icon；
- installer/SFX 行为；
- autostart/start/stop/status；
- 资源包位置。

macOS release 还要验证：

- `.app` bundle structure；
- `.icns`、Qt frameworks；
- Swift service；
- LaunchAgent plist/path；
- signing/notarization/permissions；
- Intel/Apple Silicon target（按发布策略）。

Android release 还要验证 manifest、Usage Access intent、WorkManager、ABI、签名和真机后台行为。

## 11. 测试隔离

数据库测试必须设置 Qt test mode / temporary AppData；service test 应使用独立数据目录、独立进程名或清晰 cleanup。

测试的四个理想属性：

- deterministic（确定）；
- isolated（隔离）；
- repeatable（可重复）；
- diagnostic（失败信息可诊断）。

## 12. 测试矩阵

| 层 | 示例 | 主要证明 | 不能证明 |
|---|---|---|---|
| 纯单测 | foreground state | transition 正确 | Win32 probe 真能取数据 |
| 静态测试 | manifest check | wiring 没漏 | 运行时资源一定加载 |
| smoke | DB/resource/service | 核心集成可运行 | 全部 UI 行为 |
| 手工/自动 UI | 页面交互 | 实际用户路径 | 长期后台稳定 |
| release device | 安装包/真机 | 部署和权限 | 所有未来环境 |

## 13. 如何说明“我验证过”

不要只说“tests passed”，要给 evidence：

> I ran the project build wrapper, the collector state-machine tests, database and resource smoke tests, and the platform static suite. After launching the Qt UI, I also scanned the runtime log for QML warnings. Packaging was then verified from the produced artifact rather than the source tree.

只有真正执行过的项目才能这么说。

## 14. 本章练习

1. 为“新增 QML 图标”选择至少三层验证。
2. static test 为什么不能证明 runtime permission 正常？
3. target name 与 output name 有什么差别？
4. 设计一次 Windows service 的最小 smoke test。

下一章：[从零制作 TimeArc 的开发故事](19-development-story.md)
