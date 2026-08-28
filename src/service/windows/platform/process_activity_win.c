#include "process_activity_win.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tlhelp32.h>

#include <stdlib.h>
#include <string.h>
#include <wchar.h>

static int ascii_contains_ignore_case(const char* text, const char* needle) {
  if (text == NULL || needle == NULL || needle[0] == '\0') {
    return 0;
  }
  const size_t needle_length = strlen(needle);
  for (const char* start = text; *start != '\0'; ++start) {
    if (_strnicmp(start, needle, needle_length) == 0) {
      return 1;
    }
  }
  return 0;
}

static int ascii_basename_equals_ignore_case(const char* path,
                                             const char* expected) {
  if (path == NULL || expected == NULL) return 0;
  const char* basename = path;
  for (const char* cursor = path; *cursor != '\0'; ++cursor) {
    if (*cursor == '\\' || *cursor == '/') basename = cursor + 1;
  }
  return _stricmp(basename, expected) == 0;
}

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

static int has_ancestor_image(const TimeArcProcessEntry* entries,
                              size_t count, size_t index,
                              const wchar_t* image_name) {
  uint32_t pid = entries[index].parent_pid;
  for (size_t depth = 0; depth <= count && pid != 0; ++depth) {
    size_t parent_index = 0;
    if (!find_entry(entries, count, pid, &parent_index)) return 0;
    if (_wcsicmp(entries[parent_index].image_name, image_name) == 0) return 1;
    const uint32_t parent_pid = entries[parent_index].parent_pid;
    if (parent_pid == pid) return 0;
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

static void export_agent_activity(
    const TimeArcAgentActivityState* state,
    TimeArcAgentActivityClosedSession* out_closed) {
  if (out_closed == NULL) return;
  memset(out_closed, 0, sizeof(*out_closed));
  out_closed->app = state->app;
  out_closed->start_wall_sec = state->start_wall_sec;
  out_closed->end_wall_sec = state->last_wall_sec;
}

static void start_agent_activity(TimeArcAgentActivityState* state,
                                 const AppInfo* codex_app,
                                 int64_t wall_sec,
                                 uint64_t monotonic_ms) {
  state->app = *codex_app;
  state->active = 1;
  state->start_wall_sec = wall_sec;
  state->last_wall_sec = wall_sec;
  state->lease_until_ms = monotonic_ms + state->lease_duration_ms;
}

void timearc_agent_activity_init(TimeArcAgentActivityState* state,
                                 uint64_t lease_duration_ms) {
  if (state == NULL) return;
  memset(state, 0, sizeof(*state));
  state->lease_duration_ms = lease_duration_ms;
}

int timearc_agent_activity_step(
    TimeArcAgentActivityState* state, const AppInfo* codex_app,
    int work_active, int64_t wall_sec, uint64_t monotonic_ms,
    TimeArcAgentActivityClosedSession* out_closed) {
  if (state == NULL) return 0;
  if (!state->active) {
    if (work_active && codex_app != NULL) {
      start_agent_activity(state, codex_app, wall_sec, monotonic_ms);
    }
    return 0;
  }

  if (work_active && codex_app != NULL &&
      (state->app.process_id != codex_app->process_id ||
       strcmp(state->app.exec_path, codex_app->exec_path) != 0)) {
    export_agent_activity(state, out_closed);
    start_agent_activity(state, codex_app, wall_sec, monotonic_ms);
    return 1;
  }
  if (work_active && codex_app != NULL) {
    state->last_wall_sec = wall_sec;
    state->lease_until_ms = monotonic_ms + state->lease_duration_ms;
  }
  if (monotonic_ms <= state->lease_until_ms) return 0;

  export_agent_activity(state, out_closed);
  const uint64_t lease_duration_ms = state->lease_duration_ms;
  memset(state, 0, sizeof(*state));
  state->lease_duration_ms = lease_duration_ms;
  return 1;
}

int timearc_agent_activity_checkpoint(
    TimeArcAgentActivityState* state, int64_t wall_sec,
    TimeArcAgentActivityClosedSession* out_closed) {
  (void)wall_sec;
  if (state == NULL || !state->active ||
      state->last_wall_sec <= state->start_wall_sec) {
    return 0;
  }
  export_agent_activity(state, out_closed);
  state->start_wall_sec = state->last_wall_sec;
  return 1;
}

int timearc_process_activity_aggregate(const TimeArcProcessEntry* entries,
                                       size_t count, uint32_t root_pid,
                                       TimeArcProcessCounters* out_counters) {
  return timearc_process_activity_aggregate_roots(
      entries, count, &root_pid, root_pid == 0 ? 0 : 1, out_counters);
}

int timearc_process_activity_aggregate_roots(
    const TimeArcProcessEntry* entries, size_t count,
    const uint32_t* root_pids, size_t root_count,
    TimeArcProcessCounters* out_counters) {
  if (entries == NULL || out_counters == NULL || root_pids == NULL ||
      root_count == 0) {
    return 0;
  }

  memset(out_counters, 0, sizeof(*out_counters));
  for (size_t i = 0; i < count; ++i) {
    if (!entries[i].available) {
      continue;
    }
    int included = 0;
    for (size_t root_index = 0; root_index < root_count; ++root_index) {
      if (root_pids[root_index] != 0 &&
          belongs_to_root(entries, count, i, root_pids[root_index])) {
        included = 1;
        break;
      }
    }
    if (!included) {
      continue;
    }
    out_counters->cpu_100ns += entries[i].cpu_100ns;
    out_counters->io_bytes += entries[i].io_bytes;
    out_counters->available = 1;
  }
  return out_counters->available;
}

size_t timearc_process_activity_find_codex_roots(
    const TimeArcProcessEntry* entries, size_t count,
    uint32_t foreground_pid, const char* foreground_exec_path,
    uint32_t* out_root_pids, size_t root_capacity) {
  if (entries == NULL || foreground_pid == 0 ||
      foreground_exec_path == NULL || out_root_pids == NULL ||
      root_capacity == 0 ||
      !ascii_contains_ignore_case(foreground_exec_path, "OpenAI.Codex_")) {
    return 0;
  }

  size_t foreground_index = 0;
  if (!find_entry(entries, count, foreground_pid, &foreground_index) ||
      _wcsicmp(entries[foreground_index].image_name, L"ChatGPT.exe") != 0) {
    return 0;
  }

  size_t found = 0;
  for (size_t i = 0; i < count && found < root_capacity; ++i) {
    if (_wcsicmp(entries[i].image_name, L"codex.exe") == 0 &&
        has_ancestor_image(entries, count, i, L"ChatGPT.exe")) {
      out_root_pids[found++] = entries[i].pid;
    }
  }
  return found;
}

size_t timearc_process_activity_find_autonomous_roots(
    const TimeArcProcessEntry* entries, size_t count,
    uint32_t foreground_pid, const char* foreground_exec_path,
    uint32_t* out_root_pids, size_t root_capacity) {
  // Process activity is a work signal only for official packaged Codex workers.
  // Generic foreground apps often perform background CPU/I/O while untouched;
  // treating that churn as activity would defeat keyboard/mouse idle detection.
  return timearc_process_activity_find_codex_roots(
      entries, count, foreground_pid, foreground_exec_path, out_root_pids,
      root_capacity);
}

uint32_t timearc_process_activity_find_codex_root(
    const TimeArcProcessEntry* entries, size_t count,
    uint32_t foreground_pid, const char* foreground_exec_path) {
  uint32_t root_pid = 0;
  return timearc_process_activity_find_codex_roots(
             entries, count, foreground_pid, foreground_exec_path,
             &root_pid, 1) == 1
             ? root_pid
             : 0;
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

int timearc_win_is_foreground_game(const char* exec_path) {
  if (exec_path == NULL || exec_path[0] == '\0') return 0;
  if (ascii_basename_equals_ignore_case(exec_path, "YuanShen.exe") ||
      ascii_basename_equals_ignore_case(exec_path, "GenshinImpact.exe") ||
      ascii_basename_equals_ignore_case(exec_path, "StarRail.exe") ||
      ascii_basename_equals_ignore_case(exec_path, "ZenlessZoneZero.exe")) {
    return 1;
  }
  const int wuthering_path =
      ascii_contains_ignore_case(exec_path, "Wuthering Waves") ||
      ascii_contains_ignore_case(exec_path, "WutheringWaves");
  return wuthering_path && ascii_basename_equals_ignore_case(
                                exec_path, "Client-Win64-Shipping.exe");
}

int timearc_win_process_activity_sample(uint32_t root_pid,
                                        const char* foreground_exec_path,
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
    wcsncpy(entries[count].image_name, process_entry.szExeFile,
            TIMEARC_PROCESS_IMAGE_NAME_CHARS - 1);
    entries[count].image_name[TIMEARC_PROCESS_IMAGE_NAME_CHARS - 1] = L'\0';
    ++count;
    more = Process32NextW(snapshot, &process_entry);
  }
  CloseHandle(snapshot);

  uint32_t* roots = (uint32_t*)calloc(count, sizeof(*roots));
  if (roots == NULL) {
    free(entries);
    return 0;
  }
  const size_t root_count = timearc_process_activity_find_autonomous_roots(
      entries, count, root_pid, foreground_exec_path, roots, count);
  if (root_count == 0) {
    free(roots);
    free(entries);
    return 0;
  }

  for (size_t i = 0; i < count; ++i) {
    int included = 0;
    for (size_t root_index = 0; root_index < root_count; ++root_index) {
      if (belongs_to_root(entries, count, i, roots[root_index])) {
        included = 1;
        break;
      }
    }
    if (included) {
      query_entry(&entries[i]);
    }
  }
  const int available = timearc_process_activity_aggregate_roots(
      entries, count, roots, root_count, out_counters);
  free(roots);
  free(entries);
  return available;
}
