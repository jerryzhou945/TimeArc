#ifndef TIMEARC_SRC_SERVICE_WINDOWS_SERVICE_CONFIG_H
#define TIMEARC_SRC_SERVICE_WINDOWS_SERVICE_CONFIG_H

#include <stdint.h>

// Read idle_threshold_ms and track_enabled from usage_config.json. Missing or
// invalid values leave the caller-provided defaults unchanged.
int timearc_read_service_config(int64_t* idle_threshold_ms, int* track_enabled);

#endif  // TIMEARC_SRC_SERVICE_WINDOWS_SERVICE_CONFIG_H
