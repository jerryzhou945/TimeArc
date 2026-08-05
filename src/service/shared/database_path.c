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
// containing directory may be redirected: through `database.dir` in
// service_config.json (v1), or the legacy flat `db_dir` in usage_config.json
// while the one-release overlap lasts. See CHARTER v0.13.
#define TIMEARC_SERVICE_DB_FILENAME "timearc_service.db"

#define TIMEARC_CONFIG_FILENAME "service_config.json"
#define TIMEARC_LEGACY_CONFIG_FILENAME "usage_config.json"

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

// Platform config base. Windows v1 uses roaming %APPDATA%; the legacy file
// stayed under %LOCALAPPDATA%, so the two roots differ there and only there.
// `create` is 0 for read-only fallbacks so probing never materializes a
// directory the user does not already have.
static int build_config_base(char* out_path, size_t out_path_size, int legacy,
                             int create) {
#ifdef _WIN32
  (void)create;
  const char* base = getenv(legacy ? "LOCALAPPDATA" : "APPDATA");
  if (base == NULL || base[0] == '\0') {
    return -1;
  }
  return copy_string(out_path, out_path_size, base);
#elif defined(__APPLE__)
  (void)legacy;
  const char* home = getenv("HOME");
  if (home == NULL || home[0] == '\0') {
    return -1;
  }

  char library_dir[TA_MAX_PATH_BYTES];
  if (join_path(library_dir, sizeof(library_dir), home, "Library") != 0 ||
      (create && create_dir_if_missing(library_dir) != 0) ||
      join_path(out_path, out_path_size, library_dir, "Application Support") !=
          0 ||
      (create && create_dir_if_missing(out_path) != 0)) {
    return -1;
  }
  return 0;
#else
  (void)legacy;
  const char* xdg_config_home = getenv("XDG_CONFIG_HOME");
  if (xdg_config_home != NULL && xdg_config_home[0] != '\0') {
    if (copy_string(out_path, out_path_size, xdg_config_home) != 0 ||
        (create && create_dir_if_missing(out_path) != 0)) {
      return -1;
    }
    return 0;
  }

  const char* home = getenv("HOME");
  if (home == NULL || home[0] == '\0' ||
      join_path(out_path, out_path_size, home, ".config") != 0 ||
      (create && create_dir_if_missing(out_path) != 0)) {
    return -1;
  }
  return 0;
#endif
}

// "<config base>/TimeArc/<leaf>".
static int build_app_subdir(char* out_path, size_t out_path_size,
                            const char* base, const char* leaf, int create) {
  char app_dir[TA_MAX_PATH_BYTES];
  if (join_path(app_dir, sizeof(app_dir), base, "TimeArc") != 0 ||
      (create && create_dir_if_missing(app_dir) != 0) ||
      join_path(out_path, out_path_size, app_dir, leaf) != 0 ||
      (create && create_dir_if_missing(out_path) != 0)) {
    return -1;
  }
  return 0;
}

// v1 control file. It stays in a shared config location so the UI can update
// service settings atomically without linking service code.
static int build_config_path(char* out_path, size_t out_path_size) {
  char base[TA_MAX_PATH_BYTES];
  char dir[TA_MAX_PATH_BYTES];
  if (build_config_base(base, sizeof(base), 0, 1) != 0 ||
      build_app_subdir(dir, sizeof(dir), base, "config", 1) != 0) {
    return -1;
  }
  return join_path(out_path, out_path_size, dir, TIMEARC_CONFIG_FILENAME);
}

// Legacy v0 control file: read-only fallback for the overlap release. Nothing
// writes it, so a rollback to an older build finds it intact.
static int build_legacy_config_path(char* out_path, size_t out_path_size) {
  char base[TA_MAX_PATH_BYTES];
  char dir[TA_MAX_PATH_BYTES];
  if (build_config_base(base, sizeof(base), 1, 0) != 0 ||
      build_app_subdir(dir, sizeof(dir), base, "usage", 0) != 0) {
    return -1;
  }
  return join_path(out_path, out_path_size, dir,
                   TIMEARC_LEGACY_CONFIG_FILENAME);
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

// Reads one control file and applies its directory pointer. Returns 0 when a
// directory was configured, 1 when the file parses but names none, 2 when the
// file is absent or unparseable, and -1 when the resulting path cannot fit.
static int apply_config_database_dir(char* out_path, size_t out_path_size,
                                     const char* config_path,
                                     const char* key_path, int dotted) {
  JSON_Value* root = json_parse_file(config_path);
  if (root == NULL) {
    return 2;
  }

  int rc = 1;
  JSON_Object* obj = json_value_get_object(root);
  if (obj != NULL) {
    const char* db_dir = dotted ? json_object_dotget_string(obj, key_path)
                                : json_object_get_string(obj, key_path);
    if (db_dir != NULL && db_dir[0] != '\0') {
      rc = build_database_path_from_dir(out_path, out_path_size, db_dir) == 0
               ? 0
               : -1;
    }
  }

  json_value_free(root);
  return rc;
}

// Returns 0 when a configured directory was used, 1 when the config is absent
// or has no non-empty directory pointer, and -1 when the configured database
// path cannot fit. Missing or malformed config is a normal fallback case.
//
// A v1 file that parses decides on its own: the legacy file is consulted only
// when v1 is absent or unparseable. The two are never key-merged, so a v1
// document that deliberately omits `database.dir` means "use the default"
// rather than "inherit whatever the old file said".
static int read_configured_database_dir(char* out_path, size_t out_path_size) {
  char config_path[TA_MAX_PATH_BYTES];
  if (build_config_path(config_path, sizeof(config_path)) == 0) {
    const int rc = apply_config_database_dir(out_path, out_path_size,
                                             config_path, "database.dir", 1);
    if (rc != 2) {
      return rc;
    }
  }

  char legacy_path[TA_MAX_PATH_BYTES];
  if (build_legacy_config_path(legacy_path, sizeof(legacy_path)) != 0) {
    return 1;
  }
  const int legacy_rc = apply_config_database_dir(out_path, out_path_size,
                                                  legacy_path, "db_dir", 0);
  return legacy_rc == 2 ? 1 : legacy_rc;
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
