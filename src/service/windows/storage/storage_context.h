#ifndef TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
#define TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H

#include <stdio.h>

typedef struct sqlite3 sqlite3;

typedef struct TimeArcStorageContext {
  sqlite3* db;
  FILE* jsonl_fp;

  char db_path[4096];
  char jsonl_path[4096];
  char table_name[128];

  int use_sqlite;
  int use_jsonl;
  int initialized;
} TimeArcStorageContext;

#endif  // TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
