#include "usage_tracker.h"

#include "../platform/active_app_win.h"
#include "../platform/idle_win.h"
#include "../platform/process_activity_win.h"
#include "audio_tracker.h"
#include "data_bridge.h"
#include "foreground_state.h"

#include <stdio.h>
#include <stdlib.h>
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

static void close_agent_session(
    const TimeArcAgentActivityClosedSession* session) {
  if (session == NULL || session->app.exec_path[0] == '\0' ||
      session->end_wall_sec <= session->start_wall_sec) {
    return;
  }
  if (update_apps(session->app.exec_path, "windows", session->app.app_name, "",
                  session->app.exec_path, session->end_wall_sec) != 0) {
    return;
  }
  // Reuse the existing contract-safe fallback type; the fixed title identifies
  // this as background agent work without adding a new on-disk enum value.
  update_media(session->app.exec_path, "unknown", "Codex task",
               session->start_wall_sec, session->end_wall_sec);
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
  TimeArcProcessActivityProbe codex_probe;
  timearc_process_activity_init(&codex_probe);
  TimeArcAgentActivityState agent_state;
  timearc_agent_activity_init(&agent_state, TIMEARC_USAGE_WORK_LEASE_MS);
  AppInfo cached_codex_app;
  memset(&cached_codex_app, 0, sizeof(cached_codex_app));
  int has_cached_codex_app = 0;
  TimeArcAudioTrackerState audio_state;
  timearc_audio_tracker_init(&audio_state, TIMEARC_USAGE_CHECKPOINT_SEC);
  const int diagnostics_enabled =
      getenv("TIMEARC_TRACKER_DIAGNOSTICS") != NULL;
  int64_t last_diagnostic_sec = 0;

  while (!should_stop()) {
    int64_t now_sec = unix_time_sec();

    // Record audio independently of keyboard and mouse idle time.
    timearc_audio_tracker_poll(&audio_state, now_sec);

    TimeArcForegroundSample sample;
    memset(&sample, 0, sizeof(sample));
    sample.wall_sec = now_sec;
    sample.monotonic_ms = GetTickCount64();
    AppInfo next_app;
    TimeArcProcessCounters foreground_counters;
    memset(&foreground_counters, 0, sizeof(foreground_counters));
    int foreground_process_sampled = 0;
    if (timearc_win_get_active_app(&next_app) == 0) {
      sample.app = next_app;
      sample.has_app = 1;
      sample.input_active = active_config.idle_threshold_ms == 0 ||
                            timearc_win_get_idle_ms() <
                                active_config.idle_threshold_ms;

      foreground_process_sampled = timearc_win_process_activity_sample(
          next_app.process_id, next_app.exec_path, &foreground_counters);
      if (foreground_process_sampled) {
        sample.autonomous_active = timearc_process_activity_delta(
            &process_probe, next_app.process_id, &foreground_counters);
        cached_codex_app = next_app;
        has_cached_codex_app = 1;
      } else {
        timearc_process_activity_delta(&process_probe, next_app.process_id,
                                       &foreground_counters);
      }
      if (timearc_audio_tracker_has_foreground(&audio_state, &next_app)) {
        sample.autonomous_active = 1;
      }
      // Recognized main game executables use foreground presence as the work
      // signal. This keeps controller input, cutscenes and loading screens
      // active without ever counting a minimized/background game or launcher.
      if (timearc_win_is_foreground_game(next_app.exec_path)) {
        sample.autonomous_active = 1;
      }
    } else {
      TimeArcProcessCounters unavailable;
      memset(&unavailable, 0, sizeof(unavailable));
      timearc_process_activity_delta(&process_probe, 0, &unavailable);
    }

    int codex_work_active = 0;
    if (has_cached_codex_app) {
      TimeArcProcessCounters codex_counters;
      int codex_sampled = 0;
      if (foreground_process_sampled && sample.has_app &&
          next_app.process_id == cached_codex_app.process_id &&
          strcmp(next_app.exec_path, cached_codex_app.exec_path) == 0) {
        codex_counters = foreground_counters;
        codex_sampled = 1;
      } else {
        codex_sampled = timearc_win_process_activity_sample(
            cached_codex_app.process_id, cached_codex_app.exec_path,
            &codex_counters);
      }
      if (codex_sampled) {
        codex_work_active = timearc_process_activity_delta(
            &codex_probe, cached_codex_app.process_id, &codex_counters);
      } else {
        memset(&codex_counters, 0, sizeof(codex_counters));
        timearc_process_activity_delta(
            &codex_probe, cached_codex_app.process_id, &codex_counters);
      }
    }

    TimeArcAgentActivityClosedSession closed_agent;
    if (timearc_agent_activity_step(
            &agent_state,
            has_cached_codex_app ? &cached_codex_app : NULL,
            codex_work_active, now_sec, sample.monotonic_ms, &closed_agent)) {
      close_agent_session(&closed_agent);
    }
    if (agent_state.active &&
        now_sec - agent_state.start_wall_sec >=
            TIMEARC_USAGE_CHECKPOINT_SEC &&
        timearc_agent_activity_checkpoint(&agent_state, now_sec,
                                          &closed_agent)) {
      close_agent_session(&closed_agent);
    }

    if (diagnostics_enabled && now_sec - last_diagnostic_sec >= 5) {
      fprintf(stderr,
              "TimeArc tracker: foreground=%d codex_sample=%d cached=%d "
              "codex_work=%d agent_active=%d\n",
              sample.has_app, foreground_process_sampled,
              has_cached_codex_app, codex_work_active, agent_state.active);
      last_diagnostic_sec = now_sec;
    }

    TimeArcForegroundClosedSession closed;
    if (timearc_foreground_state_step(&foreground_state, &sample, &closed)) {
      close_session(&closed);
    }
    if (foreground_state.mode != TIMEARC_FOREGROUND_CLOSED &&
        now_sec - foreground_state.start_wall_sec >=
            TIMEARC_USAGE_CHECKPOINT_SEC &&
        timearc_foreground_state_checkpoint(
            &foreground_state, now_sec, sample.monotonic_ms, &closed)) {
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
  TimeArcAgentActivityClosedSession closed_agent;
  if (timearc_agent_activity_checkpoint(&agent_state, final_sec,
                                        &closed_agent)) {
    close_agent_session(&closed_agent);
  }
  timearc_audio_tracker_shutdown();

  if (stop_event != NULL) {
    CloseHandle(stop_event);
  }

  return 0;
}
