#ifndef TIMEARC_USAGE_TRACKER_H
#define TIMEARC_USAGE_TRACKER_H

#include <stdint.h>

#define TIMEARC_USAGE_POLL_INTERVAL_MS 1000
#define TIMEARC_USAGE_IDLE_THRESHOLD_MS 60000

// 进程协同用的具名内核对象名（每会话一份，`Local\` 命名空间）。集中定义，让
// tracker（创建/等待）、main.c（单实例 mutex）、win_service.c（--stop / --status）
// 共用同一字面量，避免散落硬编码漂移。均为进程内同步原语、非数据 IPC（守 I1）。
//
// - INSTANCE_MUTEX: 单实例守卫；持有者＝当前会话里正在运行的 tracker。
// - STOP_EVENT: 优雅停采集通道；独立的 `--stop` 进程置位它请求主循环收尾 flush。
#define TIMEARC_INSTANCE_MUTEX_NAME "Local\\TimeArcUsageService"
#define TIMEARC_STOP_EVENT_NAME "Local\\TimeArcStop"

typedef struct TimeArcUsageTrackerConfig {
  // 前台窗口和空闲状态的采样频率。间隔越短越实时，但系统调用更频繁。
  int64_t poll_interval_ms;

  // 键鼠无输入超过该阈值后，关闭当前 foreground session。
  int64_t idle_threshold_ms;

  // H5「真停采集」：0＝追踪关闭，主循环不进采集（不写历史/live/音频）；1＝正常采集。
  // 由 main.c 从 usage_config.json 的 track_enabled 填入；缺省须为 1（向后兼容）。
  // 注意：初始化时必须**显式**给它 1（现用具名初始化器 `.track_enabled = 1`）——
  // 省略字段会被零初始化成 0，等于静默关闭采集，破坏既有行为。
  int track_enabled;
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
