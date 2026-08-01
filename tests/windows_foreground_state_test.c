#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "foreground_state.h"
#include "idle_win.h"

static AppInfo app(const char* path, uint32_t pid, const char* title) {
  AppInfo value;
  memset(&value, 0, sizeof(value));
  snprintf(value.exec_path, sizeof(value.exec_path), "%s", path);
  snprintf(value.app_name, sizeof(value.app_name), "%s", path);
  snprintf(value.window_title, sizeof(value.window_title), "%s", title);
  value.process_id = pid;
  return value;
}

static TimeArcForegroundSample sample(AppInfo value, int64_t wall_sec,
                                      uint64_t monotonic_ms, int input_active,
                                      int autonomous_active) {
  TimeArcForegroundSample result;
  memset(&result, 0, sizeof(result));
  result.app = value;
  result.has_app = 1;
  result.wall_sec = wall_sec;
  result.monotonic_ms = monotonic_ms;
  result.input_active = input_active;
  result.autonomous_active = autonomous_active;
  return result;
}

static int step(TimeArcForegroundState* state, AppInfo value,
                int64_t wall_sec, uint64_t monotonic_ms, int input_active,
                int autonomous_active,
                TimeArcForegroundClosedSession* closed) {
  TimeArcForegroundSample value_sample =
      sample(value, wall_sec, monotonic_ms, input_active, autonomous_active);
  return timearc_foreground_state_step(state, &value_sample, closed);
}

static void test_idle_tick_wrap(void) {
  assert(timearc_win_idle_delta_ms(25u, UINT32_MAX - 24u) == 50u);
  assert(timearc_win_idle_delta_ms(500u, 125u) == 375u);
}

static void test_lease_expires_and_resume_keeps_one_session(void) {
  TimeArcForegroundState state;
  TimeArcForegroundClosedSession closed;
  AppInfo codex = app("codex.exe", 41, "Task");

  timearc_foreground_state_init(&state, 90000);
  assert(!step(&state, codex, 1000, 0, 1, 0, &closed));
  assert(!step(&state, codex, 1001, 1000, 0, 1, &closed));
  assert(state.mode == TIMEARC_FOREGROUND_ACTIVE);

  assert(!step(&state, codex, 1092, 92000, 0, 0, &closed));
  assert(state.mode == TIMEARC_FOREGROUND_IDLE);
  assert(state.active_ms == 92000);

  assert(!step(&state, codex, 1093, 93000, 1, 0, &closed));
  assert(state.mode == TIMEARC_FOREGROUND_ACTIVE);
  assert(state.active_ms == 92000);
  assert(state.start_wall_sec == 1000);
}

static void test_media_or_process_evidence_renews_lease(void) {
  TimeArcForegroundState state;
  TimeArcForegroundClosedSession closed;
  AppInfo player = app("player.exe", 42, "Movie");

  timearc_foreground_state_init(&state, 90000);
  assert(!step(&state, player, 2000, 0, 0, 1, &closed));
  assert(state.mode == TIMEARC_FOREGROUND_ACTIVE);
  assert(!step(&state, player, 2089, 89000, 0, 0, &closed));
  assert(state.mode == TIMEARC_FOREGROUND_ACTIVE);
  assert(!step(&state, player, 2090, 90001, 0, 0, &closed));
  assert(state.mode == TIMEARC_FOREGROUND_IDLE);
}

static void test_identity_change_closes_with_active_duration(void) {
  TimeArcForegroundState state;
  TimeArcForegroundClosedSession closed;
  AppInfo editor = app("editor.exe", 50, "One");
  AppInfo other_title = app("editor.exe", 50, "Two");

  timearc_foreground_state_init(&state, 90000);
  assert(!step(&state, editor, 3000, 0, 1, 0, &closed));
  assert(step(&state, other_title, 3005, 5000, 1, 0, &closed));
  assert(strcmp(closed.app.window_title, "One") == 0);
  assert(closed.start_wall_sec == 3000);
  assert(closed.end_wall_sec == 3005);
  assert(closed.active_ms == 5000);
}

static void test_missing_observation_cannot_renew_lease(void) {
  TimeArcForegroundState state;
  TimeArcForegroundClosedSession closed;
  AppInfo editor = app("editor.exe", 51, "Task");
  TimeArcForegroundSample missing;

  timearc_foreground_state_init(&state, 1000);
  assert(!step(&state, editor, 4000, 0, 1, 0, &closed));
  memset(&missing, 0, sizeof(missing));
  missing.wall_sec = 4002;
  missing.monotonic_ms = 2000;
  assert(!timearc_foreground_state_step(&state, &missing, &closed));
  assert(state.mode == TIMEARC_FOREGROUND_IDLE);
}

static void test_shutdown_flushes_idle_session_once(void) {
  TimeArcForegroundState state;
  TimeArcForegroundClosedSession closed;
  AppInfo editor = app("editor.exe", 52, "Task");

  timearc_foreground_state_init(&state, 1000);
  assert(!step(&state, editor, 5000, 0, 1, 0, &closed));
  assert(timearc_foreground_state_shutdown(&state, 5003, 3000, &closed));
  assert(closed.active_ms == 3000);
  assert(state.mode == TIMEARC_FOREGROUND_CLOSED);
  assert(!timearc_foreground_state_shutdown(&state, 5004, 4000, &closed));
}

int main(void) {
  test_idle_tick_wrap();
  test_lease_expires_and_resume_keeps_one_session();
  test_media_or_process_evidence_renews_lease();
  test_identity_change_closes_with_active_duration();
  test_missing_observation_cannot_renew_lease();
  test_shutdown_flushes_idle_session_once();
  puts("Windows foreground state tests passed");
  return 0;
}
