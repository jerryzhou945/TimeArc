#include "usage_storage.h"

#include "data_bridge.h"
#include "usage_paths.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

// The Windows service currently uses one process-wide storage context exposed
// through data_bridge.h.
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

static int make_db_path(char* out_path, size_t out_path_size) {
  char dir[4096];
  if (timearc_get_usage_data_dir(dir, sizeof(dir)) != 0) {
    return -1;
  }

#ifdef _WIN32
  int written = snprintf(out_path, out_path_size,
                         "%s\\usage_records.sqlite3", dir);
#else
  int written = snprintf(out_path, out_path_size,
                         "%s/usage_records.sqlite3", dir);
#endif
  return written >= 0 && (size_t)written < out_path_size ? 0 : -1;
}

// TODO: Expand JSON escaping and UTF-8 validation before treating this as final.
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
  // Keep JSON emission explicit so the on-disk format mirrors
  // usage_record.schema.json field-for-field. Live checkpoint metadata is only
  // added for usage_current.json and is ignored by historical JSONL readers.
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

  // C rename does not reliably replace existing files on Windows.
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
  (void)context;
  // TODO: Open SQLite database and create usage_records table.
  return 0;
}

int timearc_storage_write_sqlite(TimeArcStorageContext* context,
                                 const TimeArcUsageRecord* record) {
  (void)context;
  (void)record;
  // TODO: Insert usage record into SQLite.
  return 0;
}

int timearc_storage_init(TimeArcStorageContext* context,
                         int use_jsonl,
                         int use_sqlite) {
  if (context == NULL) {
    return -1;
  }

  memset(context, 0, sizeof(*context));
  // Normalize backend flags to 0/1 so callers can pass any truthy value.
  context->use_jsonl = use_jsonl ? 1 : 0;
  context->use_sqlite = use_sqlite ? 1 : 0;
  copy_string(context->table_name, sizeof(context->table_name),
              "usage_records");

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

  context->db = NULL;
  context->initialized = 0;
}

int timearc_storage_write_record(TimeArcStorageContext* context,
                                 const TimeArcUsageRecord* record) {
  if (context == NULL || record == NULL || !context->initialized) {
    return -1;
  }

  int wrote = 0;
  // Treat enabled backends as all-or-nothing: if one write fails, report the
  // failure instead of silently accepting a partial record.
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

  return timearc_storage_init(&g_storage, 1, 0);
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
  // Lazily initialize so callers can use the bridge directly in simple tools or
  // tests without remembering to call ta_storage_init first.
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
