#ifndef TIMEARC_SRC_SERVICE_SHARED_USAGE_RECORD_H
#define TIMEARC_SRC_SERVICE_SHARED_USAGE_RECORD_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

// TimeArcUsageRecord 是磁盘历史记录协议的 C 结构体版本。
//
// tracker 结束一段 session 后会生成它，storage 再把它写成 JSONL。
// 字段含义要和 usage_record.schema.json / usage_record.md 保持一致。
typedef struct TimeArcUsageRecord {
  // 产生记录的平台，例如 "windows" 或 "macos"。
  char platform[32];

  // 记录来源，例如 "foreground" 或 "audio"。
  char source[32];

  // 稳定应用身份。Windows 使用完整 exe 路径，macOS 使用 bundle id。
  char app_id[4096];

  // 短应用名，例如 "chrome.exe" 或 "Safari"。
  char app_name[256];

  // session 期间采集到的前台窗口标题。
  char window_title[512];

  // Windows 完整 exe 路径或 macOS app 路径。
  char path[4096];

  // session 开始时间，Unix 秒。
  int64_t start_unix_sec;

  // session 持续时长，秒。
  uint64_t duration_sec;
} TimeArcUsageRecord;

#ifdef __cplusplus
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_USAGE_RECORD_H
