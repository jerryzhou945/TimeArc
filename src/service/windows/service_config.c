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
  const char* app_data = getenv("APPDATA");
  if (app_data == NULL || app_data[0] == '\0') {
    return -1;
  }

  char app_dir[TA_MAX_PATH_BYTES];
  char config_dir[TA_MAX_PATH_BYTES];
  if (join_path(app_dir, sizeof(app_dir), app_data, "TimeArc") != 0 ||
      create_dir_if_missing(app_dir) != 0 ||
      join_path(config_dir, sizeof(config_dir), app_dir, "config") != 0 ||
      create_dir_if_missing(config_dir) != 0) {
    return -1;
  }
  return join_path(out, out_size, config_dir, "service_config.json");
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
    JSON_Value* idle_value = json_object_dotget_value(
        object, "tracking.frontmost.idle_threshold_sec");
    if (idle_threshold_ms != NULL &&
        json_value_get_type(idle_value) == JSONNumber) {
      const double value =
          json_object_dotget_number(
              object, "tracking.frontmost.idle_threshold_sec");
      const int64_t seconds = (int64_t)value;
      if (value == (double)seconds && seconds >= 0 && seconds <= 86400) {
        *idle_threshold_ms = seconds * 1000;
      } else {
        fprintf(stderr,
                "TimeArc service: service_config.json "
                "tracking.frontmost.idle_threshold_sec %.3f invalid; "
                "using the default.\n",
                value);
      }
    }
    JSON_Value* enabled_value =
        json_object_dotget_value(object, "tracking.enabled");
    if (track_enabled != NULL &&
        json_value_get_type(enabled_value) == JSONBoolean) {
      *track_enabled = json_object_dotget_boolean(object, "tracking.enabled")
                           ? 1
                           : 0;
    }
  }

  json_value_free(root);
  return 0;
}
