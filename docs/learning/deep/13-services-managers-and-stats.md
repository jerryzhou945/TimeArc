# 13｜应用逻辑层：Services、Managers 与统计聚合

> 本章目标：理解 repository 之上怎样组合数据、管理交互状态，并重点掌握 interval union。
> Source map: `stats_service.*`, `timer_manager.*`, `pomodoro_manager.*`, `project_manager.*`.

## 1. 三层不要混在一起

```text
Repository  数据如何读写
Service     多个数据源如何形成产品答案
Manager     长生命周期交互状态如何变化
```

命名不是绝对规律，但这能帮助初学者定位责任。

## 2. StatsService 是组合层

构造函数接收三个依赖：

```cpp
StatsService::StatsService(
    FrontmostSessionRepository* frontmostRepository,
    MediaSessionRepository* mediaRepository,
    ManualProjectRepository* manualProjectRepository,
    QObject* parent)
```

这叫 **constructor injection（构造函数注入）**。StatsService 不在内部偷偷 `new` repository，因此依赖清楚，也更容易测试。

它提供：

- 今日前台 active seconds；
- 今日媒体播放 seconds；
- 今日手动项目 seconds；
- recorded coverage；
- 各类 ranking；
- home summary；
- duration formatting。

## 3. 为什么不能把三个总时长直接相加

假设 10:00–10:30 Spotify 播放，同时 10:00–10:30 VS Code 前台：

```text
frontmost = 30 min
media     = 30 min
真实覆盖  = 30 min，不是 60 min
```

因此 recorded coverage 要计算 intervals 的 **union（并集）**。

## 4. interval union 算法

`StatsService::calculateUnionDuration()`：

1. 删除 `end <= start` 的无效区间；
2. 按 start 排序，start 相同再按 end；
3. 用 `[currentStart, currentEnd]` 保存当前合并段；
4. 新 interval 若 `start <= currentEnd`，扩展 end；
5. 否则结算旧段，开始新段；
6. 循环后结算最后一段。

例子：

```text
输入：[1,5] [3,7] [10,12] [11,15]
合并：[1,7] [10,15]
总长：6 + 5 = 11
```

排序复杂度 O(n log n)，线性合并 O(n)，整体 O(n log n)。

## 5. 为什么先 clip 到查询范围

repository 返回的区间可能横跨今天边界。StatsService 先：

```cpp
start = std::max(queryStart, sessionStart);
end   = std::min(queryEnd, sessionEnd);
```

再 union，才能确保“今日覆盖”不把昨天部分算进来。

## 6. 数值与展示文本同时返回

`getHomeSummary()` 同时放入：

```text
frontmostActiveSec   原始值，适合排序/图表
frontmostActiveText  已格式化，适合快速展示
```

初学者常犯错：把 `"2h 3m"` 当作业务数据，然后再在 QML 解析。正确方向是保留 numeric source of truth，文本只是 presentation。

## 7. Manager 处理有状态交互

### TimerManager

负责通用 timer 生命周期和 elapsed updates。

### PomodoroManager

负责番茄钟阶段、倒计时、开始/暂停/重置、完成通知，并只通过 SettingsRepository 保存必要状态，不触碰 service disk contract。

### ProjectManager

协调手动项目的开始/停止和 repository 记录。

### CalendarManager

把设置与日历视图所需状态组合起来。

Manager 通常继承 `QObject`，使用 property、signal、slot 让 QML 响应状态变化。

## 8. QObject ownership

Qt 对象可以通过 parent-child 管理生命周期。当前 `main.cpp` 中许多 manager 是栈对象，生命周期覆盖 `app.exec()`；依赖指针在这段期间有效。

需要理解：

- C++ 栈对象在 `main` 退出时析构；
- QML context property 不拥有传入指针；
- 因此 C++ 对象必须比 QML engine 活得足够久；
- 动态 QObject 常用 parent 自动删除。

## 9. signal/slot 如何替代轮询 UI

Manager 状态改变时发 signal，例如 `remainingSecondsChanged`。QML property binding 自动重新计算。这样 UI 不需要每帧询问 C++。

```text
C++ state change
   → emit xxxChanged()
   → Qt meta-object dispatch
   → QML binding reevaluates
   → visible text/progress updates
```

## 10. error policy

StatsService 发现 dependency null 时返回安全空值并 `qWarning()`。这适合展示型查询：页面还能打开，但日志留下诊断。

对于 destructive write 或迁移，静默返回 0 就不够，应显式向上层传播失败。错误策略必须根据操作风险选择。

## 11. 可演进方向

随着数据量增加：

- union 可更多下推 SQL；
- ranking 可做时间桶和缓存；
- home summary 可一次 query 获取，减少 round trips；
- manager 可通过 interfaces 注入 fake repositories；
- QVariantMap 可替换为强类型 DTO/model。

这些不是当前已实现功能，而是基于现有分层自然推导的优化方向。

## 12. 面试表达

> Repositories expose source-specific queries, while `StatsService` combines them into product metrics. For recorded coverage we merge clipped foreground and media intervals instead of summing durations, because sources can overlap. Stateful interactions such as Pomodoro and manual projects live in QObject managers that notify QML through signals.

## 13. 本章练习

1. 手算 `[0,5] [2,3] [5,8] [10,11]` 的 union duration。
2. 为什么 `start <= currentEnd` 可以合并相邻边界？
3. 分别举一个应放 Repository、Service、Manager 的新功能。
4. Context property 是否拥有 C++ 对象？这对生命周期有什么要求？

下一章：[main.cpp 与 Qt/QML 桥梁](14-main-and-qml-bridge.md)
