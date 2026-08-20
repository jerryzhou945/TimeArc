#include "usage_tracker.h"

#include "../platform/active_app_win.h"
#include "../platform/idle_win.h"
#include "../platform/process_activity_win.h"
#include "audio_tracker.h"
#include "data_bridge.h"
#include "foreground_state.h"

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

static void close_session(const TimeArcForegroundClosedSession* session) {
  // Drop zero-second segments created by polling-boundary jitter.
  if (session == NULL || session->app.exec_path[0] == '\0' ||
      session->end_wall_sec <= session->start_wall_sec) {
    return;
  }

  if (update_apps(session->app.exec_path, "windows", session->app.app_name, "",
                  session->app.exec_path, session->end_wall_sec) != 0) {
    return;
  }
  update_frontmost(session->app.exec_path, session->app.window_title,
                   session->start_wall_sec, session->end_wall_sec,
                   (int64_t)(session->active_ms / 1000ULL));
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
    if (config->idle_threshold_ms >= 0) {
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

  TimeArcForegroundState foreground_state;
  timearc_foreground_state_init(&foreground_state,
                                TIMEARC_USAGE_WORK_LEASE_MS);
  TimeArcProcessActivityProbe process_probe;
  timearc_process_activity_init(&process_probe);
  TimeArcAudioTrackerState audio_state;
  timearc_audio_tracker_init(&audio_state);

  while (!should_stop()) {
    int64_t now_sec = unix_time_sec();

    // Record audio independently of keyboard and mouse idle time.
    timearc_audio_tracker_poll(&audio_state, now_sec);

    TimeArcForegroundSample sample;
    memset(&sample, 0, sizeof(sample));
    sample.wall_sec = now_sec;
    sample.monotonic_ms = GetTickCount64();
    AppInfo next_app;
    if (timearc_win_get_active_app(&next_app) == 0) {
      sample.app = next_app;
      sample.has_app = 1;
      sample.input_active = active_config.idle_threshold_ms == 0 ||
                            timearc_win_get_idle_ms() <
                                active_config.idle_threshold_ms;

      TimeArcProcessCounters counters;
      if (timearc_win_process_activity_sample(next_app.process_id, &counters)) {
        sample.autonomous_active = timearc_process_activity_delta(
            &process_probe, next_app.process_id, &counters);
      } else {
        memset(&counters, 0, sizeof(counters));
        timearc_process_activity_delta(&process_probe, next_app.process_id,
                                       &counters);
      }
      if (timearc_audio_tracker_has_foreground(&audio_state, &next_app)) {
        sample.autonomous_active = 1;
      }
    } else {
      TimeArcProcessCounters unavailable;
      memset(&unavailable, 0, sizeof(unavailable));
      timearc_process_activity_delta(&process_probe, 0, &unavailable);
    }

    TimeArcForegroundClosedSession closed;
    if (timearc_foreground_state_step(&foreground_state, &sample, &closed)) {
      close_session(&closed);
    }

    tracker_wait(stop_event, (DWORD)active_config.poll_interval_ms);
  }

  const int64_t final_sec = unix_time_sec();
  TimeArcForegroundClosedSession closed;
  if (timearc_foreground_state_shutdown(&foreground_state, final_sec,
                                        GetTickCount64(), &closed)) {
    close_session(&closed);
  }
  timearc_audio_tracker_flush(&audio_state, final_sec);
  timearc_audio_tracker_shutdown();

  if (stop_event != NULL) {
    CloseHandle(stop_event);
  }

  return 0;
}
