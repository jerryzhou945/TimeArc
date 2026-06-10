#ifndef TIMEARC_USAGE_STORAGE_H
#define TIMEARC_USAGE_STORAGE_H

#include "storage_context.h"
#include "usage_record.h"

// Windows 采集端的落盘层。
//
// tracker 只负责决定“这一段从什么时候到什么时候”；这里负责把标准化后的
// TimeArcUsageRecord 写成 JSONL 历史记录，或覆盖 usage_current.json 实时快照。
// Initialize a storage context with the requested backends. JSONL and SQLite
// are BOTH fully implemented and enabled together in production via
// timearc_storage_init_global() -> timearc_storage_init(&g, 1, 1). The flags
// stay so a build can opt one backend out; they are not stubs.
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

TimeArcStorageContext* timearc_storage_global_context(void);

// C data bridge 使用的便捷包装。多数 tracker 调用 data_bridge.h，不直接碰
// TimeArcStorageContext。
// Convenience wrappers used by the C data bridge API.
int timearc_storage_init_global(void);
void timearc_storage_shutdown_global(void);

#endif
