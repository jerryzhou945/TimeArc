# TimeArc 生活时间线产品方向

## 产品定位

TimeArc 不应该只被定义成一个普通的时间管理工具。

更准确的方向是：

> TimeArc 是一个本地优先的生活时间线工具，把每天花掉的时间重新整理成可以回看的个人记忆卡片。

普通 time tracker 只能回答：

> Chrome 3 小时，Steam 2 小时，VSCode 4 小时，微信 1 小时。

这个信息太浅。用户看完以后最多只会觉得“我今天又浪费时间了”。

TimeArc 更应该回答：

> 这些时间分别代表什么生活行为？它们和工作、学习、娱乐、社交、计划和回忆有什么关系？

这样产品就从 `time tracking` 变成 `life context tracking`。

## 核心原则

默认只记录时间轮廓，不记录私人内容。

TimeArc 应该把边界说清楚：

> 不录屏，不自动截图，不读取聊天内容，不保存原始音频。只使用轻量本地上下文，并且 AI 总结必须由用户确认后生成。

这能让 TimeArc 和 Rewind / screen recorder 一类产品拉开距离。TimeArc 的卖点不是“什么都记录”，而是“用足够轻的上下文帮用户理解自己的一天”。

## 数据边界

| 数据类型 | 默认策略 | 说明 |
|---|---|---|
| App 使用时间 | 默认记录 | 基础层：前台应用、时长、来源。 |
| Window title | 可开关 / 可分 App 配置 | 价值高，但隐私风险也高。 |
| 浏览器网页 title | 默认关闭或保护 | 用户开启浏览器上下文后才记录。默认不读历史。 |
| URL / 浏览历史 | 默认不记录 | 未来只有在用户主动安装插件时才考虑。 |
| 音乐 / 视频标题 | 可选 | 从窗口标题或系统媒体元数据读取，不做音频识别。 |
| 聊天软件使用时间 | 可记录 / 可关闭 | 只记录 App 级别时长。 |
| 聊天内容 | 不做 | 硬边界。 |
| 联系人 / 群名 | 默认不记录 | 即使记录窗口标题，也不建议进入 AI。 |
| 截图 / OCR | MVP 不做 | 风险高，会改变产品性质。 |
| 原始音频 / 麦克风 | 不做 | 记录播放状态和时长，不记录声音内容。 |
| 手动项目计时 | 默认记录 | 用户主动创建的数据。 |
| 日历待办 / 照片 | 默认记录 | 用户主动创建的数据。 |
| AI 总结 | 用户确认后生成 | AI 读取过滤后的本地摘要，不读取原始日志。 |

## 电脑端和手机端分工

电脑端是记忆采集器。

适合记录：

- 工作内容
- 学习内容
- 代码项目
- 浏览器网页标题
- 音乐 / 视频标题
- 游戏时间
- 长时间专注块

手机端是记忆展示器。

适合做：

- 今日翻牌
- 本周时间卡
- 年度总结
- 随机回忆
- 分享图片
- 小组件
- 每日提醒

第一阶段应该先把桌面端 Daily Card 的数据模型做稳定，再考虑手机端展示。

## Daily Card MVP

第一个大功能建议定为：

> Daily Card / 每日时间卡

每天结束时，TimeArc 自动生成几张本地卡片。

### 1. 今日主线卡

示例：

> 你今天的主线是 TimeArc 项目开发。你在 VSCode、Chrome、CMake 和 Qt 文档之间切换了 4 小时 20 分钟。

来源：最长、最连续、最能代表当天主题的工作 / 学习 / 项目时间块。

### 2. App 使用卡

示例：

> VSCode 4h 20m，Chrome 2h 10m，Steam 1h 30m。

这是最基础的可量化层。

### 3. 专注块卡

示例：

> 14:00-16:20 是今天最长的连续开发时间段。

来源：合并 foreground、audio、manual timer 后的连续活动片段。

### 4. 娱乐卡

示例：

> 今天 Steam 和视频内容共 2 小时 15 分钟，主要发生在晚饭后。

来源：App 分类、窗口标题、媒体标题。

### 5. 反差卡

示例：

> 你计划学习 3 小时，实际检测到的学习相关时间约 1 小时 25 分钟。

来源：日历待办 / 手动项目 和实际 App 上下文的对比。

### 6. 随机翻牌卡

示例：

> 今天最常打开的软件是：微信。

这类卡适合后续手机端和分享图。

第一版不需要 AI。先用本地规则和模板生成卡片，AI 后面只做文案增强。

## 技术管线

推荐的数据流：

```text
usage_records.jsonl / usage_current.json
manual project sessions
calendar to-dos
day photos
        |
        v
Activity Segmenter
        |
        v
Classifier
        |
        v
Privacy Filter
        |
        v
Daily Summary Builder
        |
        v
Card Generator
        |
        v
QML Daily Card UI / Memory Lake
```

## Activity Segmenter

负责把零散记录合并成有意义的活动段。

例如原始记录：

```text
14:00-14:35 VSCode / TimeArc
14:35-14:50 Chrome / Qt docs
14:50-15:20 VSCode / TimeArc
```

可以合并成：

```text
14:00-15:20 TimeArc 开发
```

这一步是 Daily Card 的基础。没有它，产品只能展示零散 App 时长。

## Classifier

负责把 App 和标题上下文分类。

第一版可以先用本地规则，不需要 AI。

初始分类：

- 开发
- 学习
- 工作
- 娱乐
- 社交
- 音乐
- 视频
- 游戏
- 生活
- 其他

示例规则：

```text
VSCode + TimeArc -> 开发
Chrome + Qt / CMake / Unity -> 学习或开发资料
Steam -> 游戏 / 娱乐
微信 / QQ / Discord -> 社交
Bilibili + tutorial / 教程 -> 学习视频
Bilibili + 番剧 / 娱乐关键词 -> 娱乐视频
```

## Privacy Filter

负责在展示和 AI 总结前过滤敏感内容。

建议默认规则：

- 聊天软件：只保留 App 时长，不保留窗口标题。
- 浏览器：用户未开启时，只显示浏览器活动。
- Office / PDF：文件名默认保护。
- 银行、密码、医疗类 App：不记录 title，不进入 AI。
- 媒体标题：用户可开启，但不分析原始音频。

这层必须在 AI 之前执行。

## Daily Summary Builder

负责生成结构化的本地摘要。

示例：

```json
{
  "date": "2026-05-30",
  "main_theme": "TimeArc 开发",
  "top_apps": [
    { "name": "VSCode", "seconds": 15600 },
    { "name": "Chrome", "seconds": 7800 }
  ],
  "focus_blocks": [
    {
      "start": "14:00",
      "end": "16:20",
      "category": "development",
      "keywords": ["TimeArc", "Qt", "CMake"]
    }
  ]
}
```

AI 不应该直接读原始日志。它应该只读这种已经过滤过的摘要。

## Card Generator

负责把结构化摘要变成卡片。

第一版可以完全用模板：

```text
你今天的主线是：TimeArc 开发。
你在 VSCode、Chrome 和 Qt/CMake 文档之间切换了 4 小时 20 分钟。
```

这样即使没有 AI key，TimeArc 也能工作。

## AI 总结策略

AI 是增强层，不是采集层。

正确流程：

```text
raw local records
  -> local summary
  -> privacy filtering
  -> user confirmation
  -> AI generation
  -> saved daily cards
```

AI 不应该读取：

- 全量原始日志
- 聊天内容
- 截图
- 原始音频
- 未授权窗口标题
- 敏感 App 标题

AI 输出最好也是结构化的：

```json
{
  "daily_title": "TimeArc 开发日",
  "cards": [
    {
      "type": "mainline",
      "title": "今日主线",
      "body": "你今天的主要时间集中在 TimeArc 开发上。"
    }
  ],
  "tags": ["开发", "学习"]
}
```

这样 QML 展示会稳定，不会因为 AI 随机输出长文而破坏 UI。

## 建议实现顺序

1. 做本地 Daily Summary，不接 AI。
2. 做 App / Window title 分类规则。
3. 做 Daily Card UI，优先放进 Memory Lake。
4. 做敏感 App 和浏览器 title 的隐私设置。
5. 做用户可编辑分类。
6. 接入用户确认后的 AI 总结。
7. 最后再做手机端展示和分享图。

## 第一阶段不做

这些能力不应该进入第一阶段：

- 录屏
- 自动截图
- OCR 屏幕内容
- 读取聊天消息
- 会议转写
- 保存原始音频
- 抓取浏览历史
- 默认上传云端

## 一句话总结

TimeArc 帮用户把一天中碎片化的 App 使用，整理成私密、可回看的生活时间线：本地优先，默认轻量，只有在用户确认后才使用 AI。
