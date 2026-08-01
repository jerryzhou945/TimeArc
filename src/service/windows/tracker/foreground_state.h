#ifndef TIMEARC_FOREGROUND_STATE_H
#define TIMEARC_FOREGROUND_STATE_H

#include <stdint.h>

#include "app_info.h"

typedef enum TimeArcForegroundMode {
  TIMEARC_FOREGROUND_CLOSED = 0,
  TIMEARC_FOREGROUND_ACTIVE = 1,
  TIMEARC_FOREGROUND_IDLE = 2,
} TimeArcForegroundMode;

typedef struct TimeArcForegroundSample {
  AppInfo app;
  int has_app;
  int64_t wall_sec;
  uint64_t monotonic_ms;
  int input_active;
  int autonomous_active;
} TimeArcForegroundSample;

typedef struct TimeArcForegroundClosedSession {
  AppInfo app;
  int64_t start_wall_sec;
  int64_t end_wall_sec;
  uint64_t active_ms;
} TimeArcForegroundClosedSession;

typedef struct TimeArcForegroundState {
  TimeArcForegroundMode mode;
  AppInfo app;
  int64_t start_wall_sec;
  int64_t last_wall_sec;
  uint64_t last_monotonic_ms;
  uint64_t active_ms;
  uint64_t lease_duration_ms;
  uint64_t lease_until_ms;
} TimeArcForegroundState;

void timearc_foreground_state_init(TimeArcForegroundState* state,
                                   uint64_t lease_duration_ms);
int timearc_foreground_state_step(
    TimeArcForegroundState* state, const TimeArcForegroundSample* sample,
    TimeArcForegroundClosedSession* out_closed);
int timearc_foreground_state_shutdown(
    TimeArcForegroundState* state, int64_t wall_sec, uint64_t monotonic_ms,
    TimeArcForegroundClosedSession* out_closed);

#endif  // TIMEARC_FOREGROUND_STATE_H
