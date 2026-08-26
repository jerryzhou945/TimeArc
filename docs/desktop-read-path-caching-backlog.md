# 桌面端读路径缓存待办（Desktop read-path caching backlog）

> 配套：[`stats-backend-performance.md`](stats-backend-performance.md)（统计页那轮修复 +
> §4 的四条不变量）。本文是 2026-08-26 对**桌面 UI 全量**做的一次"什么可以缓存"审计，
> 记录审计结论与修法。**§1–§3 已全部落地**（2026-08-26 三个会话）。简洁版 known gaps 见 `.harness/state/open-issues.md`
> （行数受 harness 100 行预算约束，故细节放这里）。
>
> 已修（不在本文）：首页 / 记忆湖 5s tick 的 `recordsGeneration()` 去重守卫 —— 见
> `.harness/journal/errors/20260826-084500-C-home-memorylake-unguarded-rebuild.md`。

## 1. 已修（2026-08-26，track A · session `20260826-1700-A-read-path-caching`）

原 §1 的四项高收益缓存都已落地，本节只留结论；细节见会话日志。

| 项 | 改法 | 实测（同一数据集，x5 循环） |
|---|---|---|
| `SettingsRepository::getValue` 每次打 SQL | 首次读把整张 settings 表装进**进程级** map，`setValue` 写通，`invalidateCache()` 供整库恢复后作废 | x200 次 1 ms → 0 ms（本地热库已低于计时分辨率；真正的收益在委托绑定与慢盘） |
| `allApps()` 按窗口重算 | 按 `m_recordsGeneration` 记忆化（该整数已覆盖记录/过滤/规则/语言四种变化） | 23 ms → 11 ms（= 1 次真算 + 4 次命中） |
| `matchesRange` 逐记录造 `QDateTime` | 装载时预存 `UsageRecord::localDate`；range 每次聚合解析成一个 `DateWindow`，不再逐记录解析 | `activeSoftwareForRange("day")` 29 ms → **3 ms** |
| 图标解析跑在缓存命中之前 | 像素图缓存改用**原始 id** 做键；`resolveIconFile` 自身也记忆化 | Windows 上每次命中省下最多 3 次注册表打开 + 一次 PATH 搜索 |

两条留给后来者的注意：

1. **`SettingsRepository` 的缓存必须是进程级的，不能是每实例一份。** 代码里确实会
   同时存在多个实例（`tests/db_smoke.cpp` 用第二个实例模拟「重启后重读」）。做成成员
   变量时，A 写入后 B 仍拿着自己那份陈旧快照——db_smoke 当场抓到了。
2. **预存 `localDate` 要跟着系统时区失效。** `refreshHistoryFromSqlite` 比对
   `QTimeZone::systemTimeZoneId()`，变了就整表重载。DST 不受影响（时区规则按时刻历史
   应用，过去某刻的本地日不会因入夏令时而改变），但用户中途改时区会。

## 2. 已修（2026-08-26 第二轮，session `20260826-1721-A-read-path-caching-2`）

| 项 | 改法 |
|---|---|
| 日历每次调用都重解析整块 JSON | `allTodosMap` / `allAnniversaries` / `manualPhotoMap` 按**原始字符串**记忆化；聊天图片改为「按日索引解析一次」，`buildPhotoLookup` 复用同一份索引 |
| `ProjectManager::timeEntriesForDate` 一天一条 SQL | 按 dateKey 缓存，构造时连自己的 `projectsChanged` 清空；顺带把两处 `value()` 拷出 / `[key]=` 拷回改成引用累加（perf 文 §2.2 禁止的模式） |
| `AppVisual` 纯函数无缓存 | `siteVisual` / `appColor` / `englishDisplayName` / `ambientTone` / `coverTone` 走共享 `_cached()`（`.pragma library`，全 importer 共用） |
| 静态 Canvas 纹理每帧 resize 整幅重画 | `GridTexture` / `MemoDotTexture` 只画一格（瓦片），交给 `Image.Tile` 平铺；resize 对绘制零成本 |

## 3. 加缓存前必读的两个坑（本轮实际踩到）

1. **缓存会把「调用方可以随手改返回值」从无害变成脏数据。** 日历有两处就地改：
   `saveTodosForSelectedDate` 的 `map[key] = arr`、`addAnniversaryFromPopup` 的
   `list.push(...)`。旧实现每次重新解析所以改了无所谓，加缓存后就是污染。
   加任何缓存前，先把**所有调用方**过一遍有没有就地写；写路径要显式拿副本
   （已加 `todosMapForEdit()` / `.slice()`）。
2. **`Canvas.toDataURL()` 不能直接写在 `onPainted` 里。** 它会同步逼出一次绘制，
   那次绘制又发 `painted` → 无限递归（实测 `RangeError: Maximum call stack size
   exceeded`）。两个纹理组件都用 `exporting` 重入标志挡住。

另见第一轮（`20260826-1700-A-read-path-caching`）的两条：`SettingsRepository`
的缓存必须是进程级、预存 `localDate` 要跟着系统时区失效。

## 4. 验证手法（三轮共用，供后来者照抄）

- **后端等价**：临时 `console.warn` 把**固定过去窗口**的聚合结果 dump 出来，改前改后
  逐字节比对（过去的记录不会再变，所以任何差异都是 bug；当月/当日会漂，单独说明）。
- **渲染等价**：`QT_QPA_PLATFORM=offscreen qml` 把新旧组件并排 `grabToImage` 存 PNG，
  比对哈希；再解一遍像素确认「不是两张都空白」。
- **测试要先证明它会失败**：`timeEntriesForDate` 的新用例，先把失效逻辑注释掉跑一遍，
  确认报 "served a stale cached day"，再恢复。
