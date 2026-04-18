// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

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
  char exec_path[TA_MAX_PATH_BYTES];
  char window_title[TA_MAX_TITLE_BYTES];
  char app_name[TA_MAX_NAME_BYTES];
  char display_name[TA_MAX_NAME_BYTES];
  uint32_t process_id;
  time_t timestamp;      // The Unix timestamp when this window gained focus.
  uint64_t active_time;  // The total active time in seconds.
  bool active_status;    // Whether the keyboard and mouse are active.
} AppInfo;

#if defined(__cplusplus)
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_APP_INFO_H
