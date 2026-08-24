#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "app_identity.h"
#include "foreground_state.h"
#include "idle_win.h"
#include "process_activity_win.h"

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

static void test_normalized_identity_includes_pid_and_title(void) {
  AppInfo left = app("player.exe", 70, "Song A");
  AppInfo right = app("player.exe", 70, "Song A");

  assert(timearc_app_identity_equal(&left, &right));
  right.process_id = 71;
  assert(!timearc_app_identity_equal(&left, &right));
  right = left;
  snprintf(right.window_title, sizeof(right.window_title), "%s", "Song B");
  assert(!timearc_app_identity_equal(&left, &right));
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

static void test_checkpoint_exports_contiguous_active_segment(void) {
  TimeArcForegroundState state;
  TimeArcForegroundClosedSession closed;
  AppInfo codex = app("codex.exe", 53, "Autonomous task");

  timearc_foreground_state_init(&state, 90000);
  assert(!step(&state, codex, 6000, 0, 0, 1, &closed));
  assert(!step(&state, codex, 6060, 60000, 0, 1, &closed));
  assert(timearc_foreground_state_checkpoint(&state, 6060, 60000, &closed));
  assert(closed.start_wall_sec == 6000);
  assert(closed.end_wall_sec == 6060);
  assert(closed.active_ms == 60000);
  assert(state.start_wall_sec == 6060);
  assert(state.active_ms == 0);
  assert(state.mode == TIMEARC_FOREGROUND_ACTIVE);
  assert(strcmp(state.app.window_title, "Autonomous task") == 0);

  assert(!step(&state, codex, 6061, 61000, 0, 0, &closed));
  assert(state.active_ms == 1000);
  assert(state.mode == TIMEARC_FOREGROUND_ACTIVE);
}

static void test_checkpoint_preserves_idle_mode_without_active_growth(void) {
  TimeArcForegroundState state;
  TimeArcForegroundClosedSession closed;
  AppInfo editor = app("editor.exe", 54, "Idle document");

  timearc_foreground_state_init(&state, 1000);
  assert(!step(&state, editor, 7000, 0, 1, 0, &closed));
  assert(!step(&state, editor, 7002, 2000, 0, 0, &closed));
  assert(state.mode == TIMEARC_FOREGROUND_IDLE);
  assert(timearc_foreground_state_checkpoint(&state, 7060, 60000, &closed));
  assert(closed.active_ms == 2000);
  assert(state.mode == TIMEARC_FOREGROUND_IDLE);
  assert(state.start_wall_sec == 7060);
  assert(state.active_ms == 0);
}

static TimeArcProcessCounters counters(uint64_t cpu_100ns,
                                       uint64_t io_bytes) {
  TimeArcProcessCounters value;
  value.cpu_100ns = cpu_100ns;
  value.io_bytes = io_bytes;
  value.available = 1;
  return value;
}

static void test_process_delta_requires_meaningful_change(void) {
  TimeArcProcessActivityProbe probe;
  TimeArcProcessCounters value;

  timearc_process_activity_init(&probe);
  value = counters(100, 1000);
  assert(!timearc_process_activity_delta(&probe, 41, &value));
  assert(!timearc_process_activity_delta(&probe, 41, &value));
  value = counters(50100, 1000);
  assert(timearc_process_activity_delta(&probe, 41, &value));
  value = counters(50100, 5096);
  assert(timearc_process_activity_delta(&probe, 41, &value));
}

static void test_process_delta_resets_for_pid_or_counter_reset(void) {
  TimeArcProcessActivityProbe probe;
  TimeArcProcessCounters value;

  timearc_process_activity_init(&probe);
  value = counters(90000, 9000);
  assert(!timearc_process_activity_delta(&probe, 41, &value));
  value = counters(1, 1);
  assert(!timearc_process_activity_delta(&probe, 42, &value));
  value = counters(0, 0);
  assert(!timearc_process_activity_delta(&probe, 42, &value));
}

static void test_process_tree_aggregates_only_root_and_descendants(void) {
  const TimeArcProcessEntry entries[] = {
      {10, 1, 100, 1000, 1},
      {11, 10, 200, 2000, 1},
      {12, 11, 300, 3000, 1},
      {99, 1, 900, 9000, 1},
      {13, 10, 400, 4000, 0},
  };
  TimeArcProcessCounters total;

  assert(timearc_process_activity_aggregate(entries, 5, 10, &total));
  assert(total.available);
  assert(total.cpu_100ns == 600);
  assert(total.io_bytes == 6000);
}

static void test_process_tree_aggregates_foreground_and_related_worker_once(void) {
  const TimeArcProcessEntry entries[] = {
      {10, 1, 100, 1000, 1},   // Desktop app family root.
      {11, 10, 200, 2000, 1},  // Foreground ChatGPT branch.
      {12, 11, 300, 3000, 1},  // Foreground renderer.
      {20, 10, 400, 4000, 1},  // Related Codex backend.
      {21, 20, 500, 5000, 1},  // Active command worker.
      {30, 10, 900, 9000, 1},  // Unrelated sibling branch.
  };
  const uint32_t roots[] = {11, 20};
  TimeArcProcessCounters total;

  assert(timearc_process_activity_aggregate_roots(
      entries, 6, roots, 2, &total));
  assert(total.available);
  assert(total.cpu_100ns == 1400);
  assert(total.io_bytes == 14000);
}

static void test_codex_root_requires_same_packaged_process_family(void) {
  const TimeArcProcessEntry entries[] = {
      {10, 1, 0, 0, 1, L"ChatGPT.exe"},
      {11, 10, 0, 0, 1, L"ChatGPT.exe"},
      {12, 11, 0, 0, 1, L"ChatGPT.exe"},
      {20, 10, 0, 0, 1, L"codex.exe"},
      {21, 20, 0, 0, 1, L"pwsh.exe"},
      {90, 1, 0, 0, 1, L"other.exe"},
      {91, 90, 0, 0, 1, L"codex.exe"},
  };
  const char* packaged_path =
      "C:\\Program Files\\WindowsApps\\OpenAI.Codex_26.814.5517.0_x64__"
      "2p2nqsd0c76g0\\app\\ChatGPT.exe";

  assert(timearc_process_activity_find_codex_root(
             entries, 7, 12, packaged_path) == 20);
  assert(timearc_process_activity_find_codex_root(
             entries, 7, 12,
             "d:\\windowsapps\\openai.codex_26.814.5517.0_x64__"
             "2p2nqsd0c76g0\\app\\chatgpt.exe") == 20);
  assert(timearc_process_activity_find_codex_root(
             entries, 7, 12, "C:\\Apps\\ChatGPT.exe") == 0);
  assert(timearc_process_activity_find_codex_root(
             entries, 7, 90, packaged_path) == 0);
}

static void test_codex_collects_every_backend_in_the_packaged_family(void) {
  const TimeArcProcessEntry entries[] = {
      {10, 1, 0, 0, 1, L"ChatGPT.exe"},
      {11, 10, 0, 0, 1, L"ChatGPT.exe"},
      {20, 10, 0, 0, 1, L"codex.exe"},
      {21, 20, 0, 0, 1, L"pwsh.exe"},
      {30, 10, 0, 0, 1, L"codex.exe"},
      {31, 30, 0, 0, 1, L"cmd.exe"},
      {90, 1, 0, 0, 1, L"codex.exe"},
  };
  uint32_t roots[3] = {0, 0, 0};
  const char* packaged_path =
      "C:\\Program Files\\WindowsApps\\OpenAI.Codex_26.814.5517.0_x64__"
      "2p2nqsd0c76g0\\app\\ChatGPT.exe";

  assert(timearc_process_activity_find_codex_roots(
             entries, 7, 11, packaged_path, roots, 3) == 2);
  assert(roots[0] == 20);
  assert(roots[1] == 30);
  assert(roots[2] == 0);
}

static void test_current_codex_worker_topology_is_aggregated(void) {
  const TimeArcProcessEntry entries[] = {
      {10, 1, 10, 100, 1, L"ChatGPT.exe"},
      {11, 10, 20, 200, 1, L"ChatGPT.exe"},
      {20, 10, 100, 1000, 1, L"codex.exe"},
      {21, 20, 200, 2000, 1, L"codex-code-mode-host.exe"},
      {22, 21, 300, 3000, 1,
       L"codex-command-runner-0.149.0-alpha.4.1.exe"},
      {23, 22, 400, 4000, 1, L"pwsh.exe"},
      {90, 1, 900, 9000, 1, L"unrelated.exe"},
  };
  uint32_t roots[2] = {0, 0};
  const char* packaged_path =
      "C:\\Program Files\\WindowsApps\\OpenAI.Codex_26.818.5229.0_x64__"
      "2p2nqsd0c76g0\\app\\ChatGPT.exe";

  const size_t root_count = timearc_process_activity_find_codex_roots(
      entries, 7, 11, packaged_path, roots, 2);
  assert(root_count == 1);
  assert(roots[0] == 20);

  TimeArcProcessCounters total;
  assert(timearc_process_activity_aggregate_roots(
      entries, 7, roots, root_count, &total));
  assert(total.cpu_100ns == 1000);
  assert(total.io_bytes == 10000);

  TimeArcProcessActivityProbe probe;
  timearc_process_activity_init(&probe);
  assert(!timearc_process_activity_delta(&probe, roots[0], &total));
  total.cpu_100ns += TIMEARC_PROCESS_CPU_ACTIVE_100NS;
  assert(timearc_process_activity_delta(&probe, roots[0], &total));
}

int main(void) {
  test_idle_tick_wrap();
  test_normalized_identity_includes_pid_and_title();
  test_lease_expires_and_resume_keeps_one_session();
  test_media_or_process_evidence_renews_lease();
  test_identity_change_closes_with_active_duration();
  test_missing_observation_cannot_renew_lease();
  test_shutdown_flushes_idle_session_once();
  test_checkpoint_exports_contiguous_active_segment();
  test_checkpoint_preserves_idle_mode_without_active_growth();
  test_process_delta_requires_meaningful_change();
  test_process_delta_resets_for_pid_or_counter_reset();
  test_process_tree_aggregates_only_root_and_descendants();
  test_process_tree_aggregates_foreground_and_related_worker_once();
  test_codex_root_requires_same_packaged_process_family();
  test_codex_collects_every_backend_in_the_packaged_family();
  test_current_codex_worker_topology_is_aggregated();
  puts("Windows foreground state tests passed");
  return 0;
}
