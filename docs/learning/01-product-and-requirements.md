# 01 · 产品问题、隐私与需求 / Product, Privacy, and Requirements

## 本章目标 / Learning goals

理解 TimeArc 解决的问题，并把“本地优先、真实、不评判”翻译成可验证的工程约束。

## 1. 产品问题不是“做一个计时器”

普通计时器要求用户主动点击开始和停止。TimeArc 想回答的是：“我一天真实把时间花在了哪些应用、网页和媒体上？”因此它需要后台观察、会话切分、身份归一、区间聚合和可读界面。

**Interview English:** “The core problem was not stopwatch timing. It was reconstructing a trustworthy local timeline from noisy operating-system activity signals.”

## 2. 用户价值 / User value

- 自动记录前台应用和有效媒体活动。
- 按日、周、月、年理解时间分布。
- 保留全部应用，而不仅是 Top App。
- 允许手动项目、番茄钟、标签和回顾补充自动数据。
- 分享时默认隐藏标题、联系人、URL、包名等敏感上下文。

TimeArc 不做“效率分数”。这不是一句宣传语，而是数据和文案边界：系统展示证据，用户自己解释生活。

## 3. 从产品原则得到工程需求

| 产品原则 | 工程要求 |
| --- | --- |
| Local-first / 本地优先 | 原始历史进入本地 SQLite，不要求云账号 |
| Private by default / 默认隐私 | 不采聊天内容、截图、OCR、原始音频，不默认读浏览历史 |
| Evidence first / 证据优先 | 洞察必须能回到真实区间和聚合结果 |
| Honest timing / 真实计时 | 重叠信号按区间并集合并，不能重复累计 |
| User control / 用户控制 | 配置可关闭采集；关闭后不被下次启动偷偷重新打开 |
| Failure isolation / 故障隔离 | UI 崩溃不应终止采集，服务故障不应拖垮 UI |

## 4. 功能需求与非功能需求

功能需求（functional requirements）描述“系统做什么”：采集前台应用、识别播放、生成统计、显示页面。

非功能需求（non-functional requirements）描述“系统必须以什么质量完成”：隐私、稳定、跨平台、可恢复、低后台开销、可测试、无重复计时。

面试时主动讲非功能需求，会比罗列页面更能体现工程思维。

## 5. 先定义边界，再选择技术

TimeArc 的关键边界：

- 采集器只观察操作系统给出的活动信号，不读取内容正文。
- 自动历史由服务独占写入，避免多个写入者竞争。
- UI 消费事实并生成表达，不负责采样。
- AI 或分享只能处理本地过滤后的派生数据，不能直接接触原始日志。

**Interview English:** “I translated privacy goals into architectural boundaries: the collector records metadata, the UI reads derived facts, and sensitive raw context never becomes a cloud dependency.”

## 6. 需求如何变成验收条件

例如“正确记录前台时间”太模糊，可以拆成：

1. 切换应用时，上一段关闭，新应用开启。
2. 普通应用超过 idle 阈值后，活动时长停止增长。
3. 被允许的视频、Agent 或游戏策略可按规则跨越键鼠 idle。
4. 同一时段前台和媒体都成立时，总时长只算一次。
5. 服务重启后数据库仍可读，重复写入不会产生重复会话。

这就是从 product requirement 走向 acceptance criteria。

## 源码入口 / Source entry points

- `README.md`：产品和平台状态。
- `PRODUCT.md`：产品语气与设计原则。
- `.harness/CHARTER.md`：不能悄悄改变的架构约束。
- `src/service/README.md`：采集规则、配置和数据库契约。

## 常见误区 / Common mistakes

- 把“进程正在运行”当作“用户正在使用”。TimeArc 明确拒绝这种推断。
- 把窗口标题当作内容采集。标题只是受限制的元数据，而且分享时需要过滤。
- 把页面数量当作架构。页面是输出端，真正核心是可信的数据链路。

## 面试练习 / Interview prompt

**Q: What problem does TimeArc solve?**

**A:** “It turns fragmented operating-system activity into a private, evidence-based timeline. The difficult part was defining reliable activity semantics and privacy boundaries, not simply drawing charts.”

## 复习题 / Review

1. 为什么 TimeArc 不是普通秒表？——因为它从系统信号自动重建真实活动区间。
2. “本地优先”如何影响架构？——原始数据本地落盘，采集与展示通过本地契约解耦。
3. 为什么不做效率评分？——数据只能证明时间发生，不能客观证明价值。
