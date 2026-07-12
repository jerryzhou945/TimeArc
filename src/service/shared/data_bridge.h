// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

// DataBridge provides database update APIs for the service layer.

#ifndef TIMEARC_SRC_SERVICE_SHARED_DATA_BRIDGE_H
#define TIMEARC_SRC_SERVICE_SHARED_DATA_BRIDGE_H

#include <stdint.h>

#if defined(__has_attribute)
#if __has_attribute(swift_name)
// TA_SWIFT_NAME - annotate a C function with a custom name to be used in Swift.
// Always follow the Swift naming conventions when specifying the name.
#define TA_SWIFT_NAME(name) __attribute__((swift_name(#name)))
#else
#define TA_SWIFT_NAME(name)
#endif  // __has_attribute(swift_name)
#endif  // defined(__has_attribute)

#if defined(__cplusplus)
extern "C" {
#endif

// update_apps - update the apps table.
int update_apps(const char* app_id, const char* platform, const char* display_name,
                const char* icon_path, const char* executable_path, int64_t updated_at)
    TA_SWIFT_NAME(updateApps(appId:platform:displayName:iconPath:executablePath:updatedAt:));

// update_frontmost - update the frontmost_sessions table.
int update_frontmost(const char* app_id, const char* window_title, int64_t start_unix_sec,
                     int64_t end_unix_sec, int64_t active_sec)
    TA_SWIFT_NAME(updateFrontmost(appId:windowTitle:startUnixSec:endUnixSec:activeSec:));

// update_media - update the media_sessions table.
int update_media(const char* app_id, const char* media_type, const char* media_title,
                 int64_t start_unix_sec, int64_t end_unix_sec)
    TA_SWIFT_NAME(updateMedia(appId:mediaType:mediaTitle:startUnixSec:endUnixSec:));

#if defined(__cplusplus)
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_DATA_BRIDGE_H
