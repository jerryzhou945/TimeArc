#ifndef TIMEARC_AUDIO_TRACKER_H
#define TIMEARC_AUDIO_TRACKER_H

#include <stdint.h>

#include "app_info.h"

#define TIMEARC_AUDIO_MAX_TRACKED_APPS 64
#define TIMEARC_AUDIO_SILENCE_GRACE_SEC 3
// Audio sessions are periodically checkpointed into JSONL so long-running
// music/video calls become visible without waiting for playback to stop.
#define TIMEARC_AUDIO_FLUSH_INTERVAL_SEC 15

typedef struct TimeArcAudioSession {
  AppInfo app;
  int active;
  int seen_this_poll;
  int64_t start_sec;
  int64_t last_seen_sec;
} TimeArcAudioSession;

typedef struct TimeArcAudioTrackerState {
  TimeArcAudioSession sessions[TIMEARC_AUDIO_MAX_TRACKED_APPS];
} TimeArcAudioTrackerState;

void timearc_audio_tracker_init(TimeArcAudioTrackerState* state);
void timearc_audio_tracker_poll(TimeArcAudioTrackerState* state,
                                int64_t now_sec);
void timearc_audio_tracker_flush(TimeArcAudioTrackerState* state,
                                 int64_t now_sec);
void timearc_audio_tracker_shutdown(void);

#endif  // TIMEARC_AUDIO_TRACKER_H
