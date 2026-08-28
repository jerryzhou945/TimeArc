# 03 · QML 与 Qt Quick / QML and Qt Quick Foundations

## 1. QML 是什么

QML 是声明式 UI 语言。你描述对象树、属性关系和事件反应，Qt Quick scene graph 负责实际绘制。

```qml
Rectangle {
    width: 320
    height: 180
    color: mobileTheme.surface

    Text {
        anchors.centerIn: parent
        text: "TimeArc"
    }
}
```

外层 Rectangle 是 parent，Text 是 child。对象树同时决定视觉嵌套、坐标基准和生命周期。

## 2. `id` 与 property

```qml
Rectangle {
    id: root
    property string currentTab: "home"
    readonly property bool wallpaperActive:
        wallpaperSource.toString().length > 0
}
```

`id` 是当前 QML component 内的编译期引用名，不是普通字符串属性。`property` 声明响应式状态；`readonly property` 只能由 binding 计算，外部不能赋值。

## 3. Property binding

```qml
visible: root.currentTab === "home"
```

这不是一次性赋值。QML 记录依赖，`currentTab` 改变后重新计算 `visible`。

若后来写 `visible = true`，会用命令式赋值替换原 binding。初学者常因此发现界面不再跟随状态。

## 4. Signal handler

```qml
onClicked: root.currentTab = "stats"
```

Button 发出 `clicked` signal，QML 用 `onClicked` 命名规则处理。复杂逻辑应调用函数或 C++ service，不要把几十行数据库逻辑塞进 handler。

## 5. Anchors 与 Layout

```qml
anchors.left: parent.left
anchors.right: parent.right
anchors.bottom: tabBar.top
```

anchors 描述几何关系。不要同时对同一方向设置互相冲突的 anchor 和手动 `x/width`。

Row/Column/Qt Quick Layouts 用于规则排列；anchors 更适合与父对象或少数兄弟对齐。

## 6. Component 与实例

一个 `.qml` 文件定义一种 component。写：

```qml
MobileHomePage {
    anchors.fill: parent
    visible: root.currentTab === "home"
}
```

就是创建一个实例并给它的公开 properties 赋值。组件应隐藏内部绘制细节，只暴露页面真正需要的输入、输出 signals。

## 7. Loader

桌面 shell 使用：

```qml
Loader {
    id: pageLoader
    source: currentPageSource
}
```

Loader 根据 URL 动态创建一个 component。好处是大型页面按需加载；代价是 `item` 可能为 null，切页会销毁旧实例，状态需要决定放在页面还是 shell/service。

## 8. `Connections`

```qml
Connections {
    target: typeof mobileUsageService !== "undefined"
            ? mobileUsageService : null
    function onDataChanged() {
        root.refreshReportNotification()
    }
}
```

用于监听不是当前对象自身的 signals。跨平台对象可能不存在，所以 target 要允许 null。

## 9. JavaScript 在 QML 中的角色

QML 支持 JS 表达式和函数，但不是浏览器 DOM 环境。适合：格式化、轻量 view-model 转换、交互状态。复杂 SQL、文件 IO、平台 API 和大规模聚合应留在 C++。

TimeArc 将 `StatsViewModel.js` 单独测试，避免统计页面散落相同转换逻辑。

## 10. `Qt.resolvedUrl`

相对资源路径应从当前 QML 文件解析：

```qml
Qt.resolvedUrl("pages/DesktopStatsPage.qml")
```

这在 QRC module 内比拼裸字符串更稳定。

## 11. Context property

C++ 注册：

```cpp
engine.rootContext()->setContextProperty("usageStatManager",
                                         &usageStatManager);
```

QML 使用：

```qml
var apps = usageStatManager.activeSoftwareForRange("day")
```

名称是运行时契约。拼错时 QML 报 ReferenceError，不会在 C++ 编译阶段提示。

## 12. 状态应该放哪里

- 纯视觉临时状态：component 内，如 hover、展开。
- 跨页面 UI 状态：shell 或 settings repository。
- 业务状态：C++ manager/service。
- 自动历史：service database，QML 只读派生模型。

把状态放错层会导致切页丢失、重复真值或难以测试。

## 13. Canvas

QML Canvas 提供类似 HTML canvas 的 2D context。绘制不会因普通 property 变化自动发生；需要 `requestPaint()`，并在 `onPaint` 使用当前模型重建画面。

Canvas 是栅格目标。缩放、device pixel ratio、logical coordinate 与实际 texture size 不一致时会模糊或裁切，备忘章节会深入。

## 14. Safe area 与移动端

Android 状态栏/导航栏可能覆盖内容。`MobileAppShell` 从 `SafeArea.margins` 计算 top/bottom inset，页面布局不能假设屏幕所有像素都可用。

## 15. 性能直觉

- Binding 应便宜，避免其中每次执行大聚合。
- 不可见不一定未实例化；移动四 tab 都存在。
- Loader 可减少 desktop 首屏对象数。
- Repeater/ListView delegate 数量要关注。
- 动画属性应尽量由 scene graph 高效处理。

## English vocabulary

declarative UI, object tree, property binding, signal handler, anchor, component instance, lazy loading, context property, scene graph, safe-area inset, device pixel ratio.

## Interview sentence

“QML provides the declarative presentation layer. Bindings react to QObject notifications, desktop pages are loaded lazily, and mobile tabs remain instantiated to preserve state. Heavy aggregation stays in testable C++ services.”

## 练习

1. 找到 `qml/main.qml` 中 desktop/mobile shell 的 Loader。
2. 在 `MobileAppShell.qml` 找一个 binding 和一个命令式赋值，解释区别。
3. 找出一个跨页面状态，说明为什么它放在 shell 而非某个 page。
