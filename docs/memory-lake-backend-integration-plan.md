# 记忆湖 · 后端数据接入完整计划（Phase E 展开）

> 前置：本文是 `docs/memory-lake-implementation-plan.md` §4 / Phase E 的**完整展开**，
> 也对应 `.harness/state/open-issues.md` 的「Memory Lake real-data wiring (phase E)」。
> 现状：前端（`qml/desktop/memorylake/` + `qml/desktop/pages/DesktopMemoryLakePage.qml`）
> 视觉/交互/动效已 1:1 完工，**全部内容来自写死的 `MemoryLakeMock.js`**。本文逐处列出
> 「写死内容 → 真实来源 → 需要的改动 → 风险」，并按优先级排出落地顺序。
>
> 开工走 **Track B**：`python .harness/tools/preflight.py --track B`，
> 收尾 `python .harness/tools/harness_check.py`。
> 硬边界（CLAUDE.md / rule 07）：**不碰服务端磁盘契约、不加 IPC、不改 schema；
> 文案走本地确定性模板，绝不把原始日志喂 AI；MVP 无聊天/截图/OCR/原始音频/浏览器历史。**
>
> **实现期凡与本计划假设不符，必须记入 [`docs/memory-lake-integration-issues.md`](memory-lake-integration-issues.md)（§10 数据安全法规）。**

---

## 0. 三个必须解决的问题（用户点名）

| # | 问题 | 本质 | 处理章节 |
|---|------|------|----------|
| **A** | **图片替换** | 真实 APP 没有游戏海报（`exit8/senren/p3r/elden.png`），不能再当封面/大背景/主角图 | §4 |
| **B** | **description 换成更 general 的语言** | `type / mood / analysis` 是按具体游戏手写的，套到任意软件上表述会很怪 | §5 |
| **C** | **月度回顾（Monthly Recap）不能牛头不对马嘴** | 11 屏里 3–6 屏是为某款游戏量身写的剧本+独占版式；换成真实 APP 后文案、版式、断言会和数据对不上 | §6 |

这三点贯穿下面的全量清单（§3），并在 §4–§6 单独展开根因与解法，最后在 §8 **分两阶段落地**
（**阶段一：记忆湖本体/日视图先做** → **阶段二：Monthly Recap 后做**）。

## 0.1 三条硬性保证（用户追加，验收一票否决）

| # | 保证 | 含义 | 处理章节 |
|---|------|------|----------|
| **保证 1** | **复用首页同款自动捕获内容** | 用首页（`DesktopHomePage.qml`）已上线、已验证的**那一套只读接口**取数据；APP 图标取代现有预设测试图，但**图标本体只是系统小图标、不是整张图**，必须解决"卡片/大背景如何依旧美观" | §2.1–2.2、§4 |
| **保证 2** | **后端数据与现用数据一样安全** | 不引入任何新的取数路径；新代码只能**组合现有只读管理器**，不自己开文件/开库/读磁盘 → 安全面与首页完全相同 | §2.3、§9 |
| **保证 3** | **代码编辑法规：不碰不该碰的文件** | 明确"绝不可改 / 改前须变更提案 / 可改"三类文件红线 | §10 |

---

## 1. 核心原则（接入时一票否决）

1. **数据驱动一致性**：任何展示给用户的「判断句」（标题、心情、分析、关键词、趋势断言）
   都必须由**可度量的真实信号**推导，不允许出现与当月/当日数据相矛盾的写死断言。
2. **通用语言**：文案模板只能引用**类别 + 可度量模式**（连续时长 / 启动次数 / 时段分布 /
   占比 / 环比），不得出现游戏专有叙事（"夜间循环""慢速阅读的河""重力场"）。
3. **不捏造**：没有的数据宁可不显示 / 走空态，绝不用占位数字冒充真实（现在 11 屏全是假数字）。
4. **后端产模型、QML 只渲染**（rule 07 §3）：把"原始日志 → 结构化、已成文的卡片/回顾模型"放在
   C++ 服务层（沿用 `DailyCardService` 的模式），QML 不做日志解析、不在 QML 里拼长句。
5. **隐私边界**：窗口标题等可能含隐私的字段只用于本地聚合，不进 AI、不直接展示原文。
6. **预期不符必登记（数据安全）**：实现期凡发现与本计划假设不符（接口/字段/行为/分类/数据形态），
   **必须立即写入 `docs/memory-lake-integration-issues.md`** 并按严重度跑 `record_error.py`；
   **绝不用猜测或假数据掩盖**，未解决前该处走空态而非伪造（详见 §10）。

---

## 2. 数据复用与接入架构（复用首页同款只读路径 — 保证 1 & 2）

### 2.1 复用首页已验证的自动捕获数据路径
首页 `DesktopHomePage.qml` + 每日卡片 `DesktopDailyCardView.qml` 已在用一套**只读、已上线**的接口
拿自动捕获数据。记忆湖**必须复用同一套**，不另起炉灶、不新增数据来源：

| 用途 | 首页已用的调用（直接照搬，行号示意） | 返回关键字段 |
|------|----------------------------------------|--------------|
| 当日 APP 列表 | `usageStatManager.activeSoftwareForRange("day")`（`DesktopHomePage.qml:58/172`） | `{groupKey, appId, name, appName, path, seconds, time, foregroundSeconds, audioSeconds}` |
| 刷新 / 实时更新 | `usageStatManager.refresh()` + `Connections{ onUsageStatsChanged }` + 5s `Timer` | — |
| 当前前台应用 | `usageStatManager.currentSoftware()`（`:231`） | `{name, appName, …}` |
| 区间秒数合计 | `usageStatManager.softwareSecondsForRange("day"\|"month")` | int |
| 会话区间（时间河流 / launches / longest） | `frontmostRepository.getSessionsByRange(start,end)`（`DailyCardService`/Stats 已用，只读 SQLite） | `{appIdentifier, startUnixSec, endUnixSec, durationSec, activeSec, displayName, appIconPath}` |
| 月度 APP 列表 | `usageStatManager.activeSoftwareForRange("month")` | 同当日 |

> 记忆湖与首页**共享 `main.cpp` 注册的同一对象实例**，数据天然一致、刷新同步。
> QML 端可直接像首页那样调用（零新增后端），这本身就满足"与现用数据一样安全"。
> `softwareForRange` 与 `activeSoftwareForRange` 等价（均为 foreground+audio 合并视图）；本文统一用首页在用的 `activeSoftwareForRange`。

### 2.2 复用首页的 APP 图标渲染法（保证 1 的图标部分）
首页**从不直接贴原始图标**，而是用两个纯函数（`DesktopHomePage.qml:131‑163`）+ 一种叠放：
- `appColor(appId, appName, path)` → 由 APP 身份推出的**柔和底色**（已知品牌固定色，未知则哈希取色，稳定）。
- `appIconSource(appId, path)` → `image://appicon/<encodeURIComponent(path)>`；`site:bilibili` 等特例走内置 SVG；无 path 返回 `""`。
- 叠放：**圆角底色块（`appColor`）+ 居中小图标（`PreserveAspectFit` + `mipmap` + `asynchronous`，`sourceSize` 给到 48/256）**；图标缺失时底色块仍成立 → 优雅降级。

**做法**：把这两个函数抽成共享 JS（如 `qml/desktop/components/AppVisual.js`，或记忆湖内 `MemoryLakeVisual.js`），
首页与记忆湖**共用同一份**，杜绝两套色表/取图逻辑漂移。大尺寸场景如何用见 §4。
> 取图路径字段名因来源而异：`usageStatManager` 项用 `path`，`frontmostRepository` 项用 `appIconPath`；helper 取图前判空，空走兜底（§4.5）。

### 2.3 缺失聚合 / 文案代码放哪（保证 2 的安全面 + 保证 3 的避坑）
`src/CMakeLists.txt` 是**冻结文件**且用**显式源文件清单（非 glob）**：**新增任何 .cpp/.h 都要改它 → 必须先走变更提案**（§10）。因此：

- **首选**：把缺失的月度聚合 / 文案模板**加进已在清单里的现有文件**——
  `services/usage_stat_manager.cpp/.h`（聚合）、`services/daily_card_service.cpp/.h`（文案模板，已是同类本地确定性逻辑）。
  **扩这两个文件不碰冻结 CMake**，也不新增数据来源。
- 新方法只能**组合现有只读管理器**，**不得自己开文件 / 开库 / 读磁盘** → 安全面与首页**完全一致**（保证 2）。
- 注册新 invokable 通常无需动 `main.cpp`（在现有对象上加方法即可）；若确需新上下文对象，`main.cpp` 可改（非冻结）。
- **次选**（仅当确需独立 `MemoryLakeService` 新文件以隔离逻辑）：**先按 §10 填变更提案**，再加 `src/services/memory_lake_service.{h,cpp}` 并改冻结 `src/CMakeLists.txt`；该服务同样只组合现有只读管理器。
- QML 替换最小化：让新方法/服务返回**与 `MemoryLakeMock` 同形**的结构（字段名一致），QML 只需把 `Mock.apps/overview/recap` 换成真实来源。
- `MemoryLakeMock.js` **保留**作白天预览 / 无数据兜底样例，不删除。

> **2026-06-04 增补（v88 首页化）**：`memoryLakeDay()` 在原 `{apps, overview, todayTheme}` 上**增量**返回两个键，
> 配合记忆湖升为首页后的新左/右面板（纯增量、不改数据契约、不新增取数路径）：
> - `usageShare`：前 4 个 app + 「其他」的占比切片 `{name,appId,path,iconColors,seconds,percent,isOther}`，喂**右栏 Daily Usage Share 饼图**。
> - `todayConclusion`：`{kicker,title,desc,total,chips:[{label,value}]}`，喂**左栏「今日结论」卡**（替换原 Monthly Recap CTA 位置）；
>   chips 的「高峰时段」由 segments 按小时分桶在后端算出，「待办剩余」由 QML 从 `calendarManager` 叠加（DCS 不链接日历符号）。
>
> 月度回顾已从页内覆盖层**拆为独立页**（菜单底部入口），右栏原「详情卡」移除。详见 `README.md` 与
> `docs/memory-lake-implementation-plan.md` 顶部「现状更新」。

---

## 3. 全量内容清单（逐处过一遍整个记忆湖）

风险标记：🖼️图片替换 ｜ 🗣️文案通用化 ｜ 🧩错配(牛头不对马嘴) ｜ 🧱缺后端聚合 ｜ ✅数据现成只需接线。
来源缩写：`USM`=`usageStatManager`，`FSR`=`frontmostRepository`，`appicon`=`image://appicon/<path>`。

### 3.1 整页 · 氛围大背景（`DesktopMemoryLakePage.qml:31` → `DesktopAppShell.qml:225‑251`）

| 元素 | 当前写死 | 真实来源 | 改动 | 风险 |
|------|----------|----------|------|------|
| 全 App 模糊大背景 `ambientSource` | 当前卡封面图（游戏海报） | 当前选中 APP 的 **appColor 色彩晕染**（§4.4），非图标放大 | 改 `ambientSource` 为 appColor 生成背景；交叉淡入保留（图或色，见 §4.4） | 🖼️ |

### 3.2 左栏 · 用户卡 / 总览 / 今日主题 / CTA（`DesktopMemoryLakePage.qml:76‑196`）

| 元素 | 当前写死 | 真实来源 | 改动 | 风险 |
|------|----------|----------|------|------|
| 标题 "Memory Lake" / 副标 "电脑使用时间记录" | 静态 | 静态（保留）或加当日日期 | 可选：副标显示 `今天 · 6月3日` | — |
| 头像渐变块 | aqua→violet 渐变 | 保留（无真实用户头像） | 不动 | — |
| 使用总览 `overview.total` "8.9h" | 写死 | `USM.softwareSecondsForRange("day")` 格式化 | 接线 | ✅ |
| 总览副 `overview.sub` "今日 · 42 次切换" | 写死 | "今日 · N 次切换"，N = `FSR.getSessionsByRange(dayStart,dayEnd).length`（前台会话数≈切换数，**语义待实测，见 §10**） | 接线 + 文案模板 | ✅🗣️ |
| 今日主题 `todayTheme.title` "游戏沉浸" | 写死 | 当日**最高类别 + 模式**派生（如"游戏为主""创作为主"） | 模板（§5） | 🗣️🧱 |
| `todayTheme.desc` "游戏类占比最高，晚间有明显连续使用段。" | 写死断言 | 由类别占比 + 时段分布**条件生成**，无对应特征就不写该从句 | 模板 + 断言守卫 | 🗣️🧩🧱 |
| `todayTheme.ratio` 0.73 | 写死 | 最高类别秒数 / 当日总秒数 | 需类别聚合 | 🧱 |
| Monthly Recap CTA 文案 | 静态 + "这个月" | 文案保留，但"这个月"应跟随当前月 | 注入月份 | 🗣️ |

### 3.3 左栏 · APP 使用排行（`UsageRankList.qml`）

| 元素 | 当前写死 | 真实来源 | 改动 | 风险 |
|------|----------|----------|------|------|
| 列表与顺序 `ranking` | 写死 9 项下标 | `USM.activeSoftwareForRange("day")` 按 `seconds` 降序 | 接线 | ✅ |
| 行图标 34px | 卡封面图缩略 | `appicon` + `path`（小尺寸用真实应用图标最合适） | 换 source 为 appicon | 🖼️✅ |
| 行 `name` | 写死 | 条目 `name`（显示名） | 接线 | ✅ |
| 行 `time` | 写死 | 条目 `time`（已格式化） | 接线 | ✅ |
| 行进度条 `progress` | 写死 | `seconds / 榜首seconds` | 接线（QML 算或服务给） | ✅ |
| 副标 "给排行榜更多空间" | 静态装饰 | 保留 | 不动 | — |

### 3.4 中栏 · 卡牌轮盘（`CardCarousel.qml` / `MemoryCard.qml`）

每张卡来自 `apps[i]`。同一个 `apps` 数组同时喂排行、详情、时间河流、回顾。

| 元素 | 当前写死 | 真实来源 | 改动 | 风险 |
|------|----------|----------|------|------|
| 正面大封面图 `image`（196px 高） | 游戏海报 | **生成式封面**（appColor 渐变 + 居中图标，§4.3） | 换图策略 | 🖼️ |
| 背面淡背景图 | 同上海报 0.18 透明 | 同上生成式封面（§4.3） | 同上 | 🖼️ |
| `name` | 写死 | 条目 `name` | 接线 | ✅ |
| `type` "Game · Horror Walking Sim" 等 | 按游戏手写 | 通用类别串（游戏/视频/音乐/社交/开发/其他）+ 可选细分 | 模板（§5） | 🗣️ |
| `time` / `progress` | 写死 | 同 §3.3 | 接线 | ✅ |
| 时间 pill / 进度条 | 写死 | 同上 | 接线 | ✅ |
| 翻面 `mood` "循环探索"/"剧情阅读"… | 按游戏手写 | 由类别 + 使用模式（连续/碎片/长段/短段）生成的**通用心情词** | 模板（§5） | 🗣️🧩🧱 |
| 翻面 `analysis` 长叙事 | 按游戏手写 | 由可度量事实拼装的通用分析句 | 模板（§5） | 🗣️🧩🧱 |
| 翻面 `launches` "3 次" | 写死 | 当日该 APP 前台会话数（`FSR` 按 appId 过滤） | 需按 app 聚合 | 🧱 |
| 翻面 `longest` "70 min" | 写死 | 该 APP 最长单次会话 `max(durationSec)` | 需按 app 聚合 | 🧱 |

### 3.5 右栏 · 详情卡（`DetailPanel.qml`）

| 元素 | 当前写死 | 真实来源 | 改动 | 风险 |
|------|----------|----------|------|------|
| 标题 "{name} · 使用时间分布" | 派生自 `name` | 同 | 接线 | ✅ |
| 封面图（104px 高） | 游戏海报 | 生成式封面（§4.3） | 换图 | 🖼️ |
| "{type} · {time}" | 写死 | 同 §3.4 | 模板 + 接线 | 🗣️ |
| `mood` / `analysis` | 同卡牌背面 | 同 §3.4 | 模板 | 🗣️🧩🧱 |

### 3.6 右栏 · 时间河流（`TimeRiver.qml`）

| 元素 | 当前写死 | 真实来源 | 改动 | 风险 |
|------|----------|----------|------|------|
| 节点 `times` `[start,end,宽px,y%]` | 写死 3 段 | `FSR.getSessionsByRange(dayStart,dayEnd)` 过滤当前 appId → 每段 `{start,end}`；y% = (start−dayStart)/日长，宽 = 时长映射 | 需把会话转节点（服务给 `times` 同形数组最省事） | 🧱 |
| 左侧轴标签 `axisLabels` 10:00/16:00/20:00/24:00 | **写死在 QML** | 应按当日实际首末会话**动态生成**刻度（或固定 0–24 但映射正确） | 改为动态/参数化 | 🧩🧱 |
| 底部刻度 `ruler` 10:00–22:00 | **写死在 QML** | 同上 | 同上 | 🧩🧱 |
| 标题 "几点到几点" | 静态 | 保留 | — | — |

> ⚠️ 现在轴是 10–24 点写死，真实会话若发生在早上，节点 y% 会和轴标签对不上 → **错配**。
> **节点 y% 与轴刻度必须共用同一时间窗**（统一固定 0–24h，或统一取当日首末会话，二者一致），轴随真实数据走；否则即便节点对了，刻度也是假的。

### 3.7 右栏 · note（`DesktopMemoryLakePage.qml:279‑293`）

纯交互提示（"点击中心记忆查看分析…"），静态保留。— 无改动。

---

### 3.8 月度回顾 11 屏（`MemoryLakeMock.recap` → `RecapOverlay.qml` / `RecapSlide.qml`）

> 这是 §6「牛头不对马嘴」的主战场。**所有 11 屏当前全是为 2026.06 这套游戏手写的假数据**，
> 且 `recap` 通过 `bgIndex` 复用**日级** `apps` 数组（月级主角 ≠ 当日卡牌，结构本身就错位）。
> 月度回顾需要**独立的月级数据集**（`activeSoftwareForRange("month")`）。

| 屏 | type | 当前写死内容 | 真实来源 | 风险 |
|----|------|--------------|----------|------|
| header | — | "… Monthly Recap · **2026.06**" / 操作提示 | 月份动态化；提示保留 | 🗣️ |
| 01 | cover | 标题"**六月**的记忆湖…"、副文、3 指标（月度总使用 **118.6h**、最高类别 **游戏 64%**、最活跃时段 **20:00–24:00**） | 月份名动态；总使用=`USM.softwareSecondsForRange("month")`；最高类别+占比=月类别聚合；最活跃时段=时段直方图峰值 | 🗣️🧩🧱 |
| 02 | monthMap | 标题"**月末明显抬升**"断言 + 7 根柱 `{h,value,day}` | 按天序列（§7-1）；标题改为**按真实趋势条件生成**（升/降/平） | 🧩🧱 |
| 03 | poster | **8幡出口**专属海报 + "它不是卡牌，而是一段夜间循环" + stats | 月度第 1 名 APP；版式通用化；文案由类别+模式生成（§6） | 🖼️🗣️🧩🧱 |
| 04 | split | **千恋万花** + "像一条慢速阅读的河" | 月度第 2 名；同上 | 🖼️🗣️🧩🧱 |
| 05 | orbit | **ELDEN RING** + "高强度重力场" + 环绕节点 | 月度第 3 名；同上 | 🖼️🗣️🧩🧱 |
| 06 | article | **P3R** + "像一本章节日志" | 月度第 4 名；同上 | 🖼️🗣️🧩🧱 |
| 07 | timeline | 3 条时段带，apps 写死 "Figma / VS Code / Chrome" 等 | 按时段(下午/傍晚/夜间)聚合**月内**会话的类别/代表 APP | 🗣️🧩🧱 |
| 08 | trend | 标题"月末出现明显高峰…" + 曲线 **写死在 `RecapSlide.qml:427`**（连 Mock 都不是） | 按天序列（§7-1）画曲线；断言条件生成 | 🧩🧱 |
| 09 | keywords | 关键词云 + major "沉浸"（写死 7 词） | 由月类别/连续时长/启动/时段**本地模板**生成关键词 | 🗣️🧩🧱 |
| 10 | comparison | 3 个环比 `{label,change,desc}`（+23%/−12%/+8% 写死） | 环比上月类别聚合（§7-2） | 🧩🧱 |
| 11 | ticket | 票根 rows（总使用/最高类别/关键词/较上月）写死 | 由 01/09/10 的真实值汇总 | 🗣️🧩🧱 |

---

## 4. 问题 A — 图片替换策略：用 APP 图标取代预设图，且保持美观 🖼️

### 4.1 根因与硬约束（务必先认清）
- 现有封面是**单款游戏的官方海报**（`exit8/senren/p3r/elden.png` + 通用 `desktop.png`）。真实 APP **没有海报**。
- 真实可得的只有**系统应用图标**：`AppIconImageProvider`（`image://appicon/<path>`）用 `QFileIconProvider`
  取图，**尺寸钳制在 16–256px**，取不到时返回**透明 pixmap**（不破版）。
- **关键约束**：图标最大只有 **256px**，且本质是带留白的小图标。
  - 把它拉满 196–460px 的卡面 / 全窗大背景 → **必糊、必丑**。
  - 所以"图标进入预设图的位置"**不能等于"把图标拉大铺满"**，而要**按尺寸分级、用图标做主体或色源去合成一张耐看的图**。
- **可用素材**：`resources/features/memory-lake/` 已备主题艺术图 `hotspring_01..08 / memory_bg / memory_cat_1/2 /
  memory_pond_rocks / memory_tree`，可作大尺寸场景的"画布/纹理"。

### 4.2 分级方案（图标尺寸越大、越要"合成"而非"拉伸"）

| 场景 | 区域尺寸 | 做法 | 图标请求尺寸 |
|------|----------|------|--------------|
| 排行行图标 / 卡牌小徽标 | ≤34px | **直接复用首页法**：`appColor` 圆角底块 + 居中小图标（§2.2） | `sourceSize` 48 |
| 卡牌封面 / 详情封面 / 回顾主角图 | 128–460px | **生成式封面**（§4.3），**不拉伸图标** | `sourceSize` 256 |
| 全 App 氛围大背景 | 满窗（>1000px） | **色彩晕染背景**（§4.4），图标只当色源 | 256 + 重模糊 |

### 4.3 生成式封面（128–460px）——核心美观方案
不把 256px 图标拉满，而是**合成一张"专辑封面"式的图**（无封面的播放器就这么做，观感是"有意设计"而非"缺图"）：
1. **底**：用该 APP 的 `appColor` 出一道**柔和渐变**（`appColor` → 同色系更深/哈希第二色），保证大面积平滑无像素感。
2. **可选纹理**：在底上叠一张主题艺术图（`hotspring_*`/`memory_*`），**用 `appColor` 着色 + 低透明**，给"记忆湖"质感且每个 APP 色调不同。
3. **主体**：把**应用图标按中等尺寸（约 96–128px，向 provider 请求 256）居中**，下方叠 APP 名 / 类别；可加一圈柔光（`MultiEffect` glow，参考卡牌底灯）让图标"坐得住"。
4. 仍保留卡面现有的圆角遮罩 + 边缘光管线（`MemoryCard.qml` 已稳定，见 fidelity-gaps「漏边修复」），只是**把"整张海报图"换成"上面这层合成"**。

> 效果：卡面是「APP 专属色 + 居中清晰图标 + APP 名」，清晰、统一、可辨识，且天然适配白天/夜晚两套主题色。

### 4.4 氛围大背景（满窗模糊）——色彩晕染，不喂糊图标
`DesktopAppShell.qml:225‑251` 把当前卡封面做模糊大背景。256px 图标铺满整窗即便模糊也偏糊/偏单色，故：
- **主层**：用当前 APP 的 `appColor` **大渐变**作背景（绝对平滑，零像素感），随选中卡切换淡入。
  > 注意：现有 shell 背景按 `Image{source:url}` 双图淡入；若主层改用渐变色，需把该层调成**双色淡入**（`DesktopAppShell` 记忆湖背景层属 §10 可改）——属"与预期不符"须按 §10 记一笔。
  > 注意 2：`appColor` 是**预设单色系**，实测背景偏纯色、与图标真实色调不符；**阶段三（§8）升级为「图标主色提取 + 多色 blend」**。
- **点缀层（可选）**：把图标**放大 + 重模糊（现有 `MultiEffect blur≈42` 已在做）**叠一层**色晕**，丰富色彩；因为被模糊到化开，分辨率不再是问题。
- 即 `ambientSource` 从"游戏海报"改为"由 `appColor`(+模糊图标色晕) 生成的色彩背景"。

### 4.5 兜底链（缺图标也不破版）
真实图标 → 若 provider 返回透明/空 path → 退到 **`appColor` 底块 / 着色主题图**（图标缺失也只是少一枚图标，色与版式仍完整）。
特例（如 `site:bilibili`）沿用首页的内置 SVG 分支。

### 4.6 约束
- **不新增第三方依赖**（rule 07 §4）；合成全用现有 `Image`/`Gradient`/`MultiEffect`/已备素材。
- 如需补主题素材，放 `resources/features/memory-lake/` 并登记 `resources/CMakeLists.txt`（非冻结，可改；rule 04 §5）。
- 色表/取图/合成逻辑集中到 §2.2 的共享 helper，首页与记忆湖一致。

**验收**：任意真实 APP（含纯工具类、无自带海报）在 排行/卡面/详情/回顾主角/大背景 都清晰美观、可辨识、
白天夜晚都协调；无图标拉伸糊图、无"游戏海报"残留；缺图标时不破版。

---

## 5. 问题 B — 描述通用化（type / mood / analysis）🗣️

**根因**：`type`、`mood`、`analysis` 现在是**逐游戏手写的文学化句子**。套到 VS Code、Chrome、Excel 上会很怪
（"高强度战斗""慢速阅读的河"）。

**解法：本地确定性模板系统**（沿用 `DailyCardService` 既有套路，**加进现有 `daily_card_service.*`**，见 §2.3）：

1. **类别**：复用 `DailyCardService::classifyApp` 的关键字规则（游戏/视频/音乐/社交/开发/其他），
   作为唯一的"题材"来源。`type` = `类别` 或 `类别 · 细分`（细分仅在可靠时给，如 浏览器/笔记）。
2. **使用模式信号**（全部可度量）：单次最长时长、平均单次、启动次数、连续性（长段 vs 碎片）、
   主要时段（晨/午/傍晚/夜）、占比。
3. **心情词 `mood`**：用「类别 × 模式」查一张**通用词表**，例如：
   - 长连续段 → "沉浸使用" / "连续投入"；碎片多启动 → "碎片使用" / "穿插切换"；
   - 开发类长段 → "专注开发"；视频类长段 → "连续观看"；社交类碎片 → "穿插沟通"。
   - 词表只引用**可测信号**，不引用题材专有叙事。
4. **分析句 `analysis`**：用**带槽位的句式**拼装可测事实，如
   "{APP} 今天使用约 {time}，集中在 {主要时段}，单次最长 {longest}，共启动 {launches}。
   系统据连续性把它识别为 {模式标签}。" —— 每个槽位都有真实值，无法填的从句**整句省略**（断言守卫）。
5. **空/稀疏数据**：使用很短或只 1 次时，给保守句式（"今天只有少量使用"），不强行"识别模式"。

**验收**：把模板套到 5 类真实 APP（游戏/视频/开发/社交/其他）各看一遍，句子**通顺、与数据一致、不出现题材专属词**。

---

## 6. 问题 C — 月度回顾不牛头不对马嘴 🧩（阶段二核心 · 反错配）

**三层根因**：

1. **手写剧本**：03–06 屏的标题/副文是为某款游戏写的（"夜间循环""阅读的河""重力场""章节日志"），
   换成真实 APP 必然张冠李戴。
2. **独占版式硬绑题材**：poster/split/orbit/article 四种版式现在和"4 款特定游戏"一一绑定；
   真实月度的 Top APP 数量、类别都不定，硬塞会错配（如把"重力场 orbit"扣在 Excel 上）。
3. **写死断言 + 复用日级数据**：标题里"月末明显抬升""出现高峰"等是**无条件断言**；
   且 `recap` 用 `bgIndex` 引日级 `apps`，月级主角根本没接。趋势曲线还直接写死在 `RecapSlide.qml`。

**解法**：

- **独立月级数据集**：回顾用 `activeSoftwareForRange("month")` 取月度 Top APP，**不复用日级卡牌**。
- **主角版式数据驱动分配**：把 poster/split/orbit/article 当**纯展示模板**，按"月度第 1/2/3/4 名"
  顺序套用；**不足 4 个**有意义主角时，减少主角屏数量（动态生成 `slides`，而非固定 11 屏）。
- **题材中立文案**：03–06 的标题/副文/stats 全部由 §5 的模板按**该 APP 的类别+模式**生成，
  保证"无论是谁坐这个位置，话都说得通"。stats 标签统一为通用项（月度时长/最长连续/主要时段/关键词）。
- **断言守卫**：02/08 的趋势标题、01 的"最活跃时段"等，必须由真实序列**条件生成**
  （上升→"月末抬升"；下降→"逐渐回落"；平稳→"整体平稳"），数据不支持就换中性句，**绝不写死方向**。
- **趋势曲线接真值**：`RecapSlide.qml:427` 写死的 `pts` 改为读按天序列（§7-1）；无数据则隐藏该屏或显空态。
- **关键词/对比/票根**：分别接 §5 关键词模板、§7-2 环比、以及对前面真实值的汇总（票根只是复述，不可另造数字）。

**验收**：用**真实账户当月数据**跑一遍 11（或动态条数）屏：每屏标题/版式/数字/关键词与该月数据自洽；
任挑 Top APP 验证"换个 APP 坐主角位，文案依然通顺无错配"；趋势方向与按天序列一致。

---

## 7. 后端能力差距（需新增 C++ 聚合，**不改 schema**）

现成可用（来自 `usageStatManager` / `frontmostRepository` / `statsService` / `dailyCardService`）：
按 range（day/month/year/all）的 APP 聚合 `{name,seconds,time,appId,path,foregroundSeconds,audioSeconds…}`、
会话区间 `{appIdentifier,startUnixSec,endUnixSec,durationSec,activeSec,idleSec,displayName,appIconPath}`、
今日排行、`image://appicon`、`classifyApp` 类别关键字。

**缺失（按 §2.3：优先加进现有 `usage_stat_manager.*` / `daily_card_service.*`，内部只组合上述只读接口；
新文件须先走 §10 变更提案）**。**按 §8 阶段归属**：缺口 5 + 6/7 的"日"部分 → **阶段一/本体**；
缺口 1、2、4 与 3 的"月"部分 → **阶段二/Monthly Recap**。

| # | 缺口 | 用途 | 建议接口 |
|---|------|------|----------|
| 1 | **月度按天时长序列** | monthMap 7 柱、trend 曲线 | `dailySecondsForMonth(year,month)` → `[{day,seconds}]`（USM 现仅 range 桶聚合） |
| 2 | **环比上月** | comparison / 票根"较上月" | `categorySecondsForMonth(year,month)` 取本月+上月做差（按类别） |
| 3 | **类别聚合 + 占比** | 今日主题 ratio、月度"最高类别 N%"、对比 | 在服务内按 `classifyApp` 把 APP 秒数归类汇总 |
| 4 | **时段直方图 / 峰值窗口** | "最活跃时段 20:00–24:00"、timeline 时段带 | 按会话 start 小时分桶，取峰值连续窗口 |
| 5 | **按 APP 的会话派生** | `launches`(会话数)、`longest`(最长单次)、time-river `times` | 服务内对 `getSessionsByRange` 按 appId 分组 |
| 6 | **心情/分析/关键词/主题模板** | §5 / §6 全部文案 | 本地确定性模板函数（C++），非 AI |
| 7 | **封面/背景合成** | §4 图片替换 | `appColor`+图标合成（§4.3/4.4），主题纹理着色可选；纯函数放共享 helper |

> 说明：现有 `classifyApp` 是中文类别（游戏/视频/音乐/社交/开发/其他），与 Mock 里英文 `type`
> （Game/Creative App…）不一致，统一以中文类别为准并相应调整 `type` 展示串。

---

## 8. 分两阶段落地（先「记忆湖本体」，后「Monthly Recap」）

> **总原则：两阶段严格分开做、各自独立 commit / 验收。**
> - **阶段一只做记忆湖本体**（日视图三栏 + 氛围大背景），做到**完整可用、全真不假**；
>   期间**完全不碰 Monthly Recap**（CTA 仍存在，先指向回顾的占位/空态即可）。
> - **阶段二再单独做 Monthly Recap**（11/动态屏）。
> - 为什么这么分：本体几乎全用**现成只读数据**（§2.1），能先独立上线；回顾依赖一批**尚不存在的
>   月度聚合**（§7-1/2/3/4），自然后置，避免被它阻塞本体。
> - 每步走 `build.py` + `harness_check.py` + 真机 `run.cmd`；与预期不符按 §10 记入 issue 文档；
>   展示值一律真实，缺数据走空态（§1.6）。

---

### 阶段一 · 记忆湖本体（日视图，先做、可独立交付）

> 范围：左栏 总览/今日主题/排行 + 中栏 卡牌 + 右栏 详情/时间河流 + 氛围大背景。
> 不依赖任何新月度聚合，不改 Monthly Recap。

**1A 数据接线（复用首页只读路径，零/最小新增后端）**
- [ ] 复用首页调用（§2.1）：`activeSoftwareForRange("day")` + `refresh` + `onUsageStatsChanged`
      + `currentSoftware` 喂 排行/卡牌/总览/进度。
- [ ] `getSessionsByRange` 按 appId 派生 `launches`/`longest` + time-river `times`（§7-5）。
- [ ] 把 `Mock.apps/overview/ranking` 切到真实来源（保留 Mock 作兜底）。
- [ ] 时间河流 `times` 接真实会话 + **轴动态化**（§3.6），消除轴错配。

**1B 文案通用化（§5，加进现有 `daily_card_service.*`）**
- [ ] `type`(中文类别)/`mood`/`analysis` 本地模板，套 5 类 APP 验证通顺。
- [ ] 今日主题 标题/`desc`/`ratio`：当日**类别聚合 + 占比**（§7-3 的"日"部分）+ 断言守卫。

**1C 图片（§4，本体部分 = 保证 1 的图标落地）**
- [ ] 抽共享图标 helper（§2.2）`appColor`/`appIconSource`，首页与记忆湖共用。
- [ ] 小尺寸：排行/徽标用 `appColor` 底块 + `image://appicon`（§4.2）。
- [ ] 大尺寸：卡面/详情封面用**生成式封面**（§4.3）。
- [ ] 氛围大背景改 `appColor` 色彩晕染（§4.4，含 shell 背景层 图淡入→色淡入 改造）。
- [ ] 缺图标兜底链（§4.5）。

**1D 本体动态/空态**
- [ ] 副标日期跟随当天；无当日数据 / 单 APP 走保守空态，不崩不假。

**阶段一验收**：日视图三栏 + 大背景 数字全真自洽、文案通用通顺、图片美观可辨、轴不错配、空态不崩；
安全面与首页一致；**全程未改动 Monthly Recap**。

---

### 阶段二 · Monthly Recap（本体完成后，单独进行）

> 前置：阶段一的**共享图标 helper / 文案模板**已就绪，阶段二直接复用。
> 范围：11（→ 动态条数）屏全部接真实当月数据、题材中立、防错配（§6）。

**2A 缺失月度聚合（§7，优先加进现有 `usage_stat_manager.*` / `daily_card_service.*`）**
- [ ] 按天序列（§7-1）、月度类别占比（§7-3 的"月"部分）、时段峰值（§7-4）、环比上月（§7-2）。

**2B 月级数据集 + 主角版式数据驱动（§6）**
- [ ] 回顾用 `activeSoftwareForRange("month")` 取月度 Top（**不复用日级卡牌**）。
- [ ] poster/split/orbit/article 当纯模板，按月度第 1/2/3/4 名套用；**不足 N 个主角动态减屏**。

**2C 回顾文案 + 断言守卫（§6）**
- [ ] 01/02/03–06/08 文案全模板化 + 断言守卫；趋势曲线接按天序列（替换 `RecapSlide.qml` 写死 `pts`）。
- [ ] 07 时段带 / 09 关键词 / 10 环比 / 11 票根 汇总接真值。

**2D 回顾动态/空态**
- [ ] 月份名/header 跟随当前月（去"六月/2026.06"写死）。
- [ ] 无当月数据空态；动态屏数下 目录 / 进度条 / `storyComplete` 仍自洽。

**阶段二验收**：逐屏 标题/版式/数字/关键词 与当月数据自洽；换主角 APP 文案不崩；趋势/环比方向正确；
动态屏数下导航正常。

---

### 阶段三 · 图标主色背景 blend 精修（Phase 2 / 阶段二之后做）

> **背景（实测问题）**：阶段一/二的背景用 `appColor`（按 APP 身份查表/哈希出的**预设单色**）做底，
> 截图显示背景几乎是**纯色色系**，与 APP 图标本身的真实色调不吻合——因为 appColor 不是从图标像素提取的。
> 目标：背景颜色改为**由图标本身主色调提取并 blend**，让大背景/卡面底色与该 APP 图标观感一致。

**3A 提取图标主色（C++，放进现有源文件，不新建 / 不碰冻结 CMake）**
- [ ] 在现有已注册对象上加只读 invokable（如 `appIconDominantColors(path) → [color…]`；宿主放
      `app_icon_image_provider.*` 配套或 `usage_stat_manager.*`）：`QFileIconProvider`/`QImage` 取图标位图 →
      缩到小图(16–32px) → 剔除透明/近白近黑边缘 → 按饱和度加权统计出 **1–3 个主色**。
- [ ] **按 path/groupKey 缓存**（取色仅在卡列表加载时算一次，不在每帧/切卡重算）。
- [ ] 取不到图标/透明 → 回退现有 `appColor`（兜底不变）。

**3B 背景/底色改 blend（QML）**
- [ ] 氛围大背景：把现有单色（A7 已改成的 Rectangle 渐变交叉淡入，正好能承载多色）换成
      **图标 1–3 主色的多色渐变 blend**；保留夜间压暗 + 文字对比 + 450ms 交叉淡入。
- [ ] 生成式封面底（§4.3）同源升级（可选）：底色也用图标主色，使卡面与图标更统一。
- [ ] `appColor` 降级为**取色失败兜底**，不再作为主背景来源。

**阶段三验收**：背景/卡面底色随各 APP 图标呈现**相符色调**（不再清一色纯色），切卡多色渐变平滑；
取不到图标回退 appColor 不破版；切卡/滚动无掉帧（取色已缓存）；真机截图修前/修后对比。

> 移动端等价（沿用同一卡片/回顾模型）—— 以上阶段全部完成后再跟进，不在本轮（rule 07 §2）。

---

## 9. 数据契约 / 隐私 / 安全边界（不可逾越，保证 2）
- **安全面与现用数据一致**：只复用首页/Stats/DailyCard 已在用的**只读管理器**（§2.1）；
  任何新方法**只组合这些管理器，不自己开文件 / 开库 / 读磁盘 / 加网络** → 不引入任何新攻击面或新失败点。
- 只读现有接口；**不改 `data_bridge.h` / `database_storage.*` / `database_path.*` 或 SQLite 表契约**；不加 IPC/socket/共享内存（CLAUDE.md / rule 03）。
- 文案/关键词=**本地确定性模板**，**不把原始日志/窗口标题喂 AI**（rule 07 §5）。
- 不新增第三方库；不顺手重构其它页面（rule 07 §4）。

---

## 10. 代码编辑法规 —— 文件红线（保证 3，开工前必读）

> 依据：`.harness/CHARTER.md` §3 冻结清单 + `.harness/state/frozen-files.json` 哈希锁 + CLAUDE.md 架构边界。
> 违反会被 `harness_check.py` pass 2（冻结哈希）/ pass 4（平台隔离）抓到。**改前先想：它在哪一类。**

### 🔴 绝不可改（除非先填变更提案 `.harness/templates/change-proposal.md` → `journal/sessions/`）
这些是**冻结文件**（哈希锁定）：
- 磁盘契约 / 服务共享头：`src/service/shared/data_bridge.h`、`database_path.h`、
  `database_path.c`、`app_info.h`、`app_env.h`
- `src/include/util.h`
- 构建根：`CMakeLists.txt`、`src/CMakeLists.txt`、`src/service/CMakeLists.txt`
- 治理：`.harness/CHARTER.md`、`.harness/AGENTS.md`、`AGENTS.md`

> ⚠️ **`src/CMakeLists.txt` 冻结 + 显式源清单**的直接后果：**新增任何 .cpp/.h 都得改它 → 要变更提案**。
> 所以本项目**优先扩现有源文件**（`usage_stat_manager.*` / `daily_card_service.*`），别新建文件（§2.3）。

### ⛔ 绝不可碰（架构边界，CLAUDE.md / rule 01–03）—— 即使非冻结
- **整个 `src/service/`（单数 = 捕获守护进程）**：不改其采样/写盘逻辑、不改磁盘记录格式。记忆湖是**纯 UI 侧消费者**。
- **不加 IPC / socket / 共享内存 / UI 直连服务内部**；两进程只经磁盘契约通信。
- **不做 schema 变更 / DB 迁移**；不新增第三方依赖。
- 注意 `src/service/`（守护进程，禁碰）与 `src/services/`（**复数** = UI 应用服务层，可改）**仅差一个 s**，别看错。

### 🟢 可以改（本计划的真正工作面）
- `qml/desktop/memorylake/*.qml`、`qml/desktop/pages/DesktopMemoryLakePage.qml`、`MemoryLakeMock.js`（留作兜底）。
- `qml/desktop/DesktopAppShell.qml` 的记忆湖大背景层（§4.4，仅记忆湖相关属性）。
- 共享 helper：新增 `qml/desktop/components/AppVisual.js`（图标/色，§2.2）。
- **扩**现有 UI 服务：`src/services/usage_stat_manager.cpp/.h`、`src/services/daily_card_service.cpp/.h`（加只读聚合/文案方法，§2.3/§7）。
- `src/main.cpp`（仅在需要时加上下文对象注册；**非冻结**）。
- `qml/CMakeLists.txt`（登记新增 `.qml`）、`resources/CMakeLists.txt` + `resources/features/memory-lake/`（补素材）——均**非冻结**。
- 文档：本文件、`docs/memory-lake-implementation-plan.md`、`.harness/state/open-issues.md`、session log。

### 📋 预期不符必登记（数据安全法规 — 强制，本轮新增）
本计划基于对现有接口/数据的勘查**假设**；实现期一旦**实测与预期不符**，必须当场登记，不得绕过：
- **触发**：接口/字段名不符、返回形态不同、`classifyApp` 误分类、应有数据却为空、图标/路径取不到、
  兜底被非预期触发、数字与别处对不上——任何"和计划写的不一样"。
- **登记到** `docs/memory-lake-integration-issues.md`（本次实现专属 issue 文档），每条含
  `日期 / 位置(§) / 预期 / 实际 / 影响 / 处置`；属构建/运行/认知错误的另按严重度跑 `record_error.py`（L1/L2/L3）。
- **数据安全硬线**：**不符未解决前，该处一律走空态/隐藏，绝不用猜测值或假数据顶替**（呼应 §1「不捏造」）；
  展示的每个数字都必须可追溯到真实来源。

### 流程纪律（每次会话）
1. `python .harness/tools/preflight.py --track B`（开工，非零退出先修漂移）。
2. 任何构建走 `python .harness/tools/build.py`（不要裸 `cmake --build`）。
3. Qt/QML 跑完 `python .harness/tools/scan_qt_log.py`。
4. 任何错误 `python .harness/tools/record_error.py --level <L1|L2|L3> --track B --topic <slug> --summary "…"`。
5. 提交前 `python .harness/tools/harness_check.py`（非零不提交）。
6. 若不得已要动 🔴 文件：**先**复制 `change-proposal.md` 到 `journal/sessions/` 填好，再改。

---

## 11. 验收总清单（按 §8 两阶段，各自独立验收）
**阶段一 · 本体（日视图）**
- [ ] 总览/主题/排行/卡牌/详情/时间河流/大背景——数字真实、文案通用通顺、图片合适、轴不错配。
- [ ] 空/稀疏数据（无当日数据 / 单 APP）兜底不崩、不显假数据；安全面与首页一致。
- [ ] 全程未改动 Monthly Recap。

**阶段二 · Monthly Recap**
- [ ] 动态屏数；每屏标题/版式/数字/关键词与真实当月数据自洽；主角文案题材中立；趋势/环比方向正确。
- [ ] 无当月数据空态；动态屏数下 目录/进度条/`storyComplete` 自洽。

**阶段三 · 图标主色背景 blend**
- [ ] 背景/卡面底色随各 APP 图标呈现相符色调（非清一色纯色）；切卡多色渐变平滑、无掉帧；取色失败回退 appColor 不破版。

**各阶段通用**
- [ ] `build.py` 干净、`scan_qt_log.py` 无新增 QML 告警、`harness_check.py` 通过；真机 `run.cmd` 走查留 session log。
- [ ] 所有"与预期不符"已记入 `docs/memory-lake-integration-issues.md`；无任何展示值用假数据顶替（§1.6 / §10）。
