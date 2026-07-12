#include "audio_tracker.h"

#include "../platform/audio_win.h"
#include "data_bridge.h"

#include <string.h>

// 音频 session 按 exe 路径去重。WASAPI 可能为同一进程暴露多个会话，
// TimeArc 当前只关心“这个应用正在出声”这一层。
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

  if (update_apps(session->app.exec_path, "windows", session->app.app_name, "",
                  session->app.exec_path, end_sec) == 0) {
    const char* title = session->app.window_title[0] != '\0'
                            ? session->app.window_title
                            : "Audio playback";
    update_media(session->app.exec_path, "audio", title, session->start_sec,
                 end_sec);
  }

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
  // 平台层每轮返回“当前仍有可听声音”的应用；未返回的旧 session 会在下面
  // 根据 last_seen_sec 和 grace period 关闭。
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
      // 长时间播放时定期写段，然后立即开启下一段，避免一整天播放只在退出时可见。
      AppInfo app = session->app;
      close_audio_session(session, now_sec);
      start_or_update_session(state, &app, now_sec);
      continue;
    }

    if (!session->seen_this_poll &&
        now_sec - session->last_seen_sec > TIMEARC_AUDIO_SILENCE_GRACE_SEC) {
      // 没有连续出现在采样结果里，说明停止播放或静音；留一点宽限避免峰值抖动。
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
