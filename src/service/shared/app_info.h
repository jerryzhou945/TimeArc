// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

// AppInfo represents the information about an application at a specific point
// in time. This structure is used to store and manage application information
// within the TimeArc service.

#ifndef TIMEARC_SRC_SERVICE_SHARED_APP_INFO_H
#define TIMEARC_SRC_SERVICE_SHARED_APP_INFO_H

#ifdef __cplusplus
extern "C" {
#endif

#include "app_env.h"

typedef struct AppInfo {
  char exec_path[_TIMEARC_MAX_PATH_BYTES];
  char window_title[_TIMEARC_MAX_TITLE_BYTES];
  char app_name[_TIMEARC_MAX_NAME_BYTES];
  time_t timestamp;       // The Unix timestamp when this window gained focus.
  uint64_t active_time;   // The total active time in seconds.
  uint8_t active_status;  // 0 for inactive, 1 for active.
} AppInfo;

#ifdef __cplusplus
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_APP_INFO_H
