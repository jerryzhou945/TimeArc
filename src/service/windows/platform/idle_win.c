#include "idle_win.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

// 读取系统最后一次键鼠输入距现在的毫秒数。前台使用计时会用它判断用户
// 是否离开电脑；音频播放计时不受这个空闲状态影响。
int64_t timearc_win_get_idle_ms(void) {
  LASTINPUTINFO input_info;
  input_info.cbSize = sizeof(input_info);

  if (GetLastInputInfo(&input_info) == 0) {
    return 0;
  }

  // GetTickCount64 和 LASTINPUTINFO.dwTime 使用同一个单调毫秒时钟，
  // 所以用户修改系统时间不会影响空闲时长。
  ULONGLONG now = GetTickCount64();
  if (now < input_info.dwTime) {
    return 0;
  }

  return (int64_t)(now - input_info.dwTime);
}

int timearc_win_is_idle(int64_t idle_threshold_ms) {
  return timearc_win_get_idle_ms() >= idle_threshold_ms ? 1 : 0;
}
