#ifndef TIMEARC_SRC_SERVICE_WINDOWS_SERVICE_CONFIG_H
#define TIMEARC_SRC_SERVICE_WINDOWS_SERVICE_CONFIG_H

#include <stdint.h>

// Read the Windows-supported tracking leaves from service_config.json v1.
// Missing, malformed, or invalid values leave caller-provided defaults
// unchanged. The idle value is converted from documented seconds to the
// tracker's millisecond boundary.
int timearc_read_service_config(int64_t* idle_threshold_ms, int* track_enabled);

#endif  // TIMEARC_SRC_SERVICE_WINDOWS_SERVICE_CONFIG_H
