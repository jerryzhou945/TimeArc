#include "usage_storage.h"

#include "data_bridge.h"
#include "database_storage.h"
#include "database_path.h"
#include "parson.h"

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

static int join_usage_path(char* out,
                           size_t out_size,
                           const char* parent,
                           const char* child) {
  if (out == NULL || out_size == 0 || parent == NULL || parent[0] == '\0' ||
      child == NULL || child[0] == '\0') {
    return -1;
  }

  const size_t parent_len = strlen(parent);
#ifdef _WIN32
  const char separator = '\\';
#else
  const char separator = '/';
#endif
  const int parent_has_separator =
      parent[parent_len - 1] == '/' || parent[parent_len - 1] == '\\';
  const int written =
      parent_has_separator
          ? snprintf(out, out_size, "%s%s", parent, child)
          : snprintf(out, out_size, "%s%c%s", parent, separator, child);

  return (written > 0 && (size_t)written < out_size) ? 0 : -1;
}

static int make_usage_data_dir(char* out, size_t out_size) {
#ifdef _WIN32
  const char* base = getenv("LOCALAPPDATA");
  if (base == NULL || base[0] == '\0') {
    return -1;
  }

  char app_dir[TA_MAX_PATH_BYTES];
  if (join_usage_path(app_dir, sizeof(app_dir), base, "TimeArc") != 0 ||
      create_dir_if_missing(app_dir) != 0 ||
      join_usage_path(out, out_size, app_dir, "usage") != 0 ||
      create_dir_if_missing(out) != 0) {
    return -1;
  }
#else
  const char* home = getenv("HOME");
  if (home == NULL || home[0] == '\0') {
    return -1;
  }

  char root_dir[TA_MAX_PATH_BYTES];
  if (join_usage_path(root_dir, sizeof(root_dir), home, ".timearc") != 0 ||
      create_dir_if_missing(root_dir) != 0 ||
      join_usage_path(out, out_size, root_dir, "usage") != 0 ||
      create_dir_if_missing(out) != 0) {
    return -1;
  }
#endif
  return 0;
}

static int make_usage_file_path(char* out, size_t out_size, const char* file) {
  char dir[TA_MAX_PATH_BYTES];
  if (make_usage_data_dir(dir, sizeof(dir)) != 0) {
    return -1;
  }
  return join_usage_path(out, out_size, dir, file);
}

// Build "<usageDir>/usage_config.json" into out. 0 on success, -1 otherwise.
static int make_usage_config_path(char* out, size_t out_size) {
  return make_usage_file_path(out, out_size, "usage_config.json");
}

// H5 (UI→service config channel): read idle_threshold_ms + track_enabled from
// the SAME usage_config.json the D2 db_dir lives in. Contract in
// usage_storage.h. Fail-safe: a missing/malformed file or a missing/ill-typed
// key leaves the caller's default in place; a configured-but-insane idle value
// is rejected with a stderr note rather than silently honored (G6). Read-only —
// the D2 db_dir key is preserved because nothing is written here.
int timearc_read_service_config(int64_t* idle_threshold_ms, int* track_enabled) {
  char config_path[TA_MAX_PATH_BYTES];
  if (make_usage_config_path(config_path, sizeof(config_path)) != 0) {
    return -1;
  }

  JSON_Value* root = json_parse_file(config_path);
  if (root == NULL) {
    return -1;  // absent or malformed -> caller keeps compile-time defaults
  }

  JSON_Object* obj = json_value_get_object(root);
  if (obj != NULL) {
    if (idle_threshold_ms != NULL &&
        json_object_has_value_of_type(obj, "idle_threshold_ms", JSONNumber)) {
      double ms = json_object_get_number(obj, "idle_threshold_ms");
      // 夹取合理区间（1s..24h），防 UI 分钟→毫秒换算错位或脏值把空闲判定推离谱。
      if (ms >= 1000.0 && ms <= 86400000.0) {
        *idle_threshold_ms = (int64_t)ms;
      } else {
        fprintf(stderr,
                "TimeArc service: usage_config.json idle_threshold_ms %.0f out "
                "of range [1000,86400000]; using the default.\n",
                ms);
      }
    }
    if (track_enabled != NULL &&
        json_object_has_value_of_type(obj, "track_enabled", JSONBoolean)) {
      *track_enabled = json_object_get_boolean(obj, "track_enabled") ? 1 : 0;
    }
  }

  json_value_free(root);
  return 0;
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

static int write_database_record(TimeArcStorageContext* context,
                                 const TimeArcUsageRecord* record) {
  if (context == NULL || record == NULL) {
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

  if (database_storage_begin() != 0) {
    return -1;
  }

  if (update_apps(app_identifier, platform, app_name, "", executable_path,
                  now) != 0) {
    database_storage_rollback();
    return -1;
  }

  if (is_foreground) {
    if (update_frontmost(app_identifier, record->window_title,
                         record->start_unix_sec, end_unix_sec,
                         duration_sec) != 0) {
      database_storage_rollback();
      return -1;
    }
  } else if (is_audio) {
    const char* media_title =
        record->window_title[0] != '\0' ? record->window_title : "Audio playback";
    if (update_media(app_identifier, "audio", media_title,
                     record->start_unix_sec, end_unix_sec) != 0) {
      database_storage_rollback();
      return -1;
    }
  }

  if (database_storage_commit() != 0) {
    database_storage_rollback();
    return -1;
  }

  return 0;
}

int timearc_storage_init(TimeArcStorageContext* context) {
  if (context == NULL) {
    return -1;
  }

  memset(context, 0, sizeof(*context));
  if (get_database_path(context->db_path, sizeof(context->db_path)) != 0) {
    return -1;
  }

  if (database_storage_open() != 0) {
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

  database_storage_close();

  context->initialized = 0;
}

int timearc_storage_write_record(TimeArcStorageContext* context,
                                 const TimeArcUsageRecord* record) {
  if (context == NULL || record == NULL || !context->initialized) {
    return -1;
  }

  return write_database_record(context, record);
}

TimeArcStorageContext* timearc_storage_global_context(void) {
  return &g_storage;
}

int timearc_storage_init_global(void) {
  if (g_storage.initialized) {
    return 0;
  }

  return timearc_storage_init(&g_storage);
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
