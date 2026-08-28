# 11 · Qt/C++ 到 QML 的桥 / Qt-to-QML Bridge

## 本章目标 / Learning goals

理解 C++ 对象怎样进入 QML、状态怎样自动更新、QML 怎样调用业务逻辑。

## 1. 元对象系统 / Meta-object system

普通 C++ 不知道“属性变化通知”或“按名字调用方法”。Qt 的 moc 读取 `Q_OBJECT`、`Q_PROPERTY`、signals 和 slots，生成额外元数据。

```cpp
Q_PROPERTY(int todaySoftwareMinutes
           READ todaySoftwareMinutes
           NOTIFY usageStatsChanged)
```

QML 读取属性时会订阅 NOTIFY signal；signal 发出后，依赖该属性的 binding 自动重算。

## 2. 三种常见桥接方式

TimeArc 主要使用：

1. `engine.rootContext()->setContextProperty(...)`：注入应用级单例对象。
2. `engine.addImageProvider("appicon", ...)`：提供 `image://appicon/...` 原生应用图标。
3. QML module/resource：`qt_add_qml_module` 注册 QML 文件和 URI。

项目没有让每个 QML 页面自己 new 一套 repositories，这保证数据源一致。

## 3. Context properties

主要名字包括：`databaseManager`、`settingsRepository`、`statsService`、`dailyCardService`、`usageStatManager`、`timerManager`、`pomodoroManager`、`projectManager`、`mobileUsageService` 和 `mobileUiService`。

这些名字是运行时契约。C++ 改名而 QML 未同步会在运行时出现 undefined，而不是普通 C++ 编译错误。

## 4. QML 调 C++

标记 `Q_INVOKABLE` 的方法可直接调用：

```qml
Component.onCompleted: usageStatManager.refresh()
```

参数和返回值必须是 Qt 元类型系统能转换的类型。`QString`、`bool`、数字、`QVariantMap/List` 最常用。

## 5. C++ 推送状态到 QML

以计时器为例：C++ 内部 `QTimer` 更新 elapsed time，更新成员后 emit NOTIFY signal；QML 的文本绑定自动刷新。QML 不需要每帧主动查询数据库。

这叫 reactive update / push-based UI update。

## 6. Connections 与生命周期

QML `Connections` 可以监听注入对象的 signals。目标对象可能只在某平台存在，因此移动和 macOS 平台桥常使用 null-safe target。

C++ 对象必须比 QML 长寿。TimeArc 将它们创建在 `main()` 中，并在 engine 销毁后才离开作用域，满足生命周期要求。

## 7. Image provider

应用图标来自 executable/package 等原生来源，不一定是普通文件 URL。`AppIconImageProvider` 把请求映射为 Qt image，让 QML 统一写 `image://appicon/<encoded-id>`，并在失败时走站点资产或通用 fallback。

## 8. 为什么不把复杂统计写在 QML

QML/JavaScript 适合展示和轻交互，但数据库、区间算法、缓存和平台逻辑放在 C++ 更容易测试、复用和控制性能。QML 应消费 view model，而不是自己打开 SQLite。

## 面试表达 / Interview answer

“I use Qt’s meta-object system as the boundary between typed C++ services and declarative QML. Application-scoped objects are injected once, invokable methods handle commands, and NOTIFY signals drive reactive updates.”

## 源码入口 / Source entry points

- `src/main.cpp`
- `src/services/usage_stat_manager.h`
- `src/services/timer_manager.h`
- `src/services/app_icon_image_provider.cpp`
- `qml/main.qml`

## 复习题 / Review

1. `Q_INVOKABLE` 与 `Q_PROPERTY` 分别解决什么？——命令调用与可观察状态读取。
2. 为什么 context property 名称危险？——它是运行时字符串契约，编译器无法完整检查。
3. QML 是否应直接访问 SQLite？——不应；应经 C++ 数据和业务层。
