#include "usage_tracker.h"

#include "../platform/active_app_win.h"
#include "../platform/idle_win.h"
#include "audio_tracker.h"
#include "data_bridge.h"

#define WIN32_LEAN_AND_MEAN
#include <string.h>
#include <windows.h>

static volatile LONG g_stop_requested = 0;

// Shutdown signals set this flag so the loop can flush the current session.
void timearc_usage_tracker_request_stop(void) {
  InterlockedExchange(&g_stop_requested, 1);
}

static int should_stop(void) {
  return InterlockedCompareExchange(&g_stop_requested, 0, 0) != 0;
}

// Wait for the stop event during a poll interval, falling back to Sleep.
static void tracker_wait(HANDLE stop_event, DWORD ms) {
  if (stop_event != NULL) {
    if (WaitForSingleObject(stop_event, ms) == WAIT_OBJECT_0) {
      timearc_usage_tracker_request_stop();
    }
    return;
  }
  Sleep(ms);
}

static int64_t unix_time_sec(void) {
  FILETIME ft;
  GetSystemTimeAsFileTime(&ft);

  ULARGE_INTEGER value;
  value.LowPart = ft.dwLowDateTime;
  value.HighPart = ft.dwHighDateTime;

  // Convert 100 ns FILETIME ticks since 1601 to Unix seconds.
  return (int64_t)((value.QuadPart - 116444736000000000ULL) / 10000000ULL);
}

static int same_active_app(const AppInfo* a, const AppInfo* b) {
  if (a == NULL || b == NULL) {
    return 0;
  }

  // Continue foreground time while executable and window title both match.
  return strcmp(a->exec_path, b->exec_path) == 0 &&
         strcmp(a->window_title, b->window_title) == 0;
}

static void close_session(const AppInfo* app, int64_t start_sec,
                          int64_t end_sec) {
  // Drop zero-second segments created by polling-boundary jitter.
  if (app == NULL || app->exec_path[0] == '\0' || end_sec <= start_sec) {
    return;
  }

  if (update_apps(app->exec_path, "windows", app->app_name, "",
                  app->exec_path, end_sec) != 0) {
    return;
  }
  update_frontmost(app->exec_path, app->window_title, start_sec, end_sec,
                   end_sec - start_sec);
}

int timearc_usage_tracker_run(const TimeArcUsageTrackerConfig* config) {
  TimeArcUsageTrackerConfig active_config = {
      .poll_interval_ms = TIMEARC_USAGE_POLL_INTERVAL_MS,
      .idle_threshold_ms = TIMEARC_USAGE_IDLE_THRESHOLD_MS,
      .track_enabled = 1,  // Explicit compatible default; omitted fields become zero.
  };

  if (config != NULL) {
    if (config->poll_interval_ms > 0) {
      active_config.poll_interval_ms = config->poll_interval_ms;
    }
    if (config->idle_threshold_ms > 0) {
      active_config.idle_threshold_ms = config->idle_threshold_ms;
    }
    active_config.track_enabled = config->track_enabled ? 1 : 0;
  }

  // Disabled tracking exits without polling or writing, releasing the mutex.
  // A later startup resumes only if track_enabled is restored.
  if (!active_config.track_enabled) {
    return 0;
  }

  // A named event lets a separate --stop process request a clean shutdown.
  // If creation fails, console shutdown remains available.
  HANDLE stop_event = CreateEventA(NULL, TRUE, FALSE, TIMEARC_STOP_EVENT_NAME);

  AppInfo current_app;
  memset(&current_app, 0, sizeof(current_app));
  int has_session = 0;
  int64_t session_start_sec = 0;
  TimeArcAudioTrackerState audio_state;
  timearc_audio_tracker_init(&audio_state);

  while (!should_stop()) {
    int64_t now_sec = unix_time_sec();

    // Record audio independently of keyboard and mouse idle time.
    timearc_audio_tracker_poll(&audio_state, now_sec);

    // End foreground activity while idle and resume after input.
    int is_idle = timearc_win_is_idle(active_config.idle_threshold_ms);

    if (is_idle) {
      if (has_session) {
        close_session(&current_app, session_start_sec, now_sec);
        memset(&current_app, 0, sizeof(current_app));
        has_session = 0;
      }
      tracker_wait(stop_event, (DWORD)active_config.poll_interval_ms);
      continue;
    }

    AppInfo next_app;
    if (timearc_win_get_active_app(&next_app) != 0) {
      tracker_wait(stop_event, (DWORD)active_config.poll_interval_ms);
      continue;
    }

    // Start on the first active sample and roll over when path or title changes.
    if (!has_session) {
      current_app = next_app;
      session_start_sec = now_sec;
      has_session = 1;
    } else if (!same_active_app(&current_app, &next_app)) {
      close_session(&current_app, session_start_sec, now_sec);
      current_app = next_app;
      session_start_sec = now_sec;
    }

    tracker_wait(stop_event, (DWORD)active_config.poll_interval_ms);
  }

  int64_t final_sec = unix_time_sec();
  if (has_session) {
    close_session(&current_app, session_start_sec, final_sec);
  }
  timearc_audio_tracker_flush(&audio_state, final_sec);
  timearc_audio_tracker_shutdown();

  if (stop_event != NULL) {
    CloseHandle(stop_event);
  }

  return 0;
}
