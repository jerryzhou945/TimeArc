#include "idle_win.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

// Return milliseconds since the last keyboard or mouse input.
// Foreground tracking uses this value; audio tracking does not.
int64_t timearc_win_get_idle_ms(void) {
  LASTINPUTINFO input_info;
  input_info.cbSize = sizeof(input_info);

  if (GetLastInputInfo(&input_info) == 0) {
    return 0;
  }

  // Both values use the same monotonic clock, unaffected by wall-clock changes.
  ULONGLONG now = GetTickCount64();
  if (now < input_info.dwTime) {
    return 0;
  }

  return (int64_t)(now - input_info.dwTime);
}

int timearc_win_is_idle(int64_t idle_threshold_ms) {
  return timearc_win_get_idle_ms() >= idle_threshold_ms ? 1 : 0;
}
