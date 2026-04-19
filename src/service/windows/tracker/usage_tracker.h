#ifndef TIMEARC_USAGE_TRACKER_H
#define TIMEARC_USAGE_TRACKER_H

#include <stdint.h>

#define TIMEARC_USAGE_POLL_INTERVAL_MS 1000
#define TIMEARC_USAGE_IDLE_THRESHOLD_MS 60000

typedef struct TimeArcUsageTrackerConfig {
  // How often the foreground app and idle state are sampled.
  int64_t poll_interval_ms;

  // Input inactivity longer than this closes the current usage session.
  int64_t idle_threshold_ms;
} TimeArcUsageTrackerConfig;

// Run the foreground-app tracker loop. This call blocks until stop is requested
// and persists a record whenever focus changes or the user becomes idle.
int timearc_usage_tracker_run(const TimeArcUsageTrackerConfig *config);
void timearc_usage_tracker_request_stop(void);

#endif
