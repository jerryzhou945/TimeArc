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
//    A v1 file that parses decides on its own — it is never key-merged with
//    the legacy file, so omitting the key means "use the default".
// 2. Only when no v1 file is present or it does not parse: the legacy
//    `usage_config.json` `db_dir`, same filename appended. Read-only fallback
//    for the one-release overlap; nothing writes that file.
// 3. The platform default service-data directory, with the same filename.
//
// Returns 0 on success and -1 when arguments are invalid, a path does not fit,
// or a required directory cannot be created.
int get_database_path(char* out_path, size_t out_path_size);

#ifdef __cplusplus
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_DATABASE_PATH_H
