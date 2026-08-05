// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jerry Zhou
// Copyright (C) 2026 Jeff Zhang

#include "database_path.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "parson.h"
#include "util.h"

#ifdef _WIN32
#include <direct.h>
#else
#include <sys/stat.h>
#include <sys/types.h>
#endif

// The service database filename is fixed by the disk contract. Only the
// containing directory may be redirected, through `database.dir` in
// service_config.json. See CHARTER v0.13.
#define TIMEARC_SERVICE_DB_FILENAME "timearc_service.db"

#define TIMEARC_CONFIG_FILENAME "service_config.json"

static int copy_string(char* dst, size_t dst_size, const char* src) {
  if (dst == NULL || dst_size == 0 || src == NULL) {
    return -1;
  }

  size_t len = strlen(src);
  if (len + 1 > dst_size) {
    return -1;
  }

  memcpy(dst, src, len + 1);
  return 0;
}

static int join_path(char* out, size_t out_size, const char* parent,
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

static int create_dir_if_missing(const char* path) {
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

// Platform config base: roaming %APPDATA% on Windows, ~/Library/Application
// Support on macOS, $XDG_CONFIG_HOME or ~/.config elsewhere.
static int build_config_base(char* out_path, size_t out_path_size) {
#ifdef _WIN32
  const char* base = getenv("APPDATA");
  if (base == NULL || base[0] == '\0') {
    return -1;
  }
  return copy_string(out_path, out_path_size, base);
#elif defined(__APPLE__)
  const char* home = getenv("HOME");
  if (home == NULL || home[0] == '\0') {
    return -1;
  }

  char library_dir[TA_MAX_PATH_BYTES];
  if (join_path(library_dir, sizeof(library_dir), home, "Library") != 0 ||
      create_dir_if_missing(library_dir) != 0 ||
      join_path(out_path, out_path_size, library_dir, "Application Support") !=
          0 ||
      create_dir_if_missing(out_path) != 0) {
    return -1;
  }
  return 0;
#else
  const char* xdg_config_home = getenv("XDG_CONFIG_HOME");
  if (xdg_config_home != NULL && xdg_config_home[0] != '\0') {
    if (copy_string(out_path, out_path_size, xdg_config_home) != 0 ||
        create_dir_if_missing(out_path) != 0) {
      return -1;
    }
    return 0;
  }

  const char* home = getenv("HOME");
  if (home == NULL || home[0] == '\0' ||
      join_path(out_path, out_path_size, home, ".config") != 0 ||
      create_dir_if_missing(out_path) != 0) {
    return -1;
  }
  return 0;
#endif
}

// The control file. It stays in a shared config location so the UI can update
// service settings atomically without linking service code.
static int build_config_path(char* out_path, size_t out_path_size) {
  char base[TA_MAX_PATH_BYTES];
  char app_dir[TA_MAX_PATH_BYTES];
  char dir[TA_MAX_PATH_BYTES];
  if (build_config_base(base, sizeof(base)) != 0 ||
      join_path(app_dir, sizeof(app_dir), base, "TimeArc") != 0 ||
      create_dir_if_missing(app_dir) != 0 ||
      join_path(dir, sizeof(dir), app_dir, "config") != 0 ||
      create_dir_if_missing(dir) != 0) {
    return -1;
  }
  return join_path(out_path, out_path_size, dir, TIMEARC_CONFIG_FILENAME);
}

// Default DB storage is separate from the config directory:
// service history lives under the platform service-data location.
static int build_default_database_dir(char* out_path, size_t out_path_size) {
#ifdef _WIN32
  const char* app_data = getenv("APPDATA");
  if (app_data == NULL || app_data[0] == '\0') {
    return -1;
  }

  char app_dir[TA_MAX_PATH_BYTES];
  if (join_path(app_dir, sizeof(app_dir), app_data, "TimeArc") != 0 ||
      create_dir_if_missing(app_dir) != 0 ||
      join_path(out_path, out_path_size, app_dir, "service") != 0 ||
      create_dir_if_missing(out_path) != 0) {
    return -1;
  }
#elif defined(__APPLE__)
  const char* home = getenv("HOME");
  if (home == NULL || home[0] == '\0') {
    return -1;
  }

  char library_dir[TA_MAX_PATH_BYTES];
  char app_support_dir[TA_MAX_PATH_BYTES];
  char app_dir[TA_MAX_PATH_BYTES];
  if (join_path(library_dir, sizeof(library_dir), home, "Library") != 0 ||
      create_dir_if_missing(library_dir) != 0 ||
      join_path(app_support_dir, sizeof(app_support_dir), library_dir,
                "Application Support") != 0 ||
      create_dir_if_missing(app_support_dir) != 0 ||
      join_path(app_dir, sizeof(app_dir), app_support_dir, "TimeArc") != 0 ||
      create_dir_if_missing(app_dir) != 0 ||
      join_path(out_path, out_path_size, app_dir, "service") != 0 ||
      create_dir_if_missing(out_path) != 0) {
    return -1;
  }
#else
  char data_base[TA_MAX_PATH_BYTES];
  const char* xdg_data_home = getenv("XDG_DATA_HOME");
  if (xdg_data_home != NULL && xdg_data_home[0] != '\0') {
    if (copy_string(data_base, sizeof(data_base), xdg_data_home) != 0 ||
        create_dir_if_missing(data_base) != 0) {
      return -1;
    }
  } else {
    const char* home = getenv("HOME");
    char local_dir[TA_MAX_PATH_BYTES];
    if (home == NULL || home[0] == '\0' ||
        join_path(local_dir, sizeof(local_dir), home, ".local") != 0 ||
        create_dir_if_missing(local_dir) != 0 ||
        join_path(data_base, sizeof(data_base), local_dir, "share") != 0 ||
        create_dir_if_missing(data_base) != 0) {
      return -1;
    }
  }

  char app_dir[TA_MAX_PATH_BYTES];
  if (join_path(app_dir, sizeof(app_dir), data_base, "TimeArc") != 0 ||
      create_dir_if_missing(app_dir) != 0 ||
      join_path(out_path, out_path_size, app_dir, "service") != 0 ||
      create_dir_if_missing(out_path) != 0) {
    return -1;
  }
#endif
  return 0;
}

static int build_database_path_from_dir(char* out_path, size_t out_path_size,
                                        const char* db_dir) {
  if (db_dir == NULL || db_dir[0] == '\0') {
    return -1;
  }
  return join_path(out_path, out_path_size, db_dir,
                   TIMEARC_SERVICE_DB_FILENAME);
}

static int build_default_database_path(char* out_path, size_t out_path_size) {
  char db_dir[TA_MAX_PATH_BYTES];
  if (build_default_database_dir(db_dir, sizeof(db_dir)) != 0) {
    return -1;
  }

  return build_database_path_from_dir(out_path, out_path_size, db_dir);
}

// Returns 0 when a configured directory was used, 1 when the config is absent
// or has no non-empty `database.dir`, and -1 when the configured database path
// cannot fit. Missing or malformed config is a normal fallback case.
//
// There is no legacy fallback: the retired flat `db_dir` in usage_config.json
// is never read. An install that relocated its database under the old format
// must re-select the directory once, which rewrites the pointer here.
static int read_configured_database_dir(char* out_path, size_t out_path_size) {
  char config_path[TA_MAX_PATH_BYTES];
  if (build_config_path(config_path, sizeof(config_path)) != 0) {
    return 1;
  }

  JSON_Value* root = json_parse_file(config_path);
  if (root == NULL) {
    return 1;
  }

  int rc = 1;
  JSON_Object* obj = json_value_get_object(root);
  if (obj != NULL) {
    const char* db_dir = json_object_dotget_string(obj, "database.dir");
    if (db_dir != NULL && db_dir[0] != '\0') {
      rc = build_database_path_from_dir(out_path, out_path_size, db_dir) == 0
               ? 0
               : -1;
    }
  }

  json_value_free(root);
  return rc;
}

int get_database_path(char* out_path, size_t out_path_size) {
  if (out_path == NULL || out_path_size == 0) {
    return -1;
  }

  const int config_result =
      read_configured_database_dir(out_path, out_path_size);
  if (config_result == 0) {
    return 0;
  }
  if (config_result < 0) {
    return -1;
  }

  return build_default_database_path(out_path, out_path_size);
}
