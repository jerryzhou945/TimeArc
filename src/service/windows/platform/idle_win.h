#ifndef TIMEARC_IDLE_WIN_H
#define TIMEARC_IDLE_WIN_H

#include <stdint.h>

int64_t timearc_win_get_idle_ms(void);
int timearc_win_is_idle(int64_t idle_threshold_ms);

#endif  // TIMEARC_IDLE_WIN_H
