#ifndef TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
#define TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H

#include "util.h"

// Windows 存储上下文。
//
// SQLite 是唯一历史后端，连接和 DDL 由 shared/database_storage.* 管理。
// current_path 指向 JSON 实时快照文件，供 Qt UI 每几秒读取一次当前应用。
typedef struct TimeArcStorageContext {
  char db_path[TA_MAX_PATH_BYTES];
  char current_path[TA_MAX_PATH_BYTES];

  // Set only after the database and live-snapshot path initialize successfully.
  int initialized;
} TimeArcStorageContext;

#endif  // TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
