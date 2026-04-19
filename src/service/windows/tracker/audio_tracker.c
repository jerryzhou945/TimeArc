#include "audio_tracker.h"

#include "../platform/audio_win.h"
#include "data_bridge.h"

#include <string.h>

static int same_audio_app(const AppInfo* a, const AppInfo* b) {
  if (a == NULL || b == NULL) {
    return 0;
  }

  return strcmp(a->exec_path, b->exec_path) == 0;
}

static void close_audio_session(TimeArcAudioSession* session,
                                int64_t end_sec) {
  if (session == NULL || !session->active ||
      session->app.exec_path[0] == '\0' || end_sec <= session->start_sec) {
    return;
  }

  ta_write_usage_record_with_source(
      "windows", "audio", session->app.exec_path, session->app.app_name,
      session->app.window_title, session->app.exec_path, session->start_sec,
      (uint64_t)(end_sec - session->start_sec));

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
  session->last_seen_sec = now_sec;
}

void timearc_audio_tracker_init(TimeArcAudioTrackerState* state) {
  if (state != NULL) {
    memset(state, 0, sizeof(*state));
  }
}

void timearc_audio_tracker_poll(TimeArcAudioTrackerState* state,
                                int64_t now_sec) {
  if (state == NULL) {
    return;
  }

  for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
    state->sessions[i].seen_this_poll = 0;
  }

  AppInfo apps[TIMEARC_AUDIO_MAX_APPS];
  size_t app_count = 0;
  if (timearc_win_get_audio_apps(apps, TIMEARC_AUDIO_MAX_APPS, &app_count) ==
      0) {
    for (size_t i = 0; i < app_count; ++i) {
      start_or_update_session(state, &apps[i], now_sec);
    }
  }

  for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
    TimeArcAudioSession* session = &state->sessions[i];
    if (!session->active) {
      continue;
    }

    if (session->seen_this_poll &&
        now_sec - session->start_sec >= TIMEARC_AUDIO_FLUSH_INTERVAL_SEC) {
      AppInfo app = session->app;
      close_audio_session(session, now_sec);
      start_or_update_session(state, &app, now_sec);
      continue;
    }

    if (!session->seen_this_poll &&
        now_sec - session->last_seen_sec > TIMEARC_AUDIO_SILENCE_GRACE_SEC) {
      int64_t end_sec = session->last_seen_sec + 1;
      close_audio_session(session, end_sec);
    }
  }
}

void timearc_audio_tracker_flush(TimeArcAudioTrackerState* state,
                                 int64_t now_sec) {
  if (state == NULL) {
    return;
  }

  for (int i = 0; i < TIMEARC_AUDIO_MAX_TRACKED_APPS; ++i) {
    close_audio_session(&state->sessions[i], now_sec);
  }
}

void timearc_audio_tracker_shutdown(void) {
  timearc_win_audio_shutdown();
}
