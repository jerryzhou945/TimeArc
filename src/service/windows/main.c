#include "data_bridge.h"
#include "tracker/usage_tracker.h"

#include <stdio.h>

int main(void) {
  if (ta_storage_init() != 0) {
    fprintf(stderr, "failed to initialize TimeArc usage storage\n");
    return 1;
  }

  TimeArcUsageTrackerConfig config = {
      TIMEARC_USAGE_POLL_INTERVAL_MS,
      TIMEARC_USAGE_IDLE_THRESHOLD_MS,
  };

  int result = timearc_usage_tracker_run(&config);
  ta_storage_shutdown();
  return result;
}
