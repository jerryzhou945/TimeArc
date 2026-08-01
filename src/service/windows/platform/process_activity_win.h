#ifndef TIMEARC_PROCESS_ACTIVITY_WIN_H
#define TIMEARC_PROCESS_ACTIVITY_WIN_H

#include <stddef.h>
#include <stdint.h>

#define TIMEARC_PROCESS_CPU_ACTIVE_100NS 50000ULL
#define TIMEARC_PROCESS_IO_ACTIVE_BYTES 4096ULL

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
} TimeArcProcessEntry;

typedef struct TimeArcProcessActivityProbe {
  uint32_t root_pid;
  TimeArcProcessCounters previous;
  int has_baseline;
} TimeArcProcessActivityProbe;

void timearc_process_activity_init(TimeArcProcessActivityProbe* probe);
int timearc_process_activity_aggregate(const TimeArcProcessEntry* entries,
                                       size_t count, uint32_t root_pid,
                                       TimeArcProcessCounters* out_counters);
int timearc_process_activity_delta(TimeArcProcessActivityProbe* probe,
                                   uint32_t root_pid,
                                   const TimeArcProcessCounters* counters);
int timearc_win_process_activity_sample(uint32_t root_pid,
                                        TimeArcProcessCounters* out_counters);

#endif  // TIMEARC_PROCESS_ACTIVITY_WIN_H
