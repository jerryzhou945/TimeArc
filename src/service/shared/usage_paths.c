#include "usage_paths.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <errno.h>
#include <sys/stat.h>
#endif

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

static int create_dir_if_missing(const char* path) {
#ifdef _WIN32
  if (CreateDirectoryA(path, NULL) != 0) {
    return 0;
  }
  return GetLastError() == ERROR_ALREADY_EXISTS ? 0 : -1;
#else
  if (mkdir(path, 0755) == 0) {
    return 0;
  }
  return errno == EEXIST ? 0 : -1;
#endif
}

int timearc_get_usage_data_dir(char* out_path, size_t out_path_size) {
  if (out_path == NULL || out_path_size == 0) {
    return -1;
  }

  char base[1024];

#ifdef _WIN32
  const char* local_app_data = getenv("LOCALAPPDATA");
  if (local_app_data == NULL || local_app_data[0] == '\0') {
    local_app_data = getenv("APPDATA");
  }
  if (local_app_data == NULL || local_app_data[0] == '\0') {
    return -1;
  }

  int written = snprintf(base, sizeof(base), "%s\\TimeArc", local_app_data);
  if (written < 0 || (size_t)written >= sizeof(base)) {
    return -1;
  }
  if (create_dir_if_missing(base) != 0) {
    return -1;
  }

  written = snprintf(out_path, out_path_size, "%s\\usage", base);
  if (written < 0 || (size_t)written >= out_path_size) {
    return -1;
  }
#else
  const char* home = getenv("HOME");
  if (home == NULL || home[0] == '\0') {
    return -1;
  }

  int written = snprintf(base, sizeof(base), "%s/.timearc", home);
  if (written < 0 || (size_t)written >= sizeof(base)) {
    return -1;
  }
  if (create_dir_if_missing(base) != 0) {
    return -1;
  }

  written = snprintf(out_path, out_path_size, "%s/usage", base);
  if (written < 0 || (size_t)written >= out_path_size) {
    return -1;
  }
#endif

  return create_dir_if_missing(out_path);
}

int timearc_get_usage_jsonl_path(char* out_path, size_t out_path_size) {
  char dir[1024];
  if (timearc_get_usage_data_dir(dir, sizeof(dir)) != 0) {
    return -1;
  }

  char path[1200];
#ifdef _WIN32
  int written = snprintf(path, sizeof(path), "%s\\usage_records.jsonl", dir);
#else
  int written = snprintf(path, sizeof(path), "%s/usage_records.jsonl", dir);
#endif
  if (written < 0 || (size_t)written >= sizeof(path)) {
    return -1;
  }

  return copy_string(out_path, out_path_size, path);
}

int timearc_get_usage_current_path(char* out_path, size_t out_path_size) {
  char dir[1024];
  if (timearc_get_usage_data_dir(dir, sizeof(dir)) != 0) {
    return -1;
  }

  char path[1200];
#ifdef _WIN32
  int written = snprintf(path, sizeof(path), "%s\\usage_current.json", dir);
#else
  int written = snprintf(path, sizeof(path), "%s/usage_current.json", dir);
#endif
  if (written < 0 || (size_t)written >= sizeof(path)) {
    return -1;
  }

  return copy_string(out_path, out_path_size, path);
}
