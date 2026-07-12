// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang
// Copyright (C) 2026 Jerry Zhou

#ifndef TIMEARC_SRC_SERVICE_SHARED_DATABASE_STORAGE_H
#define TIMEARC_SRC_SERVICE_SHARED_DATABASE_STORAGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DatabaseAppRecord {
  const char* app_id;
  const char* platform;
  const char* display_name;
  const char* icon_path;
  const char* executable_path;
  int64_t updated_at;
} DatabaseAppRecord;

typedef struct DatabaseFrontmostSession {
  const char* app_id;
  const char* window_title;
  int64_t start_unix_sec;
  int64_t end_unix_sec;
  int64_t active_sec;
} DatabaseFrontmostSession;

typedef struct DatabaseMediaSession {
  const char* app_id;
  const char* media_type;
  const char* media_title;
  int64_t start_unix_sec;
  int64_t end_unix_sec;
} DatabaseMediaSession;

// SQLite-backed storage for the service-owned timearc_service.db. This layer
// owns the connection, schema, statements, and table writes.
int database_storage_open(void);
void database_storage_close(void);

int database_storage_begin(void);
int database_storage_commit(void);
void database_storage_rollback(void);

int database_storage_upsert_app(const DatabaseAppRecord* app);
int database_storage_insert_frontmost_session(
    const DatabaseFrontmostSession* session);
int database_storage_insert_media_session(const DatabaseMediaSession* session);

#ifdef __cplusplus
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_DATABASE_STORAGE_H
