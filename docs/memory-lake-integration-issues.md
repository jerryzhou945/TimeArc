# 记忆湖后端接入 · 实现期 Issue 文档

> 本文是 `docs/memory-lake-backend-integration-plan.md` 的**配套实现期 issue 记录**，由该计划
> §1.6 / §10「预期不符必登记（数据安全法规）」强制要求。
>
> **法规**：实现期一旦发现**实测与计划假设不符**（接口/字段名、返回形态、分类、数据有无、
> 图标/路径、兜底被非预期触发、数字对不上……任何"和计划写的不一样"），**必须当场在此登记**。
> **数据安全硬线**：不符未解决前，该处一律走**空态/隐藏**，**绝不用猜测值或假数据顶替**；
> 展示的每个数字都要可追溯到真实来源。属构建/运行/认知错误的，另按严重度跑
> `python .harness/tools/record_error.py --level <L1|L2|L3> --track <A|B|C> --topic <slug> --summary "…"`。

## 条目格式

```
### [状态] 简述
- 日期：YYYY-MM-DD
- 位置：计划 §x.y / 文件:行
- 预期：计划假设的接口/字段/行为/数据
- 实际：实测结果
- 影响：影响哪个展示项、是否会显示错误/假数据
- 处置：改计划? 走空态? 改接口? 已 record_error(Lx)?
```
状态用 `OPEN` / `RESOLVED` / `WONTFIX`。

---

## 开工前已知 · 待实测验证的假设（A 系列）

> 这些是计划中**尚未在真实数据上验证**的假设。实现到对应步骤时逐条核实：若成立标 `RESOLVED`，
> 不成立则补「实际/影响/处置」。**未核实前不得据其展示数字**。

### [OPEN] A1 「次切换」≈ 前台会话数
- 位置：§3.2 总览副标
- 预期：`getSessionsByRange(dayStart,dayEnd).length` 可当"今日切换次数"。
- 待验证：连续同一 APP 的会话是否被合并？该计数语义是否=用户感知的"切换"？否则文案改措辞或换口径。

### [OPEN] A2 月度聚合接口不存在，需新增
- 位置：§7-1/2/3/4
- 预期：按天序列 / 环比上月 / 类别占比 / 时段峰值 **现后端均无**，须在
  `usage_stat_manager.*` / `daily_card_service.*` 内新增（只组合现有只读接口）。
- 待验证：实现前再确认确无现成等价接口（避免重复造）；新增后核对结果与首页同口径数字一致。

### [OPEN] A3 取图路径字段名因来源而异
- 位置：§2.2 / §4.5
- 预期：`usageStatManager` 项用 `path`，`frontmostRepository` 项用 `appIconPath`。
- 待验证：两来源实际字段名与非空率；helper 取图前判空，空走兜底。

### [OPEN] A4 classifyApp 对真实 APP 的命中率
- 位置：§5 / §7-3
- 预期：`DailyCardService::classifyApp` 关键字分类够用。
- 待验证：真实环境"其他"占比是否过高、有无明显误分类（影响 type/mood/关键词质量）；记录误分类样本。

### [OPEN] A5 图标缺失占比 → 生成式封面兜底是否够看
- 位置：§4.3 / §4.5
- 预期：多数 APP 有系统图标；缺失走 appColor 兜底。
- 待验证：实际取不到图标（无 path / 返回透明）的占比；若偏高，生成式封面是否仍美观。

### [OPEN] A6 monthMap 7 柱 vs 一月 28–31 天
- 位置：§3.8 屏02 / §7-1
- 预期：7 柱来自按天序列的**下采样/分箱**，且与 trend 曲线同源同口径。
- 待验证：定下采样策略（等距抽样 or 分箱聚合），确保 7 柱与 trend 方向一致、不自相矛盾。

### [OPEN] A7 氛围大背景：图淡入 → 色淡入的改造
- 位置：§4.4 / §3.1
- 预期：氛围层主层改用 `appColor` 渐变。
- 待验证：现有 `DesktopAppShell` 记忆湖背景层是 `Image{source:url}` 双图淡入；改渐变色需调成
  双色淡入。属预期不符，落地时确认改法、避免回归到图片糊大背景。

---

## 实现期新发现（按时间追加）

> 实现过程中新出现的不符项写在这里，沿用上面的条目格式。

### [RESOLVED] B1 frontmost_sessions 生产环境是否落库不可确认 → 改走 USM 记录派生
- 日期：2026-06-03
- 位置：计划 §2.1 / §7-5（launches/longest/time-river 来源）
- 预期：`frontmostRepository.getSessionsByRange` 是「已上线、只读 SQLite」的可用会话源。
- 实际：勘查代码发现 (a) UI 侧 `addFrontmostSession`/`upsertApp` 仅被 `tests/db_smoke.cpp` 调用，
  无任何生产调用方；(b) `frontmost_sessions` 表由**服务端** `src/service/windows/storage/usage_storage.c`
  写入，但受 `use_sqlite` 后端开关 + 服务/UI 是否共用同一 DB 文件影响，**生产是否真有数据无法静态确认**。
- 影响：若该表为空，launches/longest/time-river 会全空态。
- 处置：**改从 `UsageStatManager` 自己的 `m_records`（=首页同款已验证 JSONL 路径）派生会话**，
  不依赖 SQLite。安全面与首页完全一致（保证 2），且避免 `appIdentifier`↔`groupKey` 跨源 join 问题。
  未改 schema、未碰服务端。真机验收：仍需确认 SQLite 路径是否会被误用（本实现不用它，故影响为 0）。

### [RESOLVED] A1 「次切换」语义 → 服务按「同 exe+同窗口标题连续」切会话
- 日期：2026-06-03
- 位置：§3.2 总览副标 / §7-5
- 实际：`usage_tracker.c:36-57,120-129` 确认——前台记录是「同 exe 且同窗口标题」的连续时段，
  exe 或标题一变就滚动成新记录。浏览器换标签页标题会**频繁切会话 → 记录数虚高**。
- 处置：派生 launches 时，把**同一 groupKey 相邻且间隙很小（contiguous, gap ≤ 60s）**的记录**合并成一次会话**，
  消除标题抖动，保留真实再次访问（中间隔了别的 app → 有真实间隙，不合并）。launches=合并会话数，
  longest=最长合并会话，time-river=合并会话段。文案用「N 次使用」中性措辞。

### [RESOLVED] A3 取图/身份字段名因来源而异 → 统一走 USM 的 path
- 日期：2026-06-03 ｜ 位置：§2.2 / §4.5
- 实际：USM 项用 `path`（exe 全路径）；FSR 用 `appIconPath`/`appIdentifier`。本实现只用 USM，
  故图标统一 `image://appicon/<encodeURIComponent(path)>`，path 为空走 appColor 兜底。

### [OPEN] A4 classifyApp 命中率偏低（待真机统计）
- 日期：2026-06-03 ｜ 位置：§5 / §7-3
- 实际：`classifyApp`（daily_card_service.cpp:48）关键词表小且偏 Windows exe 名，**无 chrome/firefox/figma/
  excel/word 等**，且读 `appIdentifier`+`displayName` 两键（USM 项用 `name`/`path`/`appId`，字段不兼容）。
- 处置：本实现喂 classifier 时把 USM 项适配成 `{appIdentifier: path, displayName: name}`；类别串用中文（游戏/视频/
  音乐/社交/开发/其他）。**真机需统计「其他」占比是否过高**；偏高则后续补关键词（仍本地确定性，不喂 AI）。
  未补全前，type 显示真实类别（含「其他」），不伪造细分。

### [RESOLVED] A5 图标缺失占比 → appColor 兜底（强制，非可选）
- 日期：2026-06-03 ｜ 位置：§4.3 / §4.5
- 实际：`AppIconImageProvider` 在 path 空/文件不存在时返回**透明 pixmap**；服务端 `apps.app_icon_path`
  常为空串。处置：所有图标位都叠在 appColor 底块/渐变上，图标缺失只是少一枚图标，版式与色仍完整。

### [RESOLVED] A7 氛围大背景：图淡入 → 色淡入改造
- 日期：2026-06-03 ｜ 位置：§4.4 / §3.1
- 实际：`DesktopAppShell.qml:230-260` 确为**双 `Image{}` 交叉淡入 + MultiEffect blur:0.82/blurMax:64**；
  且 page 的 `ambientSource` 是 **`url` 类型**，shell 用 `!= ""` 判空。处置：page 增 `ambientColor`(color)
  供 shell 拉取（沿用 duck-type 拉取方向），shell 背景主层改为**双 Rectangle 渐变交叉淡入**（保留 450ms
  Behavior），仅改记忆湖背景层（§10 🟢 可改），不动其它页面。

### [RESOLVED] B2 classifyApp 文件内私有 → 经 DailyCardService 暴露
- 日期：2026-06-03 ｜ 位置：§5 / §7-6
- 实际：`classifyApp` 是 daily_card_service.cpp 匿名命名空间自由函数，跨 TU 不可调用。
- 处置：在 `daily_card_service.*`（非冻结）内新增记忆湖模型方法直接复用它；不新建源文件，不动冻结 CMake。

### [RESOLVED] B3 写死位置/坐标系勘误（供阶段一/二落地）
- 日期：2026-06-03 ｜ 位置：§3.6 / §3.8 / §6
- 实际：(a) 趋势曲线写死 `pts` 实际在 `RecapSlide.qml:433`（计划写 :427），14 个值。
  (b) 时间河流轴**写死在 `TimeRiver.qml:11-15`**（`Mock.timeAxis/timeRuler` 定义了但 QML 不读）；
  节点 y 用 0–100 百分比，轴 y 用 0–1 分数，**两套坐标系**，做动态轴时必须统一到同一时间窗（§3.6）。
- 处置：阶段一统一时间窗并参数化轴；阶段二把 :433 写死曲线换按天序列。

### [RESOLVED] B4 背景是预设单色、与图标真实色调不符 → 已接图标主色多色 blend
> 2026-06-03 已落地：`usage_stat_manager.cpp` 新增 `iconDominantColors(path)`（QFileIconProvider 取图标
> 位图、量化直方图取最多 3 主色、跳过透明/灰/黑白、按 path 缓存），item 输出 `iconColors`；放在 USM
> 而非 DCS（db_smoke 只链 Core+Sql，DCS 不能含 QtGui 头）。背景/封面改图标主色多色渐变 + 两团模糊色块
> 混入（`DesktopAppShell` 记忆湖背景层 + `GenerativeCover` + 回顾背景），缺色退回 appColor。真机实测：
> QQ Music 背景已是其图标的绿+金双色 blend，非预设单色。下方原始条目存档。

### [DEFERRED→阶段三] B4 背景是预设单色、与图标真实色调不符
- 日期：2026-06-03
- 位置：§4.4 / §8 阶段三 / `DesktopMemoryLakePage.ambientColor` → `DesktopAppShell` 记忆湖背景层
- 预期：背景以**图标主色系**做 blend，贴合该 APP 图标观感。
- 实际（截图）：给所有图标统一套了 `appColor`（查表/哈希出的**预设单色**），背景几乎是**纯色色系**，
  没有图标本身的色调；appColor 并非从图标像素提取。
- 影响：纯观感问题，不影响数据正确性（数字/文案仍真实）；故**不阻塞**阶段一/二。
- 处置：**排期到阶段三**（§8）——加 C++ `appIconDominantColors(path)`（取图标位图统计 1–3 主色、按 path 缓存），
  背景/卡面底色改多色 blend，`appColor` 降级为取色失败兜底。用户已确认排在 Phase 2 之后。

### [OPEN] B5 系统/外壳进程上榜 + 类别「其他」占比偏高（真机观察，A4 延伸）
- 日期：2026-06-03
- 位置：§5 / §7-3 / §3.8（回顾主角、最高类别、关键词）
- 实际（真机回顾截图）：当月 Top1 = `StartMenuExperienceHost`（开始菜单外壳进程，5h30m）、最高类别
  「其他 41%」。系统/外壳进程（StartMenuExperienceHost / 锁屏 / 资源管理器等）与未被 `classifyApp`
  命中的常用软件都落「其他」，导致主角位与"最高类别"偏向系统进程/其他。
- 影响：**数据真实、不阻塞**（每个数字可追溯，与首页同源）；但回顾"主角"观感偏弱，"其他"当头不够漂亮。
- 处置：不伪造、不静默过滤（过滤前台进程属服务端/行为变更，超本轮范围）。后续可选：
  (a) 在 UI 侧 classify 增补常见软件关键词（仍本地确定性，不喂 AI）；
  (b) 评估是否把纯外壳进程并入"系统/其他"并降权。均**待用户拍板**，本轮先如实展示。

### [RESOLVED] B6 回顾趋势把"未来天"补 0 → 误判"月末回落"（断言守卫漏洞，对抗式评审发现）
- 日期：2026-06-03 ｜ 位置：§6 断言守卫 / `dailySecondsForMonth` / `monthTrendDir` / 回顾 02·08 屏
- 预期：趋势方向（升/降/平）由**真实序列**条件生成，数据不支持就走中性句，绝不写死方向。
- 实际：`dailySecondsForMonth` 把当月**整月**每天都补进序列（含尚未发生的未来天=0）。月初时
  后 1/3 全是未来 0，`monthTrendDir` 据此判成 `falling` → 02 屏"使用强度在月末逐渐回落。"、
  08 屏"使用在月末逐渐回落。"——**数据不支持的断言**（月末根本还没到）；月历柱/趋势曲线也把
  未来天画成 0 尾巴。
- 影响：向用户展示了**错误的行为趋势断言**（非崩溃、随月份推进自愈）。违反 §6 断言守卫本意。
- 处置：**根因修复**——`dailySecondsForMonth` 对"当月"只覆盖到今天为止（过去月用整月天数），
  一处修好趋势判定 + 月历柱/曲线尾巴。已 `record_error.py L3`。修复后月初（<6 天）走 `flat`
  中性句，elapsed 足够后才据真实首末段判方向。

### [RESOLVED] B7 任务化重构：分类增强 + 任务块总结 + Top10 + 系统降权 + 碎片→穿插（用户拍板）
- 日期：2026-06-03 ｜ 位置：§5 / §7-3 / §3.2 / §3.3 ｜ 关联：A4、B5
- 背景：用户反馈"其他"占比最大、StartMenuExperienceHost 当主角、排行被 <1min 长尾撑长、
  "碎片"无法概括"在多 app 间正常跳转"的日常。用户选定"任务块 + 分类增强"方向，并准许窗口标题做本地分类。
- 处置（已落地）：
  1. **分类增强（A4）**：`usage_stat_manager.cpp` 新增 `classifyActivity`，除 exe/显示名外**读窗口标题**
     做本地确定性分类（仅定类别，绝不展示原文/不进 AI/不落库——符合隐私边界 §1.5/§9）；类别扩到
     游戏/视频/音乐/社交/开发/办公/创作/笔记/浏览/系统/其他；逐记录按标题分类、时长加权，item 输出 `category`。
  2. **系统/外壳桶（B5）**：StartMenuExperienceHost/SearchHost/explorer/dwm… 归「系统」，排行沉底、
     不当今日主题头条、不当回顾主角（catOf + skip 系统）。
  3. **任务块总结（§3.2 头条）**：`taskBlocks` 把全 app 前台会话段在统一时间轴合并成"连续使用块"
     （块间空闲 <12min），按块时长取主类别+代表 app；今日主题头条＝**前台任务**占比（背景音乐不顶上来），
     desc="今天有 N 段连续使用，最长约 X，主要在 A、B"。真机实测：从误判"音乐为主"修正为"开发为主"。
  4. **Top10（§3.3）**：日视图 apps 截前 10（非系统优先），<1min 长尾不进 List。
  5. **碎片→穿插**：单 app 多短段判为中性「穿插使用」（非负面"碎片"）；"是否专注"改由 day 层连续块判断。
- 真机验收：开发为主 / 9 段连续使用 / 排行含 StreetFighter6·Terminal·Discord·QQ Music（真实图标）、
  系统进程已沉底。build/scan/harness_check 干净。**仍 OPEN 的尾巴**：classifyActivity 关键词表可继续补全
  （长尾软件仍可能落"其他"）；是否进一步把音乐/视频的"前台 vs 背景"在更多面区分，待用户反馈。
