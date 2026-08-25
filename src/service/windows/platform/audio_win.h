#ifndef TIMEARC_AUDIO_WIN_H
#define TIMEARC_AUDIO_WIN_H

#include <stddef.h>

#include "app_info.h"

// Windows audio-session sampling.
//
// Convert audible WASAPI process sessions into AppInfo samples for the tracker.
#define TIMEARC_AUDIO_MAX_APPS 64

#define TIMEARC_AUDIO_SESSION_POLICY_DECLARED 1
typedef enum TimeArcWinPlaybackState {
  TIMEARC_WIN_PLAYBACK_UNKNOWN = 0,
  TIMEARC_WIN_PLAYBACK_PLAYING = 1,
  TIMEARC_WIN_PLAYBACK_NOT_PLAYING = 2,
} TimeArcWinPlaybackState;

// Decide whether one Windows render session represents effective use.
// Browser playback state is authoritative when known; supported voice-chat
// apps use their active/unmuted session even at zero peak; other apps retain
// audible-output gating.
int timearc_win_should_record_audio_session(
    const char* path, int session_active, int muted, float volume, float peak,
    TimeArcWinPlaybackState playback_state);
TimeArcWinPlaybackState timearc_win_parse_playback_status(
    const char* playback_status);
TimeArcWinPlaybackState timearc_win_merge_playback_state(
    TimeArcWinPlaybackState current, TimeArcWinPlaybackState candidate);

// Enumerates per-process render sessions that Windows currently reports as
// active audio sessions. Results are deduplicated by executable path.
int timearc_win_get_audio_apps(AppInfo* out_apps,
                               size_t max_apps,
                               size_t* out_count);

// Keep the stable GSMTC media identity whenever it is available. A correlated
// browser foreground title may enrich the identity with its site marker, then
// remains cached while unrelated tabs take focus so playback is not split.
const char* timearc_win_preferred_observed_media_title(
    const char* path, uint32_t process_id, const char* system_media_title,
    const char* matching_foreground_title);
const char* timearc_win_preferred_observed_media_title_at(
    const char* path, uint32_t process_id, const char* system_media_title,
    const char* matching_foreground_title, int64_t now_sec);
// Remember a short-lived explicit browser-site marker before navigation changes
// the window title to a marker-free media title (observed on Bilibili/Chrome).
void timearc_win_observe_browser_site_hint(const char* path,
                                           const char* window_title);
void timearc_win_observe_browser_site_hint_at(const char* path,
                                              const char* window_title,
                                              int64_t now_sec);
void timearc_win_reset_observed_media_title_cache(void);

void timearc_win_audio_shutdown(void);

#endif  // TIMEARC_AUDIO_WIN_H
