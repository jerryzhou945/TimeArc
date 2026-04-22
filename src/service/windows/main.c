#include "data_bridge.h"
#include "tracker/usage_tracker.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <stdio.h>

// Windows 采集进程入口。
//
// 当前实现还是前台控制台程序：启动后初始化存储、进入 tracker 轮询循环，
// Ctrl+C/关闭控制台时请求 tracker 收尾。后续改成真正的 Windows 服务时，
// 这里会和 Service Control Manager 的入口衔接。
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

int main(void) {
  SetConsoleCtrlHandler(console_handler, TRUE);

  // 防止同时启动多个采集进程。否则多个进程会同时写 usage_records.jsonl
  // 和 usage_current.json，历史记录与实时状态都会变得不可预测。
  HANDLE instance_mutex = CreateMutexA(NULL, TRUE, "Local\\TimeArcUsageService");
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

  // 轮询间隔和空闲阈值集中放在配置里，后续可以自然接到设置项。
  TimeArcUsageTrackerConfig config = {
      TIMEARC_USAGE_POLL_INTERVAL_MS,
      TIMEARC_USAGE_IDLE_THRESHOLD_MS,
  };

  int result = timearc_usage_tracker_run(&config);
  ta_storage_shutdown();
  ReleaseMutex(instance_mutex);
  CloseHandle(instance_mutex);
  return result;
}
