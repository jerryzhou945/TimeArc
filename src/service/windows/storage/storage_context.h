#ifndef TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H
#define TIMEARC_SRC_SERVICE_WINDOWS_STORAGE_CONTEXT_H

#include <stdio.h>

typedef struct sqlite3 sqlite3;

typedef struct TimeArcStorageContext {
  // SQLite is forward-declared so this header does not force every caller to
  // include sqlite3.h while that backend is still optional.
  sqlite3* db;

  // JSONL is the active storage backend today; each line is one usage record.
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
