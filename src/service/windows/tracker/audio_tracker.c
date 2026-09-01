#include "audio_tracker.h"

#include "../platform/app_identity.h"
#include "../platform/audio_win.h"
#include "data_bridge.h"

#include <string.h>

// Codex can leave a WASAPI session looking active across sleep. Polling is
// nominally once per second, so a longer gap is not valid Codex evidence.
#define TIMEARC_AUDIO_MAX_OBSERVATION_GAP_SEC 5

// Deduplicate WASAPI sessions by executable path.
static int same_audio_app(const AppInfo* a, const AppInfo* b) {
  if (a == NULL || b == NULL) {
    return 0;
  }

  return timearc_app_identity_equal(a, b);
}

static int persist_audio_session(const TimeArcAudioSession* session,
                                 int64_t end_sec) {
  if (session == NULL || !session->active ||
      session->app.exec_path[0] == '\0' || end_sec <= session->start_sec) {
    return -1;
  }

  if (update_apps(session->app.exec_path, "windows", session->app.app_name, "",
                  session->app.exec_path, end_sec) != 0) {
    return -1;
  }

  const char* title = session->app.window_title[0] != '\0'
                          ? session->app.window_title
                          : "Audio playback";
  return update_media(session->app.exec_path, "audio", title,
                      session->start_sec, end_sec);
}

static void close_audio_session(TimeArcAudioSession* session,
                                int64_t end_sec) {
  if (session == NULL || !session->active) {
    return;
  }

  persist_audio_session(session, end_sec);
  memset(session, 0, sizeof(*session));
}

static TimeArcAudioSession* find_session(TimeArcAudioTrackerState* state,
                                         const AppInfo* app) {
  if (state == NULL || app == NULL) {
    return NULL;
  }

  for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
    if (state->sessions[i].active && same_audio_app(&state->sessions[i].app,
                                                    app)) {
      return &state->sessions[i];
    }
  }

  return NULL;
}

static TimeArcAudioSession* find_free_session(TimeArcAudioTrackerState* state) {
  if (state == NULL) {
    return NULL;
  }

  for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
    if (!state->sessions[i].active) {
      return &state->sessions[i];
    }
  }

  return NULL;
}

static int has_observation_gap(const TimeArcAudioTrackerState* state,
                               int64_t now_sec) {
  return state->last_poll_sec > 0 &&
         (now_sec < state->last_poll_sec ||
          now_sec - state->last_poll_sec >
              TIMEARC_AUDIO_MAX_OBSERVATION_GAP_SEC);
}

static int is_codex_audio_app(const AppInfo* app) {
  static const char marker[] = "\\WindowsApps\\OpenAI.Codex_";
  if (app == NULL) return 0;

  const size_t marker_len = sizeof(marker) - 1;
  for (const char* cursor = app->exec_path; *cursor != '\0'; ++cursor) {
    if (_strnicmp(cursor, marker, marker_len) == 0) return 1;
  }
  return 0;
}

static void close_all_sessions(TimeArcAudioTrackerState* state,
                               int64_t end_sec) {
  for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
    close_audio_session(&state->sessions[i], end_sec);
  }
}

static void close_codex_sessions(TimeArcAudioTrackerState* state,
                                 int64_t end_sec) {
  for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
    if (is_codex_audio_app(&state->sessions[i].app)) {
      close_audio_session(&state->sessions[i], end_sec);
    }
  }
}

static void start_or_update_session(TimeArcAudioTrackerState* state,
                                    const AppInfo* app,
                                    int64_t now_sec) {
  TimeArcAudioSession* session = find_session(state, app);
  if (session == NULL) {
    session = find_free_session(state);
    if (session == NULL) {
      return;
    }

    memset(session, 0, sizeof(*session));
    session->app = *app;
    session->active = 1;
    session->start_sec = now_sec;
  } else {
    session->app = *app;
  }

  session->seen_this_poll = 1;
}

void timearc_audio_tracker_init(TimeArcAudioTrackerState* state,
                                int64_t checkpoint_sec) {
  if (state != NULL) {
    memset(state, 0, sizeof(*state));
    state->checkpoint_sec = checkpoint_sec > 0 ? checkpoint_sec : 0;
  }
}

void timearc_audio_tracker_poll(TimeArcAudioTrackerState* state,
                                int64_t now_sec) {
  if (state == NULL) {
    return;
  }

  if (has_observation_gap(state, now_sec)) {
    close_codex_sessions(state, state->last_poll_sec);
  }
  state->last_poll_sec = now_sec;

  for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
    state->sessions[i].seen_this_poll = 0;
  }

  AppInfo apps[TIMEARC_AUDIO_MAX_APPS];
  size_t app_count = 0;
  const int sample_succeeded =
      timearc_win_get_audio_apps(apps, TIMEARC_AUDIO_MAX_APPS, &app_count) == 0;
  state->last_sample_succeeded = sample_succeeded;
  if (sample_succeeded) {
    for (size_t i = 0; i < app_count; ++i) {
      start_or_update_session(state, &apps[i], now_sec);
    }
  }

  for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
    TimeArcAudioSession* session = &state->sessions[i];
    if (!session->active) {
      continue;
    }

    if (sample_succeeded && !session->seen_this_poll) {
      close_audio_session(session, now_sec);
      continue;
    }

    if (sample_succeeded && session->seen_this_poll &&
        state->checkpoint_sec > 0 &&
        now_sec - session->start_sec >= state->checkpoint_sec &&
        persist_audio_session(session, now_sec) == 0) {
      session->start_sec = now_sec;
    }
  }
}

int timearc_audio_tracker_has_foreground(
    const TimeArcAudioTrackerState* state, const AppInfo* foreground) {
  if (state == NULL || foreground == NULL || !state->last_sample_succeeded) {
    return 0;
  }

  for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
    const TimeArcAudioSession* session = &state->sessions[i];
    if (!session->active || !session->seen_this_poll) {
      continue;
    }
    if (session->app.process_id != 0 && foreground->process_id != 0 &&
        session->app.process_id == foreground->process_id) {
      return 1;
    }
    if (session->app.exec_path[0] != '\0' &&
        strcmp(session->app.exec_path, foreground->exec_path) == 0) {
      return 1;
    }
  }
  return 0;
}

void timearc_audio_tracker_flush(TimeArcAudioTrackerState* state,
                                 int64_t now_sec) {
  if (state == NULL) {
    return;
  }

  if (has_observation_gap(state, now_sec)) {
    close_codex_sessions(state, state->last_poll_sec);
  }
  close_all_sessions(state, now_sec);
  state->last_poll_sec = now_sec;
}

void timearc_audio_tracker_shutdown(void) {
  timearc_win_audio_shutdown();
}
