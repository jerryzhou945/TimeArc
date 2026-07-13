#ifndef TIMEARC_AUDIO_TRACKER_H
#define TIMEARC_AUDIO_TRACKER_H

#include <stdint.h>

#include "app_info.h"

#define TIMEARC_AUDIO_MAX_TRACKED_APPS 64
#define TIMEARC_AUDIO_SILENCE_GRACE_SEC 3
// 音频 session 不是前台窗口，而是“当前有可听声音的进程”。
//
// 长时间播放会按固定间隔切成多段写入数据库，这样 UI 不必等到播放停止才能看到
// 音频时长增长。短暂静音有 grace period，避免播放器瞬间掉峰值就切段。
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
