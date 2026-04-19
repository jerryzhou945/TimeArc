#include "data_bridge.h"
#include "tracker/usage_tracker.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <stdio.h>

static BOOL WINAPI console_handler(DWORD event_type) {
  switch (event_type) {
    case CTRL_C_EVENT:
    case CTRL_BREAK_EVENT:
    case CTRL_CLOSE_EVENT:
    case CTRL_LOGOFF_EVENT:
    case CTRL_SHUTDOWN_EVENT:
      timearc_usage_tracker_request_stop();
      return TRUE;
    default:
      return FALSE;
  }
}

int main(void) {
  SetConsoleCtrlHandler(console_handler, TRUE);

  HANDLE instance_mutex = CreateMutexA(NULL, TRUE, "Local\\TimeArcUsageService");
  if (instance_mutex == NULL) {
    fprintf(stderr, "failed to create TimeArc service mutex\n");
    return 1;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    CloseHandle(instance_mutex);
    return 0;
  }

  // Storage is initialized before the tracker starts so every closed session can
  // be persisted immediately from inside the polling loop.
  if (ta_storage_init() != 0) {
    fprintf(stderr, "failed to initialize TimeArc usage storage\n");
    CloseHandle(instance_mutex);
    return 1;
  }

  // The Windows binary currently runs in the foreground and blocks in the
  // tracker loop until Ctrl+C, console close, or a future service stop signal.
  TimeArcUsageTrackerConfig config = {
      TIMEARC_USAGE_POLL_INTERVAL_MS,
      TIMEARC_USAGE_IDLE_THRESHOLD_MS,
  };

  int result = timearc_usage_tracker_run(&config);
  ta_storage_shutdown();
  ReleaseMutex(instance_mutex);
  CloseHandle(instance_mutex);
  return result;
}
