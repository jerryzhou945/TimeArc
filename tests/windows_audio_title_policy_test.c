#ifdef NDEBUG
#undef NDEBUG
#endif

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "audio_win.h"

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
  test_browser_keeps_initial_site_identity_when_foreground_changes();
  test_music_app_keeps_richer_system_media_title();
  test_browser_without_matching_foreground_uses_system_title();
  test_browser_without_system_title_uses_matching_foreground();
  test_browser_same_title_new_process_does_not_inherit_old_site();
  test_browser_correlated_new_context_replaces_cached_site();
  puts("Windows audio title policy tests passed");
  return 0;
}
