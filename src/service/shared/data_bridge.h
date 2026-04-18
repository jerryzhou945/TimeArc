// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

// DataBridge provides database-related functionalities.

#ifndef TIMEARC_SRC_SERVICE_SHARED_DATA_BRIDGE_H
#define TIMEARC_SRC_SERVICE_SHARED_DATA_BRIDGE_H

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

#if defined(__cplusplus)
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_DATA_BRIDGE_H
