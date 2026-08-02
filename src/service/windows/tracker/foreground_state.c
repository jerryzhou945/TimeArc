#include "foreground_state.h"

#include "../platform/app_identity.h"

#include <string.h>

static void advance(TimeArcForegroundState* state, int64_t wall_sec,
                    uint64_t monotonic_ms) {
  if (state->mode == TIMEARC_FOREGROUND_CLOSED) {
    return;
  }

  if (monotonic_ms >= state->last_monotonic_ms &&
      state->mode == TIMEARC_FOREGROUND_ACTIVE) {
    state->active_ms += monotonic_ms - state->last_monotonic_ms;
  }
  state->last_monotonic_ms = monotonic_ms;
  state->last_wall_sec = wall_sec;
}

static void export_closed(const TimeArcForegroundState* state,
                          TimeArcForegroundClosedSession* out_closed) {
  if (out_closed == NULL) {
    return;
  }
  memset(out_closed, 0, sizeof(*out_closed));
  out_closed->app = state->app;
  out_closed->start_wall_sec = state->start_wall_sec;
  out_closed->end_wall_sec = state->last_wall_sec;
  out_closed->active_ms = state->active_ms;
}

static void start_session(TimeArcForegroundState* state,
                          const TimeArcForegroundSample* sample) {
  state->app = sample->app;
  state->start_wall_sec = sample->wall_sec;
  state->last_wall_sec = sample->wall_sec;
  state->last_monotonic_ms = sample->monotonic_ms;
  state->active_ms = 0;
  state->lease_until_ms = 0;
  if (sample->autonomous_active) {
    state->lease_until_ms = sample->monotonic_ms + state->lease_duration_ms;
  }
  state->mode =
      sample->input_active || sample->autonomous_active
          ? TIMEARC_FOREGROUND_ACTIVE
          : TIMEARC_FOREGROUND_IDLE;
}

static void update_mode(TimeArcForegroundState* state,
                        const TimeArcForegroundSample* sample) {
  if (sample->autonomous_active) {
    state->lease_until_ms = sample->monotonic_ms + state->lease_duration_ms;
  }
  const int lease_active =
      state->lease_until_ms > 0 &&
      sample->monotonic_ms <= state->lease_until_ms;
  state->mode = sample->input_active || lease_active
                    ? TIMEARC_FOREGROUND_ACTIVE
                    : TIMEARC_FOREGROUND_IDLE;
}

void timearc_foreground_state_init(TimeArcForegroundState* state,
                                   uint64_t lease_duration_ms) {
  if (state == NULL) {
    return;
  }
  memset(state, 0, sizeof(*state));
  state->mode = TIMEARC_FOREGROUND_CLOSED;
  state->lease_duration_ms = lease_duration_ms;
}

int timearc_foreground_state_step(
    TimeArcForegroundState* state, const TimeArcForegroundSample* sample,
    TimeArcForegroundClosedSession* out_closed) {
  if (state == NULL || sample == NULL) {
    return 0;
  }

  if (state->mode == TIMEARC_FOREGROUND_CLOSED) {
    if (sample->has_app) {
      start_session(state, sample);
    }
    return 0;
  }

  advance(state, sample->wall_sec, sample->monotonic_ms);
  if (sample->has_app &&
      !timearc_app_identity_equal(&state->app, &sample->app)) {
    export_closed(state, out_closed);
    start_session(state, sample);
    return 1;
  }

  if (sample->has_app) {
    state->app = sample->app;
  }
  update_mode(state, sample);
  return 0;
}

int timearc_foreground_state_shutdown(
    TimeArcForegroundState* state, int64_t wall_sec, uint64_t monotonic_ms,
    TimeArcForegroundClosedSession* out_closed) {
  if (state == NULL || state->mode == TIMEARC_FOREGROUND_CLOSED) {
    return 0;
  }
  advance(state, wall_sec, monotonic_ms);
  export_closed(state, out_closed);
  const uint64_t lease_duration_ms = state->lease_duration_ms;
  memset(state, 0, sizeof(*state));
  state->mode = TIMEARC_FOREGROUND_CLOSED;
  state->lease_duration_ms = lease_duration_ms;
  return 1;
}
