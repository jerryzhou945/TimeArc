# Media Metadata Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Windows audio session 在可确认来源时保存真实前台媒体标题，并改善微信/会议类应用可能走 communications 音频角色导致的漏采。

**Architecture:** 不改 frozen schema，不新增字段，不引入依赖。Windows service 仍写 `source=audio` 记录；当发声进程与当前前台窗口同进程/同路径时，把前台窗口标题写入 audio record 的 `window_title`，现有 SQLite writer 会继续把它落到 `media_sessions.media_title`。WASAPI 枚举从单一 `eConsole` 扩展到 `eConsole + eCommunications`，按 exe path 去重。

**Tech Stack:** C/Win32/WASAPI, Qt/C++ SQLite repositories, harness build wrapper, `timearc_db_smoke.exe`。

---

### Task 1: 锁定 media title 落库行为

**Files:**
- Modify: `tests/db_smoke.cpp`

- [ ] **Step 1: 添加 smoke 断言**

在插入 frontmost smoke session 之后，加入一段 media session 插入和读取校验：

```cpp
  const QString mediaTitle =
      QStringLiteral("lofi study beats - Bilibili - Google Chrome");
  const qint64 mediaStart = startUnixSec + 1;
  const qint64 mediaEnd = qMax(mediaStart + 1, endUnixSec);
  const int mediaDuration = static_cast<int>(mediaEnd - mediaStart);
  if (!mediaRepository.addMediaSession(appIdentifier, QStringLiteral("audio"),
                                       mediaTitle, mediaStart, mediaEnd,
                                       mediaDuration)) {
    return fail(QStringLiteral("Failed to insert smoke media session."));
  }
  const QVariantList mediaSessions =
      mediaRepository.getSessionsByRange(mediaStart - 1, mediaEnd + 1);
  bool sawMediaTitle = false;
  for (const QVariant& item : mediaSessions) {
    const QVariantMap session = item.toMap();
    if (session.value(QStringLiteral("appIdentifier")).toString() ==
            appIdentifier &&
        session.value(QStringLiteral("mediaTitle")).toString() == mediaTitle) {
      sawMediaTitle = true;
    }
  }
  if (!sawMediaTitle) {
    return fail(QStringLiteral("Media title was not persisted."));
  }
```

- [ ] **Step 2: 运行 smoke，确认测试能保护行为**

Run: `build\timearc_db_smoke.exe`

Expected: 如果现有 DB 层已支持标题保存，测试通过；如果失败，失败信息应是 `Media title was not persisted.`

### Task 2: Windows audio 采样带上可信前台标题

**Files:**
- Modify: `src/service/windows/platform/audio_win.c`

- [ ] **Step 1: 引入前台窗口采样头文件**

在 `#include "audio_win.h"` 后加入：

```c
#include "active_app_win.h"
```

- [ ] **Step 2: 让 `fill_audio_app` 接受标题**

把函数签名改为：

```c
static void fill_audio_app(AppInfo* app, DWORD pid, const char* path,
                           const char* media_title)
```

把固定标题赋值改为：

```c
  copy_string(app->window_title, sizeof(app->window_title),
              media_title != NULL && media_title[0] != '\0'
                  ? media_title
                  : "Audio playback");
```

- [ ] **Step 3: 添加前台匹配辅助函数**

在 `fill_audio_app` 前加入：

```c
static const char* matching_foreground_title(const AppInfo* foreground,
                                             DWORD pid,
                                             const char* path) {
  if (foreground == NULL || foreground->window_title[0] == '\0') {
    return NULL;
  }
  if (foreground->process_id == (uint32_t)pid) {
    return foreground->window_title;
  }
  if (path != NULL && path[0] != '\0' &&
      strcmp(foreground->exec_path, path) == 0) {
    return foreground->window_title;
  }
  return NULL;
}
```

- [ ] **Step 4: 在枚举音频时读取一次前台窗口**

在 `timearc_win_get_audio_apps` 成功初始化 COM 后添加：

```c
  AppInfo foreground_app;
  int has_foreground = timearc_win_get_active_app(&foreground_app) == 0;
```

调用 `fill_audio_app` 时改为：

```c
      const char* media_title =
          has_foreground ? matching_foreground_title(&foreground_app, pid, path)
                         : NULL;
      fill_audio_app(&out_apps[added], pid, path, media_title);
```

### Task 3: Windows audio 枚举 communications render endpoint

**Files:**
- Modify: `src/service/windows/platform/audio_win.c`

- [ ] **Step 1: 抽出单个 role 枚举函数**

把 `timearc_win_get_audio_apps` 中从 `GetDefaultAudioEndpoint` 到 session loop 的逻辑抽成：

```c
static int enumerate_audio_endpoint_role(IMMDeviceEnumerator* device_enumerator,
                                         ERole role,
                                         const AppInfo* foreground_app,
                                         int has_foreground,
                                         AppInfo* out_apps,
                                         size_t max_apps,
                                         size_t* added)
```

函数内部保留原有 session audible、system sounds、pid、path、ignore、dedupe 逻辑。

- [ ] **Step 2: 主函数枚举两个 role**

`timearc_win_get_audio_apps` 创建一次 `IMMDeviceEnumerator` 后执行：

```c
  const ERole roles[] = {eConsole, eCommunications};
  size_t added = 0;
  for (size_t role_index = 0;
       role_index < sizeof(roles) / sizeof(roles[0]) && added < max_apps;
       ++role_index) {
    enumerate_audio_endpoint_role(device_enumerator, roles[role_index],
                                  has_foreground ? &foreground_app : NULL,
                                  has_foreground, out_apps, max_apps, &added);
  }
```

返回前释放 `device_enumerator`，并写回 `*out_count = added`。

### Task 4: 验证

**Files:**
- No direct code files.

- [ ] **Step 1: 构建**

Run: `.local-python\Python312\python.exe .harness/tools/build.py`

Expected: `build.py: success`

- [ ] **Step 2: DB smoke**

Run: `build\timearc_db_smoke.exe`

Expected: `database smoke ok: <path>`

- [ ] **Step 3: harness check**

Run: `.local-python\Python312\python.exe .harness/tools/harness_check.py`

Expected: `harness_check.py: clean`

### Task 5: 完成记录

**Files:**
- Create: `docs/media-metadata-capture-status.md`
- Modify: `.harness/journal/sessions/20260605-1721-B-media-metadata-capture.md`

- [ ] **Step 1: 写中文状态文档**

文档包含：已完成功能、未完成能力、后续计划、手动验证建议。

- [ ] **Step 2: 更新 session log**

记录实际验证结果；如果 build 因环境 ACL 失败，明确写“未能验证构建”的原因和已记录的 error report。
