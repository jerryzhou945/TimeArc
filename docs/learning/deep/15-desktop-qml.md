# 15｜桌面 QML：Shell、路由、组件与响应式界面

> 本章目标：从 `qml/main.qml` 到桌面页面，理解 QML 如何声明界面、绑定状态、加载页面并处理平台窗口差异。
> English focus: **declarative UI, property binding, component, Loader, shell, responsive layout**.

## 1. QML 与命令式 UI 的差别

QML 更像描述“界面应该是什么”：

```qml
Text {
    text: pomodoroManager.running
          ? pomodoroManager.remainingText
          : qsTr("Ready")
}
```

当依赖 property 变化，binding 自动重新计算。开发者不是每秒手动寻找 Text 再 setText。

## 2. root `ApplicationWindow`

`qml/main.qml` 是整个可视树根。它负责：

- 窗口尺寸、最小尺寸、字体和颜色；
- Android/mobile preview 与 desktop shell 选择；
- safe area；
- Windows frameless chrome 与 macOS native traffic lights；
- 关闭、托盘、恢复、退出；
- 保存/恢复窗口 geometry；
- 加载 desktop/mobile shell。

这是真正的 **application shell（应用外壳）**，不等同于某一个业务页面。

## 3. shell 选择

```qml
property bool runningOnAndroid: Qt.platform.os === "android"
property bool useMobileShell: runningOnAndroid || mobilePreview || width <= 720

Loader {
    sourceComponent: useMobileShell ? mobileShell : desktopShell
}
```

`Loader` 只实例化当前选择的 component。它不是把 desktop 和 mobile 都隐藏起来，而是按需创建，减少不必要对象和互相干扰的状态。

## 4. property binding 与普通赋值

```qml
property bool nightMode: settingsRepository
    ? settingsRepository.getBool("night_mode", false)
    : false
```

注意：调用函数的 binding 不一定知道 repository 内部何时变化，除非另有 signal 触发重新赋值；而绑定到带 NOTIFY 的 QObject property 能天然更新。理解这一点能解释“设置已保存但页面没刷新”的常见 bug。

## 5. `DesktopAppShell` 的责任

`qml/desktop/DesktopAppShell.qml` 管理：

- 当前 page key 与 sidebar selection；
- 白天/夜晚主题和 accent；
- 导航列表；
- 页面 Loader；
- timer、memo、recap 等 overlay；
- tray commands 与 global hotkeys；
- 向 page 传递参数和接收 signals。

Shell 管的是跨页面状态；具体统计卡片或日历网格留在 page/component。

## 6. 路由为什么使用 page key

导航项中同时保存：

```qml
{
    title: "统计",
    subtitle: "Stats",
    page: "stats",
    icon: ...
}
```

`page` 是稳定 routing key，index 只是显示顺序。若直接用 index 代表业务页面，插入一个导航项会让所有条件判断错位。

这叫 **stable identifier（稳定标识符）**。

## 7. 页面 Loader

典型路由流程：

```text
用户点击 sidebar item
  → selectedIndex / selectedPage 更新
  → currentPageSource 重新计算
  → Loader 销毁旧 page、创建新 page
  → page Component.onCompleted 加载数据
```

需要注意 Loader 生命周期：离开页面后 item 可能被销毁，不能把必须长期保存的业务状态只存在 page 局部 property 中。

## 8. 可复用组件

`qml/desktop/components/` 有：

- `SoftCard.qml`
- `SoftButton.qml`
- `SoftPill.qml`
- `WindowChrome.qml`
- icon、tag、hotkey、i18n 等 JS helpers。

复用组件不仅减少代码行数，更重要的是集中 hover、pressed、disabled、focus、theme 和 spacing 规则。

## 9. 设计 token 与单一事实源

Memory Lake 使用 `MemoryLakeStyle.qml` 集中定义颜色、边框、透明度和尺寸。页面接收 style，而不是散落几十个相似 hex。

```text
accent seed / night mode
          ↓
MemoryLakeStyle tokens
          ↓
panel, nav, card, memo, overlay
```

这使主题变化一致，也让视觉回归更容易定位。

## 10. platform-specific chrome

Windows 使用 frameless window + 自绘 `WindowChrome`，但保留 min/max hints 和原生 rounded corner integration。macOS 保留 native window/traffic lights，同时把内容延伸进透明 title area。

不能用“一套自绘按钮”强行覆盖所有平台，因为窗口行为与用户习惯本身就是平台 contract。

## 11. 关闭不一定等于退出

`onClosing` 中：

- 先 flush memo pending save；
- 保存正常窗口 geometry；
- macOS 按平台惯例关闭窗口但进程可留在 menu bar/Dock；
- Windows/Linux 可拦截关闭并 hide to tray；
- 显式 quit 时 `forceQuit` 绕过 hide。

这是一个小型 lifecycle state machine。若没有 `forceQuit`，从 tray 菜单点退出可能再次被 close handler 拦截，永远退不掉。

## 12. SafeArea 与移动/桌面差异

Android 要处理 status/navigation insets；macOS expanded client area 又不应额外预留普通 top inset。`topPadding/bottomPadding/...` 根据平台选择。

响应式不是只改宽度；还包括输入方式、系统区域、字体、窗口 chrome 和导航模型。

## 13. QML 性能基础

需要警惕：

- binding loop；
- 在频繁 binding 中调用昂贵 C++ 查询；
- 大列表不用 model/delegate；
- 不可见重组件仍全部实例化；
- Canvas 每次 repaint 整幅大图；
- 大量 blur/effect 叠加。

TimeArc 使用 Loader、独立 model/helper、Canvas threaded strategy 和资源包来控制部分成本，但仍应通过 profiler 验证。

## 14. 面试表达

> The root QML window selects a desktop or mobile shell and owns platform window lifecycle. The desktop shell keeps navigation and cross-page state, while pages and reusable components stay focused. Stable page keys decouple routing from visual order, and design tokens keep theme behavior consistent. C++ services are consumed through Qt properties, invokables, and signals.

## 15. 本章练习

1. 为什么 Loader 比 `visible: false` 更适合重页面？
2. stable page key 比 index 有什么优势？
3. 找一个 QML binding，列出它的依赖。
4. 描述 Windows close-to-tray 与 macOS close-window 的差别。

下一章：[Android 与移动端 UI](16-mobile-android.md)
