#ifndef TIMEARC_USAGE_STORAGE_H
#define TIMEARC_USAGE_STORAGE_H

#include "storage_context.h"
#include "usage_record.h"

// Initialize a storage context with the requested backends. JSONL is currently
// implemented; SQLite is stubbed behind these flags for the future backend.
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

// Convenience wrappers used by the C data bridge API.
int timearc_storage_init_global(void);
void timearc_storage_shutdown_global(void);

#endif
