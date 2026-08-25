#ifdef NDEBUG
#undef NDEBUG
#endif

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "audio_win.h"

#ifndef TIMEARC_AUDIO_SESSION_POLICY_DECLARED
typedef enum TimeArcWinPlaybackState {
  TIMEARC_WIN_PLAYBACK_UNKNOWN = 0,
  TIMEARC_WIN_PLAYBACK_PLAYING = 1,
  TIMEARC_WIN_PLAYBACK_NOT_PLAYING = 2,
} TimeArcWinPlaybackState;

int timearc_win_should_record_audio_session(
    const char* path, int session_active, int muted, float volume, float peak,
    TimeArcWinPlaybackState playback_state);
#endif

TimeArcWinPlaybackState timearc_win_parse_playback_status(
    const char* playback_status);
void timearc_win_observe_browser_site_hint(const char* path,
                                           const char* window_title);
void timearc_win_observe_browser_site_hint_at(const char* path,
                                              const char* window_title,
                                              int64_t now_sec);
const char* timearc_win_preferred_observed_media_title_at(
    const char* path, uint32_t process_id, const char* system_media_title,
    const char* matching_foreground_title, int64_t now_sec);

static void test_playback_status_parser_is_conservative(void) {
  assert(timearc_win_parse_playback_status("Playing") ==
         TIMEARC_WIN_PLAYBACK_PLAYING);
  assert(timearc_win_parse_playback_status("playing") ==
         TIMEARC_WIN_PLAYBACK_PLAYING);
  assert(timearc_win_parse_playback_status("Paused") ==
         TIMEARC_WIN_PLAYBACK_NOT_PLAYING);
  assert(timearc_win_parse_playback_status("Stopped") ==
         TIMEARC_WIN_PLAYBACK_NOT_PLAYING);
  assert(timearc_win_parse_playback_status("Closed") ==
         TIMEARC_WIN_PLAYBACK_NOT_PLAYING);
  assert(timearc_win_parse_playback_status("") ==
         TIMEARC_WIN_PLAYBACK_UNKNOWN);
  assert(timearc_win_parse_playback_status("Changing") ==
         TIMEARC_WIN_PLAYBACK_UNKNOWN);
  assert(timearc_win_parse_playback_status(NULL) ==
         TIMEARC_WIN_PLAYBACK_UNKNOWN);
}

static void test_playing_session_wins_when_browser_has_multiple_media_tabs(void) {
  assert(timearc_win_merge_playback_state(
             TIMEARC_WIN_PLAYBACK_UNKNOWN,
             TIMEARC_WIN_PLAYBACK_NOT_PLAYING) ==
         TIMEARC_WIN_PLAYBACK_NOT_PLAYING);
  assert(timearc_win_merge_playback_state(
             TIMEARC_WIN_PLAYBACK_NOT_PLAYING,
             TIMEARC_WIN_PLAYBACK_PLAYING) ==
         TIMEARC_WIN_PLAYBACK_PLAYING);
  assert(timearc_win_merge_playback_state(
             TIMEARC_WIN_PLAYBACK_PLAYING,
             TIMEARC_WIN_PLAYBACK_NOT_PLAYING) ==
         TIMEARC_WIN_PLAYBACK_PLAYING);
}

static void test_media_activity_policy_uses_the_right_evidence(void) {
  const char* chrome =
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
  const char* discord =
      "C:\\Users\\Tester\\AppData\\Local\\Discord\\Discord.exe";

  assert(timearc_win_should_record_audio_session(
      chrome, 1, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_PLAYING));
  assert(timearc_win_should_record_audio_session(
      chrome, 0, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_PLAYING));
  assert(!timearc_win_should_record_audio_session(
      chrome, 1, 0, 1.0f, 0.7f, TIMEARC_WIN_PLAYBACK_NOT_PLAYING));
  assert(timearc_win_should_record_audio_session(
      chrome, 1, 0, 1.0f, 0.01f, TIMEARC_WIN_PLAYBACK_UNKNOWN));
  assert(!timearc_win_should_record_audio_session(
      chrome, 1, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));

  assert(timearc_win_should_record_audio_session(
      discord, 1, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));
  assert(!timearc_win_should_record_audio_session(
      discord, 0, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));
  assert(!timearc_win_should_record_audio_session(
      discord, 1, 1, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));
  assert(!timearc_win_should_record_audio_session(
      discord, 1, 0, 0.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));

  assert(!timearc_win_should_record_audio_session(
      "C:\\Apps\\background.exe", 1, 0, 1.0f, 0.0f,
      TIMEARC_WIN_PLAYBACK_UNKNOWN));
  assert(timearc_win_should_record_audio_session(
      "C:\\Program Files (x86)\\Netease\\CloudMusic\\cloudmusic.exe", 1,
      0, 1.0f, 0.01f, TIMEARC_WIN_PLAYBACK_UNKNOWN));
}

static void test_chinese_voice_apps_follow_discord_session_policy(void) {
  const char* oopz =
      "C:\\Users\\Tester\\AppData\\Local\\Oopz\\Oopz.exe";
  const char* kook =
      "C:\\Users\\Tester\\AppData\\Local\\KOOK\\KOOK.exe";
  const char* legacy_kook =
      "C:\\Users\\Tester\\AppData\\Local\\KaiHeiLa\\KaiHeiLa.exe";

  assert(timearc_win_should_record_audio_session(
      oopz, 1, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));
  assert(timearc_win_should_record_audio_session(
      kook, 1, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));
  assert(timearc_win_should_record_audio_session(
      legacy_kook, 1, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));

  assert(!timearc_win_should_record_audio_session(
      oopz, 0, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));
  assert(!timearc_win_should_record_audio_session(
      kook, 1, 1, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));
  assert(!timearc_win_should_record_audio_session(
      "C:\\Apps\\ordinary-background.exe", 1, 0, 1.0f, 0.0f,
      TIMEARC_WIN_PLAYBACK_UNKNOWN));
}

static void test_browser_keeps_initial_site_identity_when_foreground_changes(void) {
  timearc_win_reset_observed_media_title_cache();
  const char* selected = timearc_win_preferred_observed_media_title(
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
      101,
      "Bilibili video title",
      "Bilibili video title_哔哩哔哩_bilibili - Google Chrome");
  assert(strcmp(selected,
                "Bilibili video title_哔哩哔哩_bilibili - Google Chrome") == 0);

  selected = timearc_win_preferred_observed_media_title(
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
      101,
      "Bilibili video title", "Unrelated documentation - Google Chrome");
  assert(strcmp(selected,
                "Bilibili video title_哔哩哔哩_bilibili - Google Chrome") == 0);
}

static void test_bilibili_navigation_hint_survives_marker_free_video_title(void) {
  const char* chrome =
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
  timearc_win_reset_observed_media_title_cache();
  timearc_win_observe_browser_site_hint(
      chrome, "Bilibili home_bilibili - Google Chrome");

  const char* selected = timearc_win_preferred_observed_media_title(
      chrome, 707, "Marker-free video title",
      "Marker-free video title - Google Chrome");
  assert(strstr(selected, "bilibili") != NULL);
}

static void test_bilibili_navigation_hint_survives_delayed_media_session(void) {
  const char* chrome =
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
  timearc_win_reset_observed_media_title_cache();
  timearc_win_observe_browser_site_hint_at(
      chrome, "Bilibili home_bilibili - Google Chrome", 1000);

  const char* selected = timearc_win_preferred_observed_media_title_at(
      chrome, 708, "Ten-minute video title",
      "Ten-minute video title - Google Chrome", 1150);
  assert(strstr(selected, "bilibili") != NULL);
}

static void test_music_app_keeps_richer_system_media_title(void) {
  timearc_win_reset_observed_media_title_cache();
  const char* selected = timearc_win_preferred_observed_media_title(
      "C:\\Apps\\cloudmusic.exe", 202, "Song - Artist", "网易云音乐");
  assert(strcmp(selected, "Song - Artist") == 0);
}

static void test_browser_without_matching_foreground_uses_system_title(void) {
  timearc_win_reset_observed_media_title_cache();
  const char* selected = timearc_win_preferred_observed_media_title(
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
      303, "Background video", NULL);
  assert(strcmp(selected, "Background video") == 0);
}

static void test_browser_without_system_title_uses_matching_foreground(void) {
  timearc_win_reset_observed_media_title_cache();
  const char* selected = timearc_win_preferred_observed_media_title(
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe", 404,
      NULL, "Video title_哔哩哔哩_bilibili - Google Chrome");
  assert(strcmp(selected,
                "Video title_哔哩哔哩_bilibili - Google Chrome") == 0);
}

static void test_browser_same_title_new_process_does_not_inherit_old_site(void) {
  timearc_win_reset_observed_media_title_cache();
  const char* selected = timearc_win_preferred_observed_media_title(
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe", 501,
      "Shared media title",
      "Shared media title_哔哩哔哩_bilibili - Google Chrome");
  assert(strstr(selected, "bilibili") != NULL);

  selected = timearc_win_preferred_observed_media_title(
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe", 502,
      "Shared media title", "Unrelated documentation - Google Chrome");
  assert(strcmp(selected, "Shared media title") == 0);
}

static void test_browser_correlated_new_context_replaces_cached_site(void) {
  timearc_win_reset_observed_media_title_cache();
  timearc_win_preferred_observed_media_title(
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe", 601,
      "Shared media title",
      "Shared media title_哔哩哔哩_bilibili - Google Chrome");

  const char* selected = timearc_win_preferred_observed_media_title(
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe", 601,
      "Shared media title", "Shared media title - YouTube - Google Chrome");
  assert(strcmp(selected, "Shared media title - YouTube - Google Chrome") == 0);
}

int main(void) {
  test_playback_status_parser_is_conservative();
  test_playing_session_wins_when_browser_has_multiple_media_tabs();
  test_media_activity_policy_uses_the_right_evidence();
  test_chinese_voice_apps_follow_discord_session_policy();
  test_browser_keeps_initial_site_identity_when_foreground_changes();
  test_bilibili_navigation_hint_survives_marker_free_video_title();
  test_bilibili_navigation_hint_survives_delayed_media_session();
  test_music_app_keeps_richer_system_media_title();
  test_browser_without_matching_foreground_uses_system_title();
  test_browser_without_system_title_uses_matching_foreground();
  test_browser_same_title_new_process_does_not_inherit_old_site();
  test_browser_correlated_new_context_replaces_cached_site();
  puts("Windows audio title policy tests passed");
  return 0;
}
