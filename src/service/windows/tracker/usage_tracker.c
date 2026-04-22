#include "usage_tracker.h"

#include "../platform/active_app_win.h"
#include "../platform/idle_win.h"
#include "audio_tracker.h"
#include "data_bridge.h"

#define WIN32_LEAN_AND_MEAN
#include <string.h>
#include <windows.h>

static volatile LONG g_stop_requested = 0;

// 控制台关闭或未来服务 stop 信号会设置这个标记。主循环每轮检查一次，
// 这样可以在退出前正常 flush 当前 session。
void timearc_usage_tracker_request_stop(void) {
  InterlockedExchange(&g_stop_requested, 1);
}

static int should_stop(void) {
  return InterlockedCompareExchange(&g_stop_requested, 0, 0) != 0;
}

static int64_t unix_time_sec(void) {
  FILETIME ft;
  GetSystemTimeAsFileTime(&ft);

  ULARGE_INTEGER value;
  value.LowPart = ft.dwLowDateTime;
  value.HighPart = ft.dwHighDateTime;

  // FILETIME 从 1601-01-01 开始计 100ns tick；存储协议使用 Unix 秒。
  return (int64_t)((value.QuadPart - 116444736000000000ULL) / 10000000ULL);
}

static int same_active_app(const AppInfo* a, const AppInfo* b) {
  if (a == NULL || b == NULL) {
    return 0;
  }

  // 前台使用按“同一个 exe + 同一个窗口标题”连续计时。浏览器切换网页标题时
  // 会自然切开，这正是当前保守版站点识别的基础。
  return strcmp(a->exec_path, b->exec_path) == 0 &&
         strcmp(a->window_title, b->window_title) == 0;
}

static void close_session(const AppInfo* app, int64_t start_sec,
                          int64_t end_sec) {
  // 0 秒片段直接丢弃，避免轮询边界抖动制造噪声记录。
  if (app == NULL || app->exec_path[0] == '\0' || end_sec <= start_sec) {
    return;
  }

  ta_write_usage_record("windows", app->exec_path, app->app_name,
                        app->window_title, app->exec_path, start_sec,
                        (uint64_t)(end_sec - start_sec));
}

static void write_current_session(const AppInfo* app, int64_t start_sec,
                                  int64_t now_sec) {
  if (app == NULL || app->exec_path[0] == '\0' || now_sec < start_sec) {
    return;
  }

  ta_write_current_usage("windows", app->exec_path, app->app_name,
                         app->window_title, app->exec_path, start_sec,
                         (uint64_t)(now_sec - start_sec), now_sec);
}

int timearc_usage_tracker_run(const TimeArcUsageTrackerConfig* config) {
  TimeArcUsageTrackerConfig active_config = {
      TIMEARC_USAGE_POLL_INTERVAL_MS,
      TIMEARC_USAGE_IDLE_THRESHOLD_MS,
  };

  if (config != NULL) {
    if (config->poll_interval_ms > 0) {
      active_config.poll_interval_ms = config->poll_interval_ms;
    }
    if (config->idle_threshold_ms > 0) {
      active_config.idle_threshold_ms = config->idle_threshold_ms;
    }
  }

  AppInfo current_app;
  memset(&current_app, 0, sizeof(current_app));
  int has_session = 0;
  int64_t session_start_sec = 0;
  TimeArcAudioTrackerState audio_state;
  timearc_audio_tracker_init(&audio_state);

  while (!should_stop()) {
    int64_t now_sec = unix_time_sec();

    // 音频播放独立于键鼠空闲：人离开电脑但音乐/视频还在播放时，仍然记录 audio。
    timearc_audio_tracker_poll(&audio_state, now_sec);

    // foreground 使用尊重空闲状态：人离开后关闭当前前台 session，
    // 等下一次输入恢复再重新开始。
    int is_idle = timearc_win_is_idle(active_config.idle_threshold_ms);

    if (is_idle) {
      if (has_session) {
        close_session(&current_app, session_start_sec, now_sec);
        memset(&current_app, 0, sizeof(current_app));
        has_session = 0;
      }
      ta_clear_current_usage();

      Sleep((DWORD)active_config.poll_interval_ms);
      continue;
    }

    AppInfo next_app;
    if (timearc_win_get_active_app(&next_app) != 0) {
      Sleep((DWORD)active_config.poll_interval_ms);
      continue;
    }

    // 第一轮非空闲采样开启 session；之后只要 exe 或标题变化就滚动到新 session。
    if (!has_session) {
      current_app = next_app;
      session_start_sec = now_sec;
      has_session = 1;
    } else if (!same_active_app(&current_app, &next_app)) {
      close_session(&current_app, session_start_sec, now_sec);
      current_app = next_app;
      session_start_sec = now_sec;
    }

    write_current_session(&current_app, session_start_sec, now_sec);

    Sleep((DWORD)active_config.poll_interval_ms);
  }

  int64_t final_sec = unix_time_sec();
  if (has_session) {
    close_session(&current_app, session_start_sec, final_sec);
  }
  timearc_audio_tracker_flush(&audio_state, final_sec);
  timearc_audio_tracker_shutdown();
  ta_clear_current_usage();

  return 0;
}
