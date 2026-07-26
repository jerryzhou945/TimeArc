#include "active_app_win.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

// Copy safely into fixed AppInfo fields, truncating long API results.
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

// Convert UTF-16 Windows titles and paths to the UTF-8 storage format.
static int wide_to_utf8(const wchar_t* src, char* dst, size_t dst_size) {
  if (dst == NULL || dst_size == 0) {
    return -1;
  }
  dst[0] = '\0';

  if (src == NULL || src[0] == L'\0') {
    return 0;
  }

  int written = WideCharToMultiByte(CP_UTF8, 0, src, -1, dst, (int)dst_size,
                                    NULL, NULL);
  if (written <= 0) {
    dst[0] = '\0';
    return -1;
  }

  dst[dst_size - 1] = '\0';
  return 0;
}

static int query_process_path(DWORD pid, char* out_path, size_t out_path_size) {
  if (out_path == NULL || out_path_size == 0) {
    return -1;
  }
  out_path[0] = '\0';

  // Prefer PSAPI for complete paths from ordinary desktop processes.
  HANDLE process =
      OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
  if (process != NULL) {
    wchar_t path_w[TA_MAX_PATH_BYTES];
    DWORD len = GetModuleFileNameExW(process, NULL, path_w,
                                     (DWORD)(sizeof(path_w) / sizeof(path_w[0])));
    CloseHandle(process);
    if (len > 0 && len < (sizeof(path_w) / sizeof(path_w[0])) &&
        wide_to_utf8(path_w, out_path, out_path_size) == 0) {
      return 0;
    }
    out_path[0] = '\0';
  }

  // Fall back to limited image queries for elevated or protected processes.
  process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process != NULL) {
    wchar_t path_w[TA_MAX_PATH_BYTES];
    DWORD len = (DWORD)(sizeof(path_w) / sizeof(path_w[0]));
    int ok = QueryFullProcessImageNameW(process, 0, path_w, &len);
    CloseHandle(process);
    if (ok && len > 0 && len < (sizeof(path_w) / sizeof(path_w[0])) &&
        wide_to_utf8(path_w, out_path, out_path_size) == 0) {
      return 0;
    }
    out_path[0] = '\0';
  }

  return -1;
}

int timearc_win_get_active_app(AppInfo* out_app) {
  if (out_app == NULL) {
    return -1;
  }

  memset(out_app, 0, sizeof(*out_app));

  HWND hwnd = GetForegroundWindow();
  if (hwnd == NULL) {
    return -1;
  }

  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0) {
    return -1;
  }

  out_app->process_id = (uint32_t)pid;
  out_app->timestamp = time(NULL);
  out_app->active_status = true;

  // Empty titles are valid; the executable path still provides stable identity.
  wchar_t title_w[TA_MAX_TITLE_BYTES];
  title_w[0] = L'\0';
  GetWindowTextW(hwnd, title_w, (int)(sizeof(title_w) / sizeof(title_w[0])));
  wide_to_utf8(title_w, out_app->window_title, sizeof(out_app->window_title));

  if (query_process_path(pid, out_app->exec_path, sizeof(out_app->exec_path)) !=
      0) {
    snprintf(out_app->exec_path, sizeof(out_app->exec_path), "pid:%lu",
             (unsigned long)pid);
  }

  copy_string(out_app->app_name, sizeof(out_app->app_name),
              basename_from_path(out_app->exec_path));
  copy_string(out_app->display_name, sizeof(out_app->display_name),
              out_app->app_name);

  return 0;
}
