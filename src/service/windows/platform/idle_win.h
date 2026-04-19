#ifndef TIMEARC_IDLE_WIN_H
#define TIMEARC_IDLE_WIN_H

#include <stdint.h>

// Return how long it has been since the last keyboard or mouse input.
int64_t timearc_win_get_idle_ms(void);

// Return 1 when the current idle duration is at least idle_threshold_ms.
int timearc_win_is_idle(int64_t idle_threshold_ms);

#endif  // TIMEARC_IDLE_WIN_H
