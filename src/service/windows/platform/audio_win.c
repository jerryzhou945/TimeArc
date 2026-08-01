#include "audio_win.h"

#include "active_app_win.h"
#include "app_identity.h"

#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <initguid.h>
#include <audioclient.h>
#include <audiopolicy.h>
#include <endpointvolume.h>
#include <mmdeviceapi.h>
#include <psapi.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

// Some MinGW/SDK combinations omit the C IAudioMeterInformation definition.
// This minimal vtable exposes the peak meter needed to detect audible output.
#ifndef __IAudioMeterInformation_INTERFACE_DEFINED__
#define __IAudioMeterInformation_INTERFACE_DEFINED__

DEFINE_GUID(IID_IAudioMeterInformation, 0xc02216f6, 0x8c67, 0x4b5b, 0x9d,
            0x00, 0xd0, 0x08, 0xe7, 0x3e, 0x00, 0x64);

typedef struct IAudioMeterInformationVtbl {
  BEGIN_INTERFACE

  HRESULT(STDMETHODCALLTYPE* QueryInterface)(IAudioMeterInformation* This,
                                             REFIID riid,
                                             void** ppvObject);
  ULONG(STDMETHODCALLTYPE* AddRef)(IAudioMeterInformation* This);
  ULONG(STDMETHODCALLTYPE* Release)(IAudioMeterInformation* This);
  HRESULT(STDMETHODCALLTYPE* GetPeakValue)(IAudioMeterInformation* This,
                                           float* pfPeak);
  HRESULT(STDMETHODCALLTYPE* GetMeteringChannelCount)(
      IAudioMeterInformation* This,
      UINT* pnChannelCount);
  HRESULT(STDMETHODCALLTYPE* GetChannelsPeakValues)(
      IAudioMeterInformation* This,
      UINT32 u32ChannelCount,
      float* afPeakValues);
  HRESULT(STDMETHODCALLTYPE* QueryHardwareSupport)(
      IAudioMeterInformation* This,
      DWORD* pdwHardwareSupportMask);

  END_INTERFACE
} IAudioMeterInformationVtbl;

interface IAudioMeterInformation {
  CONST_VTBL IAudioMeterInformationVtbl* lpVtbl;
};

#define IAudioMeterInformation_Release(This) (This)->lpVtbl->Release(This)
#define IAudioMeterInformation_GetPeakValue(This, pfPeak) \
  (This)->lpVtbl->GetPeakValue(This, pfPeak)

#endif  // __IAudioMeterInformation_INTERFACE_DEFINED__

#define TIMEARC_AUDIO_PEAK_THRESHOLD 0.005f
#define TIMEARC_GSMTC_CACHE_SEC 10

static const char* kGsmtcQueryCommand =
    "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass "
    "-EncodedCommand "
    "WwBDAG8AbgBzAG8AbABlAF0AOgA6AE8AdQB0AHAAdQB0AEUAbgBjAG8AZABpAG4AZwA9AFsAUwB5AHMAdABlAG0ALgBUAGUAeAB0AC4AVQBUAEYAOABFAG4AYwBvAGQAaQBuAGcAXQA6ADoAbgBlAHcAKAAkAGYAYQBsAHMAZQApAAoAJABuAHUAbABsACAAPQAgAFsAVwBpAG4AZABvAHcAcwAuAE0AZQBkAGkAYQAuAEMAbwBuAHQAcgBvAGwALgBHAGwAbwBiAGEAbABTAHkAcwB0AGUAbQBNAGUAZABpAGEAVAByAGEAbgBzAHAAbwByAHQAQwBvAG4AdAByAG8AbABzAFMAZQBzAHMAaQBvAG4ATQBhAG4AYQBnAGUAcgAsACAAVwBpAG4AZABvAHcAcwAuAE0AZQBkAGkAYQAuAEMAbwBuAHQAcgBvAGwALAAgAEMAbwBuAHQAZQBuAHQAVAB5AHAAZQA9AFcAaQBuAGQAbwB3AHMAUgB1AG4AdABpAG0AZQBdAAoAJABuAHUAbABsACAAPQAgAFsAVwBpAG4AZABvAHcAcwAuAE0AZQBkAGkAYQAuAEMAbwBuAHQAcgBvAGwALgBHAGwAbwBiAGEAbABTAHkAcwB0AGUAbQBNAGUAZABpAGEAVAByAGEAbgBzAHAAbwByAHQAQwBvAG4AdAByAG8AbABzAFMAZQBzAHMAaQBvAG4ATQBlAGQAaQBhAFAAcgBvAHAAZQByAHQAaQBlAHMALAAgAFcAaQBuAGQAbwB3AHMALgBNAGUAZABpAGEALgBDAG8AbgB0AHIAbwBsACwAIABDAG8AbgB0AGUAbgB0AFQAeQBwAGUAPQBXAGkAbgBkAG8AdwBzAFIAdQBuAHQAaQBtAGUAXQAKAEEAZABkAC0AVAB5AHAAZQAgAC0AQQBzAHMAZQBtAGIAbAB5AE4AYQBtAGUAIABTAHkAcwB0AGUAbQAuAFIAdQBuAHQAaQBtAGUALgBXAGkAbgBkAG8AdwBzAFIAdQBuAHQAaQBtAGUACgBmAHUAbgBjAHQAaQBvAG4AIABBAHcAYQBpAHQAKAAkAG8AcAAsACAAWwBUAHkAcABlAF0AJAByAGUAcwB1AGwAdABUAHkAcABlACkAIAB7AAoAIAAgACQAbQBlAHQAaABvAGQAcwAgAD0AIABbAFMAeQBzAHQAZQBtAC4AVwBpAG4AZABvAHcAcwBSAHUAbgB0AGkAbQBlAFMAeQBzAHQAZQBtAEUAeAB0AGUAbgBzAGkAbwBuAHMAXQAuAEcAZQB0AE0AZQB0AGgAbwBkAHMAKAApACAAfAAgAFcAaABlAHIAZQAtAE8AYgBqAGUAYwB0ACAAewAgACQAXwAuAE4AYQBtAGUAIAAtAGUAcQAgACcAQQBzAFQAYQBzAGsAJwAgAC0AYQBuAGQAIAAkAF8ALgBJAHMARwBlAG4AZQByAGkAYwBNAGUAdABoAG8AZABEAGUAZgBpAG4AaQB0AGkAbwBuACAALQBhAG4AZAAgACQAXwAuAEcAZQB0AFAAYQByAGEAbQBlAHQAZQByAHMAKAApAC4AQwBvAHUAbgB0ACAALQBlAHEAIAAxACAAfQAKACAAIAAkAG0AZQB0AGgAbwBkACAAPQAgACQAbQBlAHQAaABvAGQAcwBbADAAXQAuAE0AYQBrAGUARwBlAG4AZQByAGkAYwBNAGUAdABoAG8AZAAoACQAcgBlAHMAdQBsAHQAVAB5AHAAZQApAAoAIAAgACQAdABhAHMAawAgAD0AIAAkAG0AZQB0AGgAbwBkAC4ASQBuAHYAbwBrAGUAKAAkAG4AdQBsAGwALAAgAEAAKAAkAG8AcAApACkACgAgACAAJAB0AGEAcwBrAC4AVwBhAGkAdAAoADEAMgAwADAAKQAgAHwAIABPAHUAdAAtAE4AdQBsAGwACgAgACAAaQBmACAAKAAtAG4AbwB0ACAAJAB0AGEAcwBrAC4ASQBzAEMAbwBtAHAAbABlAHQAZQBkACkAIAB7ACAAcgBlAHQAdQByAG4AIAAkAG4AdQBsAGwAIAB9AAoAIAAgACQAdABhAHMAawAuAFIAZQBzAHUAbAB0AAoAfQAKACQAbQBhAG4AYQBnAGUAcgAgAD0AIABBAHcAYQBpAHQAIAAoAFsAVwBpAG4AZABvAHcAcwAuAE0AZQBkAGkAYQAuAEMAbwBuAHQAcgBvAGwALgBHAGwAbwBiAGEAbABTAHkAcwB0AGUAbQBNAGUAZABpAGEAVAByAGEAbgBzAHAAbwByAHQAQwBvAG4AdAByAG8AbABzAFMAZQBzAHMAaQBvAG4ATQBhAG4AYQBnAGUAcgBdADoAOgBSAGUAcQB1AGUAcwB0AEEAcwB5AG4AYwAoACkAKQAgACgAWwBXAGkAbgBkAG8AdwBzAC4ATQBlAGQAaQBhAC4AQwBvAG4AdAByAG8AbAAuAEcAbABvAGIAYQBsAFMAeQBzAHQAZQBtAE0AZQBkAGkAYQBUAHIAYQBuAHMAcABvAHIAdABDAG8AbgB0AHIAbwBsAHMAUwBlAHMAcwBpAG8AbgBNAGEAbgBhAGcAZQByAF0AKQAKAGkAZgAgACgAJABuAHUAbABsACAALQBlAHEAIAAkAG0AYQBuAGEAZwBlAHIAKQAgAHsAIABlAHgAaQB0ACAAMAAgAH0ACgBmAG8AcgBlAGEAYwBoACAAKAAkAHMAZQBzAHMAaQBvAG4AIABpAG4AIAAkAG0AYQBuAGEAZwBlAHIALgBHAGUAdABTAGUAcwBzAGkAbwBuAHMAKAApACkAIAB7AAoAIAAgACQAcAByAG8AcABzACAAPQAgAEEAdwBhAGkAdAAgACgAJABzAGUAcwBzAGkAbwBuAC4AVAByAHkARwBlAHQATQBlAGQAaQBhAFAAcgBvAHAAZQByAHQAaQBlAHMAQQBzAHkAbgBjACgAKQApACAAKABbAFcAaQBuAGQAbwB3AHMALgBNAGUAZABpAGEALgBDAG8AbgB0AHIAbwBsAC4ARwBsAG8AYgBhAGwAUwB5AHMAdABlAG0ATQBlAGQAaQBhAFQAcgBhAG4AcwBwAG8AcgB0AEMAbwBuAHQAcgBvAGwAcwBTAGUAcwBzAGkAbwBuAE0AZQBkAGkAYQBQAHIAbwBwAGUAcgB0AGkAZQBzAF0AKQAKACAAIABpAGYAIAAoACQAbgB1AGwAbAAgAC0AZQBxACAAJABwAHIAbwBwAHMAKQAgAHsAIABjAG8AbgB0AGkAbgB1AGUAIAB9AAoAIAAgACQAcwBvAHUAcgBjAGUAIAA9ACAAJABzAGUAcwBzAGkAbwBuAC4AUwBvAHUAcgBjAGUAQQBwAHAAVQBzAGUAcgBNAG8AZABlAGwASQBkAAoAIAAgACQAdABpAHQAbABlACAAPQAgACQAcAByAG8AcABzAC4AVABpAHQAbABlAAoAIAAgACQAYQByAHQAaQBzAHQAIAA9ACAAJABwAHIAbwBwAHMALgBBAHIAdABpAHMAdAAKACAAIABpAGYAIAAoAC0AbgBvAHQAIABbAHMAdAByAGkAbgBnAF0AOgA6AEkAcwBOAHUAbABsAE8AcgBXAGgAaQB0AGUAUwBwAGEAYwBlACgAJAB0AGkAdABsAGUAKQApACAAewAKACAAIAAgACAAIgAkAHMAbwB1AHIAYwBlAGAAdAAkAHQAaQB0AGwAZQBgAHQAJABhAHIAdABpAHMAdAAiAAoAIAAgAH0ACgB9AAoA";

static char g_gsmtc_cache_app[TA_MAX_NAME_BYTES];
static char g_gsmtc_cache_title[TA_MAX_TITLE_BYTES];
static time_t g_gsmtc_cache_time = 0;

// Initialize thread-local COM lazily and track whether this file owns cleanup.
static int g_com_initialized = 0;
static int g_should_uninitialize_com = 0;

// Convert Windows PIDs, paths, and UTF-16 strings into UTF-8 AppInfo values.
static void copy_string(char* dst, size_t dst_size, const char* src) {
  if (dst == NULL || dst_size == 0) {
    return;
  }

  if (src == NULL) {
    dst[0] = '\0';
    return;
  }

  size_t len = strlen(src);
  if (len >= dst_size) {
    len = dst_size - 1;
  }

  memcpy(dst, src, len);
  dst[len] = '\0';
}

static const char* basename_from_path(const char* path) {
  const char* base = path;

  if (path == NULL) {
    return "";
  }

  for (const char* p = path; *p != '\0'; ++p) {
    if (*p == '\\' || *p == '/') {
      base = p + 1;
    }
  }

  return base;
}

static int wide_to_utf8(const wchar_t* src, char* dst, size_t dst_size) {
  if (dst == NULL || dst_size == 0) {
    return -1;
  }
  dst[0] = '\0';

  if (src == NULL || src[0] == L'\0') {
    return 0;
  }

  int written = WideCharToMultiByte(CP_UTF8, 0, src, -1, dst, (int)dst_size,
                                    NULL, NULL);
  if (written <= 0) {
    dst[0] = '\0';
    return -1;
  }

  dst[dst_size - 1] = '\0';
  return 0;
}

static int query_process_path(DWORD pid, char* out_path, size_t out_path_size) {
  if (out_path == NULL || out_path_size == 0) {
    return -1;
  }
  out_path[0] = '\0';

  HANDLE process =
      OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
  if (process != NULL) {
    wchar_t path_w[TA_MAX_PATH_BYTES];
    DWORD len = GetModuleFileNameExW(process, NULL, path_w,
                                     (DWORD)(sizeof(path_w) / sizeof(path_w[0])));
    CloseHandle(process);
    if (len > 0 && len < (sizeof(path_w) / sizeof(path_w[0])) &&
        wide_to_utf8(path_w, out_path, out_path_size) == 0) {
      return 0;
    }
    out_path[0] = '\0';
  }

  process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process != NULL) {
    wchar_t path_w[TA_MAX_PATH_BYTES];
    DWORD len = (DWORD)(sizeof(path_w) / sizeof(path_w[0]));
    int ok = QueryFullProcessImageNameW(process, 0, path_w, &len);
    CloseHandle(process);
    if (ok && len > 0 && len < (sizeof(path_w) / sizeof(path_w[0])) &&
        wide_to_utf8(path_w, out_path, out_path_size) == 0) {
      return 0;
    }
    out_path[0] = '\0';
  }

  return -1;
}

static int ensure_com_initialized(void) {
  if (g_com_initialized) {
    return 0;
  }

  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (SUCCEEDED(hr)) {
    g_com_initialized = 1;
    g_should_uninitialize_com = 1;
    return 0;
  }

  if (hr == RPC_E_CHANGED_MODE) {
    // Reuse a COM apartment initialized elsewhere without owning its cleanup.
    g_com_initialized = 1;
    g_should_uninitialize_com = 0;
    return 0;
  }

  return -1;
}

static AppInfo* find_equal_audio_observation(AppInfo* apps, size_t count,
                                             const AppInfo* candidate) {
  for (size_t i = 0; i < count; ++i) {
    if (timearc_app_identity_equal(&apps[i], candidate)) {
      return &apps[i];
    }
  }

  return NULL;
}

static int contains_ascii_case_insensitive(const char* text,
                                           const char* needle) {
  if (text == NULL || needle == NULL || needle[0] == '\0') {
    return 0;
  }

  size_t needle_len = strlen(needle);
  for (const char* p = text; *p != '\0'; ++p) {
    size_t i = 0;
    while (i < needle_len && p[i] != '\0') {
      char a = p[i];
      char b = needle[i];
      if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
      if (b >= 'A' && b <= 'Z') b = (char)(b - 'A' + 'a');
      if (a != b) break;
      ++i;
    }
    if (i == needle_len) {
      return 1;
    }
  }

  return 0;
}

static int ascii_equal_case_insensitive(const char* a, const char* b) {
  if (a == NULL || b == NULL) {
    return 0;
  }

  while (*a != '\0' && *b != '\0') {
    char ca = *a;
    char cb = *b;
    if (ca >= 'A' && ca <= 'Z') ca = (char)(ca - 'A' + 'a');
    if (cb >= 'A' && cb <= 'Z') cb = (char)(cb - 'A' + 'a');
    if (ca != cb) {
      return 0;
    }
    ++a;
    ++b;
  }

  return *a == '\0' && *b == '\0';
}

static void copy_app_stem(char* dst, size_t dst_size, const char* app_name) {
  if (dst == NULL || dst_size == 0) {
    return;
  }
  dst[0] = '\0';
  if (app_name == NULL || app_name[0] == '\0') {
    return;
  }

  copy_string(dst, dst_size, app_name);
  size_t len = strlen(dst);
  if (len > 4 && ascii_equal_case_insensitive(dst + len - 4, ".exe")) {
    dst[len - 4] = '\0';
  }
}

static int gsmtc_source_matches_app(const char* source, const char* app_name) {
  if (source == NULL || source[0] == '\0' || app_name == NULL ||
      app_name[0] == '\0') {
    return 0;
  }

  if (contains_ascii_case_insensitive(source, app_name)) {
    return 1;
  }

  char stem[TA_MAX_NAME_BYTES];
  copy_app_stem(stem, sizeof(stem), app_name);
  return stem[0] != '\0' && contains_ascii_case_insensitive(source, stem);
}

static void trim_line_end(char* value) {
  if (value == NULL) {
    return;
  }

  size_t len = strlen(value);
  while (len > 0 && (value[len - 1] == '\r' || value[len - 1] == '\n' ||
                     value[len - 1] == ' ' || value[len - 1] == '\t')) {
    value[len - 1] = '\0';
    --len;
  }
}

static void format_gsmtc_title(const char* title,
                               const char* artist,
                               char* out_title,
                               size_t out_title_size) {
  if (out_title == NULL || out_title_size == 0) {
    return;
  }
  out_title[0] = '\0';
  if (title == NULL || title[0] == '\0') {
    return;
  }

  if (artist != NULL && artist[0] != '\0' &&
      !contains_ascii_case_insensitive(title, artist)) {
    int written = snprintf(out_title, out_title_size, "%s - %s", title, artist);
    if (written >= 0 && (size_t)written < out_title_size) {
      return;
    }
  }

  copy_string(out_title, out_title_size, title);
}

static int query_gsmtc_media_title(const char* app_name,
                                   char* out_title,
                                   size_t out_title_size) {
  if (app_name == NULL || app_name[0] == '\0' || out_title == NULL ||
      out_title_size == 0) {
    return -1;
  }

  out_title[0] = '\0';
  time_t now = time(NULL);
  if (g_gsmtc_cache_title[0] != '\0' &&
      now - g_gsmtc_cache_time <= TIMEARC_GSMTC_CACHE_SEC &&
      gsmtc_source_matches_app(g_gsmtc_cache_app, app_name)) {
    copy_string(out_title, out_title_size, g_gsmtc_cache_title);
    return 0;
  }

  FILE* pipe = _popen(kGsmtcQueryCommand, "r");
  if (pipe == NULL) {
    return -1;
  }

  char line[1024];
  int matched = 0;
  while (fgets(line, sizeof(line), pipe) != NULL) {
    trim_line_end(line);
    char* source = strtok(line, "\t");
    char* title = strtok(NULL, "\t");
    char* artist = strtok(NULL, "\t");
    if (source == NULL || title == NULL ||
        !gsmtc_source_matches_app(source, app_name)) {
      continue;
    }

    format_gsmtc_title(title, artist, out_title, out_title_size);
    if (out_title[0] != '\0') {
      copy_string(g_gsmtc_cache_app, sizeof(g_gsmtc_cache_app), source);
      copy_string(g_gsmtc_cache_title, sizeof(g_gsmtc_cache_title), out_title);
      g_gsmtc_cache_time = now;
      matched = 1;
      break;
    }
  }

  _pclose(pipe);
  return matched ? 0 : -1;
}

static int should_ignore_audio_process(const char* path) {
  // Ignore Wallpaper Engine audio as desktop decoration, not user media.
  return contains_ascii_case_insensitive(path, "\\wallpaper_engine\\");
}

static int session_has_audio_peak(IAudioSessionControl* control) {
  // Require a nonzero peak because an active session may be paused or silent.
  IAudioMeterInformation* meter = NULL;
  if (FAILED(IAudioSessionControl_QueryInterface(
          control, &IID_IAudioMeterInformation, (void**)&meter)) ||
      meter == NULL) {
    return 0;
  }

  float peak = 0.0f;
  HRESULT hr = IAudioMeterInformation_GetPeakValue(meter, &peak);
  IAudioMeterInformation_Release(meter);

  return SUCCEEDED(hr) && peak > TIMEARC_AUDIO_PEAK_THRESHOLD;
}

static int session_is_audible(IAudioSessionControl* control) {
  AudioSessionState state = AudioSessionStateInactive;
  if (FAILED(IAudioSessionControl_GetState(control, &state)) ||
      state != AudioSessionStateActive) {
    return 0;
  }

  ISimpleAudioVolume* volume = NULL;
  if (SUCCEEDED(IAudioSessionControl_QueryInterface(
          control, &IID_ISimpleAudioVolume, (void**)&volume)) &&
      volume != NULL) {
    BOOL muted = FALSE;
    float level = 1.0f;
    if (SUCCEEDED(ISimpleAudioVolume_GetMute(volume, &muted)) && muted) {
      ISimpleAudioVolume_Release(volume);
      return 0;
    }
    if (SUCCEEDED(ISimpleAudioVolume_GetMasterVolume(volume, &level)) &&
        level <= 0.001f) {
      ISimpleAudioVolume_Release(volume);
      return 0;
    }
    ISimpleAudioVolume_Release(volume);
  }

  return session_has_audio_peak(control);
}

static int useful_media_title(const char* title, const char* app_name) {
  if (title == NULL || title[0] == '\0') {
    return 0;
  }
  if (strcmp(title, "Audio playback") == 0) {
    return 0;
  }
  if (contains_ascii_case_insensitive(title, "@%systemroot%") ||
      contains_ascii_case_insensitive(title, "@{") ||
      contains_ascii_case_insensitive(title, "system sounds")) {
    return 0;
  }
  if (app_name != NULL && app_name[0] != '\0' &&
      strcmp(title, app_name) == 0) {
    return 0;
  }
  return 1;
}

static const char* matching_foreground_title(const AppInfo* foreground,
                                             DWORD pid,
                                             const char* path) {
  if (foreground == NULL ||
      !useful_media_title(foreground->window_title, foreground->app_name)) {
    return NULL;
  }
  if (foreground->process_id == (uint32_t)pid) {
    return foreground->window_title;
  }
  if (path != NULL && path[0] != '\0' &&
      strcmp(foreground->exec_path, path) == 0) {
    return foreground->window_title;
  }
  return NULL;
}

typedef struct WindowTitleLookup {
  DWORD pid;
  const char* app_name;
  char* out_title;
  size_t out_title_size;
  int found;
} WindowTitleLookup;

static BOOL CALLBACK collect_window_title_for_pid(HWND hwnd, LPARAM param) {
  WindowTitleLookup* lookup = (WindowTitleLookup*)param;
  if (lookup == NULL || lookup->found || !IsWindowVisible(hwnd)) {
    return TRUE;
  }

  DWORD window_pid = 0;
  GetWindowThreadProcessId(hwnd, &window_pid);
  if (window_pid != lookup->pid) {
    return TRUE;
  }

  wchar_t title_w[TA_MAX_TITLE_BYTES];
  if (GetWindowTextW(hwnd, title_w,
                     (int)(sizeof(title_w) / sizeof(title_w[0]))) <= 0) {
    return TRUE;
  }

  char title[TA_MAX_TITLE_BYTES];
  if (wide_to_utf8(title_w, title, sizeof(title)) != 0 ||
      !useful_media_title(title, lookup->app_name)) {
    return TRUE;
  }

  copy_string(lookup->out_title, lookup->out_title_size, title);
  lookup->found = 1;
  return FALSE;
}

static int query_process_window_title(DWORD pid,
                                      const char* app_name,
                                      char* out_title,
                                      size_t out_title_size) {
  if (pid == 0 || out_title == NULL || out_title_size == 0) {
    return -1;
  }

  out_title[0] = '\0';
  WindowTitleLookup lookup = {pid, app_name, out_title, out_title_size, 0};
  EnumWindows(collect_window_title_for_pid, (LPARAM)&lookup);
  return lookup.found ? 0 : -1;
}

static int query_audio_session_display_name(IAudioSessionControl* control,
                                            const char* app_name,
                                            char* out_title,
                                            size_t out_title_size) {
  if (control == NULL || out_title == NULL || out_title_size == 0) {
    return -1;
  }

  out_title[0] = '\0';
  LPWSTR display_name = NULL;
  HRESULT hr = IAudioSessionControl_GetDisplayName(control, &display_name);
  if (FAILED(hr) || display_name == NULL || display_name[0] == L'\0') {
    if (display_name != NULL) {
      CoTaskMemFree(display_name);
    }
    return -1;
  }

  char title[TA_MAX_TITLE_BYTES];
  int ok = wide_to_utf8(display_name, title, sizeof(title)) == 0 &&
           useful_media_title(title, app_name);
  CoTaskMemFree(display_name);
  if (!ok) {
    return -1;
  }

  copy_string(out_title, out_title_size, title);
  return 0;
}

static const char* choose_media_title(IAudioSessionControl* control,
                                      const AppInfo* foreground,
                                      DWORD pid,
                                      const char* path,
                                      const char* app_name,
                                      char* scratch_title,
                                      size_t scratch_title_size) {
  if (query_gsmtc_media_title(app_name, scratch_title, scratch_title_size) ==
      0) {
    return scratch_title;
  }

  const char* title = matching_foreground_title(foreground, pid, path);
  if (title != NULL) {
    return title;
  }

  if (query_process_window_title(pid, app_name, scratch_title,
                                 scratch_title_size) == 0) {
    return scratch_title;
  }

  if (query_audio_session_display_name(control, app_name, scratch_title,
                                       scratch_title_size) == 0) {
    return scratch_title;
  }

  return NULL;
}

static void fill_audio_app(AppInfo* app,
                           DWORD pid,
                           const char* path,
                           const char* media_title) {
  memset(app, 0, sizeof(*app));
  app->process_id = (uint32_t)pid;
  app->timestamp = time(NULL);
  app->active_status = true;
  copy_string(app->exec_path, sizeof(app->exec_path), path);
  copy_string(app->app_name, sizeof(app->app_name), basename_from_path(path));
  copy_string(app->display_name, sizeof(app->display_name), app->app_name);
  copy_string(app->window_title, sizeof(app->window_title),
              media_title != NULL && media_title[0] != '\0'
                  ? media_title
                  : "Audio playback");
}

int timearc_win_get_audio_apps(AppInfo* out_apps,
                               size_t max_apps,
                               size_t* out_count) {
  if (out_count != NULL) {
    *out_count = 0;
  }
  if (out_apps == NULL || max_apps == 0 || out_count == NULL) {
    return -1;
  }
  if (ensure_com_initialized() != 0) {
    return -1;
  }

  AppInfo foreground_app;
  AppInfo* foreground_ptr =
      timearc_win_get_active_app(&foreground_app) == 0 ? &foreground_app : NULL;

  IMMDeviceEnumerator* device_enumerator = NULL;

  // Traverse the default device, session manager, and current session list.
  HRESULT hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL,
                                &IID_IMMDeviceEnumerator,
                                (void**)&device_enumerator);
  if (FAILED(hr) || device_enumerator == NULL) {
    return -1;
  }

  const ERole roles[] = {eConsole, eMultimedia, eCommunications};
  size_t added = 0;
  for (size_t role_index = 0;
       role_index < sizeof(roles) / sizeof(roles[0]) && added < max_apps;
       ++role_index) {
    IMMDevice* device = NULL;
    IAudioSessionManager2* session_manager = NULL;
    IAudioSessionEnumerator* session_enumerator = NULL;

    hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(
        device_enumerator, eRender, roles[role_index], &device);
    if (SUCCEEDED(hr) && device != NULL) {
      hr = IMMDevice_Activate(device, &IID_IAudioSessionManager2, CLSCTX_ALL,
                              NULL, (void**)&session_manager);
    }
    if (SUCCEEDED(hr) && session_manager != NULL) {
      hr = IAudioSessionManager2_GetSessionEnumerator(session_manager,
                                                      &session_enumerator);
    }

    if (FAILED(hr) || session_enumerator == NULL) {
      if (session_manager != NULL)
        IAudioSessionManager2_Release(session_manager);
      if (device != NULL) IMMDevice_Release(device);
      continue;
    }

    int session_count = 0;
    IAudioSessionEnumerator_GetCount(session_enumerator, &session_count);

    for (int i = 0; i < session_count && added < max_apps; ++i) {
      IAudioSessionControl* control = NULL;
      IAudioSessionControl2* control2 = NULL;

      if (FAILED(IAudioSessionEnumerator_GetSession(session_enumerator, i,
                                                    &control)) ||
          control == NULL) {
        continue;
      }

      if (!session_is_audible(control)) {
        IAudioSessionControl_Release(control);
        continue;
      }

      if (FAILED(IAudioSessionControl_QueryInterface(
              control, &IID_IAudioSessionControl2, (void**)&control2)) ||
          control2 == NULL) {
        IAudioSessionControl_Release(control);
        continue;
      }

      DWORD pid = 0;
      HRESULT system_sound_hr =
          IAudioSessionControl2_IsSystemSoundsSession(control2);
      // Skip system sounds because they lack stable application identity.
      if (system_sound_hr == S_OK ||
          FAILED(IAudioSessionControl2_GetProcessId(control2, &pid)) ||
          pid == 0) {
        IAudioSessionControl2_Release(control2);
        IAudioSessionControl_Release(control);
        continue;
      }

      char path[TA_MAX_PATH_BYTES];
      if (query_process_path(pid, path, sizeof(path)) == 0 &&
          !should_ignore_audio_process(path)) {
        const char* app_name = basename_from_path(path);
        char media_title[TA_MAX_TITLE_BYTES];
        const char* title =
            choose_media_title(control, foreground_ptr, pid, path, app_name,
                               media_title, sizeof(media_title));
        AppInfo candidate;
        fill_audio_app(&candidate, pid, path, title);
        if (find_equal_audio_observation(out_apps, added, &candidate) == NULL) {
          out_apps[added] = candidate;
          ++added;
        }
      }

      IAudioSessionControl2_Release(control2);
      IAudioSessionControl_Release(control);
    }

    IAudioSessionEnumerator_Release(session_enumerator);
    IAudioSessionManager2_Release(session_manager);
    IMMDevice_Release(device);
  }

  IMMDeviceEnumerator_Release(device_enumerator);

  *out_count = added;
  return 0;
}

void timearc_win_audio_shutdown(void) {
  if (g_com_initialized && g_should_uninitialize_com) {
    CoUninitialize();
  }
  g_com_initialized = 0;
  g_should_uninitialize_com = 0;
}
