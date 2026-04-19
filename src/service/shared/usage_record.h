#ifndef TIMEARC_SRC_SERVICE_SHARED_USAGE_RECORD_H
#define TIMEARC_SRC_SERVICE_SHARED_USAGE_RECORD_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

typedef struct TimeArcUsageRecord {
  // Platform that produced this record: "windows" or "macos".
  char platform[32];

  // Activity source, such as "foreground" or "audio".
  char source[32];

  // Stable app identifier. Windows uses full exe path; macOS uses bundle id.
  char app_id[4096];

  // Short app name, such as "chrome.exe" or "Safari".
  char app_name[256];

  // Active window title captured for this usage session.
  char window_title[512];

  // Windows full exe path or macOS app path.
  char path[4096];

  // Session start time as Unix seconds.
  int64_t start_unix_sec;

  // Session duration in seconds.
  uint64_t duration_sec;
} TimeArcUsageRecord;

#ifdef __cplusplus
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_USAGE_RECORD_H
