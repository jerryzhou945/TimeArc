# 统计页 · 后端性能优化（打开卡顿根因与修复）

> 配套文档：`docs/stats-functional-replication.md`（功能/数据）、
> `docs/stats-render-pipeline-replication.md`（渲染）、
> `docs/stats-backend-data-gaps.md`（后端缺口与接入计划，含 §12 实测登记）。
> 范围：本文记录**统计页打开时 ~10s 卡顿 + 每 5s 持续卡顿**的根因定位与修复。
> 修复点全部落在**共享只读数据路径** `src/services/usage_stat_manager.{h,cpp}` +
> 统计页 `qml/desktop/pages/DesktopStatsPage.qml` 的重算管线，因此**全 app 受益**
> （首页/记忆湖同样经 `UsageStatManager` 读 JSONL + `aggregateSoftware` 聚合）。
> Track：**C（修已观察到的错误）/ 与 B 统计页同 PR**。提交：`perf(stats): …`（PR #27）。

---

## §0 现象

- 点击导航「统计」打开统计页，**UI 冻结约 10 秒**。
- 更糟：页面的 5s 刷新 `Timer` 每次都重做整套工作（≈7s），其周期（5s）短于工作耗时，
  导致**长期处于"未响应"状态**，而非仅开页一次。
- 数据规模（开发机实测）：`%LOCALAPPDATA%/TimeArc/usage/usage_records.jsonl`
  ≈ **16 MB / 46,433 行**。

## §1 测量（UI 线程同步耗时）

> 方法：在 `DesktopStatsPage.rebuild()` 各后端调用前后、以及 `Component.onCompleted`
> 里用 `Date.now()` 打 `console.warn("STATSPERF …")`（捕获进 `harness-qt.log`），
> 临时插桩、验证后已移除。

| 阶段 | 修复前 | 修复后 |
|---|---|---|
| `refresh()`（解析 JSONL） | **3.9 s** | 增量后近 0（无新行时） |
| `activeSoftwareForWindow(week)` | **1.4 s**（冷 1.6s） | 冷 0.30s / **暖 42 ms** |
| `foregroundSegmentsForWindow` | 0.28 s | 18 ms |
| `focusStatsForWindow` | **1.0 s** | 37 ms |
| `prev activeSoftwareForWindow`（环比） | 0.14 s | ~20 ms |
| `memoryLakeDay`（饼） | 15 ms | 15 ms |
| **开页合计**（refresh + rebuild×?） | **≈ 10 s** | **≈ 0.56 s** |
| **数据变化时单次 rebuild** | ≈ 2.9 s | **≈ 0.13 s** |
| **空闲 5s tick** | ≈ 2.9 s（每次） | **跳过（0）** |

开页约 18×、变更重算约 22× 提速；空闲 tick 归零。数据未变（周总时长/排行/饼一致）。

---

## §2 根因与修复（四项叠加，全在 UI 线程）

### §2.1 `refresh()` 每次全量重解析整个 16MB JSONL（最大单项 + 反复发生）
- **根因**：`UsageStatManager::refresh()` 原实现每次调用都 `readLine()` 遍历全文件、
  对每行 `QJsonDocument::fromJson` + `parseRecordObject`，重建整个 `m_records`。
  开页调用一次（3.9s），且 5s `Timer` 每次都再来一遍。
- **修复（增量解析）**：service 对 JSONL 是 **append-only**，故按字节增量解析——
  跟踪上次已解析到的字节偏移与文件大小，仅解析**新追加的完整行**（末尾无 `\n` 的半写行
  本次跳过、下次再读）；文件**变小**（轮转/截断）才全量重读。空闲时近乎零成本。
  - 状态成员：`m_recordsParsedOffset` / `m_recordsParsedSize`（`usage_stat_manager.h`）。
  - 用**非 `QIODevice::Text`** 模式打开：按原始字节统计偏移（Text 会折叠 `\r\n` 致偏移与磁盘不符）。
  - `usage_current.json`（实时快照，≤459B）仍每次重读（极小）。

### §2.2 `aggregateSoftware()` 的 O(N²) 拷贝
- **根因**：聚合循环里 `Aggregate aggregate = grouped.value(key); … ; grouped[key] = aggregate;`
  ——每条记录把累积结构（含不断增长的 `QVector<UsageInterval> intervals`）**深拷出 + 拷回**。
  对一周内数千条记录的重度前台 app，是 O(K²)，构成 `activeSoftwareForWindow` 的那 ~1.4s。
- **修复**：改为引用就地累加 `Aggregate& aggregate = grouped[key];`，去掉拷回。
  （`foregroundSegmentsImpl` 本就用引用 `AppSessions& app = grouped[key]`，所以只 18ms——对照印证。）

### §2.3 `classifyActivity` / `activityGroupKey` 的 per-record 重复计算
- **根因**：两者对每条记录做 `.toLower()` + 十余次 `containsAny` 子串扫描（外加浏览器记录的
  站点目录 `matchByWindowTitle`），且被多次聚合（active / segments / daily / focus / prev）
  对**同一批记录反复调用**。
- **修复（记忆化）**：两者是**纯函数 + 确定性**（站点目录编译期静态），加**进程内 `static QHash`
  缓存**，键 = `appId\x1f appName\x1f path\x1f windowTitle`（classify 再前缀 groupKey）。
  无需失效；设 20 万软上限防极端无界增长。`classifyActivity` 拆成 `classifyActivityImpl`（原体）
  + 记忆化包装。`focusStatsForWindow` 1.0s→37ms 主要来自此。

### §2.4 `rebuild()` 每个 5s tick 都重算 + 开页双重重算
- **根因**：`refresh()` 每 5s emit `usageStatsChanged` → `Connections` 触发 `rebuild()`，
  即便**没有新数据**也重做整套聚合；且 `Component.onCompleted` 既 `refresh()`（信号触发一次）
  又**直接** `rebuild()`（开页共 2 次）。
- **修复**：
  - 新增 `Q_INVOKABLE int UsageStatManager::recordsGeneration()`——仅当 `m_records` **真**变化
    （全量重读或增量追加）时自增；live current 快照变化不计。
  - 统计页 `rebuild()` **守卫**：`(recordsGeneration, range, periodOffset)` 三者都未变则直接返回
    （记于 `_builtGen/_builtRange/_builtOffset`）。空闲 tick 不再做昂贵聚合。
  - `Component.onCompleted` 仅 `refresh()`（其信号同步触发一次 guarded rebuild），不再直接 `rebuild()`。

---

## §3 新增 / 变更的后端表面（契约）

| 符号 | 文件 | 说明 |
|---|---|---|
| `recordsGeneration()` `Q_INVOKABLE int` | `usage_stat_manager.h` | 数据代际；UI 据此跳过无新数据的重算。仅 `m_records` 变化时自增。 |
| `refresh()`（增量语义） | `usage_stat_manager.cpp` | append-only 增量解析；size 变小→全量重读；半写尾行延后。**幂等且便宜**。 |
| `m_recordsGeneration / m_recordsParsedSize / m_recordsParsedOffset` | `usage_stat_manager.h`（private） | 增量解析状态。 |
| `aggregateSoftware()`（引用累加） | `usage_stat_manager.cpp` | `Aggregate& = grouped[key]`，消除 O(N²)。 |
| `activityGroupKey` / `classifyActivity`（记忆化） | `usage_stat_manager.cpp`（匿名命名空间） | 纯函数 static 缓存；`classifyActivityImpl` 为原体。 |

> 安全边界不变：仍只读 JSONL（`UsageStatManager`），不加 IPC/socket/共享内存；
> db_smoke 契约不变（`DailyCardService` 不引用 USM 符号）；统计页只读、零 usage/SQLite 写入。

---

## §4 不变量 / 给后续贡献者的规则

1. **不要在 UI 线程全量重解析 JSONL**。文件 append-only → 走增量；只有 size 变小才全量重读。
2. **聚合累加用引用**（`map[key]` / `Aggregate&`），切勿 `value()` 拷出再拷回——含 `QVector` 的
   结构会被深拷成 O(N²)。
3. **per-record 的纯分类函数要记忆化**（`classifyActivity` / `activityGroupKey` 类）；它们确定性、
   可进程内静态缓存、无需失效。
4. **UI 重算要按数据代际去重**：拿 `recordsGeneration()` + 视图键（range/period）守卫，
   5s 刷新管线在无变化时必须近乎零成本。
5. 新增「窗口聚合」沿用 `[startUnixSec, endUnixSec]` 闭区间口径（与 `matchesRange` 当前周期一致，
   见 `stats-backend-data-gaps.md`）。

---

## §5 验证方法

- 临时 `console.warn("STATSPERF …")` 计时插桩（`Date.now()` 包裹各后端调用），跑 `launch.cmd`
  后读 `%LOCALAPPDATA%/TimeArc/logs/harness-qt.log` 的 `STATSPERF` 行；验证后移除插桩。
- 观察空闲 tick 出现 `rebuild SKIP`（守卫生效）、开页合计从 ~10s 降到 ~0.56s。
- 数据正确性：对比修复前后周/月/年总时长、排行、饼一致（增量解析不得改变结果）。
- 收尾：`build.py` 干净、`scan_qt_log` 0 warning、`harness_check` exit 0。

---

## §6 与既有文档关系

- 数据缺口/接入：`docs/stats-backend-data-gaps.md`（§7 G-1..G-10、§12 实测登记）。
- 功能/渲染：`docs/stats-functional-replication.md` / `docs/stats-render-pipeline-replication.md`。
- 本文聚焦**性能**：上述文档定义"接什么数据"，本文定义"如何便宜地反复取它"。
