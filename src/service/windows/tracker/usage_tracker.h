#ifndef TIMEARC_USAGE_TRACKER_H
#define TIMEARC_USAGE_TRACKER_H

#include <stdint.h>

#define TIMEARC_USAGE_POLL_INTERVAL_MS 1000
#define TIMEARC_USAGE_IDLE_THRESHOLD_MS 60000

typedef struct TimeArcUsageTrackerConfig {
  // 前台窗口和空闲状态的采样频率。间隔越短越实时，但系统调用更频繁。
  int64_t poll_interval_ms;

  // 键鼠无输入超过该阈值后，关闭当前 foreground session。
  int64_t idle_threshold_ms;
} TimeArcUsageTrackerConfig;

// 前台使用采集主循环。
//
// 每轮采样：先更新音频 tracker，再检查键鼠空闲，然后读取前台窗口。
// 当前台 exe 或窗口标题变化时，关闭上一段并开启新段。
// Run the foreground-app tracker loop. This call blocks until stop is requested
// and persists a record whenever focus changes or the user becomes idle.
int timearc_usage_tracker_run(const TimeArcUsageTrackerConfig *config);
void timearc_usage_tracker_request_stop(void);

#endif
