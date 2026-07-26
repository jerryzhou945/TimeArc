#ifndef TIMEARC_AUDIO_WIN_H
#define TIMEARC_AUDIO_WIN_H

#include <stddef.h>

#include "app_info.h"

// Windows audio-session sampling.
//
// Convert audible WASAPI process sessions into AppInfo samples for the tracker.
#define TIMEARC_AUDIO_MAX_APPS 64

// Enumerates per-process render sessions that Windows currently reports as
// active audio sessions. Results are deduplicated by executable path.
int timearc_win_get_audio_apps(AppInfo* out_apps,
                               size_t max_apps,
                               size_t* out_count);

void timearc_win_audio_shutdown(void);

#endif  // TIMEARC_AUDIO_WIN_H
