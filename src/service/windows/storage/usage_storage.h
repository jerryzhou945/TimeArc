#ifndef TIMEARC_USAGE_STORAGE_H
#define TIMEARC_USAGE_STORAGE_H

#include "storage_context.h"
#include "usage_record.h"

int timearc_storage_init(TimeArcStorageContext* context,
                         int use_jsonl,
                         int use_sqlite);
void timearc_storage_close(TimeArcStorageContext* context);

int timearc_storage_write_record(TimeArcStorageContext* context,
                                 const TimeArcUsageRecord* record);

int timearc_storage_init_sqlite(TimeArcStorageContext* context);
int timearc_storage_write_sqlite(TimeArcStorageContext* context,
                                 const TimeArcUsageRecord* record);

TimeArcStorageContext* timearc_storage_global_context(void);
int timearc_storage_init_global(void);
void timearc_storage_shutdown_global(void);

#endif
