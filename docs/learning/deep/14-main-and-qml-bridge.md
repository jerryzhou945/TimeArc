# 14｜`main.cpp`：对象装配与 Qt/QML 桥梁

> 本章目标：逐阶段理解 GUI 启动、依赖装配、context property 和 QML 加载。
> Source map: `src/main.cpp`, `qml/main.qml`, `src/CMakeLists.txt`, `qml/CMakeLists.txt`.

## 1. `main.cpp` 是 composition root

**Composition root（装配根）** 是创建对象并连接依赖的地方。它不应承载大量业务算法，而是回答：

- 程序使用哪个 Application class？
- 创建哪些 repositories/services/managers？
- 谁依赖谁？
- 哪些对象暴露给 QML？
- 加载哪个 root QML？

## 2. 启动前参数

程序识别：

```text
--mobile / --mobile-preview
--start-in-tray / --tray
TIMEARC_MOBILE_PREVIEW 环境变量
```

这使桌面构建可以预览 mobile shell，也允许安装启动时直接进 tray。参数解析在创建 UI 后端之前完成，因为它会影响根页面选择。

## 3. GUI 单实例

Windows GUI 使用独立命名 mutex。如果发现已有 TimeArc 窗口，新进程尝试恢复并激活旧窗口后退出。

注意这里有两个单实例：

- UI mutex：防止两个 GUI；
- service mutex：防止两个 collector。

它们保护不同进程角色，不能共用一个概念模糊的锁。

## 4. QGuiApplication 与 QApplication

大部分平台使用 `QGuiApplication`；macOS 因原生 status menu 基于 `QMenu`，使用更完整的 `QApplication`。

这展示 compile-time branch：

```cpp
#if defined(Q_OS_MACOS)
  QApplication app(argc, argv);
#else
  QGuiApplication app(argc, argv);
#endif
```

预处理器在编译时选择代码，不是运行时 if。

## 5. 资源包注册

桌面端启动时注册多个 `.rcc`：背景、site icons、monthly recap。如果必需资源缺失，启动明确失败，而不是让页面稍后出现一片空白。

这叫 **fail fast（快速失败）**：对不可恢复的部署错误尽早报告。

## 6. 初始化数据库

```cpp
DatabaseManager databaseManager;
if (!databaseManager.initialize()) {
  qWarning() << "Database initialization failed.";
}
```

数据库 manager 必须先于 repository 查询准备好连接。这里失败后仍继续，是为了让应用可能展示有限 UI/诊断；具体页面要处理空数据。

## 7. 创建对象图

简化后的依赖图：

```text
DatabaseManager
     │ 提供命名连接
     ├── FrontmostSessionRepository ─┐
     ├── MediaSessionRepository ─────┼── StatsService ── DailyCardService
     ├── ManualProjectRepository ────┘
     └── SettingsRepository ── CalendarManager / PomodoroManager / MobileUiService
```

`main.cpp` 中按依赖顺序创建对象，构造器参数公开表达连接。

## 8. 后台服务启动边界

Windows GUI 启动后通过 `QTimer::singleShot(0, ...)`：

- 确保默认 autostart policy；
- 请求独立 service 启动；
- 如果 `tracking.enabled=false`，返回 false 也是预期状态。

为什么 defer 到 event loop？潜在慢操作不应阻塞首个窗口出现。macOS 的自检也采用相同思想。

## 9. context property 是什么

示例：

```cpp
engine.rootContext()->setContextProperty(
    "statsService", &statsService);
```

之后 QML 可以直接写：

```qml
property var summary: statsService.getHomeSummary()
```

Qt meta-object system 负责把 `Q_INVOKABLE`、public slots、properties 和 signals 暴露给 QML。

## 10. 暴露了哪些能力

当前 context 包含 database manager、多个 repositories、stats/daily card services、timer/pomodoro/project managers、mobile services，以及平台控制器和 flags。

优点：简单直接。代价：全局 context 名称较多，页面可以越过 service 直接调用 repository，长期可能形成隐式依赖。更大项目可逐步使用 QML singleton、registered type 或 page-specific view model。

## 11. image provider

```cpp
engine.addImageProvider("appicon", new AppIconImageProvider);
```

QML 可通过类似 `image://appicon/...` 请求应用图标。Image provider 把“从 executable/site identity 解析图标”的平台/缓存细节隐藏在 C++。

## 12. QML 从哪里加载

```cpp
engine.load(QUrl(
  QStringLiteral("qrc:/qt/qml/time_arc/qml/main.qml")));
```

- `qrc:` 表示 Qt Resource System；
- `time_arc` 来自 QML module URI；
- `qml/main.qml` 是 root component。

若 object creation 失败，signal handler 让进程以错误码退出；加载后还检查 `rootObjects().isEmpty()`。

## 13. event loop

```cpp
const int rc = app.exec();
```

到这里程序进入事件循环：处理窗口事件、timer、queued signal、QML binding、输入和异步回调。`app.exec()` 返回时才开始退出清理。

## 14. QObject 暴露到 QML 的必要条件

常见方式：

```cpp
Q_PROPERTY(int value READ value NOTIFY valueChanged)
Q_INVOKABLE QVariantMap loadSummary();
signals:
  void valueChanged();
```

- `Q_OBJECT` 启用 meta-object；
- property 适合状态绑定；
- invokable 适合命令/查询；
- signal 通知 QML 变化。

忘记 NOTIFY 常导致 C++ 值已变但 QML 不刷新。

## 15. 面试表达

> `main.cpp` is our composition root. It initializes the two database connections, creates repositories and higher-level services in dependency order, exposes selected QObject APIs to QML, registers image and resource providers, and finally loads the packaged QML module. Platform-specific lifecycle code is guarded at compile time and kept out of page components.

## 16. 本章练习

1. 从 `StatsService` 反向画出它的三个 dependencies。
2. context property 的 C++ 对象为何不能在局部 block 结束时销毁？
3. Q_PROPERTY、Q_INVOKABLE、signal 各适合什么？
4. 如果 `engine.rootObjects()` 为空，说明哪一阶段失败？

下一章：[桌面 QML 界面](15-desktop-qml.md)
