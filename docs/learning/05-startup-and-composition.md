# 05 · 启动与对象装配 / Startup and Object Composition

## 本章目标 / Learning goals

从两个入口函数出发，理解程序启动后对象以什么顺序出现、依赖怎样连接、何时进入事件循环。

## 1. GUI 的 composition root

`src/main.cpp` 是 GUI 的 composition root（组合根）：它不负责所有业务，而是负责创建应用级对象并把它们连接起来。

启动顺序大致是：

1. Windows 创建 UI 单实例 mutex；已有实例时激活旧窗口并退出。
2. 解析 `--mobile-preview`、`--start-in-tray` 等参数。
3. 创建 `QGuiApplication`；macOS 因原生菜单使用 `QApplication`。
4. 注册外部 `.rcc` 资源并安装 Harness 日志处理器。
5. 创建 `QQmlApplicationEngine`。
6. 初始化 GUI 数据库和 repositories。
7. 构造 services、managers 和平台控制器。
8. 将对象注册为 QML context properties。
9. 加载 `qml/main.qml`，最后进入 `app.exec()` 事件循环。

**Interview English:** “`main.cpp` acts as the composition root. It constructs long-lived application services, injects their dependencies, and exposes the selected façade objects to QML.”

## 2. 为什么对象多放在栈上

`DatabaseManager databaseManager;` 等对象在 `main()` 栈帧中存在，直到 `app.exec()` 返回。QML 只持有指向它们的 QObject 指针，因此生命周期覆盖整个 UI 会话。

这比在 QML 中随意创建业务对象更清晰：依赖关系集中、初始化顺序明确、测试可以替换底层对象。

## 3. 延迟启动后台采集

Windows 使用 `QTimer::singleShot(0, ...)` 在事件循环开始后确保登录自启默认值并请求服务启动。macOS 也延迟执行后台采集自检。

这样首屏初始化不会被一个可能较慢的外部服务命令阻塞。

## 4. 服务入口

`src/service/windows/main.c` 有两种模式：

- 有命令参数：分派 `--install`、`--uninstall`、`--start`、`--stop`、`--status`、`--run-service`。
- 无参数：在当前用户会话直接运行 tracker。

启动 tracker 前会：注册 console shutdown handler、获取命名互斥量、载入带默认值的 `service_config.json`。

## 5. 优雅停止 / Graceful shutdown

控制台关闭或 stop event 不会直接杀死循环，而是设置原子 stop flag。循环退出后会 flush 当前前台、音频和 Agent 会话，再释放句柄。

**English:** cooperative cancellation, stop flag, graceful shutdown, flush pending state.

## 6. QML 根入口

`qml/main.qml` 根据平台或 `mobilePreview` 使用 `Loader` 选择 `DesktopAppShell` 或 `MobileAppShell`。同一个 Qt executable 因此可以共享 C++ 层，同时加载不同 UI shell。

## 7. 启动失败策略

- 资源包缺失：GUI 立即失败，因为界面无法可靠渲染。
- GUI 私有数据库初始化失败：记录 warning，仍尝试进入 UI，便于展示错误或已有能力。
- QML 根对象创建失败：通过 `objectCreationFailed` 退出。
- 服务已运行：新服务实例正常退出，不把“已经运行”当作错误。

## 源码入口 / Source entry points

- `src/main.cpp`
- `src/service/windows/main.c`
- `src/service/windows/service/win_service.c`
- `qml/main.qml`

## 复习题 / Review

1. composition root 为什么重要？——集中创建和连接长生命周期依赖。
2. 为什么服务停止要 flush？——采样中的开放会话尚未持久化完整结束时间。
3. `app.exec()` 做什么？——进入 Qt 事件循环，分发输入、定时器、窗口和信号事件。
