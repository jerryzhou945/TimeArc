#ifndef TIMEARC_SRC_SERVICE_SHARED_USAGE_PATHS_H
#define TIMEARC_SRC_SERVICE_SHARED_USAGE_PATHS_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

int timearc_get_usage_data_dir(char* out_path, size_t out_path_size);
int timearc_get_usage_jsonl_path(char* out_path, size_t out_path_size);
int timearc_get_usage_current_path(char* out_path, size_t out_path_size);

#ifdef __cplusplus
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_USAGE_PATHS_H
