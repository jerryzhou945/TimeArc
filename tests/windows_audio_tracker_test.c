#ifdef NDEBUG
#undef NDEBUG
#endif

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "audio_tracker.h"

static AppInfo g_observed[2];
static size_t g_observed_count = 0;
static int g_media_writes = 0;
static int64_t g_media_start[4];
static int64_t g_media_end[4];

static AppInfo audio_app(const char* title) {
  AppInfo value;
  memset(&value, 0, sizeof(value));
  value.process_id = 80;
  snprintf(value.exec_path, sizeof(value.exec_path), "%s", "chrome.exe");
  snprintf(value.app_name, sizeof(value.app_name), "%s", "chrome.exe");
  snprintf(value.window_title, sizeof(value.window_title), "%s", title);
  return value;
}

int timearc_win_get_audio_apps(AppInfo* out_apps, size_t max_apps,
                               size_t* out_count) {
  const size_t count = g_observed_count < max_apps ? g_observed_count : max_apps;
  for (size_t i = 0; i < count; ++i) out_apps[i] = g_observed[i];
  *out_count = count;
  return 0;
}

void timearc_win_audio_shutdown(void) {}

int update_apps(const char* app_id, const char* platform,
                const char* display_name, const char* icon_path,
                const char* executable_path, int64_t updated_at) {
  (void)app_id;
  (void)platform;
  (void)display_name;
  (void)icon_path;
  (void)executable_path;
  (void)updated_at;
  return 0;
}

int update_media(const char* app_id, const char* media_type,
                 const char* media_title, int64_t start_unix_sec,
                 int64_t end_unix_sec) {
  (void)app_id;
  (void)media_type;
  (void)media_title;
  g_media_start[g_media_writes] = start_unix_sec;
  g_media_end[g_media_writes] = end_unix_sec;
  ++g_media_writes;
  return 0;
}

static void test_open_audio_checkpoints_and_continues_from_boundary(void) {
  TimeArcAudioTrackerState state;
  g_observed[0] = audio_app("Video_bilibili");
  g_observed_count = 1;
  g_media_writes = 0;

  timearc_audio_tracker_init(&state, 60);
  timearc_audio_tracker_poll(&state, 1000);
  timearc_audio_tracker_poll(&state, 1059);
  assert(g_media_writes == 0);
  timearc_audio_tracker_poll(&state, 1060);
  assert(g_media_writes == 1);
  assert(g_media_start[0] == 1000);
  assert(g_media_end[0] == 1060);
  assert(state.sessions[0].active);
  assert(state.sessions[0].start_sec == 1060);

  g_observed_count = 0;
  timearc_audio_tracker_poll(&state, 1070);
  assert(g_media_writes == 2);
  assert(g_media_start[1] == 1060);
  assert(g_media_end[1] == 1070);
}

int main(void) {
  test_open_audio_checkpoints_and_continues_from_boundary();
  puts("Windows audio tracker tests passed");
  return 0;
}
