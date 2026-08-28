# 12 · 桌面与移动 QML 界面 / Desktop and Mobile QML UI

## 本章目标 / Learning goals

理解 QML 对象树、shell、路由、页面和复用组件如何协作，以及为什么桌面与移动共享逻辑但不强行共享布局。

## 1. 根入口选择 shell

`qml/main.qml` 创建窗口并用 `Loader` 选择：

- `DesktopAppShell`：桌面导航、无边框窗口、托盘/菜单、全局番茄与备忘覆盖层。
- `MobileAppShell`：四 tab、safe area、Usage Access onboarding、移动壁纸和分享。

共享同一 C++ composition root，但 UI shell 按 form factor 分开。

## 2. 桌面 shell 的路由

桌面 `navItems` 使用稳定字符串 page key，而不是把业务逻辑绑死在数组下标。`currentPageSource` 根据 key 选择：

- `DesktopMemoryLakePage.qml`
- `DesktopCalenderPage.qml`
- `DesktopStatsPage.qml`
- `DesktopProfilePage.qml`
- 可选 `DesktopMonthlyRecapPage.qml`
- 手动计时时切换 `DesktopTimerPage.qml`

中心 `Loader` 只实例化当前页面，shell 负责向已加载页面下发 theme/language properties。

## 3. 移动 shell

移动端同时声明 Home、Stats、History、Settings 页面，通过 `visible/enabled` 切换。它处理 Android safe-area inset、壁纸 veil、底部 tab bar、权限引导和报告未读状态。

移动页面持续存在可保留滚动/选择状态；代价是内存高于按需 Loader。这是针对少量固定 tab 的合理取舍。

## 4. 可复用组件

- 桌面基础：`SoftCard`、`SoftButton`、`WindowChrome`。
- 记忆湖：`GlassPanel`、`MemoryCard`、`MemoOverlay`、`MemoInkCanvas`、`TimeRiver`。
- 移动：`MobileGlassPanel`、`MobileFlipCard`、`MobileSwitch`、share overlays。
- JavaScript helpers：I18n、Hotkeys、AppVisual、StatsViewModel。

组件把视觉规则和交互细节集中，页面负责组合业务区块。

## 5. 声明式状态流

推荐方向：C++ model/state → QML property binding → visual result；用户动作 → signal handler → C++ command → signal/属性更新。

不要在多个组件里复制同一状态。一个值应有 single source of truth，例如主题存在 shell/settings 中，再下发页面。

## 6. 覆盖层不是普通页面

备忘黑板和番茄钟跨页面存在，因此放在 shell 的 overlay layer，而不是某个页面内部。这样导航不会销毁正在编辑的备忘或专注状态。

## 7. 性能与渲染注意

- 大页面按需加载，避免首屏同时实例化所有复杂桌面页面。
- 列表使用 delegate，避免手写重复对象。
- Canvas 适合墨迹和程序化图形，但要显式请求重绘并控制逻辑坐标。
- 统计刷新应观察数据 generation，避免固定 Timer 每次做昂贵全量聚合。
- 动效应尊重 reduced motion。

## 8. 可访问性和隐私

触控目标至少 44px、文字保持可读对比、状态不能只靠颜色、分享前提供匿名预览。界面文案应说明事实，不把休闲时间描述成失败。

## 面试表达 / Interview answer

“The desktop and mobile shells share the C++ domain layer but use separate QML compositions. The desktop lazily loads complex pages, while the mobile shell keeps four fixed tabs alive for state continuity.”

## 源码入口 / Source entry points

- `qml/main.qml`
- `qml/desktop/DesktopAppShell.qml`
- `qml/desktop/pages/`
- `qml/desktop/memorylake/`
- `qml/mobile/MobileAppShell.qml`
- `qml/mobile/pages/`

## 复习题 / Review

1. 为什么 page key 比 index 稳定？——导航排序变化不会改变业务身份。
2. 为什么备忘放 shell？——它是跨页面持久的全局覆盖层。
3. 桌面和移动为什么不共用一个布局？——输入方式、空间和生命周期不同，强行复用会增加条件分支。
