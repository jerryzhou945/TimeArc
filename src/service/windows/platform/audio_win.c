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
#include <wctype.h>

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
#define TIMEARC_GSMTC_TITLE_CACHE_SEC 10
// Browser playback state is activity evidence, so never carry it into a later
// sampling second. Calls within the same second can still share the result.
#define TIMEARC_GSMTC_PLAYBACK_CACHE_SEC 0
#define TIMEARC_BROWSER_MEDIA_CACHE_SEC 30
#define TIMEARC_BROWSER_MEDIA_CACHE_SIZE 4
#define TIMEARC_BROWSER_SITE_HINT_SEC 600

static char g_gsmtc_cache_app[TA_MAX_NAME_BYTES];
static char g_gsmtc_cache_title[TA_MAX_TITLE_BYTES];
static TimeArcWinPlaybackState g_gsmtc_cache_playback_state =
    TIMEARC_WIN_PLAYBACK_UNKNOWN;
static time_t g_gsmtc_cache_time = 0;

typedef struct BrowserMediaTitleCache {
  char path[TA_MAX_PATH_BYTES];
  uint32_t process_id;
  char system_title[TA_MAX_TITLE_BYTES];
  char observed_title[TA_MAX_TITLE_BYTES];
  time_t last_seen_time;
} BrowserMediaTitleCache;

static BrowserMediaTitleCache
    g_browser_media_title_cache[TIMEARC_BROWSER_MEDIA_CACHE_SIZE];

typedef struct BrowserSiteHintCache {
  char path[TA_MAX_PATH_BYTES];
  char marker[32];
  time_t last_seen_time;
} BrowserSiteHintCache;

static BrowserSiteHintCache
    g_browser_site_hint_cache[TIMEARC_BROWSER_MEDIA_CACHE_SIZE];

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

TimeArcWinPlaybackState timearc_win_parse_playback_status(
    const char* playback_status) {
  if (playback_status == NULL || playback_status[0] == '\0') {
    return TIMEARC_WIN_PLAYBACK_UNKNOWN;
  }
  if (ascii_equal_case_insensitive(playback_status, "Playing")) {
    return TIMEARC_WIN_PLAYBACK_PLAYING;
  }
  if (ascii_equal_case_insensitive(playback_status, "Paused") ||
      ascii_equal_case_insensitive(playback_status, "Stopped") ||
      ascii_equal_case_insensitive(playback_status, "Closed")) {
    return TIMEARC_WIN_PLAYBACK_NOT_PLAYING;
  }
  return TIMEARC_WIN_PLAYBACK_UNKNOWN;
}

TimeArcWinPlaybackState timearc_win_merge_playback_state(
    TimeArcWinPlaybackState current, TimeArcWinPlaybackState candidate) {
  if (current == TIMEARC_WIN_PLAYBACK_PLAYING ||
      candidate == TIMEARC_WIN_PLAYBACK_PLAYING) {
    return TIMEARC_WIN_PLAYBACK_PLAYING;
  }
  if (current == TIMEARC_WIN_PLAYBACK_NOT_PLAYING ||
      candidate == TIMEARC_WIN_PLAYBACK_NOT_PLAYING) {
    return TIMEARC_WIN_PLAYBACK_NOT_PLAYING;
  }
  return TIMEARC_WIN_PLAYBACK_UNKNOWN;
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

// --- Windows.Media.Control (GSMTC) through the WinRT ABI ---------------------
//
// System media metadata used to come from a powershell.exe child per query.
// Each spawn cost ~0.5 s CPU and ~90 MB, and ran about once per sampling second
// while a browser held an audio session. The same WinRT API is now called
// in-process. MinGW ships no projection header for this namespace, so only the
// vtable prefixes TimeArc calls are declared; the IIDs and slot order come
// from the system Windows.Media.Control metadata. combase.dll is resolved at
// runtime, which keeps the service link line unchanged.

#define TIMEARC_GSMTC_ASYNC_TIMEOUT_MS 1200
// Re-request the session manager periodically so a restarted media broker
// cannot leave a stale manager in place for the life of the service.
#define TIMEARC_GSMTC_MANAGER_REFRESH_MS 30000
#define TIMEARC_GSMTC_FIELD_BYTES 1024

typedef struct TaHStringOpaque* TaHString;

typedef HRESULT(WINAPI* TaRoGetActivationFactoryFn)(TaHString class_id,
                                                    REFIID iid,
                                                    void** factory);
typedef HRESULT(WINAPI* TaWindowsCreateStringFn)(const wchar_t* source,
                                                 UINT32 length,
                                                 TaHString* out);
typedef HRESULT(WINAPI* TaWindowsDeleteStringFn)(TaHString value);
typedef const wchar_t*(WINAPI* TaWindowsGetStringRawBufferFn)(TaHString value,
                                                             UINT32* length);

#define TA_WINRT_DECLARE(Name)        \
  typedef struct Name##Vtbl Name##Vtbl; \
  typedef struct Name {               \
    const Name##Vtbl* lpVtbl;         \
  } Name;

// IUnknown + IInspectable prefix shared by every WinRT interface.
#define TA_WINRT_INSPECTABLE_SLOTS(Name)                                  \
  HRESULT(STDMETHODCALLTYPE* QueryInterface)(Name* self, REFIID riid,     \
                                             void** out);                 \
  ULONG(STDMETHODCALLTYPE* AddRef)(Name* self);                           \
  ULONG(STDMETHODCALLTYPE* Release)(Name* self);                          \
  void (*GetIids)(void);                                                  \
  void (*GetRuntimeClassName)(void);                                      \
  void (*GetTrustLevel)(void);

TA_WINRT_DECLARE(TaAsyncInfo)
TA_WINRT_DECLARE(TaAsyncOperation)
TA_WINRT_DECLARE(TaVectorView)
TA_WINRT_DECLARE(TaGsmtcManagerStatics)
TA_WINRT_DECLARE(TaGsmtcManager)
TA_WINRT_DECLARE(TaGsmtcSession)
TA_WINRT_DECLARE(TaGsmtcMediaProperties)
TA_WINRT_DECLARE(TaGsmtcPlaybackInfo)

// Windows.Foundation.IAsyncInfo
struct TaAsyncInfoVtbl {
  TA_WINRT_INSPECTABLE_SLOTS(TaAsyncInfo)
  HRESULT(STDMETHODCALLTYPE* get_Id)(TaAsyncInfo* self, UINT32* id);
  HRESULT(STDMETHODCALLTYPE* get_Status)(TaAsyncInfo* self, int* status);
  HRESULT(STDMETHODCALLTYPE* get_ErrorCode)(TaAsyncInfo* self, HRESULT* code);
  HRESULT(STDMETHODCALLTYPE* Cancel)(TaAsyncInfo* self);
  HRESULT(STDMETHODCALLTYPE* Close)(TaAsyncInfo* self);
};

// Windows.Foundation.IAsyncOperation<T>; T is always a runtime-class pointer.
struct TaAsyncOperationVtbl {
  TA_WINRT_INSPECTABLE_SLOTS(TaAsyncOperation)
  void (*put_Completed)(void);
  void (*get_Completed)(void);
  HRESULT(STDMETHODCALLTYPE* GetResults)(TaAsyncOperation* self,
                                         void** results);
};

// Windows.Foundation.Collections.IVectorView<T>
struct TaVectorViewVtbl {
  TA_WINRT_INSPECTABLE_SLOTS(TaVectorView)
  HRESULT(STDMETHODCALLTYPE* GetAt)(TaVectorView* self, UINT32 index,
                                    void** item);
  HRESULT(STDMETHODCALLTYPE* get_Size)(TaVectorView* self, UINT32* size);
};

// IGlobalSystemMediaTransportControlsSessionManagerStatics
struct TaGsmtcManagerStaticsVtbl {
  TA_WINRT_INSPECTABLE_SLOTS(TaGsmtcManagerStatics)
  HRESULT(STDMETHODCALLTYPE* RequestAsync)(TaGsmtcManagerStatics* self,
                                           TaAsyncOperation** operation);
};

// IGlobalSystemMediaTransportControlsSessionManager
struct TaGsmtcManagerVtbl {
  TA_WINRT_INSPECTABLE_SLOTS(TaGsmtcManager)
  void (*GetCurrentSession)(void);
  HRESULT(STDMETHODCALLTYPE* GetSessions)(TaGsmtcManager* self,
                                          TaVectorView** sessions);
};

// IGlobalSystemMediaTransportControlsSession
struct TaGsmtcSessionVtbl {
  TA_WINRT_INSPECTABLE_SLOTS(TaGsmtcSession)
  HRESULT(STDMETHODCALLTYPE* get_SourceAppUserModelId)(TaGsmtcSession* self,
                                                       TaHString* value);
  HRESULT(STDMETHODCALLTYPE* TryGetMediaPropertiesAsync)(
      TaGsmtcSession* self, TaAsyncOperation** operation);
  void (*GetTimelineProperties)(void);
  HRESULT(STDMETHODCALLTYPE* GetPlaybackInfo)(TaGsmtcSession* self,
                                              TaGsmtcPlaybackInfo** info);
};

// IGlobalSystemMediaTransportControlsSessionMediaProperties
struct TaGsmtcMediaPropertiesVtbl {
  TA_WINRT_INSPECTABLE_SLOTS(TaGsmtcMediaProperties)
  HRESULT(STDMETHODCALLTYPE* get_Title)(TaGsmtcMediaProperties* self,
                                        TaHString* value);
  void (*get_Subtitle)(void);
  void (*get_AlbumArtist)(void);
  HRESULT(STDMETHODCALLTYPE* get_Artist)(TaGsmtcMediaProperties* self,
                                         TaHString* value);
};

// IGlobalSystemMediaTransportControlsSessionPlaybackInfo
struct TaGsmtcPlaybackInfoVtbl {
  TA_WINRT_INSPECTABLE_SLOTS(TaGsmtcPlaybackInfo)
  void (*get_Controls)(void);
  HRESULT(STDMETHODCALLTYPE* get_PlaybackStatus)(TaGsmtcPlaybackInfo* self,
                                                 int* status);
};

// Windows.Foundation.IAsyncInfo
DEFINE_GUID(TA_IID_IAsyncInfo, 0x00000036, 0x0000, 0x0000, 0xc0, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x46);
// IGlobalSystemMediaTransportControlsSessionManagerStatics
DEFINE_GUID(TA_IID_GsmtcManagerStatics, 0x2050c4ee, 0x11a0, 0x57de, 0xae,
            0xd7, 0xc9, 0x7c, 0x70, 0x33, 0x82, 0x45);

enum {
  TA_ASYNC_STARTED = 0,
  TA_ASYNC_COMPLETED = 1,
};

typedef struct TaWinrtApi {
  int load_attempted;
  int available;
  TaRoGetActivationFactoryFn get_activation_factory;
  TaWindowsCreateStringFn create_string;
  TaWindowsDeleteStringFn delete_string;
  TaWindowsGetStringRawBufferFn get_raw_buffer;
} TaWinrtApi;

static TaWinrtApi g_winrt;
static TaGsmtcManagerStatics* g_gsmtc_statics = NULL;
static TaGsmtcManager* g_gsmtc_manager = NULL;
static ULONGLONG g_gsmtc_manager_tick = 0;

static int gsmtc_load_winrt(void) {
  if (g_winrt.load_attempted) {
    return g_winrt.available ? 0 : -1;
  }
  g_winrt.load_attempted = 1;

  HMODULE combase =
      LoadLibraryExW(L"combase.dll", NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (combase == NULL) {
    return -1;
  }
  // Cast through void (*)(void) so GCC accepts the FARPROC conversion.
  g_winrt.get_activation_factory = (TaRoGetActivationFactoryFn)(void (*)(void))
      GetProcAddress(combase, "RoGetActivationFactory");
  g_winrt.create_string = (TaWindowsCreateStringFn)(void (*)(void))
      GetProcAddress(combase, "WindowsCreateString");
  g_winrt.delete_string = (TaWindowsDeleteStringFn)(void (*)(void))
      GetProcAddress(combase, "WindowsDeleteString");
  g_winrt.get_raw_buffer = (TaWindowsGetStringRawBufferFn)(void (*)(void))
      GetProcAddress(combase, "WindowsGetStringRawBuffer");
  g_winrt.available = g_winrt.get_activation_factory != NULL &&
                      g_winrt.create_string != NULL &&
                      g_winrt.delete_string != NULL &&
                      g_winrt.get_raw_buffer != NULL;
  return g_winrt.available ? 0 : -1;
}

// Block until an async operation settles, bounded like the retired script's
// Task.Wait(1200). Return 0 only when it completed successfully.
static int gsmtc_wait_async(TaAsyncOperation* operation) {
  TaAsyncInfo* info = NULL;
  if (FAILED(operation->lpVtbl->QueryInterface(operation, &TA_IID_IAsyncInfo,
                                               (void**)&info)) ||
      info == NULL) {
    return -1;
  }

  const ULONGLONG deadline = GetTickCount64() + TIMEARC_GSMTC_ASYNC_TIMEOUT_MS;
  int status = TA_ASYNC_STARTED;
  for (;;) {
    if (FAILED(info->lpVtbl->get_Status(info, &status))) {
      status = -1;
      break;
    }
    if (status != TA_ASYNC_STARTED) {
      break;
    }
    if (GetTickCount64() >= deadline) {
      info->lpVtbl->Cancel(info);
      break;
    }
    Sleep(1);
  }
  info->lpVtbl->Release(info);
  return status == TA_ASYNC_COMPLETED ? 0 : -1;
}

// Await an operation and take its runtime-class result. Releases operation.
static void* gsmtc_await_result(TaAsyncOperation* operation) {
  if (operation == NULL) {
    return NULL;
  }
  void* result = NULL;
  if (gsmtc_wait_async(operation) != 0 ||
      FAILED(operation->lpVtbl->GetResults(operation, &result))) {
    result = NULL;
  }
  operation->lpVtbl->Release(operation);
  return result;
}

static void gsmtc_release_manager(void) {
  if (g_gsmtc_manager != NULL) {
    g_gsmtc_manager->lpVtbl->Release(g_gsmtc_manager);
    g_gsmtc_manager = NULL;
  }
}

static TaGsmtcManager* gsmtc_manager(void) {
  const ULONGLONG now = GetTickCount64();
  if (g_gsmtc_manager != NULL &&
      now - g_gsmtc_manager_tick < TIMEARC_GSMTC_MANAGER_REFRESH_MS) {
    return g_gsmtc_manager;
  }
  gsmtc_release_manager();
  if (gsmtc_load_winrt() != 0) {
    return NULL;
  }

  if (g_gsmtc_statics == NULL) {
    static const wchar_t kClassName[] =
        L"Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager";
    TaHString class_id = NULL;
    if (FAILED(g_winrt.create_string(
            kClassName, (UINT32)(sizeof(kClassName) / sizeof(kClassName[0]) - 1),
            &class_id))) {
      return NULL;
    }
    const HRESULT hr = g_winrt.get_activation_factory(
        class_id, &TA_IID_GsmtcManagerStatics, (void**)&g_gsmtc_statics);
    g_winrt.delete_string(class_id);
    if (FAILED(hr)) {
      g_gsmtc_statics = NULL;
      return NULL;
    }
  }

  TaAsyncOperation* operation = NULL;
  if (FAILED(g_gsmtc_statics->lpVtbl->RequestAsync(g_gsmtc_statics,
                                                   &operation))) {
    return NULL;
  }
  g_gsmtc_manager = (TaGsmtcManager*)gsmtc_await_result(operation);
  g_gsmtc_manager_tick = now;
  return g_gsmtc_manager;
}

// Convert and free an HSTRING. Returns 1 when it held a non-whitespace
// character, matching the retired script's IsNullOrWhiteSpace check.
static int gsmtc_take_hstring(TaHString value, char* dst, size_t dst_size) {
  dst[0] = '\0';
  if (value == NULL) {
    return 0;
  }
  int has_text = 0;
  const wchar_t* raw = g_winrt.get_raw_buffer(value, NULL);
  if (raw != NULL) {
    for (const wchar_t* c = raw; *c != L'\0'; ++c) {
      if (!iswspace(*c)) {
        has_text = 1;
        break;
      }
    }
    wide_to_utf8(raw, dst, dst_size);
  }
  g_winrt.delete_string(value);
  return has_text;
}

// PlaybackStatus enum names, as the retired script printed them via ToString().
static const char* gsmtc_playback_status_name(int status) {
  static const char* const kNames[] = {"Closed",  "Opened",  "Changing",
                                       "Stopped", "Playing", "Paused"};
  if (status < 0 || status >= (int)(sizeof(kNames) / sizeof(kNames[0]))) {
    return "";
  }
  return kNames[status];
}

typedef struct GsmtcSessionInfo {
  char source[TA_MAX_NAME_BYTES];
  char title[TIMEARC_GSMTC_FIELD_BYTES];
  char artist[TIMEARC_GSMTC_FIELD_BYTES];
  const char* status;
} GsmtcSessionInfo;

// Read one session if it belongs to app_name and reports a non-blank title.
// Return 0 when out holds a usable entry.
static int gsmtc_read_session(TaGsmtcSession* session,
                              const char* app_name,
                              GsmtcSessionInfo* out) {
  memset(out, 0, sizeof(*out));
  out->status = "";

  TaHString source = NULL;
  if (FAILED(session->lpVtbl->get_SourceAppUserModelId(session, &source))) {
    return -1;
  }
  gsmtc_take_hstring(source, out->source, sizeof(out->source));
  if (!gsmtc_source_matches_app(out->source, app_name)) {
    return -1;
  }

  TaAsyncOperation* operation = NULL;
  if (FAILED(session->lpVtbl->TryGetMediaPropertiesAsync(session,
                                                         &operation))) {
    return -1;
  }
  TaGsmtcMediaProperties* props =
      (TaGsmtcMediaProperties*)gsmtc_await_result(operation);
  if (props == NULL) {
    return -1;
  }
  TaHString title = NULL;
  TaHString artist = NULL;
  const int has_title =
      SUCCEEDED(props->lpVtbl->get_Title(props, &title)) &&
      gsmtc_take_hstring(title, out->title, sizeof(out->title));
  if (SUCCEEDED(props->lpVtbl->get_Artist(props, &artist))) {
    gsmtc_take_hstring(artist, out->artist, sizeof(out->artist));
  }
  props->lpVtbl->Release(props);
  if (!has_title) {
    return -1;
  }

  // Older builds may not report playback status; keep it empty (UNKNOWN).
  TaGsmtcPlaybackInfo* info = NULL;
  if (SUCCEEDED(session->lpVtbl->GetPlaybackInfo(session, &info)) &&
      info != NULL) {
    int status = -1;
    if (SUCCEEDED(info->lpVtbl->get_PlaybackStatus(info, &status))) {
      out->status = gsmtc_playback_status_name(status);
    }
    info->lpVtbl->Release(info);
  }
  return 0;
}

static void gsmtc_shutdown(void) {
  gsmtc_release_manager();
  if (g_gsmtc_statics != NULL) {
    g_gsmtc_statics->lpVtbl->Release(g_gsmtc_statics);
    g_gsmtc_statics = NULL;
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

static int query_gsmtc_sessions(const char* app_name,
                                char* out_title,
                                size_t out_title_size,
                                TimeArcWinPlaybackState* out_playback_state) {
  TaGsmtcManager* manager = gsmtc_manager();
  if (manager == NULL) {
    return -1;
  }
  TaVectorView* sessions = NULL;
  if (FAILED(manager->lpVtbl->GetSessions(manager, &sessions)) ||
      sessions == NULL) {
    // Drop a manager whose broker connection went away; retry next poll.
    gsmtc_release_manager();
    return -1;
  }
  UINT32 count = 0;
  if (FAILED(sessions->lpVtbl->get_Size(sessions, &count))) {
    count = 0;
  }

  char selected_source[TA_MAX_NAME_BYTES] = {0};
  int matched = 0;
  for (UINT32 i = 0; i < count; ++i) {
    TaGsmtcSession* session = NULL;
    if (FAILED(sessions->lpVtbl->GetAt(sessions, i, (void**)&session)) ||
        session == NULL) {
      continue;
    }
    GsmtcSessionInfo info;
    const int readable = gsmtc_read_session(session, app_name, &info) == 0;
    session->lpVtbl->Release(session);
    if (!readable) {
      continue;
    }

    char candidate_title[TA_MAX_TITLE_BYTES];
    format_gsmtc_title(info.title, info.artist, candidate_title,
                       sizeof(candidate_title));
    if (candidate_title[0] != '\0') {
      const TimeArcWinPlaybackState candidate_state =
          timearc_win_parse_playback_status(info.status);
      const TimeArcWinPlaybackState merged_state =
          timearc_win_merge_playback_state(*out_playback_state,
                                           candidate_state);
      if (!matched || merged_state != *out_playback_state) {
        copy_string(selected_source, sizeof(selected_source), info.source);
        copy_string(out_title, out_title_size, candidate_title);
        *out_playback_state = merged_state;
      }
      matched = 1;
      if (*out_playback_state == TIMEARC_WIN_PLAYBACK_PLAYING) {
        break;
      }
    }
  }
  sessions->lpVtbl->Release(sessions);

  if (matched) {
    copy_string(g_gsmtc_cache_app, sizeof(g_gsmtc_cache_app), selected_source);
    copy_string(g_gsmtc_cache_title, sizeof(g_gsmtc_cache_title), out_title);
    g_gsmtc_cache_playback_state = *out_playback_state;
    g_gsmtc_cache_time = time(NULL);
  }
  return matched ? 0 : -1;
}

static int query_gsmtc_media_info(const char* app_name,
                                  char* out_title,
                                  size_t out_title_size,
                                  int require_fresh_playback,
                                  TimeArcWinPlaybackState* out_playback_state) {
  if (app_name == NULL || app_name[0] == '\0' || out_title == NULL ||
      out_title_size == 0 || out_playback_state == NULL) {
    return -1;
  }

  out_title[0] = '\0';
  *out_playback_state = TIMEARC_WIN_PLAYBACK_UNKNOWN;
  time_t now = time(NULL);
  const int cache_seconds = require_fresh_playback
                                ? TIMEARC_GSMTC_PLAYBACK_CACHE_SEC
                                : TIMEARC_GSMTC_TITLE_CACHE_SEC;
  if (g_gsmtc_cache_title[0] != '\0' &&
      now - g_gsmtc_cache_time <= cache_seconds &&
      gsmtc_source_matches_app(g_gsmtc_cache_app, app_name)) {
    copy_string(out_title, out_title_size, g_gsmtc_cache_title);
    *out_playback_state = g_gsmtc_cache_playback_state;
    return 0;
  }

  // Builds that expose metadata without playback status leave the status
  // UNKNOWN, so activity then falls back to the WASAPI peak path.
  return query_gsmtc_sessions(app_name, out_title, out_title_size,
                              out_playback_state);
}

static int should_ignore_audio_process(const char* path) {
  // Ignore Wallpaper Engine audio as desktop decoration, not user media.
  return contains_ascii_case_insensitive(path, "\\wallpaper_engine\\");
}

typedef struct TimeArcWinAudioEvidence {
  int active;
  int muted;
  float volume;
  float peak;
} TimeArcWinAudioEvidence;

static void sample_audio_evidence(IAudioSessionControl* control,
                                  TimeArcWinAudioEvidence* evidence) {
  memset(evidence, 0, sizeof(*evidence));
  evidence->volume = 1.0f;

  AudioSessionState state = AudioSessionStateInactive;
  if (SUCCEEDED(IAudioSessionControl_GetState(control, &state))) {
    evidence->active = state == AudioSessionStateActive;
  }

  ISimpleAudioVolume* volume = NULL;
  if (SUCCEEDED(IAudioSessionControl_QueryInterface(
          control, &IID_ISimpleAudioVolume, (void**)&volume)) &&
      volume != NULL) {
    BOOL muted = FALSE;
    float level = 1.0f;
    if (SUCCEEDED(ISimpleAudioVolume_GetMute(volume, &muted))) {
      evidence->muted = muted ? 1 : 0;
    }
    if (SUCCEEDED(ISimpleAudioVolume_GetMasterVolume(volume, &level))) {
      evidence->volume = level;
    }
    ISimpleAudioVolume_Release(volume);
  }

  IAudioMeterInformation* meter = NULL;
  if (FAILED(IAudioSessionControl_QueryInterface(
          control, &IID_IAudioMeterInformation, (void**)&meter)) ||
      meter == NULL) {
    return;
  }

  IAudioMeterInformation_GetPeakValue(meter, &evidence->peak);
  IAudioMeterInformation_Release(meter);
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

static int is_browser_path(const char* path) {
  return contains_ascii_case_insensitive(path, "chrome.exe") ||
         contains_ascii_case_insensitive(path, "msedge.exe") ||
         contains_ascii_case_insensitive(path, "firefox.exe") ||
         contains_ascii_case_insensitive(path, "brave.exe") ||
         contains_ascii_case_insensitive(path, "vivaldi.exe") ||
         contains_ascii_case_insensitive(path, "opera.exe");
}

static const char* known_browser_site_marker(const char* title) {
  if (contains_ascii_case_insensitive(title, "bilibili") ||
      contains_ascii_case_insensitive(title, "b23.tv")) {
    return "bilibili";
  }
  if (contains_ascii_case_insensitive(title, "youtube") ||
      contains_ascii_case_insensitive(title, "youtu.be")) {
    return "YouTube";
  }
  if (contains_ascii_case_insensitive(title, "iqiyi")) return "iqiyi";
  if (contains_ascii_case_insensitive(title, "youku")) return "youku";
  if (contains_ascii_case_insensitive(title, "v.qq.com")) return "v.qq.com";
  return NULL;
}

void timearc_win_observe_browser_site_hint_at(const char* path,
                                              const char* window_title,
                                              int64_t now_sec) {
  if (!is_browser_path(path)) return;
  const char* marker = known_browser_site_marker(window_title);
  if (marker == NULL) return;

  const time_t now = (time_t)now_sec;
  BrowserSiteHintCache* available = NULL;
  BrowserSiteHintCache* oldest = &g_browser_site_hint_cache[0];
  for (size_t i = 0; i < TIMEARC_BROWSER_MEDIA_CACHE_SIZE; ++i) {
    BrowserSiteHintCache* entry = &g_browser_site_hint_cache[i];
    if (entry->path[0] == '\0' ||
        now - entry->last_seen_time > TIMEARC_BROWSER_SITE_HINT_SEC) {
      if (available == NULL) available = entry;
    } else if (strcmp(entry->path, path) == 0) {
      copy_string(entry->marker, sizeof(entry->marker), marker);
      entry->last_seen_time = now;
      return;
    }
    if (entry->last_seen_time < oldest->last_seen_time) oldest = entry;
  }

  BrowserSiteHintCache* entry = available != NULL ? available : oldest;
  memset(entry, 0, sizeof(*entry));
  copy_string(entry->path, sizeof(entry->path), path);
  copy_string(entry->marker, sizeof(entry->marker), marker);
  entry->last_seen_time = now;
}

void timearc_win_observe_browser_site_hint(const char* path,
                                           const char* window_title) {
  timearc_win_observe_browser_site_hint_at(path, window_title,
                                           (int64_t)time(NULL));
}

static const char* recent_browser_site_hint(const char* path,
                                            time_t now) {
  for (size_t i = 0; i < TIMEARC_BROWSER_MEDIA_CACHE_SIZE; ++i) {
    BrowserSiteHintCache* entry = &g_browser_site_hint_cache[i];
    if (entry->path[0] != '\0' && strcmp(entry->path, path) == 0 &&
        now - entry->last_seen_time <= TIMEARC_BROWSER_SITE_HINT_SEC) {
      return entry->marker;
    }
  }
  return NULL;
}

static void copy_title_with_recent_site_hint(char* dst, size_t dst_size,
                                             const char* path,
                                             const char* title, time_t now) {
  copy_string(dst, dst_size, title);
  const char* marker = recent_browser_site_hint(path, now);
  if (marker == NULL || known_browser_site_marker(dst) != NULL) return;
  const size_t used = strlen(dst);
  if (used + 3 < dst_size) {
    snprintf(dst + used, dst_size - used, " - %s", marker);
  }
}

static int executable_basename_equals(const char* path, const char* name) {
  if (path == NULL || name == NULL) return 0;
  const char* basename = path;
  for (const char* cursor = path; *cursor != '\0'; ++cursor) {
    if (*cursor == '\\' || *cursor == '/') basename = cursor + 1;
  }
  return _stricmp(basename, name) == 0;
}

static int is_voice_chat_path(const char* path) {
  return executable_basename_equals(path, "Discord.exe") ||
         executable_basename_equals(path, "Oopz.exe") ||
         executable_basename_equals(path, "KOOK.exe") ||
         executable_basename_equals(path, "KaiHeiLa.exe");
}

int timearc_win_should_record_audio_session(
    const char* path, int session_active, int muted, float volume, float peak,
    TimeArcWinPlaybackState playback_state) {
  if (is_browser_path(path) &&
      playback_state != TIMEARC_WIN_PLAYBACK_UNKNOWN) {
    return playback_state == TIMEARC_WIN_PLAYBACK_PLAYING;
  }
  if (is_voice_chat_path(path)) {
    return session_active && !muted && volume > 0.001f;
  }
  return session_active && !muted && volume > 0.001f &&
         peak > TIMEARC_AUDIO_PEAK_THRESHOLD;
}

static int foreground_title_matches_system_media(const char* foreground_title,
                                                 const char* system_title) {
  if (foreground_title == NULL || foreground_title[0] == '\0' ||
      system_title == NULL || system_title[0] == '\0') {
    return 0;
  }
  if (contains_ascii_case_insensitive(foreground_title, system_title)) {
    return 1;
  }

  const char* artist_separator = strstr(system_title, " - ");
  if (artist_separator == NULL || artist_separator - system_title < 3) {
    return 0;
  }
  char media_title[TA_MAX_TITLE_BYTES];
  size_t title_len = (size_t)(artist_separator - system_title);
  if (title_len >= sizeof(media_title)) title_len = sizeof(media_title) - 1;
  memcpy(media_title, system_title, title_len);
  media_title[title_len] = '\0';
  return contains_ascii_case_insensitive(foreground_title, media_title);
}

void timearc_win_reset_observed_media_title_cache(void) {
  memset(g_browser_media_title_cache, 0, sizeof(g_browser_media_title_cache));
  memset(g_browser_site_hint_cache, 0, sizeof(g_browser_site_hint_cache));
}

static const char* stable_browser_media_title(
    const char* path, uint32_t process_id, const char* system_media_title,
    const char* matching_foreground_title, time_t now) {
  BrowserMediaTitleCache* available = NULL;
  BrowserMediaTitleCache* oldest = &g_browser_media_title_cache[0];
  for (size_t i = 0; i < TIMEARC_BROWSER_MEDIA_CACHE_SIZE; ++i) {
    BrowserMediaTitleCache* entry = &g_browser_media_title_cache[i];
    const int expired = entry->observed_title[0] == '\0' ||
                        now - entry->last_seen_time >
                            TIMEARC_BROWSER_MEDIA_CACHE_SEC;
    if (expired && available == NULL) available = entry;
    if (!expired && strcmp(entry->path, path) == 0 &&
        entry->process_id == process_id &&
        strcmp(entry->system_title, system_media_title) == 0) {
      if (foreground_title_matches_system_media(matching_foreground_title,
                                                system_media_title) &&
          strcmp(entry->observed_title, matching_foreground_title) != 0) {
        const char* old_marker =
            known_browser_site_marker(entry->observed_title);
        const char* new_marker =
            known_browser_site_marker(matching_foreground_title);
        if (old_marker == NULL || new_marker != NULL) {
          copy_string(entry->observed_title, sizeof(entry->observed_title),
                      matching_foreground_title);
        }
      }
      entry->last_seen_time = now;
      return entry->observed_title;
    }
    if (entry->last_seen_time < oldest->last_seen_time) oldest = entry;
  }

  BrowserMediaTitleCache* entry = available != NULL ? available : oldest;
  memset(entry, 0, sizeof(*entry));
  copy_string(entry->path, sizeof(entry->path), path);
  entry->process_id = process_id;
  copy_string(entry->system_title, sizeof(entry->system_title),
              system_media_title);
  const char* initial_title =
      foreground_title_matches_system_media(matching_foreground_title,
                                            system_media_title)
          ? matching_foreground_title
          : system_media_title;
  copy_title_with_recent_site_hint(entry->observed_title,
                                   sizeof(entry->observed_title), path,
                                   initial_title, now);
  entry->last_seen_time = now;
  return entry->observed_title;
}

const char* timearc_win_preferred_observed_media_title_at(
    const char* path, uint32_t process_id, const char* system_media_title,
    const char* matching_foreground_title, int64_t now_sec) {
  if (system_media_title != NULL && system_media_title[0] != '\0') {
    if (is_browser_path(path)) {
      return stable_browser_media_title(path, process_id, system_media_title,
                                        matching_foreground_title,
                                        (time_t)now_sec);
    }
    return system_media_title;
  }
  if (is_browser_path(path) && matching_foreground_title != NULL &&
      matching_foreground_title[0] != '\0') {
    return matching_foreground_title;
  }
  return matching_foreground_title;
}

const char* timearc_win_preferred_observed_media_title(
    const char* path, uint32_t process_id, const char* system_media_title,
    const char* matching_foreground_title) {
  return timearc_win_preferred_observed_media_title_at(
      path, process_id, system_media_title, matching_foreground_title,
      (int64_t)time(NULL));
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
                                      int query_system_media,
                                      char* scratch_title,
                                      size_t scratch_title_size,
                                      TimeArcWinPlaybackState*
                                          out_playback_state) {
  const int has_system_title = query_system_media &&
      query_gsmtc_media_info(app_name, scratch_title, scratch_title_size,
                             is_browser_path(path), out_playback_state) == 0;
  const char* foreground_title =
      matching_foreground_title(foreground, pid, path);
  const char* preferred = timearc_win_preferred_observed_media_title(
      path, (uint32_t)pid, has_system_title ? scratch_title : NULL,
      foreground_title);
  if (preferred != NULL) {
    return preferred;
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
  if (foreground_ptr != NULL) {
    timearc_win_observe_browser_site_hint(foreground_ptr->exec_path,
                                          foreground_ptr->window_title);
  }

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
        TimeArcWinAudioEvidence evidence;
        sample_audio_evidence(control, &evidence);
        const char* app_name = basename_from_path(path);
        char media_title[TA_MAX_TITLE_BYTES];
        TimeArcWinPlaybackState playback_state =
            TIMEARC_WIN_PLAYBACK_UNKNOWN;
        const int browser = is_browser_path(path);
        const int voice_chat = is_voice_chat_path(path);
        const char* title = NULL;
        if (browser) {
          title = choose_media_title(
              control, foreground_ptr, pid, path, app_name, 1, media_title,
              sizeof(media_title), &playback_state);
        }
        if (!timearc_win_should_record_audio_session(
                path, evidence.active, evidence.muted, evidence.volume,
                evidence.peak, playback_state)) {
          IAudioSessionControl2_Release(control2);
          IAudioSessionControl_Release(control);
          continue;
        }
        if (!browser) {
          // Ordinary apps must pass the cheap WASAPI activity policy before
          // spawning the GSMTC query. Voice-chat apps need no media metadata.
          title = choose_media_title(
              control, foreground_ptr, pid, path, app_name, !voice_chat,
              media_title, sizeof(media_title), &playback_state);
        }
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
  // WinRT objects must be released while COM is still initialized.
  gsmtc_shutdown();
  if (g_com_initialized && g_should_uninitialize_com) {
    CoUninitialize();
  }
  g_com_initialized = 0;
  g_should_uninitialize_com = 0;
  timearc_win_reset_observed_media_title_cache();
}
