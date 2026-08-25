#ifndef TIMEARC_PROCESS_ACTIVITY_WIN_H
#define TIMEARC_PROCESS_ACTIVITY_WIN_H

#include <stddef.h>
#include <stdint.h>

#include "app_info.h"

#define TIMEARC_PROCESS_CPU_ACTIVE_100NS 50000ULL
#define TIMEARC_PROCESS_IO_ACTIVE_BYTES 4096ULL
#define TIMEARC_PROCESS_IMAGE_NAME_CHARS 260

typedef struct TimeArcProcessCounters {
  uint64_t cpu_100ns;
  uint64_t io_bytes;
  int available;
} TimeArcProcessCounters;

typedef struct TimeArcProcessEntry {
  uint32_t pid;
  uint32_t parent_pid;
  uint64_t cpu_100ns;
  uint64_t io_bytes;
  int available;
  wchar_t image_name[TIMEARC_PROCESS_IMAGE_NAME_CHARS];
} TimeArcProcessEntry;

typedef struct TimeArcProcessActivityProbe {
  uint32_t root_pid;
  TimeArcProcessCounters previous;
  int has_baseline;
} TimeArcProcessActivityProbe;

#define TIMEARC_AGENT_ACTIVITY_STATE_DECLARED 1
typedef struct TimeArcAgentActivityClosedSession {
  AppInfo app;
  int64_t start_wall_sec;
  int64_t end_wall_sec;
} TimeArcAgentActivityClosedSession;

typedef struct TimeArcAgentActivityState {
  AppInfo app;
  int active;
  int64_t start_wall_sec;
  int64_t last_wall_sec;
  uint64_t lease_duration_ms;
  uint64_t lease_until_ms;
} TimeArcAgentActivityState;

void timearc_process_activity_init(TimeArcProcessActivityProbe* probe);
int timearc_win_is_foreground_game(const char* exec_path);
void timearc_agent_activity_init(TimeArcAgentActivityState* state,
                                 uint64_t lease_duration_ms);
int timearc_agent_activity_step(
    TimeArcAgentActivityState* state, const AppInfo* codex_app,
    int work_active, int64_t wall_sec, uint64_t monotonic_ms,
    TimeArcAgentActivityClosedSession* out_closed);
int timearc_agent_activity_checkpoint(
    TimeArcAgentActivityState* state, int64_t wall_sec,
    TimeArcAgentActivityClosedSession* out_closed);
int timearc_process_activity_aggregate(const TimeArcProcessEntry* entries,
                                       size_t count, uint32_t root_pid,
                                       TimeArcProcessCounters* out_counters);
int timearc_process_activity_aggregate_roots(
    const TimeArcProcessEntry* entries, size_t count,
    const uint32_t* root_pids, size_t root_count,
    TimeArcProcessCounters* out_counters);
uint32_t timearc_process_activity_find_codex_root(
    const TimeArcProcessEntry* entries, size_t count,
    uint32_t foreground_pid, const char* foreground_exec_path);
size_t timearc_process_activity_find_codex_roots(
    const TimeArcProcessEntry* entries, size_t count,
    uint32_t foreground_pid, const char* foreground_exec_path,
    uint32_t* out_root_pids, size_t root_capacity);
size_t timearc_process_activity_find_autonomous_roots(
    const TimeArcProcessEntry* entries, size_t count,
    uint32_t foreground_pid, const char* foreground_exec_path,
    uint32_t* out_root_pids, size_t root_capacity);
int timearc_process_activity_delta(TimeArcProcessActivityProbe* probe,
                                   uint32_t root_pid,
                                   const TimeArcProcessCounters* counters);
int timearc_win_process_activity_sample(uint32_t root_pid,
                                        const char* foreground_exec_path,
                                        TimeArcProcessCounters* out_counters);

#endif  // TIMEARC_PROCESS_ACTIVITY_WIN_H
