// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jerry Zhou
// Copyright (C) 2026 Jeff Zhang

#ifndef TIMEARC_SRC_SERVICE_SHARED_DATABASE_PATH_H
#define TIMEARC_SRC_SERVICE_SHARED_DATABASE_PATH_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

// Resolve the service-owned SQLite database path.
//
// Resolution order:
// 1. `usage_config.json` `db_dir`, with `timearc_service.db` appended.
// 2. The platform default service-data directory, with the same filename.
//
// Returns 0 on success and -1 when arguments are invalid, a path does not fit,
// or a required directory cannot be created.
int get_database_path(char* out_path, size_t out_path_size);

#ifdef __cplusplus
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_DATABASE_PATH_H
