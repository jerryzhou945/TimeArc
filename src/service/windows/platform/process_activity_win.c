#include "process_activity_win.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tlhelp32.h>

#include <stdlib.h>
#include <string.h>

static uint64_t filetime_value(FILETIME value) {
  ULARGE_INTEGER ticks;
  ticks.LowPart = value.dwLowDateTime;
  ticks.HighPart = value.dwHighDateTime;
  return ticks.QuadPart;
}

static int find_entry(const TimeArcProcessEntry* entries, size_t count,
                      uint32_t pid, size_t* out_index) {
  for (size_t i = 0; i < count; ++i) {
    if (entries[i].pid == pid) {
      if (out_index != NULL) {
        *out_index = i;
      }
      return 1;
    }
  }
  return 0;
}

static int belongs_to_root(const TimeArcProcessEntry* entries, size_t count,
                           size_t index, uint32_t root_pid) {
  uint32_t pid = entries[index].pid;
  for (size_t depth = 0; depth <= count; ++depth) {
    if (pid == root_pid) {
      return 1;
    }
    size_t parent_index = 0;
    if (!find_entry(entries, count, pid, &parent_index)) {
      return 0;
    }
    uint32_t parent_pid = entries[parent_index].parent_pid;
    if (parent_pid == 0 || parent_pid == pid) {
      return 0;
    }
    pid = parent_pid;
  }
  return 0;
}

static void query_entry(TimeArcProcessEntry* entry) {
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                               (DWORD)entry->pid);
  if (process == NULL) {
    return;
  }

  FILETIME created;
  FILETIME exited;
  FILETIME kernel;
  FILETIME user;
  IO_COUNTERS io;
  const int cpu_ok =
      GetProcessTimes(process, &created, &exited, &kernel, &user) != 0;
  const int io_ok = GetProcessIoCounters(process, &io) != 0;
  CloseHandle(process);

  if (cpu_ok) {
    entry->cpu_100ns = filetime_value(kernel) + filetime_value(user);
  }
  if (io_ok) {
    entry->io_bytes = io.ReadTransferCount + io.WriteTransferCount +
                      io.OtherTransferCount;
  }
  entry->available = cpu_ok || io_ok;
}

void timearc_process_activity_init(TimeArcProcessActivityProbe* probe) {
  if (probe != NULL) {
    memset(probe, 0, sizeof(*probe));
  }
}

int timearc_process_activity_aggregate(const TimeArcProcessEntry* entries,
                                       size_t count, uint32_t root_pid,
                                       TimeArcProcessCounters* out_counters) {
  if (entries == NULL || out_counters == NULL || root_pid == 0) {
    return 0;
  }

  memset(out_counters, 0, sizeof(*out_counters));
  for (size_t i = 0; i < count; ++i) {
    if (!entries[i].available ||
        !belongs_to_root(entries, count, i, root_pid)) {
      continue;
    }
    out_counters->cpu_100ns += entries[i].cpu_100ns;
    out_counters->io_bytes += entries[i].io_bytes;
    out_counters->available = 1;
  }
  return out_counters->available;
}

int timearc_process_activity_delta(TimeArcProcessActivityProbe* probe,
                                   uint32_t root_pid,
                                   const TimeArcProcessCounters* counters) {
  if (probe == NULL || counters == NULL || !counters->available ||
      root_pid == 0) {
    if (probe != NULL) {
      probe->has_baseline = 0;
    }
    return 0;
  }

  if (!probe->has_baseline || probe->root_pid != root_pid ||
      counters->cpu_100ns < probe->previous.cpu_100ns ||
      counters->io_bytes < probe->previous.io_bytes) {
    probe->root_pid = root_pid;
    probe->previous = *counters;
    probe->has_baseline = 1;
    return 0;
  }

  const uint64_t cpu_delta =
      counters->cpu_100ns - probe->previous.cpu_100ns;
  const uint64_t io_delta = counters->io_bytes - probe->previous.io_bytes;
  probe->previous = *counters;
  return cpu_delta >= TIMEARC_PROCESS_CPU_ACTIVE_100NS ||
         io_delta >= TIMEARC_PROCESS_IO_ACTIVE_BYTES;
}

int timearc_win_process_activity_sample(uint32_t root_pid,
                                        TimeArcProcessCounters* out_counters) {
  if (root_pid == 0 || out_counters == NULL) {
    return 0;
  }
  memset(out_counters, 0, sizeof(*out_counters));

  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) {
    return 0;
  }

  size_t count = 0;
  size_t capacity = 256;
  TimeArcProcessEntry* entries =
      (TimeArcProcessEntry*)calloc(capacity, sizeof(*entries));
  if (entries == NULL) {
    CloseHandle(snapshot);
    return 0;
  }

  PROCESSENTRY32W process_entry;
  memset(&process_entry, 0, sizeof(process_entry));
  process_entry.dwSize = sizeof(process_entry);
  BOOL more = Process32FirstW(snapshot, &process_entry);
  while (more) {
    if (count == capacity) {
      const size_t next_capacity = capacity * 2;
      TimeArcProcessEntry* grown = (TimeArcProcessEntry*)realloc(
          entries, next_capacity * sizeof(*entries));
      if (grown == NULL) {
        free(entries);
        CloseHandle(snapshot);
        return 0;
      }
      entries = grown;
      memset(entries + capacity, 0,
             (next_capacity - capacity) * sizeof(*entries));
      capacity = next_capacity;
    }
    entries[count].pid = (uint32_t)process_entry.th32ProcessID;
    entries[count].parent_pid =
        (uint32_t)process_entry.th32ParentProcessID;
    ++count;
    more = Process32NextW(snapshot, &process_entry);
  }
  CloseHandle(snapshot);

  for (size_t i = 0; i < count; ++i) {
    if (belongs_to_root(entries, count, i, root_pid)) {
      query_entry(&entries[i]);
    }
  }
  const int available = timearc_process_activity_aggregate(
      entries, count, root_pid, out_counters);
  free(entries);
  return available;
}
