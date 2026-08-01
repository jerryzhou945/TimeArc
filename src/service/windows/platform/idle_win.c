#include "idle_win.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

uint32_t timearc_win_idle_delta_ms(uint32_t now_tick,
                                   uint32_t last_input_tick) {
  return now_tick - last_input_tick;
}

// Return milliseconds since the last keyboard or mouse input.
// Foreground tracking uses this value; audio tracking does not.
int64_t timearc_win_get_idle_ms(void) {
  LASTINPUTINFO input_info;
  input_info.cbSize = sizeof(input_info);

  if (GetLastInputInfo(&input_info) == 0) {
    return 0;
  }

  // LASTINPUTINFO stores a 32-bit tick. Compare it in the same domain so the
  // subtraction remains correct when GetTickCount wraps every 49.7 days.
  return (int64_t)timearc_win_idle_delta_ms(GetTickCount(),
                                            input_info.dwTime);
}

int timearc_win_is_idle(int64_t idle_threshold_ms) {
  return timearc_win_get_idle_ms() >= idle_threshold_ms ? 1 : 0;
}
