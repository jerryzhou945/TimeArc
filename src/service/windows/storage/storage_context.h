#ifndef TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
#define TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H

#include "util.h"

// Windows 存储上下文。
//
// SQLite 是唯一使用记录后端，连接和 DDL 由 shared/database_storage.* 管理。
typedef struct TimeArcStorageContext {
  char db_path[TA_MAX_PATH_BYTES];

  // Set only after the service database initializes successfully.
  int initialized;
} TimeArcStorageContext;

#endif  // TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
