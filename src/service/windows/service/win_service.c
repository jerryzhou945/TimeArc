#include "win_service.h"

#include "../service_config.h"
#include "../tracker/usage_tracker.h"  // TIMEARC_INSTANCE_MUTEX_NAME / TIMEARC_STOP_EVENT_NAME

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <stdio.h>
#include <wchar.h>

// Route A registers a logon task so collection runs as the interactive user.
// Fall back to HKCU Run if schtasks is unavailable. The named stop event
// requests a clean flush.

#define TIMEARC_TASK_NAME L"TimeArc Usage Service"
#define TIMEARC_RUN_VALUE L"TimeArc Usage Service"
#define TIMEARC_RUN_KEY \
  L"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"

enum { EXE_CAP = 1024, CMD_CAP = 1536 };

// Get the full service executable path. Return 0 on success.
static int current_exe_path(wchar_t* buf, DWORD cap) {
  DWORD n = GetModuleFileNameW(NULL, buf, cap);
  return (n > 0 && n < cap) ? 0 : -1;
}

// Run a system command synchronously without a console window.
// cmdline must be writable because CreateProcessW modifies it.
static int run_hidden_wait(wchar_t* cmdline) {
  STARTUPINFOW si;
  PROCESS_INFORMATION pi;
  ZeroMemory(&si, sizeof(si));
  si.cb = sizeof(si);
  ZeroMemory(&pi, sizeof(pi));

  if (!CreateProcessW(NULL, cmdline, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL,
                      NULL, &si, &pi)) {
    return -1;
  }
  WaitForSingleObject(pi.hProcess, INFINITE);
  DWORD code = 1;
  GetExitCodeProcess(pi.hProcess, &code);
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);
  return (int)code;
}

// Primary path: a logon task running with the standard user token.
// Quote both the /tr value and executable path. --start launches the tracker
// without leaving a visible console window.
static int register_logon_task(const wchar_t* exe) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP,
             L"schtasks /create /tn \"%ls\" /tr \"\\\"%ls\\\" --start\" /sc onlogon /f",
             TIMEARC_TASK_NAME, exe);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd);
}

static int unregister_logon_task(void) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP, L"schtasks /delete /tn \"%ls\" /f", TIMEARC_TASK_NAME);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd);
}

static int logon_task_exists(void) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP, L"schtasks /query /tn \"%ls\"", TIMEARC_TASK_NAME);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd) == 0;  // Exit code 0 means the task exists.
}

// Fallback path: HKCU Run, used only when schtasks fails.
static int register_run_key(const wchar_t* exe) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP,
             L"reg add \"%ls\" /v \"%ls\" /t REG_SZ /d \"\\\"%ls\\\" --start\" /f",
             TIMEARC_RUN_KEY, TIMEARC_RUN_VALUE, exe);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd);
}

static int unregister_run_key(void) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP, L"reg delete \"%ls\" /v \"%ls\" /f", TIMEARC_RUN_KEY,
             TIMEARC_RUN_VALUE);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd);
}

static int run_key_exists(void) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP, L"reg query \"%ls\" /v \"%ls\"", TIMEARC_RUN_KEY,
             TIMEARC_RUN_VALUE);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd) == 0;
}

int timearc_win_service_install(void) {
  wchar_t exe[EXE_CAP];
  if (current_exe_path(exe, EXE_CAP) != 0) {
    fprintf(stderr, "install: cannot resolve service exe path\n");
    return 1;
  }
  if (register_logon_task(exe) == 0) {
    // Remove a stale Run fallback after the primary path succeeds.
    unregister_run_key();
    printf("autostart registered (logon task)\n");
    return 0;
  }
  if (register_run_key(exe) == 0) {
    printf("autostart registered (run key)\n");
    return 0;
  }
  fprintf(stderr, "install: failed to register autostart\n");
  return 1;
}

int timearc_win_service_uninstall(void) {
  // Attempt both removals; missing entries already represent a clean uninstall.
  unregister_logon_task();
  unregister_run_key();
  printf("autostart unregistered\n");
  return 0;
}

int timearc_win_service_start(void) {
  wchar_t exe[EXE_CAP];
  if (current_exe_path(exe, EXE_CAP) != 0) {
    fprintf(stderr, "start: cannot resolve service exe path\n");
    return 1;
  }
  // Launch the tracker in the current session; the Local\ mutex makes it idempotent.
  wchar_t cmd[EXE_CAP + 4];
  _snwprintf(cmd, EXE_CAP + 4, L"\"%ls\"", exe);
  cmd[EXE_CAP + 3] = L'\0';

  STARTUPINFOW si;
  PROCESS_INFORMATION pi;
  ZeroMemory(&si, sizeof(si));
  si.cb = sizeof(si);
  ZeroMemory(&pi, sizeof(pi));
  if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE,
                      CREATE_NO_WINDOW, NULL, NULL, &si,  // DETACHED_PROCESS would override this and break Ctrl events.
                      &pi)) {
    fprintf(stderr, "start: failed to launch tracker\n");
    return 1;
  }
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);
  printf("tracker started\n");
  return 0;
}

int timearc_win_service_stop(void) {
  // Signal a clean foreground and audio flush instead of force-killing.
  HANDLE ev = OpenEventA(EVENT_MODIFY_STATE, FALSE, TIMEARC_STOP_EVENT_NAME);
  if (ev == NULL) {
    printf("tracker not running\n");
    return 0;
  }
  SetEvent(ev);
  CloseHandle(ev);
  printf("stop requested\n");
  return 0;
}

int timearc_win_service_status(void) {
  int registered = logon_task_exists() || run_key_exists();

  // An open instance mutex means a tracker is running in the session.
  HANDLE m = OpenMutexA(SYNCHRONIZE, FALSE, TIMEARC_INSTANCE_MUTEX_NAME);
  int running = (m != NULL);
  if (m != NULL) {
    CloseHandle(m);
  }

  printf("autostart=%s\n", registered ? "on" : "off");
  printf("running=%s\n", running ? "yes" : "no");
  return registered ? 0 : 1;
}

int timearc_win_service_status_json(void) {
  const int has_task = logon_task_exists();
  const int has_run_key = run_key_exists();
  const int registered = has_task || has_run_key;

  HANDLE mutex =
      OpenMutexA(SYNCHRONIZE, FALSE, TIMEARC_INSTANCE_MUTEX_NAME);
  const int running = mutex != NULL;
  if (mutex != NULL) CloseHandle(mutex);

  int64_t idle_threshold_ms = TIMEARC_USAGE_IDLE_THRESHOLD_MS;
  int tracking_enabled = 1;
  timearc_read_service_config(&idle_threshold_ms, &tracking_enabled);

  const char* backend = has_task ? "scheduled_task"
                                 : (has_run_key ? "run_key" : NULL);
  printf("{\"schema_version\":1,\"command\":\"status\","
         "\"platform\":\"windows\",\"tracking\":{"
         "\"running\":%s,\"enabled\":%s,"
         "\"frontmost\":{\"enabled\":true,"
         "\"idle_threshold_sec\":%lld},"
         "\"media\":{\"enabled\":true}},"
         "\"autostart\":{\"enabled\":%s,\"backend\":",
         running ? "true" : "false",
         tracking_enabled ? "true" : "false",
         (long long)(idle_threshold_ms / 1000),
         registered ? "true" : "false");
  if (backend != NULL) {
    printf("\"%s\"", backend);
  } else {
    printf("null");
  }
  printf("}}\n");
  return registered ? 0 : 1;
}

int timearc_win_service_run(void) {
  // Route B is deferred because a LocalSystem service would collect in Session 0.
  fprintf(stderr, "--run-service (SCM mode) is not implemented in Route A\n");
  return 1;
}
