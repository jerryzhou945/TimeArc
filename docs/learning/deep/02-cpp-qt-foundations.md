# 02 · C++ 与 Qt 对象模型 / C++ and the Qt Object Model

## 1. C++ 在 GUI 进程中的位置

C++ 层连接 SQLite、系统服务和 QML。它处理数据库、聚合、缓存、计时器和平台 UI bridge；QML 负责可视化。

## 2. 类、对象和构造函数

`StatsService` 的声明：

```cpp
class StatsService : public QObject {
  Q_OBJECT

 public:
  explicit StatsService(FrontmostSessionRepository* frontmostRepository,
                        MediaSessionRepository* mediaRepository,
                        ManualProjectRepository* manualProjectRepository,
                        QObject* parent = nullptr);
};
```

- `class` 定义一种对象类型。
- `: public QObject` 表示继承 Qt 基类。
- 构造函数与类同名，在对象创建时执行。
- `explicit` 防止编译器做意外隐式转换。
- 三个 repository 指针是依赖注入。
- `parent` 进入 Qt parent-child ownership。

## 3. 头文件与实现文件

`.h` 写公开接口和成员字段，`.cpp` 写方法正文。这样使用者只需 include 接口，内部算法变化不必让调用方理解。

`private` 成员只能由类内部访问；`public` 是调用方可使用的接口；`signals` 是 Qt 事件出口。

## 4. `QObject` 与父子所有权

QObject parent 销毁时会销毁 children。TimeArc 中多数 application-wide 对象直接在 `main()` 栈上创建，生命周期覆盖整个 event loop；临时 QObject 可以通过 parent 自动管理。

不要把 QObject 按值复制。QObject 通常禁用复制，因为信号连接、对象身份和 parent 关系不能安全复制。

## 5. `Q_OBJECT` 和 moc

标准 C++ 不支持按名字查属性和 signal。Qt 的 Meta-Object Compiler 扫描 `Q_OBJECT`，生成额外 C++ 胶水，实现：

- runtime type information
- signals and slots
- properties
- invokable methods
- QML access

CMake 的 AUTOMOC 为 GUI target 自动执行这一步；原生服务关闭 AUTOMOC。

## 6. `Q_INVOKABLE`

```cpp
Q_INVOKABLE QVariantList activeSoftwareForRange(const QString& range) const;
```

它告诉 moc：这个方法可以被元对象系统按名字调用。QML 于是能写：

```qml
var rows = usageStatManager.activeSoftwareForRange("day")
```

末尾 `const` 表示方法不会修改对象的可见状态。

## 7. `Q_PROPERTY`

```cpp
Q_PROPERTY(int todaySoftwareMinutes
           READ todaySoftwareMinutes
           NOTIFY usageStatsChanged)
```

它定义一个 QML 可观察属性：读取函数是 `todaySoftwareMinutes()`，变化通知是 `usageStatsChanged()`。

若 C++ 改了成员却忘记 emit NOTIFY，QML 绑定不会更新。这是典型运行时 bug。

## 8. Signal 与 slot

Signal 表示“发生了什么”，不应该命令接收方具体怎么做。连接示例：

```cpp
QObject::connect(&app, &QGuiApplication::applicationStateChanged,
                 &mobileUsageService,
                 [&](Qt::ApplicationState state) {
  if (state == Qt::ApplicationActive)
    mobileUsageService.requestImmediateSync();
});
```

发送者不知道 lambda 内部细节；接收逻辑也不必修改 application 类。

## 9. Lambda

`[&]` 表示按引用捕获外部局部变量。lambda 是匿名函数，可直接作为 callback。要特别检查生命周期：callback 执行时，被引用对象必须仍存在。

这里 `mobileUsageService` 在 `main()` 栈上活到 event loop 结束，因此安全。

## 10. RAII

Resource Acquisition Is Initialization：资源与对象生命周期绑定。

```cpp
QSqlQuery query(db);
```

离开作用域时析构函数清理 query 内部资源。RAII 比每个 return 前手工 free 更不易泄漏。

Qt 的 `QString`、`QVariant`、containers 都使用值语义和隐式共享，普通使用无需手工 delete。

## 11. `QStringLiteral`

```cpp
QStringLiteral("tracking.enabled")
```

让字符串在编译期以 Qt 友好形式存储，减少运行时从窄字符串转换。固定 UI/SQL key 常使用它。

## 12. `QVariantMap` 与 `QVariantList`

它们是 C++ 与 QML 间的通用数据容器：map 变成 JS object，list 变成数组。

```cpp
QVariantMap row;
row.insert(QStringLiteral("appId"), appId);
row.insert(QStringLiteral("seconds"), seconds);
```

优点是跨边界方便；缺点是字段拼写不能由 C++ 类型系统完全检查。因此模型字段需要测试和集中约定。

## 13. 前置声明

Header 中写 `class FrontmostSessionRepository;`，只告诉编译器“有这种类型”。只保存指针时不需 include 完整头，可减少编译依赖；实现 `.cpp` 再 include 真正定义。

## 14. 值、引用与指针

- `QString value`：拥有一个值，Qt 容器常用隐式共享降低复制成本。
- `const QString& value`：只读引用，避免复制大对象。
- `QObject* object`：可为空、有对象身份，常用于依赖或 parent。

阅读函数签名时先判断 ownership：谁创建、谁保证活着、能否为空。

## 15. Qt 事件循环

`app.exec()` 不是什么都不做的无限循环。它从操作系统取窗口、鼠标、键盘、timer 和 queued signal 事件，再分派给 Qt 对象。

耗时数据库聚合若在 GUI thread 同步执行，会阻塞所有输入和绘制。这就是缓存、generation guard 和减少全量重算的重要性。

## English vocabulary

class, object, constructor, inheritance, access specifier, dependency injection, meta-object compiler, property notification, signal-slot connection, lambda capture, RAII, object lifetime, event loop.

## Interview sentence

“The GUI uses QObject-based application services. Constructor injection makes dependencies explicit, RAII manages resource lifetimes, and Qt’s meta-object system exposes typed C++ behavior to reactive QML bindings.”

## 练习

1. 在 `src/main.cpp` 画出 `StatsService` 的三个依赖。
2. 找一个 `Q_PROPERTY`，定位其 READ 方法、NOTIFY signal 和 emit 位置。
3. 解释为什么 `QObject*` 依赖不能随便指向函数内短生命周期临时对象。
