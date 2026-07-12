#include "service_config.h"

#include "parson.h"
#include "util.h"

#include <direct.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int create_dir_if_missing(const char* path) {
  if (path == NULL || path[0] == '\0') {
    return -1;
  }
  return _mkdir(path) == 0 || errno == EEXIST ? 0 : -1;
}

static int join_path(char* out, size_t out_size, const char* parent,
                     const char* child) {
  if (out == NULL || out_size == 0 || parent == NULL || parent[0] == '\0' ||
      child == NULL || child[0] == '\0') {
    return -1;
  }

  const size_t parent_len = strlen(parent);
  const int parent_has_separator =
      parent[parent_len - 1] == '/' || parent[parent_len - 1] == '\\';
  const int written =
      parent_has_separator
          ? snprintf(out, out_size, "%s%s", parent, child)
          : snprintf(out, out_size, "%s\\%s", parent, child);
  return written > 0 && (size_t)written < out_size ? 0 : -1;
}

static int build_config_path(char* out, size_t out_size) {
  const char* local_app_data = getenv("LOCALAPPDATA");
  if (local_app_data == NULL || local_app_data[0] == '\0') {
    return -1;
  }

  char app_dir[TA_MAX_PATH_BYTES];
  char usage_dir[TA_MAX_PATH_BYTES];
  if (join_path(app_dir, sizeof(app_dir), local_app_data, "TimeArc") != 0 ||
      create_dir_if_missing(app_dir) != 0 ||
      join_path(usage_dir, sizeof(usage_dir), app_dir, "usage") != 0 ||
      create_dir_if_missing(usage_dir) != 0) {
    return -1;
  }
  return join_path(out, out_size, usage_dir, "usage_config.json");
}

int timearc_read_service_config(int64_t* idle_threshold_ms,
                                int* track_enabled) {
  char config_path[TA_MAX_PATH_BYTES];
  if (build_config_path(config_path, sizeof(config_path)) != 0) {
    return -1;
  }

  JSON_Value* root = json_parse_file(config_path);
  if (root == NULL) {
    return -1;
  }

  JSON_Object* object = json_value_get_object(root);
  if (object != NULL) {
    if (idle_threshold_ms != NULL && json_object_has_value_of_type(
                                         object, "idle_threshold_ms",
                                         JSONNumber)) {
      const double value =
          json_object_get_number(object, "idle_threshold_ms");
      if (value >= 1000.0 && value <= 86400000.0) {
        *idle_threshold_ms = (int64_t)value;
      } else {
        fprintf(stderr,
                "TimeArc service: usage_config.json idle_threshold_ms %.0f "
                "out of range [1000,86400000]; using the default.\n",
                value);
      }
    }
    if (track_enabled != NULL && json_object_has_value_of_type(
                                     object, "track_enabled", JSONBoolean)) {
      *track_enabled =
          json_object_get_boolean(object, "track_enabled") ? 1 : 0;
    }
  }

  json_value_free(root);
  return 0;
}
