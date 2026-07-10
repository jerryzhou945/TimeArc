#ifndef TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
#define TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H

#include <stdio.h>

#include "util.h"

// Windows 存储上下文。
//
// JSONL 与 SQLite 是两个生产默认同时启用的历史后端。JSONL/current 快照
// 仍由 Windows storage 文件管理；SQLite 连接和 DDL 由 shared/database_storage.*
// 管理。current_path 指向实时快照文件，供 Qt UI 每几秒读取一次当前应用。
typedef struct TimeArcStorageContext {
  // JSONL history backend; each line is one usage record (append-only).
  FILE* jsonl_fp;

  char db_path[TA_MAX_PATH_BYTES];
  char jsonl_path[TA_MAX_PATH_BYTES];
  char current_path[TA_MAX_PATH_BYTES];
  char table_name[128];

  int use_sqlite;
  int use_jsonl;

  // Set only after paths and requested backends have initialized successfully.
  int initialized;
} TimeArcStorageContext;

#endif  // TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
