#ifndef TIMEARC_AUDIO_TRACKER_H
#define TIMEARC_AUDIO_TRACKER_H

#include <stdint.h>

#include "app_info.h"

#define TIMEARC_AUDIO_MAX_TRACKED_APPS 64
// Audio sessions represent processes with audible output, not foreground windows.

typedef struct TimeArcAudioSession {
  AppInfo app;
  int active;
  int seen_this_poll;
  int64_t start_sec;
} TimeArcAudioSession;

typedef struct TimeArcAudioTrackerState {
  TimeArcAudioSession sessions[TIMEARC_AUDIO_MAX_TRACKED_APPS];
  int last_sample_succeeded;
  int64_t checkpoint_sec;
} TimeArcAudioTrackerState;

void timearc_audio_tracker_init(TimeArcAudioTrackerState* state,
                                int64_t checkpoint_sec);
void timearc_audio_tracker_poll(TimeArcAudioTrackerState* state,
                                int64_t now_sec);
void timearc_audio_tracker_flush(TimeArcAudioTrackerState* state,
                                 int64_t now_sec);
int timearc_audio_tracker_has_foreground(
    const TimeArcAudioTrackerState* state, const AppInfo* foreground);
void timearc_audio_tracker_shutdown(void);

#endif  // TIMEARC_AUDIO_TRACKER_H
