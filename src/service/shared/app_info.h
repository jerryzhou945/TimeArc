// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

// AppInfo 表示某一瞬间采样到的应用状态。
//
// Windows 前台窗口采样和音频会话采样都会先填这个结构，再交给 tracker 比较
// “当前状态是否和上一轮相同”。它是“瞬时状态”，不是最终落盘的历史记录。
// AppInfo represents the information about an application at a specific point
// in time. This structure is used to store and manage application information
// within the TimeArc service.

#ifndef TIMEARC_SRC_SERVICE_SHARED_APP_INFO_H
#define TIMEARC_SRC_SERVICE_SHARED_APP_INFO_H

#if defined(__cplusplus)
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>
#include <time.h>

#include "util.h"

typedef struct AppInfo {
  // Windows 上通常是完整 exe 路径；它是最稳定的应用身份。
  char exec_path[TA_MAX_PATH_BYTES];
  // 前台窗口标题；浏览器网站保守识别就是依赖这个字段。
  char window_title[TA_MAX_TITLE_BYTES];
  // exe 文件名或平台层能拿到的短名称。
  char app_name[TA_MAX_NAME_BYTES];
  // 预留给更友好的显示名；当前 Windows 实现基本等于 app_name。
  char display_name[TA_MAX_NAME_BYTES];
  uint32_t process_id;
  time_t timestamp;      // 本次采样的 Unix 时间。
  uint64_t active_time;  // 预留累计时长字段；当前 tracker 自己维护 session 时长。
  bool active_status;    // 这次采样是否被认为是活跃状态。
} AppInfo;

#if defined(__cplusplus)
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_APP_INFO_H
