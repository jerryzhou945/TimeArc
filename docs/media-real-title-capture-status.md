# Media 真实标题采集状态

更新时间：2026-06-06
工作区：`D:\TimeArc\time-arc`
分支：`codex/media-real-title-capture`

## 本轮完成

- D 盘仓库已更新到远端最新 `dev`，并从 D 盘创建功能分支。
- Windows audio 采集不再只依赖固定的 `Audio playback`：
  - 优先读取 Windows GSMTC / 系统媒体控制中心的 `title` 和 `artist`，格式化为 `title - artist`。
  - 如果当前播放进程正好在前台，回退使用同进程前台窗口标题。
  - 如果播放进程有可见窗口，回退枚举该进程窗口标题。
  - 再回退 WASAPI audio session display name。
  - 都拿不到时才写 `Audio playback`。
- audio 采集现在会检查 `eConsole / eMultimedia / eCommunications` 三种默认播放角色，减少漏采。
- `media_sessions.media_title` 继续沿用现有 schema，无需数据库迁移。
- `MediaSessionRepository::getTodayMediaRanking()` 现在返回 `mediaTitle`，并按 `app + media_type + media_title` 聚合，方便之后月报写“听了什么歌/看了什么视频”。
- `tests/db_smoke.cpp` 增加了 media title 持久化和今日 ranking 暴露测试。
- D 盘 `time-arc-service.exe` 已重新编译，并已重启为新版本。

## 本轮验证

- D 盘 preflight：通过。
- `build.py --target time_arc_service`：通过。
- `build.py --target timearc_db_smoke`：通过。
- `build\timearc_db_smoke.exe`：通过。
- 新 service 进程确认：`D:\TimeArc\time-arc\build\time-arc-service.exe`，2026-06-06 18:53:23 启动。
- 数据库最新 media 记录在 service 重启前仍是 `Audio playback`；重启后当时没有新的播放片段写入，所以运行态真实标题还需要再播放一小段网易云/Chrome 音频后复查。

## B 站时长核对结论

用户提到的视频标题：`更了300多期视频以后。。。终于轮到我了！！！_哔哩哔哩_bilibili - Google Chrome`。

2026-06-06 本机 SQLite 原始 `frontmost_sessions` 里：

- 该精确标题共 14 段。
- 原始时长合计：577 秒，即 9 分 37 秒。
- 60 秒以内间隔合并后：622 秒，即 10 分 22 秒。
- 今日所有 B 站 Chrome 前台标题合计：1285 秒，即 21 分 25 秒。

因此目前 UI 里看到接近 19 分钟/20 分钟的 B 站时长，更像是 `site:bilibili` 站点级聚合，而不是单个视频标题级聚合。当前系统会把 Chrome 的 B 站窗口标题归为 `site:bilibili`，适合回答“今天用了 B 站多久”，但还不能直接在 UI 上回答“这个具体视频看了多久”。

## 仍未完成

- 还没有把 GSMTC fallback 替换成原生 WinRT ABI；当前实现会通过 PowerShell 查询系统媒体元数据，能验证方向，但不是最终形态。
- 还没有浏览器扩展，因此后台多标签页场景下，Chrome 只能依赖窗口标题/GSMTC，不能稳定知道哪个 tab 正在 audible。
- UI 还没有视频级/歌曲级明细页；目前 B 站仍主要显示站点级聚合。
- 重启新 service 后尚未捕获到一条新的网易云/Chrome 播放记录来证明运行态已经从 `Audio playback` 变为真实标题。

## 后续计划

1. 播放网易云或 Chrome/B 站音频 30 秒，复查 `media_sessions` 最新记录，确认新 service 是否写入真实标题。
2. 如果仍是 `Audio playback`，给 service 增加受控诊断日志，记录每轮 GSMTC 输出、匹配到的 source app、最终 title 选择原因。
3. 将 PowerShell GSMTC fallback 替换成原生 WinRT/COM 查询，避免后台服务频繁启动 PowerShell。
4. 设计可选浏览器采集通道：只在用户开启后读取 audible tab 的 `title/url`，解决 B 站/YouTube/lofi 多标签页标题归属问题。
5. 增加“媒体明细/视频明细”聚合 API，把 `media_title` 和 foreground `window_title` 做成月报可消费的数据，而不是只展示站点总时长。

## 工作区约定

之后 TimeArc 只使用 `D:\TimeArc\time-arc`。F 盘旧工作区会被隔离归档，避免后续误触。
