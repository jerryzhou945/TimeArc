#include "service_config.h"
#include "service/win_service.h"
#include "tracker/usage_tracker.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <stdio.h>
#include <string.h>

// Windows collector entry point.
//
// The console process initializes storage and runs the tracker loop.
// Console shutdown requests a clean flush. win_service.c handles lifecycle
// verbs while keeping collection in the interactive user session.
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

// Run the resident collector as a background-class process: EcoQoS power
// throttling (Windows 11 "Efficiency mode") plus below-normal priority. The
// tracker timestamps by wall clock, so slower scheduling never changes
// recorded durations. Resolved at runtime because SetProcessInformation is
// absent before Windows 8; failure leaves default scheduling in place.
static void enter_efficiency_mode(void) {
  typedef BOOL(WINAPI * SetProcessInformationFn)(HANDLE, PROCESS_INFORMATION_CLASS,
                                                 LPVOID, DWORD);
  HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
  SetProcessInformationFn set_process_information =
      kernel32 == NULL
          ? NULL
          : (SetProcessInformationFn)(void (*)(void))GetProcAddress(
                kernel32, "SetProcessInformation");
  if (set_process_information != NULL) {
    PROCESS_POWER_THROTTLING_STATE throttling;
    ZeroMemory(&throttling, sizeof(throttling));
    throttling.Version = PROCESS_POWER_THROTTLING_CURRENT_VERSION;
    throttling.ControlMask = PROCESS_POWER_THROTTLING_EXECUTION_SPEED;
    throttling.StateMask = PROCESS_POWER_THROTTLING_EXECUTION_SPEED;
    set_process_information(GetCurrentProcess(), ProcessPowerThrottling,
                            &throttling, sizeof(throttling));
  }
  SetPriorityClass(GetCurrentProcess(), BELOW_NORMAL_PRIORITY_CLASS);
}

// Dispatch lifecycle verbs. No arguments runs the tracker for compatibility;
// verbs manage autostart and the tracker in the current user session.
static int dispatch_verb(int argc, char** argv) {
  const char* verb = argv[1];
  if (strcmp(verb, "--install") == 0) return timearc_win_service_install();
  if (strcmp(verb, "--uninstall") == 0) return timearc_win_service_uninstall();
  if (strcmp(verb, "--start") == 0) return timearc_win_service_start();
  if (strcmp(verb, "--stop") == 0) return timearc_win_service_stop();
  if (strcmp(verb, "--status") == 0) {
    if (argc >= 3 && strcmp(argv[2], "--json") == 0) {
      return timearc_win_service_status_json();
    }
    return timearc_win_service_status();
  }
  if (strcmp(verb, "--run-service") == 0) return timearc_win_service_run();

  fprintf(stderr,
          "TimeArc usage service\n"
          "usage: time-arc-service "
          "[--install|--uninstall|--start|--stop|--status]\n"
          "  (no args)   run the foreground user-session tracker\n");
  return 2;
}

int main(int argc, char** argv) {
  if (argc >= 2) {
    return dispatch_verb(argc, argv);
  }

  SetConsoleCtrlHandler(console_handler, TRUE);

  // Prevent concurrent collectors from writing unpredictable history.
  HANDLE instance_mutex = CreateMutexA(NULL, TRUE, TIMEARC_INSTANCE_MUTEX_NAME);
  if (instance_mutex == NULL) {
    fprintf(stderr, "failed to create TimeArc service mutex\n");
    return 1;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    CloseHandle(instance_mutex);
    return 0;
  }

  enter_efficiency_mode();

  // Start with compatible defaults, then apply valid service_config.json values.
  // Explicitly initialize track_enabled because omitted fields become zero.
  TimeArcUsageTrackerConfig config = {
      .poll_interval_ms = TIMEARC_USAGE_POLL_INTERVAL_MS,
      .idle_threshold_ms = TIMEARC_USAGE_IDLE_THRESHOLD_MS,
      .track_enabled = 1,
  };

  // Read configuration once at startup; invalid or missing values keep defaults.
  timearc_read_service_config(&config.idle_threshold_ms, &config.track_enabled);
  fprintf(stderr,
          "TimeArc service: applied config idle_threshold_ms=%lld "
          "track_enabled=%d\n",
          (long long)config.idle_threshold_ms, config.track_enabled);

  int result = timearc_usage_tracker_run(&config);
  ReleaseMutex(instance_mutex);
  CloseHandle(instance_mutex);
  return result;
}
