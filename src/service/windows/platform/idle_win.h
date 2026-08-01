#ifndef TIMEARC_IDLE_WIN_H
#define TIMEARC_IDLE_WIN_H

#include <stdint.h>

// Compute elapsed time in the 32-bit LASTINPUTINFO tick domain. Unsigned
// subtraction intentionally handles the GetTickCount rollover.
uint32_t timearc_win_idle_delta_ms(uint32_t now_tick,
                                   uint32_t last_input_tick);

// Return how long it has been since the last keyboard or mouse input.
int64_t timearc_win_get_idle_ms(void);

// Return 1 when the current idle duration is at least idle_threshold_ms.
int timearc_win_is_idle(int64_t idle_threshold_ms);

#endif  // TIMEARC_IDLE_WIN_H
