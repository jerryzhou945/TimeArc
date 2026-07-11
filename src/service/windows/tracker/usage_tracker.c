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

// 在一个轮询周期内等待停机事件。语义等价于既有 Sleep(ms)，但能即时响应独立
// `--stop` 进程的 SetEvent（不必等满一个周期）。事件置位即请求停机，主循环下一
// 轮的 should_stop() 处自然退出、走既有 flush。事件为 NULL 时退化为纯 Sleep。
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

int timearc_usage_tracker_run(const TimeArcUsageTrackerConfig* config) {
  TimeArcUsageTrackerConfig active_config = {
      .poll_interval_ms = TIMEARC_USAGE_POLL_INTERVAL_MS,
      .idle_threshold_ms = TIMEARC_USAGE_IDLE_THRESHOLD_MS,
      .track_enabled = 1,  // 默认采集（向后兼容）；具名初始化器须显式给 1，见头文件。
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

  // H5「真停采集」：追踪关闭时根本不进采集循环——不写历史、不轮询音频。
  // 进程随之退出、释放单实例 mutex，于是
  // `--status` 报 running=no（诚实反映「未在采集」）。重启后读到 track_enabled=1 才
  // 恢复（startup-read，与 idle 阈值一致）。绝不回溯删除既有记录（append-only）。
  if (!active_config.track_enabled) {
    return 0;
  }

  // 停采集通道（B1 Route A）：除 console_handler 外另开一个具名事件，让独立的
  // `--stop` 进程能请求优雅停机（OpenEvent+SetEvent）。今天 tracker 是 UI
  // detached-spawn 的无控制台进程，兄弟进程无法对它投递 CTRL，故必须有这条事件
  // 通道才能优雅停（详见 docs/b1-windows-service-scm-kickoff.md §4.4）。手动重置，
  // 置位后保持；创建失败则退化为仅 console_handler 可停（不影响采集本身）。
  HANDLE stop_event = CreateEventA(NULL, TRUE, FALSE, TIMEARC_STOP_EVENT_NAME);

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
      tracker_wait(stop_event, (DWORD)active_config.poll_interval_ms);
      continue;
    }

    AppInfo next_app;
    if (timearc_win_get_active_app(&next_app) != 0) {
      tracker_wait(stop_event, (DWORD)active_config.poll_interval_ms);
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
