#ifndef TIMEARC_USAGE_TRACKER_H
#define TIMEARC_USAGE_TRACKER_H

#include <stdint.h>

#define TIMEARC_USAGE_POLL_INTERVAL_MS 1000
#define TIMEARC_USAGE_IDLE_THRESHOLD_MS 60000
#define TIMEARC_USAGE_WORK_LEASE_MS 90000

// Per-session Local\ kernel object names shared by the tracker and lifecycle verbs.
//
// INSTANCE_MUTEX guards a single tracker; STOP_EVENT requests a clean flush.
#define TIMEARC_INSTANCE_MUTEX_NAME "Local\\TimeArcUsageService"
#define TIMEARC_STOP_EVENT_NAME "Local\\TimeArcStop"

typedef struct TimeArcUsageTrackerConfig {
  // Foreground and idle sampling interval.
  int64_t poll_interval_ms;

  // Keyboard and mouse idle threshold for foreground tracking.
  int64_t idle_threshold_ms;

  // Zero disables all collection; one enables it.
  // Initialize explicitly to one because omitted fields are zero-initialized.
  int track_enabled;
} TimeArcUsageTrackerConfig;

// Foreground collection loop.
//
// Each sample combines input idle, foreground identity, foreground process-tree
// work, and audio presence. Idle pauses active time without closing the logical
// session. This call blocks until stop is requested.
int timearc_usage_tracker_run(const TimeArcUsageTrackerConfig *config);
void timearc_usage_tracker_request_stop(void);

#endif
