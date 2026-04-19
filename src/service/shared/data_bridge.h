// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

// DataBridge provides database-related functionalities.

#ifndef TIMEARC_SRC_SERVICE_SHARED_DATA_BRIDGE_H
#define TIMEARC_SRC_SERVICE_SHARED_DATA_BRIDGE_H

#include <stdint.h>

#if defined(__has_attribute)
#if __has_attribute(swift_name)
// TA_SWIFT_NAME - annotate a C function with a custom name to be used in Swift.
// Always follow the Swift naming conventions when specifying the name.
#define TA_SWIFT_NAME(name) __attribute__((swift_name(#name)))
#endif  // __has_attribute(swift_name)
#endif  // defined(__has_attribute)

#if defined(__cplusplus)
extern "C" {
#endif

int ta_storage_init(void);
void ta_storage_shutdown(void);

int ta_write_usage_record(
    const char* platform,
    const char* app_id,
    const char* app_name,
    const char* window_title,
    const char* path,
    int64_t start_unix_sec,
    uint64_t duration_sec);

int ta_write_usage_record_with_source(
    const char* platform,
    const char* source,
    const char* app_id,
    const char* app_name,
    const char* window_title,
    const char* path,
    int64_t start_unix_sec,
    uint64_t duration_sec);

int ta_write_current_usage(
    const char* platform,
    const char* app_id,
    const char* app_name,
    const char* window_title,
    const char* path,
    int64_t start_unix_sec,
    uint64_t duration_sec,
    int64_t updated_unix_sec);

int ta_write_current_usage_with_source(
    const char* platform,
    const char* source,
    const char* app_id,
    const char* app_name,
    const char* window_title,
    const char* path,
    int64_t start_unix_sec,
    uint64_t duration_sec,
    int64_t updated_unix_sec);

void ta_clear_current_usage(void);

#if defined(__cplusplus)
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_DATA_BRIDGE_H
