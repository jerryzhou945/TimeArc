# 02 · 技术地基 / Technology Foundations

## 本章目标 / Learning goals

只学习读懂 TimeArc 所需的最小技术集合，而不是把每门语言完整学一遍。

## 1. C：原生 Windows 服务 / Native collector

C 适合与 Win32、COM、WASAPI 和 SQLite C API 直接协作。你需要理解：

- `.h` 声明接口，`.c` 实现接口。
- `struct` 把一次观察需要的字段放在一起。
- 指针 `T*` 指向对象或输出缓冲区。
- 返回 `0` 常代表成功，非零代表失败。
- `#ifdef WIN32` 是编译期选择，不是运行时 `if`。
- 手动资源管理要求成功路径与失败路径都释放句柄和 COM 对象。

**English:** header, implementation, structure, pointer, ownership, cleanup path, conditional compilation.

## 2. C++17 与 Qt 对象模型

GUI 逻辑使用 C++17 和 Qt：

- `QObject` 提供信号槽、父子所有权和元对象能力。
- `Q_OBJECT` 让 moc 生成运行时元数据。
- `Q_PROPERTY` 把状态暴露给 QML。
- `Q_INVOKABLE` 让 QML 调用 C++ 方法。
- signal 表示事件，slot 或普通可调用方法处理事件。
- RAII 让对象在离开作用域时自动清理资源。

**Interview English:** “Qt’s meta-object system bridges statically typed C++ objects into the declarative QML runtime.”

## 3. QML：声明式界面 / Declarative UI

QML 描述“界面应当是什么样”，不是一步步命令系统画图。

```qml
Text {
    text: timerManager.running ? timerManager.timeText : "Ready"
}
```

当依赖属性变化时，绑定自动重新计算。对象通过 `id` 在同一组件内引用；信号处理器如 `onClicked` 响应事件；`Loader` 按需装载页面。

**English:** declarative UI, property binding, object tree, signal handler, component, lazy loading.

## 4. SQLite：进程之间的持久化契约

SQLite 是嵌入式关系数据库，不需要单独数据库服务器。核心概念：

- table：同类记录集合。
- row：一条记录。
- primary key：唯一身份。
- foreign key：表间关联。
- index：用额外空间加速查询。
- transaction：一组操作要么成功，要么回滚。
- prepared statement：参数绑定，避免拼 SQL。

TimeArc 有两个 SQLite 文件，必须先理解“所有权”再理解表。

## 5. CMake：描述目标，不是编译器

CMake 读取 `CMakeLists.txt`，生成真正的构建系统。TimeArc 的关键概念：

- target：可执行文件或库。
- source list：属于目标的源文件。
- include directory：头文件搜索路径。
- link library：链接依赖。
- generator expression：根据配置选择值。
- `if(WIN32)` / `if(APPLE)`：选择平台源文件。

目标 `time-arc` 的输出名是 `TimeArc`；目标 `time_arc_service` 的输出名是 `time-arc-service`。

## 6. Swift 与 Android Java/JNI

macOS 服务用 Swift 调 AppKit、ApplicationServices、CoreAudio 等框架，再通过 C ABI 调共享 SQLite 写入函数。Android 由 Java 读取 UsageStats/UsageEvents，经 JNI 进入 C++ 移动仓储和服务。

JNI（Java Native Interface）是 Java 与原生 C/C++ 的调用边界。它不是网络通信。

## 7. 一次调用里会经过哪些语言

桌面 Windows：WinAPI → C collector → SQLite C API → QtSql/C++ → QML。

Android：Android Usage APIs/Java → JNI → C++ repository/service → QML。

macOS：Apple frameworks/Swift → C ABI → SQLite → Qt/C++ → QML。

## 源码入口 / Source entry points

- `src/service/windows/main.c`
- `src/service/shared/data_bridge.h`
- `src/main.cpp`
- `src/services/*.h`
- `qml/main.qml`
- `android/src/main/java/com/timearc/mobile/usage/`
- `CMakeLists.txt`

## 常见误区 / Common mistakes

- Qt 是框架；C++ 是语言；QML 是声明式语言，三者不是同一个概念。
- CMake 不负责运行应用，它负责生成构建规则。
- signal/slot 不是跨进程 IPC；这里主要是同一 GUI 进程内对象通信。

## 复习题 / Review

1. `Q_PROPERTY` 的作用？——让 Qt 元对象系统和 QML观察 C++ 属性。
2. SQLite 为什么适合本项目？——本地、嵌入式、事务化、跨语言 API 稳定。
3. `#ifdef` 与 `if` 区别？——前者决定代码是否参与编译，后者在运行时判断。
