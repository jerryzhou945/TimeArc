# 08｜音频与媒体追踪：独立信号、去重和失败语义

> 本章目标：理解多个 app 同时输出声音时，TimeArc 怎样维护独立 session，并避免 probe 失败造成错误关闭。
> Source map: `tracker/audio_tracker.c`, `platform/audio_win.c`, `platform/app_identity.c`.

## 1. 为什么音频不能附属于前台窗口

常见场景：

- Spotify 在后台播放，VS Code 在前台；
- 浏览器视频在前台，键鼠长时间没有输入；
- 通知音只播放几秒；
- 多个进程同时拥有 WASAPI session。

因此音频是和前台窗口并列的 **independent signal（独立信号）**。它有自己的采样、状态和数据库表。

## 2. audio tracker 的内存模型

`TimeArcAudioTrackerState` 内有固定数量的 session slot。每个 slot 概念上保存：

```text
active          是否被占用
app             app identity + 当前标题
start_sec       当前持久化片段起点
seen_this_poll  本轮是否再次看到
```

固定数组避免长期服务循环中频繁动态分配，也为“最多追踪多少音频 app”提供明确上限。

## 3. 每轮先清 seen flag

`timearc_audio_tracker_poll()` 开头：

```c
for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
  state->sessions[i].seen_this_poll = 0;
}
```

随后平台 probe 返回本轮活跃音频 app；看到的 app 被重新标记为 1。最后，只有在采样成功的前提下，没被重新看到的旧 session 才会关闭。

这是一种 **mark-and-sweep（标记后清理）** 思路。

## 4. 根据什么去重

平台 API 可能返回同一 app 的多个音频 session。TimeArc 用 `timearc_app_identity_equal()` 按稳定 app identity 合并，而不是把每个 WASAPI object 当作用户可见 app。

为什么不能只比较显示名？

- 两个程序可能同名；
- app 更新后显示名可能变；
- 本地化语言可能改变显示名；
- executable path 更接近稳定身份。

详细 identity 规则会在统计章节继续解释。

## 5. start 或 update

核心流程：

```c
TimeArcAudioSession* session = find_session(state, app);
if (session == NULL) {
  session = find_free_session(state);
  session->app = *app;
  session->active = 1;
  session->start_sec = now_sec;
} else {
  session->app = *app;
}
session->seen_this_poll = 1;
```

已存在时更新整个 `app` 很重要：同一播放器在 session 存续期间，窗口标题可能从歌曲 A 变成歌曲 B。当前 session 最终会使用较新的 metadata。

这也带来一个可讨论的取舍：如果需要逐首歌精确分段，应把 title change 也定义成边界；当前实现主要按 app 音频活动区间追踪。

## 6. “没看到”与“采样失败”不是一回事

这是本章最重要的可靠性逻辑：

```c
const int sample_succeeded =
    timearc_win_get_audio_apps(...) == 0;

if (sample_succeeded && !session->seen_this_poll) {
  close_audio_session(session, now_sec);
}
```

两种情况：

| 情况 | 语义 | 动作 |
|---|---|---|
| probe 成功，app 不在结果中 | 有证据表明已停止 | 关闭 session |
| probe 失败 | 不知道是否停止 | 保留 session，等待下轮 |

这叫 **absence vs uncertainty（不存在与不确定）**。把二者混为一谈会在 API 瞬时失败时切碎媒体记录。

## 7. persistence 的顺序

写一条音频记录前：

```c
update_apps(...);
update_media(...);
```

先 upsert app identity，再写 media session。这满足逻辑上的引用关系：session 中的 `app_id` 必须能指向 app catalog。

标题策略：

```c
const char* title = session->app.window_title[0] != '\0'
                        ? session->app.window_title
                        : "Audio playback";
```

平台没拿到真实标题时仍有安全 fallback，避免空字符串让 UI 难以解释。

## 8. 音频如何影响前台 active time

`timearc_audio_tracker_has_foreground()` 只在以下条件返回 true：

1. 上次音频采样成功；
2. 对应 session 本轮 active 且 `seen_this_poll`；
3. process id 或 executable path 与前台 app 匹配。

它不会因为“电脑上任意 app 在播放音乐”就让当前前台 VS Code 自动 active。信号必须归属于同一 app。

## 9. checkpoint 与 flush

长媒体播放同样会定期 checkpoint：

```text
若 now - start >= checkpoint
  写 [start, now]
  start = now
```

退出时 `timearc_audio_tracker_flush()` 遍历所有 active slots 并关闭。这保证最后一段尽可能落盘。

## 10. 底层 WASAPI 的角色

`src/service/windows/platform/audio_win.c` 负责 Windows-specific probing：

- 初始化 COM/WASAPI 相关对象；
- 枚举音频 session；
- 取得关联进程；
- 解析 app identity/title；
- 向 tracker 返回普通 `AppInfo` 数组。

上层 `audio_tracker.c` 不应该知道 COM interface 细节。这个边界叫 **platform adapter（平台适配器）**。

## 11. 边界场景

### 同时播放两个 app

两个 slot 分别维护 session，分别写入 `media_sessions`。

### 音频 app 崩溃

下一次成功 probe 中它缺席，于是 session 以当前时间关闭。

### probe 连续失败

session 暂时保留，可能造成少量尾部高估；但比每次失败都错误切碎更稳。可在未来增加 maximum uncertainty timeout。

### 超过固定 slot 数

`find_free_session()` 返回 null，新 app 本轮不被跟踪。这是容量上限带来的显式降级，而不是越界写内存。

## 12. 面试表达

> Audio tracking is an independent state machine because background playback is not tied to foreground focus. We deduplicate native audio sessions by application identity, checkpoint long-running sessions, and distinguish a successful sample with no app from a failed sample. That failure semantic prevents transient WASAPI errors from closing every media session.

## 13. 本章练习

1. 用自己的话解释 `seen_this_poll`。
2. 为什么 probe 失败不能等同于空数组？
3. 如果产品要逐首歌统计，状态边界需要怎样改变？
4. 固定数组和动态容器各有什么优缺点？

下一章：[用状态机理解全部采集逻辑](09-state-machines-by-example.md)
