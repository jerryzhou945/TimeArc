# 13 · 统计、区间与应用身份 / Statistics, Intervals, and App Identity

## 本章目标 / Learning goals

理解原始 session 怎样变成准确统计，以及应用路径、浏览器站点、显示名和图标怎样组成稳定身份。

## 1. 统计的基本单位是区间

每条记录至少有 `[start, end)`。查询一个周期时先裁剪到周期边界，再按业务 key 分组、排序、合并，最后求 union duration。

使用 half-open interval `[start, end)` 可以让相邻区间 `[0,10)` 与 `[10,20)` 无重叠歧义。

## 2. 多数据源聚合

TimeArc 的统计可能包含：

- 自动前台区间。
- 自动媒体区间。
- 手动项目区间。
- Android device usage summaries/sessions。

“自动活跃总时长”需要合并前台与媒体；“手动项目时长”是另一种用户声明事实，页面必须明确口径，不能随意相加并称为屏幕时间。

## 3. `StatsService` 与 `UsageStatManager`

`StatsService` 提供首页级今日摘要和区间 union。`UsageStatManager` 支持 day/month/year/all、应用排名、前台/音频拆分、月度序列、会话段、读层过滤和增量刷新。

`recordsGeneration()` 只在底层记录变化时递增，UI 可以跳过没有新数据的重算。

## 4. 时间边界与 DST

“今天”不是 `now - 86400`。应从本地日历的当天起点构造范围，让 Qt/平台时区规则处理夏令时（DST）。月、年同理使用日历边界，而不是固定秒数。

**English:** calendar boundary, local time zone, daylight saving time, range clipping.

## 5. 稳定 app identity

Windows 当前主要以规范化 executable path 作为稳定 `app_id`。展示名不是身份：用户可以修改 display name，但历史关联不能因此改变。

浏览器需要额外站点归因。适配器可根据受限标题标记把 Chrome/Edge 会话识别为 YouTube、Bilibili、Spotify Web 等站点身份。

## 6. Adapter 系统

`src/services/adapters/` 分为 desktop app、website 和 activity adapters。Adapter 输出友好名称、分类、图标提示或策略元数据，但不能随意改写底层时间事实。

新增支持通常要：定义匹配条件 → 注册 adapter → 提供可审计图标资产 → 添加正反测试 → 验证不会误匹配相似进程/标题。

## 7. 显示名与图标 fallback

推荐优先级：

1. 用户自定义 display name。
2. adapter/系统解析的友好名称。
3. executable/package derived name。

图标类似：系统原生图标 → 已登记站点资源 → 通用 initial fallback。稳定 identity 与 presentation metadata 必须分离。

## 8. 读层过滤不删除历史

隐藏应用、合并窗口、分类、标题脱敏等设置由 `UsageStatManager.setReadFilters()` 作用于派生视图。它们不删除或重写服务数据库，因此可撤销。

## 9. 确定性卡片

`DailyCardService` 从统计模型生成模板化卡片和月度回顾。相同输入应产生相同输出；没有数据就返回空态，不编造“人格”或活动。

## 面试表达 / Interview answer

“The aggregation layer clips sessions to calendar ranges, groups by stable identity, and unions overlaps before summing. Display names and icons are presentation metadata, so users can customize them without breaking historical keys.”

## 源码入口 / Source entry points

- `src/services/stats_service.cpp`
- `src/services/usage_stat_manager.cpp`
- `src/services/daily_card_service.cpp`
- `src/services/app_identity_policy.h`
- `src/services/adapters/`
- `qml/desktop/pages/StatsViewModel.js`

## 复习题 / Review

1. 为什么“今天”不能简单减 86400 秒？——DST 日可能不是 24 小时。
2. 自定义显示名为什么不能改变 app_id？——显示信息可变，历史主键必须稳定。
3. 读层过滤为什么优于删记录？——安全、可撤销且保持原始证据。
