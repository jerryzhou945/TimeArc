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
