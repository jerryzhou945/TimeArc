# 10 · C++ 应用层 / C++ Application Layers

## 本章目标 / Learning goals

理解 Repository、Service、Manager 三类对象的边界，以及为何它们都可能暴露给 QML，却承担不同职责。

## 1. Repository：靠近数据源

Repository（仓储）隐藏 SQL、连接名和字段映射，让调用者用业务方法查询数据。

实际例子：

- `FrontmostSessionRepository`：范围查询、区间、今日前台排名。
- `MediaSessionRepository`：媒体范围查询、播放时长和排名。
- `ManualProjectRepository`：手动项目、会话和待办关联。
- `SettingsRepository`：GUI settings KV、迁移、服务生命周期 CLI。
- `MobileUsageRepository`：移动设备汇总和 session。

仓储并不一定都可写同一数据库。前台/媒体仓储的当前主用途是读服务数据库；自动历史仍由原生服务独占写入。

## 2. Service：组合多个数据源形成用例

Service（业务服务）处理跨仓储逻辑：

- `StatsService` 合并前台、媒体和手动项目区间，生成首页摘要。
- `DailyCardService` 把确定性统计变成卡片/回顾模型，不重新采集也不落盘。
- `MobileUsageService` 管理 Android 权限状态、同步和报告模型。
- `MobileUiService` 提供壁纸、系统栏和分享等平台 UI 能力。

Service 关注 use case，不应该知道 QML 控件坐标或 WinAPI HANDLE。

## 3. Manager：面向交互的状态门面

Manager 常保存可观察状态并响应 UI 操作：

- `CalendarManager`：日历和待办 KV 门面。
- `ProjectManager`：手动项目和累计时间。
- `TimerManager`：项目秒表，停止时写入手动项目。
- `PomodoroManager`：番茄钟状态机和设置持久化。
- `UsageStatManager`：读取服务历史、缓存、过滤和多周期聚合。

Manager 往往有 `Q_PROPERTY`、signals 和 `Q_INVOKABLE`，因此很适合作为 QML façade。

## 4. 分层不是按文件名机械判断

真实项目中边界会有历史原因。例如 `UsageStatManager` 同时承担读取缓存和聚合，`SettingsRepository` 也封装 service CLI。面试时应诚实描述当前职责，再说明理想演进，而不是强行说“完全纯净的三层架构”。

## 5. 依赖注入 / Dependency injection

`src/main.cpp` 显式构造依赖：

```text
FrontmostSessionRepository --\
MediaSessionRepository ------> StatsService ---> DailyCardService
ManualProjectRepository -----/

SettingsRepository ---> CalendarManager
SettingsRepository ---> PomodoroManager
ManualProjectRepository ---> ProjectManager
```

构造函数注入的优点：依赖可见、对象不会自己偷偷创建数据库、测试可以提供替身。

## 6. QVariant 是 QML 边界的数据货币

Qt 将 `QVariantMap` 映射为 QML JavaScript object，将 `QVariantList` 映射为 array-like list。业务层用稳定字段输出 view model，QML 负责渲染。

缺点是编译期类型检查较弱。因此字段命名必须集中、测试必须覆盖模型形状，复杂模型不能靠散落字符串随意拼接。

## 7. 典型请求链

“显示今天应用排名”：

```text
QML page
 -> UsageStatManager.activeSoftwareForRange("day")
 -> read cached frontmost/media records
 -> normalize and union intervals
 -> QVariantList of app rows
 -> QML delegate renders name/icon/time
```

“生成今日卡片”：QML/调用者 → `DailyCardService` → `StatsService` + frontmost intervals → deterministic `QVariantMap` → card component。

## 面试表达 / Interview answer

“Repositories isolate persistence, services compose domain use cases, and managers expose observable interaction state to QML. The boundaries are pragmatic rather than ceremonial, and dependencies are assembled explicitly in `main.cpp`.”

## 源码入口 / Source entry points

- `src/services/*_repository.h`
- `src/services/stats_service.h`
- `src/services/daily_card_service.h`
- `src/services/*_manager.h`
- `src/main.cpp`

## 复习题 / Review

1. Repository 与 Service 的区别？——前者隐藏数据访问，后者组合数据完成用例。
2. 为什么 Manager 常有 `Q_PROPERTY`？——它需要向 QML 提供可观察交互状态。
3. QVariant 的主要风险？——字段错误延迟到运行时暴露，需要契约和测试补强。
