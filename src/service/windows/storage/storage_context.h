#ifndef TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
#define TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H

#include <stdio.h>

typedef struct sqlite3 sqlite3;

// Windows 存储上下文。
//
// JSONL 与 SQLite 是两个**都已实装、生产默认同时启用**的历史后端（见
// usage_storage.c timearc_storage_init(&g,1,1)）；UI 历史读源正由 JSONL 迁往
// SQLite（A1）。current_path 指向实时快照文件，供 Qt UI 每几秒读取一次当前应用。
typedef struct TimeArcStorageContext {
  // SQLite is forward-declared so this header does not force every caller to
  // include sqlite3.h; the backend itself is fully implemented (see
  // timearc_storage_write_sqlite) and enabled by default.
  sqlite3* db;

  // JSONL history backend; each line is one usage record (append-only).
  FILE* jsonl_fp;

  char db_path[4096];
  char jsonl_path[4096];
  char current_path[4096];
  char table_name[128];

  int use_sqlite;
  int use_jsonl;

  // Set only after paths and requested backends have initialized successfully.
  int initialized;
} TimeArcStorageContext;

#endif  // TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
