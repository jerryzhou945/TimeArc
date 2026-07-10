#ifndef TIMEARC_USAGE_STORAGE_H
#define TIMEARC_USAGE_STORAGE_H

#include <stdint.h>

#include "storage_context.h"
#include "usage_record.h"

// Windows 采集端的落盘层。
//
// tracker 只负责决定“这一段从什么时候到什么时候”；这里负责把标准化后的
// TimeArcUsageRecord 写成 JSONL 历史记录、写入 shared/database_storage.* 管理的
// SQLite 历史库，或覆盖 usage_current.json 实时快照。Initialize a storage
// context with the requested backends. JSONL and SQLite are both enabled
// together in production via timearc_storage_init_global() ->
// timearc_storage_init(&g, 1, 1). The flags stay so a build can opt one
// backend out; they are not stubs.
int timearc_storage_init(TimeArcStorageContext* context,
                         int use_jsonl,
                         int use_sqlite);
void timearc_storage_close(TimeArcStorageContext* context);

// Persist one normalized usage record through every enabled backend.
int timearc_storage_write_record(TimeArcStorageContext* context,
                                 const TimeArcUsageRecord* record);

// Overwrite the live checkpoint for the currently active in-memory session.
// This file is read by the Qt UI for realtime display and is not historical
// storage.
int timearc_storage_write_current_record(TimeArcStorageContext* context,
                                         const TimeArcUsageRecord* record,
                                         int64_t updated_unix_sec);
void timearc_storage_clear_current_record(TimeArcStorageContext* context);

int timearc_storage_init_sqlite(TimeArcStorageContext* context);
int timearc_storage_write_sqlite(TimeArcStorageContext* context,
                                 const TimeArcUsageRecord* record);

// H5 (UI→service config channel): read the service-behavior keys the UI writes
// into `<usageDir>/usage_config.json`. Fills *idle_threshold_ms (from the
// "idle_threshold_ms" number, clamped to a sane 1s–24h window) and/or
// *track_enabled (from the "track_enabled" bool) ONLY for keys that are present
// and well-typed; absent/invalid keys leave the out-param untouched so the
// caller's compile-time default survives (fail-safe — same backward-compat
// posture as the D2 db_dir reader). Either out-param may be NULL. Returns 0
// when the file parsed (even if a key was missing), -1 when absent/unreadable.
// Read-only: this never rewrites usage_config.json (the D2 db_dir key is shared
// with this file and must be preserved by whoever writes it).
int timearc_read_service_config(int64_t* idle_threshold_ms, int* track_enabled);

TimeArcStorageContext* timearc_storage_global_context(void);

// Convenience wrappers used by tracker code that does not directly manage a
// TimeArcStorageContext.
int timearc_storage_init_global(void);
void timearc_storage_shutdown_global(void);

#endif
