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
// Resolution order (CHARTER v0.13):
// 1. `service_config.json` `database.dir`, with `timearc_service.db` appended.
// 2. The platform default service-data directory, with the same filename.
//
// The retired `usage_config.json` `db_dir` is never read. An install that
// relocated its database under the old format must re-select the directory
// once, which rewrites the pointer in the current format.
//
// Returns 0 on success and -1 when arguments are invalid, a path does not fit,
// or a required directory cannot be created.
int get_database_path(char* out_path, size_t out_path_size);

#ifdef __cplusplus
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_DATABASE_PATH_H
