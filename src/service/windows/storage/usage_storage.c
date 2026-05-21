#include "usage_storage.h"

#include "data_bridge.h"
#include "sqlite3.h"
#include "usage_paths.h"

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef _WIN32
#include <direct.h>
#else
#include <sys/stat.h>
#endif

static TimeArcStorageContext g_storage;

static void copy_string(char* dst, size_t dst_size, const char* src) {
  if (dst == NULL || dst_size == 0) {
    return;
  }

  if (src == NULL) {
    dst[0] = '\0';
    return;
  }

  size_t len = strlen(src);
  if (len >= dst_size) {
    len = dst_size - 1;
  }

  memcpy(dst, src, len);
  dst[len] = '\0';
}

static int create_dir_if_missing(const char* path) {
  if (path == NULL || path[0] == '\0') {
    return -1;
  }

#ifdef _WIN32
  if (_mkdir(path) == 0 || errno == EEXIST) {
    return 0;
  }
#else
  if (mkdir(path, 0755) == 0 || errno == EEXIST) {
    return 0;
  }
#endif

  return -1;
}

static int make_db_path(char* out_path, size_t out_path_size) {
  if (out_path == NULL || out_path_size == 0) {
    return -1;
  }

  const char* app_data = getenv("APPDATA");
  if (app_data == NULL || app_data[0] == '\0') {
    app_data = getenv("LOCALAPPDATA");
  }
  if (app_data == NULL || app_data[0] == '\0') {
    return -1;
  }

  char org_dir[4096];
  char app_dir[4096];

#ifdef _WIN32
  int written = snprintf(org_dir, sizeof(org_dir), "%s\\TimeArc", app_data);
#else
  int written = snprintf(org_dir, sizeof(org_dir), "%s/.timearc", app_data);
#endif
  if (written < 0 || (size_t)written >= sizeof(org_dir) ||
      create_dir_if_missing(org_dir) != 0) {
    return -1;
  }

#ifdef _WIN32
  written = snprintf(app_dir, sizeof(app_dir), "%s\\TimeArc", org_dir);
#else
  written = snprintf(app_dir, sizeof(app_dir), "%s/TimeArc", org_dir);
#endif
  if (written < 0 || (size_t)written >= sizeof(app_dir) ||
      create_dir_if_missing(app_dir) != 0) {
    return -1;
  }

#ifdef _WIN32
  written = snprintf(out_path, out_path_size, "%s\\timearc.db", app_dir);
#else
  written = snprintf(out_path, out_path_size, "%s/timearc.db", app_dir);
#endif

  return written >= 0 && (size_t)written < out_path_size ? 0 : -1;
}

static const char* basename_from_path(const char* path) {
  const char* base = path;

  if (path == NULL) {
    return "";
  }

  for (const char* p = path; *p != '\0'; ++p) {
    if (*p == '\\' || *p == '/') {
      base = p + 1;
    }
  }

  return base;
}

static const char* non_empty_or(const char* value, const char* fallback) {
  return value != NULL && value[0] != '\0' ? value : fallback;
}

static int sqlite_exec(TimeArcStorageContext* context, const char* sql) {
  char* error = NULL;
  if (context == NULL || context->db == NULL || sql == NULL) {
    return -1;
  }

  if (sqlite3_exec(context->db, sql, NULL, NULL, &error) != SQLITE_OK) {
    fprintf(stderr, "sqlite exec failed: %s\nSQL: %s\n",
            error != NULL ? error : sqlite3_errmsg(context->db), sql);
    sqlite3_free(error);
    return -1;
  }

  return 0;
}

static void write_json_string(FILE* file, const char* value) {
  fputc('"', file);

  if (value != NULL) {
    const unsigned char* p = (const unsigned char*)value;
    while (*p != '\0') {
      switch (*p) {
        case '\\':
          fputs("\\\\", file);
          break;
        case '"':
          fputs("\\\"", file);
          break;
        case '\n':
          fputs("\\n", file);
          break;
        case '\r':
          fputs("\\r", file);
          break;
        case '\t':
          fputs("\\t", file);
          break;
        default:
          if (*p < 0x20) {
            fprintf(file, "\\u%04x", *p);
          } else {
            fputc(*p, file);
          }
          break;
      }
      ++p;
    }
  }

  fputc('"', file);
}

static void write_json_field(FILE* file, const char* name, const char* value) {
  fprintf(file, "\"%s\":", name);
  write_json_string(file, value);
}

static void write_usage_record_object(FILE* file,
                                      const TimeArcUsageRecord* record,
                                      int live,
                                      int64_t updated_unix_sec) {
  fputc('{', file);
  write_json_field(file, "platform", record->platform);
  fputc(',', file);
  write_json_field(file, "source", record->source);
  fputc(',', file);
  write_json_field(file, "app_id", record->app_id);
  fputc(',', file);
  write_json_field(file, "app_name", record->app_name);
  fputc(',', file);
  write_json_field(file, "window_title", record->window_title);
  fputc(',', file);
  write_json_field(file, "path", record->path);
  fprintf(file, ",\"start_unix_sec\":%lld",
          (long long)record->start_unix_sec);
  fprintf(file, ",\"duration_sec\":%llu",
          (unsigned long long)record->duration_sec);
  if (live) {
    fputs(",\"live\":1", file);
    fprintf(file, ",\"updated_unix_sec\":%lld", (long long)updated_unix_sec);
  }
  fputc('}', file);
}

static int timearc_storage_write_jsonl(TimeArcStorageContext* context,
                                       const TimeArcUsageRecord* record) {
  if (context == NULL || record == NULL || context->jsonl_fp == NULL) {
    return -1;
  }

  FILE* file = context->jsonl_fp;
  write_usage_record_object(file, record, 0, 0);
  fputc('\n', file);
  fflush(file);

  return ferror(file) ? -1 : 0;
}

int timearc_storage_write_current_record(TimeArcStorageContext* context,
                                         const TimeArcUsageRecord* record,
                                         int64_t updated_unix_sec) {
  if (context == NULL || record == NULL || !context->initialized ||
      context->current_path[0] == '\0') {
    return -1;
  }

  char temp_path[4096];
  int written = snprintf(temp_path, sizeof(temp_path), "%s.tmp",
                         context->current_path);
  if (written < 0 || (size_t)written >= sizeof(temp_path)) {
    return -1;
  }

  FILE* file = fopen(temp_path, "wb");
  if (file == NULL) {
    return -1;
  }

  write_usage_record_object(file, record, 1, updated_unix_sec);
  fputc('\n', file);
  fflush(file);

  int failed = ferror(file);
  fclose(file);
  if (failed) {
    remove(temp_path);
    return -1;
  }

  remove(context->current_path);
  if (rename(temp_path, context->current_path) != 0) {
    remove(temp_path);
    return -1;
  }

  return 0;
}

void timearc_storage_clear_current_record(TimeArcStorageContext* context) {
  if (context == NULL || context->current_path[0] == '\0') {
    return;
  }

  remove(context->current_path);
}

int timearc_storage_init_sqlite(TimeArcStorageContext* context) {
  if (context == NULL || context->db_path[0] == '\0') {
    return -1;
  }

  if (sqlite3_open(context->db_path, &context->db) != SQLITE_OK) {
    fprintf(stderr, "failed to open SQLite database: %s (%s)\n",
            context->db_path,
            context->db != NULL ? sqlite3_errmsg(context->db) : "unknown");
    if (context->db != NULL) {
      sqlite3_close(context->db);
      context->db = NULL;
    }
    return -1;
  }

  sqlite3_busy_timeout(context->db, 5000);

  if (sqlite_exec(context, "PRAGMA foreign_keys = ON;") != 0 ||
      sqlite_exec(context, "PRAGMA journal_mode = WAL;") != 0 ||
      sqlite_exec(context,
                  "CREATE TABLE IF NOT EXISTS apps ("
                  "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                  "app_identifier TEXT NOT NULL UNIQUE,"
                  "app_name TEXT NOT NULL,"
                  "display_name TEXT,"
                  "app_icon_path TEXT,"
                  "executable_path TEXT,"
                  "platform TEXT DEFAULT 'windows',"
                  "created_at INTEGER NOT NULL,"
                  "updated_at INTEGER NOT NULL"
                  ");") != 0 ||
      sqlite_exec(context,
                  "CREATE TABLE IF NOT EXISTS frontmost_sessions ("
                  "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                  "app_identifier TEXT NOT NULL,"
                  "window_title TEXT,"
                  "start_unix_sec INTEGER NOT NULL,"
                  "end_unix_sec INTEGER NOT NULL,"
                  "duration_sec INTEGER NOT NULL,"
                  "active_sec INTEGER NOT NULL,"
                  "idle_sec INTEGER DEFAULT 0,"
                  "created_at INTEGER NOT NULL"
                  ");") != 0 ||
      sqlite_exec(context,
                  "CREATE TABLE IF NOT EXISTS media_sessions ("
                  "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                  "app_identifier TEXT NOT NULL,"
                  "media_type TEXT NOT NULL,"
                  "media_title TEXT,"
                  "start_unix_sec INTEGER NOT NULL,"
                  "end_unix_sec INTEGER NOT NULL,"
                  "playback_sec INTEGER NOT NULL,"
                  "created_at INTEGER NOT NULL"
                  ");") != 0 ||
      sqlite_exec(context,
                  "CREATE INDEX IF NOT EXISTS idx_frontmost_time "
                  "ON frontmost_sessions(start_unix_sec, end_unix_sec);") !=
          0 ||
      sqlite_exec(context,
                  "CREATE INDEX IF NOT EXISTS idx_frontmost_app "
                  "ON frontmost_sessions(app_identifier);") != 0 ||
      sqlite_exec(context,
                  "CREATE UNIQUE INDEX IF NOT EXISTS "
                  "idx_frontmost_unique_record "
                  "ON frontmost_sessions(app_identifier, window_title, "
                  "start_unix_sec, end_unix_sec);") != 0 ||
      sqlite_exec(context,
                  "CREATE INDEX IF NOT EXISTS idx_media_time "
                  "ON media_sessions(start_unix_sec, end_unix_sec);") != 0 ||
      sqlite_exec(context,
                  "CREATE INDEX IF NOT EXISTS idx_media_app "
                  "ON media_sessions(app_identifier);") != 0 ||
      sqlite_exec(context,
                  "CREATE UNIQUE INDEX IF NOT EXISTS idx_media_unique_record "
                  "ON media_sessions(app_identifier, media_type, media_title, "
                  "start_unix_sec, end_unix_sec);") != 0 ||
      sqlite_exec(context,
                  "CREATE INDEX IF NOT EXISTS idx_apps_identifier "
                  "ON apps(app_identifier);") != 0) {
    sqlite3_close(context->db);
    context->db = NULL;
    return -1;
  }

  return 0;
}

static int bind_text(sqlite3_stmt* stmt, int index, const char* value) {
  return sqlite3_bind_text(stmt, index, non_empty_or(value, ""), -1,
                           SQLITE_TRANSIENT);
}

int timearc_storage_write_sqlite(TimeArcStorageContext* context,
                                 const TimeArcUsageRecord* record) {
  if (context == NULL || record == NULL || context->db == NULL) {
    return -1;
  }

  int is_foreground =
      record->source[0] == '\0' || strcmp(record->source, "foreground") == 0;
  int is_audio = strcmp(record->source, "audio") == 0;
  if (!is_foreground && !is_audio) {
    return 0;
  }

  const char* app_identifier = non_empty_or(record->app_id, record->path);
  if (app_identifier == NULL || app_identifier[0] == '\0' ||
      record->start_unix_sec <= 0 || record->duration_sec == 0) {
    return 0;
  }

  int64_t duration_sec = (int64_t)record->duration_sec;
  int64_t end_unix_sec = record->start_unix_sec + duration_sec;
  if (end_unix_sec <= record->start_unix_sec) {
    return 0;
  }

  const char* executable_path = non_empty_or(record->path, app_identifier);
  const char* app_name = record->app_name[0] != '\0'
                             ? record->app_name
                             : basename_from_path(executable_path);
  if (app_name == NULL || app_name[0] == '\0') {
    app_name = app_identifier;
  }

  const char* platform = non_empty_or(record->platform, "windows");
  int64_t now = (int64_t)time(NULL);

  if (sqlite_exec(context, "BEGIN IMMEDIATE;") != 0) {
    return -1;
  }

  sqlite3_stmt* app_stmt = NULL;
  const char* app_sql =
      "INSERT INTO apps ("
      "app_identifier, app_name, display_name, app_icon_path, "
      "executable_path, platform, created_at, updated_at"
      ") VALUES (?, ?, ?, '', ?, ?, ?, ?) "
      "ON CONFLICT(app_identifier) DO UPDATE SET "
      "app_name = excluded.app_name,"
      "display_name = excluded.display_name,"
      "app_icon_path = excluded.app_icon_path,"
      "executable_path = excluded.executable_path,"
      "platform = excluded.platform,"
      "updated_at = excluded.updated_at;";

  if (sqlite3_prepare_v2(context->db, app_sql, -1, &app_stmt, NULL) !=
      SQLITE_OK) {
    fprintf(stderr, "failed to prepare app upsert: %s\n",
            sqlite3_errmsg(context->db));
    sqlite_exec(context, "ROLLBACK;");
    return -1;
  }

  bind_text(app_stmt, 1, app_identifier);
  bind_text(app_stmt, 2, app_name);
  bind_text(app_stmt, 3, app_name);
  bind_text(app_stmt, 4, executable_path);
  bind_text(app_stmt, 5, platform);
  sqlite3_bind_int64(app_stmt, 6, now);
  sqlite3_bind_int64(app_stmt, 7, now);

  int rc = sqlite3_step(app_stmt);
  sqlite3_finalize(app_stmt);
  if (rc != SQLITE_DONE) {
    fprintf(stderr, "failed to upsert app into SQLite: %s\n",
            sqlite3_errmsg(context->db));
    sqlite_exec(context, "ROLLBACK;");
    return -1;
  }

  sqlite3_stmt* session_stmt = NULL;
  int changes = 0;

  if (is_foreground) {
    const char* session_sql =
        "INSERT OR IGNORE INTO frontmost_sessions ("
        "app_identifier, window_title, start_unix_sec, end_unix_sec, "
        "duration_sec, active_sec, idle_sec, created_at"
        ") VALUES (?, ?, ?, ?, ?, ?, 0, ?);";

    if (sqlite3_prepare_v2(context->db, session_sql, -1, &session_stmt, NULL) !=
        SQLITE_OK) {
      fprintf(stderr, "failed to prepare frontmost insert: %s\n",
              sqlite3_errmsg(context->db));
      sqlite_exec(context, "ROLLBACK;");
      return -1;
    }

    bind_text(session_stmt, 1, app_identifier);
    bind_text(session_stmt, 2, record->window_title);
    sqlite3_bind_int64(session_stmt, 3, record->start_unix_sec);
    sqlite3_bind_int64(session_stmt, 4, end_unix_sec);
    sqlite3_bind_int64(session_stmt, 5, duration_sec);
    sqlite3_bind_int64(session_stmt, 6, duration_sec);
    sqlite3_bind_int64(session_stmt, 7, now);

    rc = sqlite3_step(session_stmt);
    changes = sqlite3_changes(context->db);
    sqlite3_finalize(session_stmt);
    if (rc != SQLITE_DONE) {
      fprintf(stderr, "failed to insert frontmost session into SQLite: %s\n",
              sqlite3_errmsg(context->db));
      sqlite_exec(context, "ROLLBACK;");
      return -1;
    }
  } else if (is_audio) {
    const char* media_title =
        record->window_title[0] != '\0' ? record->window_title : "Audio playback";
    const char* session_sql =
        "INSERT OR IGNORE INTO media_sessions ("
        "app_identifier, media_type, media_title, start_unix_sec, "
        "end_unix_sec, playback_sec, created_at"
        ") VALUES (?, 'audio', ?, ?, ?, ?, ?);";

    if (sqlite3_prepare_v2(context->db, session_sql, -1, &session_stmt, NULL) !=
        SQLITE_OK) {
      fprintf(stderr, "failed to prepare media insert: %s\n",
              sqlite3_errmsg(context->db));
      sqlite_exec(context, "ROLLBACK;");
      return -1;
    }

    bind_text(session_stmt, 1, app_identifier);
    bind_text(session_stmt, 2, media_title);
    sqlite3_bind_int64(session_stmt, 3, record->start_unix_sec);
    sqlite3_bind_int64(session_stmt, 4, end_unix_sec);
    sqlite3_bind_int64(session_stmt, 5, duration_sec);
    sqlite3_bind_int64(session_stmt, 6, now);

    rc = sqlite3_step(session_stmt);
    changes = sqlite3_changes(context->db);
    sqlite3_finalize(session_stmt);
    if (rc != SQLITE_DONE) {
      fprintf(stderr, "failed to insert media session into SQLite: %s\n",
              sqlite3_errmsg(context->db));
      sqlite_exec(context, "ROLLBACK;");
      return -1;
    }
  }

  if (sqlite_exec(context, "COMMIT;") != 0) {
    sqlite_exec(context, "ROLLBACK;");
    return -1;
  }

  if (changes == 0) {
    fprintf(stderr, "duplicate session skipped in SQLite\n");
  }

  return 0;
}

int timearc_storage_init(TimeArcStorageContext* context,
                         int use_jsonl,
                         int use_sqlite) {
  if (context == NULL) {
    return -1;
  }

  memset(context, 0, sizeof(*context));
  context->use_jsonl = use_jsonl ? 1 : 0;
  context->use_sqlite = use_sqlite ? 1 : 0;
  copy_string(context->table_name, sizeof(context->table_name),
              "frontmost_sessions");

  if (timearc_get_usage_jsonl_path(context->jsonl_path,
                                   sizeof(context->jsonl_path)) != 0) {
    return -1;
  }
  if (timearc_get_usage_current_path(context->current_path,
                                     sizeof(context->current_path)) != 0) {
    return -1;
  }
  if (make_db_path(context->db_path, sizeof(context->db_path)) != 0) {
    return -1;
  }

  if (context->use_jsonl) {
    context->jsonl_fp = fopen(context->jsonl_path, "ab");
    if (context->jsonl_fp == NULL) {
      return -1;
    }
  }

  if (context->use_sqlite && timearc_storage_init_sqlite(context) != 0) {
    timearc_storage_close(context);
    return -1;
  }

  context->initialized = 1;
  return 0;
}

void timearc_storage_close(TimeArcStorageContext* context) {
  if (context == NULL) {
    return;
  }

  if (context->jsonl_fp != NULL) {
    fclose(context->jsonl_fp);
    context->jsonl_fp = NULL;
  }

  if (context->db != NULL) {
    sqlite3_close(context->db);
    context->db = NULL;
  }

  context->initialized = 0;
}

int timearc_storage_write_record(TimeArcStorageContext* context,
                                 const TimeArcUsageRecord* record) {
  if (context == NULL || record == NULL || !context->initialized) {
    return -1;
  }

  int wrote = 0;
  if (context->use_jsonl) {
    if (timearc_storage_write_jsonl(context, record) != 0) {
      return -1;
    }
    wrote = 1;
  }

  if (context->use_sqlite) {
    if (timearc_storage_write_sqlite(context, record) != 0) {
      return -1;
    }
    wrote = 1;
  }

  return wrote ? 0 : -1;
}

TimeArcStorageContext* timearc_storage_global_context(void) {
  return &g_storage;
}

int timearc_storage_init_global(void) {
  if (g_storage.initialized) {
    return 0;
  }

  return timearc_storage_init(&g_storage, 1, 1);
}

void timearc_storage_shutdown_global(void) {
  timearc_storage_close(&g_storage);
}

int ta_storage_init(void) {
  return timearc_storage_init_global();
}

void ta_storage_shutdown(void) {
  timearc_storage_shutdown_global();
}

static void fill_usage_record(TimeArcUsageRecord* record,
                              const char* platform,
                              const char* source,
                              const char* app_id,
                              const char* app_name,
                              const char* window_title,
                              const char* path,
                              int64_t start_unix_sec,
                              uint64_t duration_sec) {
  memset(record, 0, sizeof(*record));
  copy_string(record->platform, sizeof(record->platform), platform);
  copy_string(record->source, sizeof(record->source),
              source != NULL && source[0] != '\0' ? source : "foreground");
  copy_string(record->app_id, sizeof(record->app_id), app_id);
  copy_string(record->app_name, sizeof(record->app_name), app_name);
  copy_string(record->window_title, sizeof(record->window_title),
              window_title);
  copy_string(record->path, sizeof(record->path), path);
  record->start_unix_sec = start_unix_sec;
  record->duration_sec = duration_sec;
}

int ta_write_usage_record(const char* platform,
                          const char* app_id,
                          const char* app_name,
                          const char* window_title,
                          const char* path,
                          int64_t start_unix_sec,
                          uint64_t duration_sec) {
  if (!g_storage.initialized && timearc_storage_init_global() != 0) {
    return -1;
  }

  TimeArcUsageRecord record;
  fill_usage_record(&record, platform, "foreground", app_id, app_name,
                    window_title, path, start_unix_sec, duration_sec);

  return timearc_storage_write_record(&g_storage, &record);
}

int ta_write_usage_record_with_source(const char* platform,
                                      const char* source,
                                      const char* app_id,
                                      const char* app_name,
                                      const char* window_title,
                                      const char* path,
                                      int64_t start_unix_sec,
                                      uint64_t duration_sec) {
  if (!g_storage.initialized && timearc_storage_init_global() != 0) {
    return -1;
  }

  TimeArcUsageRecord record;
  fill_usage_record(&record, platform, source, app_id, app_name, window_title,
                    path, start_unix_sec, duration_sec);

  return timearc_storage_write_record(&g_storage, &record);
}

int ta_write_current_usage(const char* platform,
                           const char* app_id,
                           const char* app_name,
                           const char* window_title,
                           const char* path,
                           int64_t start_unix_sec,
                           uint64_t duration_sec,
                           int64_t updated_unix_sec) {
  if (!g_storage.initialized && timearc_storage_init_global() != 0) {
    return -1;
  }

  TimeArcUsageRecord record;
  fill_usage_record(&record, platform, "foreground", app_id, app_name,
                    window_title, path, start_unix_sec, duration_sec);

  return timearc_storage_write_current_record(&g_storage, &record,
                                              updated_unix_sec);
}

int ta_write_current_usage_with_source(const char* platform,
                                       const char* source,
                                       const char* app_id,
                                       const char* app_name,
                                       const char* window_title,
                                       const char* path,
                                       int64_t start_unix_sec,
                                       uint64_t duration_sec,
                                       int64_t updated_unix_sec) {
  if (!g_storage.initialized && timearc_storage_init_global() != 0) {
    return -1;
  }

  TimeArcUsageRecord record;
  fill_usage_record(&record, platform, source, app_id, app_name, window_title,
                    path, start_unix_sec, duration_sec);

  return timearc_storage_write_current_record(&g_storage, &record,
                                              updated_unix_sec);
}

void ta_clear_current_usage(void) {
  if (!g_storage.initialized && timearc_storage_init_global() != 0) {
    return;
  }

  timearc_storage_clear_current_record(&g_storage);
}
