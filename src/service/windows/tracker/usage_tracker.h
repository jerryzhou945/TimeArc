#ifndef TIMEARC_USAGE_TRACKER_H
#define TIMEARC_USAGE_TRACKER_H

#include <stdint.h>

#define TIMEARC_USAGE_POLL_INTERVAL_MS 1000
#define TIMEARC_USAGE_IDLE_THRESHOLD_MS 60000

typedef struct TimeArcUsageTrackerConfig {
  int64_t poll_interval_ms;
  int64_t idle_threshold_ms;
} TimeArcUsageTrackerConfig;

int timearc_usage_tracker_run(const TimeArcUsageTrackerConfig *config);

#endif
