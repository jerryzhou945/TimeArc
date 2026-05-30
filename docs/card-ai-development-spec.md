# TimeArc 卡片与 AI 开发规格

## 目标

这个文档把 `life-timeline-product-direction.md` 里的大方向落到可开发的
模型和阶段。核心判断是：

> 卡片是产品载体，AI 是内容编辑器，不是采集器。

## 优先级

当前优先级顺序：

1. Card Data Model
2. Daily Summary Model
3. 本地卡片生成
4. 桌面端卡片 UI
5. 隐私过滤与用户确认
6. AI 文案增强
7. 移动端技术选型

移动端是否继续使用 Qt/QML 暂时不要绑定。只要卡片模型稳定，未来可以用
QML、Flutter、React Native 或原生实现。

## Card Model

一张卡片应该是 UI 技术无关的结构。

```json
{
  "id": "2026-05-30-mainline",
  "date": "2026-05-30",
  "type": "mainline",
  "title": "今日主线",
  "body": "你今天的主要时间集中在 TimeArc 项目开发上。",
  "time_range": "14:00-18:20",
  "metrics": [
    { "label": "开发时间", "value": "4h 20m" }
  ],
  "tags": ["开发", "学习"],
  "confidence": 0.82,
  "source": "local_rule",
  "ai_generated": false
}
```

字段说明：

- `type`: `mainline`, `top_apps`, `focus_block`, `entertainment`,
  `contrast`, `random_flip`, `ai_summary`。
- `source`: `local_rule`, `local_template`, `ai_generated`, `user_edited`。
- `confidence`: 本地规则或 AI 的可信度，用于决定是否提示用户确认。
- `ai_generated`: UI 可以据此显示“AI 生成 / 可编辑”状态。

## Daily Summary Model

AI 和卡片生成器都不直接读取原始日志，而是读取本地摘要。

```json
{
  "date": "2026-05-30",
  "total_active_sec": 28800,
  "top_apps": [],
  "activity_blocks": [],
  "category_summary": [],
  "manual_projects": [],
  "calendar_tasks": [],
  "privacy_redactions": []
}
```

`privacy_redactions` 记录哪些内容被隐藏，例如聊天窗口标题、浏览器标题、
文档文件名。这样 AI 总结时可以解释“部分上下文被保护”，但不能猜测内容。

## Activity Block

`activity_blocks` 是 Daily Card 的关键输入。

```json
{
  "start": "14:00",
  "end": "16:20",
  "category": "development",
  "apps": ["VSCode", "Chrome"],
  "keywords": ["TimeArc", "Qt", "CMake"],
  "sources": ["foreground"],
  "privacy_level": "normal"
}
```

合并规则第一版可以保守：

- 同一 category 中断小于 10 分钟，可以合并。
- `foreground` 和 `audio` 重叠时按区间并集计算，不重复计时。
- 聊天、银行、密码、医疗类 App 不贡献关键词。
- 浏览器 title 未授权时只贡献 `browser_activity`。

## AI 内容工作

AI 适合做：

- 总结：把结构化事实变成自然语言。
- 命名：给一天、时间段、卡片起标题。
- 归类辅助：对模糊 title 给出 category/topic 建议。
- 洞察表达：指出时间分布、长专注块、娱乐集中时段、计划和实际差距。
- 文案润色：把模板句子变成更像生活记录的表达。

AI 不应该做：

- 采集数据。
- 读取原始日志。
- 读取聊天内容、截图、原始音频。
- 对用户做道德评价。
- 在未授权标题上推断私人内容。
- 自动修改历史记录。

## AI Payload Policy

发送给 AI 的 payload 必须来自 `Daily Summary Model`，并经过
`Privacy Filter`。

允许进入 AI：

- App 聚合时长。
- 用户授权的窗口标题关键词。
- 用户主动创建的项目、待办、照片描述。
- 本地分类结果。
- 被隐藏内容的占位说明。

禁止进入 AI：

- 全量 `usage_records.jsonl`。
- 聊天正文、联系人、群名。
- 截图、OCR、原始音频。
- 未授权浏览器 title / URL / 历史。
- 密码、银行、医疗等敏感 App title。

## AI 输出格式

AI 必须返回结构化结果，避免 QML 直接渲染不可控长文。

```json
{
  "daily_title": "TimeArc 开发日",
  "cards": [
    {
      "type": "mainline",
      "title": "今日主线",
      "body": "你今天的主要时间集中在 TimeArc 开发上。",
      "tags": ["开发", "学习"]
    }
  ]
}
```

## 开发阶段

### Phase 1: 本地卡片

- 新增 Daily Summary 生成逻辑。
- 用规则生成 5-6 张 Daily Card。
- 先在桌面端 Memory Lake 或 Stats 中展示。
- 不接 AI。

### Phase 2: 隐私与编辑

- 加敏感 App 默认保护。
- 加浏览器 title、媒体 title 的开关。
- 允许用户修正卡片分类和标题。

### Phase 3: AI 增强

- 展示将发送给 AI 的摘要。
- 用户确认后生成 AI 文案。
- 保存 AI 结果，并允许用户编辑。

### Phase 4: 移动端

- 使用同一套 Card JSON。
- 移动端只做展示、翻牌、分享、小组件。
- 技术栈在 Card Model 稳定后再决定。
