# 媒体元数据采集状态

日期：2026-06-05

## 已完成

- Windows audio 采样现在会同时检查默认播放设备的 `eConsole` 和 `eCommunications` 角色。
  - 这能改善微信语音、会议软件等可能走通信音频角色时的漏采。
  - 同一 exe path 仍然去重，不会因为同一个进程在两个 role 中出现就重复记一份。
- 当“正在发声的进程”和“当前前台窗口”是同一个进程，或 exe path 相同时，audio record 会复用前台窗口标题。
  - 例如 B 站/YouTube/网页播放器在前台播放时，`window_title` 不再只能是 `Audio playback`。
  - 现有 SQLite writer 会把 audio record 的 `window_title` 写入 `media_sessions.media_title`。
- 当发声进程在后台，但它仍有可见顶层窗口标题时，Windows audio 采样会按 PID 枚举该进程窗口，并把有用标题写入 audio record。
  - 这能覆盖一部分后台播放器、浏览器窗口、视频客户端仍暴露标题的场景。
  - 如果标题为空、只是 exe 名、或没有可见窗口，仍回退到 `Audio playback`。
- DB smoke 源码增加了 `mediaTitle` 持久化断言，锁住 repository 层读取能力。
- `.harness/tools/build.py` 增加 fallback 日志目录：当 `.harness/journal/build-logs` 因 ACL 不可写时，会写到 `.harness/tmp/build-logs`，仍然保持 harness wrapper 构建。

## 未完成

- 还不能保证所有后台播放都有真实歌曲名。
  - 当前已支持“后台进程可见窗口标题”采集，但它依赖应用自己把歌曲/视频名暴露到窗口标题。
  - 如果播放器只通过系统媒体控件暴露曲目信息，普通窗口标题仍可能只是应用名。
- 还没有接入 Windows Global System Media Transport Controls。
  - GSMTC 是后续拿歌名、艺术家、专辑等系统媒体元数据的主要方向。
- 还没有浏览器标签级采集。
  - 当前只能拿前台窗口标题，不能区分同一浏览器进程里的多个标签页。
- 还没有 microphone/capture 侧采集。
  - 所以“我在微信语音里说话但对方没出声”的时间，仍不等价于 audio playback 时间。
- 新增的 DB smoke 源码断言尚未通过重新编译后的 `timearc_db_smoke.exe` 验证。
  - 既有 `build/timearc_db_smoke.exe` 可运行通过，但旧 `build/` 的 Qt autogen 目录 ACL 阻止了 smoke 目标重建。

## 验证记录

- 通过：`.local-python\Python312\python.exe .harness/tools/build.py -- --target time_arc_service`
  - 说明 Windows service 目标已在现有 MinGW build 中成功编译。
  - 2026-06-05 17:50 重新验证了后台窗口标题采集后的 service 构建。
- 通过：`build\timearc_db_smoke.exe`
  - 说明既有 DB smoke 二进制仍能运行。
- 阻塞：完整 `build` 目录构建。
  - 原因：`build/timearc_db_smoke_autogen/deps` 无法写入，属于现有构建目录 ACL 问题。
- 阻塞：新建 `build-codex` 完整构建。
  - 原因：默认选中 Visual Studio 生成器，而当前 Qt 是 MinGW 版本，编译器/Qt 套件不匹配。

## 后续计划

1. 新建一个干净的 MinGW 构建目录，例如 `build-codex-mingw`，用和当前 Qt 套件一致的生成器重新配置。
2. 在干净构建目录里重新编译并运行 `timearc_db_smoke.exe`，确认新增 media title 断言进入二进制。
3. 新增 GSMTC 采集模块，优先提取：
   - title
   - artist
   - album
   - source app
4. 为浏览器场景补一个轻量级标题解析层：
   - 前台窗口标题保留原文。
   - 对 B 站、YouTube、网易云网页版等常见格式做保守解析。
5. 月报侧使用 `media_title` 时增加可信度文案：
   - 有真实标题：展示“深夜还在听/看 ...”
   - 只有 fallback：展示“深夜仍有音频播放”，不编造内容。
