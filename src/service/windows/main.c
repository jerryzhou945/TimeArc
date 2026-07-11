#include "data_bridge.h"
#include "service/win_service.h"
#include "storage/usage_storage.h"  // timearc_read_service_config (H5)
#include "tracker/usage_tracker.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <stdio.h>
#include <string.h>

// Windows 采集进程入口。
//
// 当前实现还是前台控制台程序：启动后初始化存储、进入 tracker 轮询循环，
// Ctrl+C/关闭控制台时请求 tracker 收尾。生命周期动词（--install 等）由
// service/win_service.c 处理，让采集留在用户会话（B1 Route A）。
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

// 生命周期动词分派（B1 Route A）。无参 = 今天的前台/会话内 tracker（向后兼容，
// UI auto-spawn 仍可用）；动词经 win_service 注册/查询/启停用户会话登录自启项。
static int dispatch_verb(const char* verb) {
  if (strcmp(verb, "--install") == 0) return timearc_win_service_install();
  if (strcmp(verb, "--uninstall") == 0) return timearc_win_service_uninstall();
  if (strcmp(verb, "--start") == 0) return timearc_win_service_start();
  if (strcmp(verb, "--stop") == 0) return timearc_win_service_stop();
  if (strcmp(verb, "--status") == 0) return timearc_win_service_status();
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
    return dispatch_verb(argv[1]);
  }

  SetConsoleCtrlHandler(console_handler, TRUE);

  // 防止同时启动多个采集进程。否则多个进程会同时写 service DB，
  // 历史记录会变得不可预测。
  HANDLE instance_mutex = CreateMutexA(NULL, TRUE, TIMEARC_INSTANCE_MUTEX_NAME);
  if (instance_mutex == NULL) {
    fprintf(stderr, "failed to create TimeArc service mutex\n");
    return 1;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    CloseHandle(instance_mutex);
    return 0;
  }

  // 先初始化存储，再启动轮询；这样 tracker 在焦点变化或空闲时可以立刻落盘。
  if (ta_storage_init() != 0) {
    fprintf(stderr, "failed to initialize TimeArc usage storage\n");
    CloseHandle(instance_mutex);
    return 1;
  }

  // 轮询间隔、空闲阈值、采集开关集中放在配置里。先填编译期默认（＝今天行为），
  // 再让 H5 的 usage_config.json 覆盖 idle/track（缺/坏/键缺则保留默认，向后兼容）。
  // 用具名初始化器：track_enabled 必须显式给 1——任何遗漏会被零初始化成 0＝静默关
  // 采集，故宁可显式（见头文件红线）。
  TimeArcUsageTrackerConfig config = {
      .poll_interval_ms = TIMEARC_USAGE_POLL_INTERVAL_MS,
      .idle_threshold_ms = TIMEARC_USAGE_IDLE_THRESHOLD_MS,
      .track_enabled = 1,
  };

  // 启动时读一次配置（startup-read）：UI 改了设置须经「应用并重启采集」重启本进程
  // 才生效。timearc_read_service_config 只在键存在且合法时改出参，故默认值天然兜底。
  timearc_read_service_config(&config.idle_threshold_ms, &config.track_enabled);
  fprintf(stderr,
          "TimeArc service: applied config idle_threshold_ms=%lld "
          "track_enabled=%d\n",
          (long long)config.idle_threshold_ms, config.track_enabled);

  int result = timearc_usage_tracker_run(&config);
  ta_storage_shutdown();
  ReleaseMutex(instance_mutex);
  CloseHandle(instance_mutex);
  return result;
}
