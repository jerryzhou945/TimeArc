#ifndef TIMEARC_SRC_SERVICE_SHARED_USAGE_PATHS_H
#define TIMEARC_SRC_SERVICE_SHARED_USAGE_PATHS_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

// 返回并创建 TimeArc 使用记录目录。
int timearc_get_usage_data_dir(char* out_path, size_t out_path_size);
// 返回历史 JSONL 文件路径：usage_records.jsonl。
int timearc_get_usage_jsonl_path(char* out_path, size_t out_path_size);
// 返回实时快照文件路径：usage_current.json。
int timearc_get_usage_current_path(char* out_path, size_t out_path_size);

#ifdef __cplusplus
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_USAGE_PATHS_H
