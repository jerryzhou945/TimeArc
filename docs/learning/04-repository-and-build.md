# 04 · 项目目录与构建系统 / Repository and Build System

## 本章目标 / Learning goals

看到一个文件时，能判断它属于哪一层、由哪个目标编译、最后运行在哪个进程。

## 1. 顶层目录地图

| 路径 | 责任 |
| --- | --- |
| `src/main.cpp` | GUI composition root，创建对象并装配依赖 |
| `src/services/` | Qt/C++ 仓储、服务、管理器、平台桥 |
| `src/service/` | 独立原生采集服务 |
| `qml/desktop/` | 桌面外壳、页面、组件 |
| `qml/mobile/` | 移动外壳、页面、组件 |
| `android/` | Android Activity、Usage API、后台同步 |
| `resources/` | 图标、字体/图片、许可证、发行资源 |
| `tests/` | C/C++ 单元/冒烟、Python 静态测试、JavaScript 逻辑测试 |
| `.harness/` | 会话、错误、构建和提交质量门禁 |
| `tools/` | 平台构建、打包和验证脚本 |

## 2. CMake 的装配顺序

顶层 `CMakeLists.txt`：

1. 声明 C11、C++17；Apple 平台再启用 Swift 与 Objective-C++。
2. 查找 Qt Core、Quick、Svg、Sql、Widgets。
3. 加入 `thirdparty`、`src`、`qml`、`resources`。
4. 创建 GUI target `time-arc`，输出名 `TimeArc`。
5. 把 QML 注册为 URI `time_arc` 的 QML module。
6. 链接 Qt 与第三方库。
7. 创建测试目标并注册 CTest。

子目录先收集 source list，再通过 `PARENT_SCOPE` 返回顶层。这种方式让顶层掌握最终目标，而各目录维护自己的清单。

## 3. 两个主要目标 / Main targets

```text
target: time-arc          -> TimeArc.exe / TimeArc.app
target: time_arc_service  -> time-arc-service.exe / time-arc-service
```

服务目标关闭 `AUTOMOC`、`AUTOUIC`、`AUTORCC`，因为它不是 Qt 程序。Windows 链接 `user32`、`psapi`、`ole32`、`uuid`；macOS 链接 Apple 原生 frameworks。

## 4. 平台源文件如何被选择

`src/service/CMakeLists.txt` 用互斥分支：

- `APPLE`：Swift 命令、运行时、控制、自动启动、诊断和 Tracking。
- `WIN32`：C 入口、配置、tracker、WinAPI platform、Windows service。
- 其他 `UNIX`：当前 Linux 占位入口。

这意味着 Windows 编译器根本看不到 Swift 文件，macOS 编译器也不编译 Windows API 文件。

## 5. QML 如何进入应用

`qml/CMakeLists.txt` 收集 QML 和 JavaScript；`qt_add_qml_module` 把它们注册到 `time_arc` 模块。`src/main.cpp` 最终加载 `qrc:/qt/qml/time_arc/qml/main.qml`。

桌面外部资源还会被编译为独立 `.rcc` 文件，构建后复制到 `assets/`。这样可保持 GUI 可执行文件与较大资源包的发布结构。

## 6. Android 与 macOS 包装

Android target 通过 `QT_ANDROID_PACKAGE_SOURCE_DIR` 指向 `android/` 的 Gradle 包装与 Java 源码。macOS target 是 bundle，并把 `time-arc-service` 复制到 app bundle 的 `Contents/MacOS/`。

## 7. 为什么构建必须走 Harness

仓库要求使用 `.harness/tools/build.py`，它在构建失败时自动留下错误报告和完整日志。直接运行裸 `cmake --build` 会绕过项目的证据链。

常用流程：

```powershell
python .harness/tools/preflight.py --track A
python .harness/tools/build.py --track A
ctest --test-dir build --output-on-failure
python .harness/tools/harness_check.py
```

实际环境可用不同 Python 路径，但脚本入口和轨道不能跳过。

## 8. 从文件反推运行位置

- 含 `QObject`、`QVariant`、`QSqlDatabase`：通常属于 GUI 进程。
- 位于 `src/service/windows/` 且含 WinAPI：属于 Windows 服务。
- 位于 `qml/`：由 GUI 的 QML engine 实例化。
- 位于 `android/src/main/java/`：由 Android runtime 加载，通过 JNI/Qt 与原生层协作。

## 面试表达 / Interview answer

“CMake builds two independent executables. Platform-specific source selection happens at configure time, while Qt packages the shared QML module into the GUI. The collector deliberately disables Qt code generation to keep the native service lightweight.”

## 源码入口 / Source entry points

- `CMakeLists.txt`
- `src/CMakeLists.txt`
- `src/service/CMakeLists.txt`
- `qml/CMakeLists.txt`
- `tools/`

## 复习题 / Review

1. target 名和输出文件名为什么不同？——CMake 内部使用稳定标识，`OUTPUT_NAME` 决定用户看到的文件名。
2. `if(WIN32)` 的结果何时确定？——CMake 配置阶段。
3. 为什么服务关闭 AUTOMOC？——它不使用 Qt 元对象和 UI 工具链。
