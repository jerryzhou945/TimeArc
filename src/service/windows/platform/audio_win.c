#include "audio_win.h"

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

static int g_com_initialized = 0;
static int g_should_uninitialize_com = 0;

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
    g_com_initialized = 1;
    g_should_uninitialize_com = 0;
    return 0;
  }

  return -1;
}

static int app_already_added(const AppInfo* apps,
                             size_t count,
                             const char* exec_path) {
  for (size_t i = 0; i < count; ++i) {
    if (strcmp(apps[i].exec_path, exec_path) == 0) {
      return 1;
    }
  }

  return 0;
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

static int should_ignore_audio_process(const char* path) {
  // Wallpaper Engine commonly exposes a continuous audio session for animated
  // wallpapers/visualizers. Treat it as desktop decoration, not intentional
  // media playback.
  return contains_ascii_case_insensitive(path, "\\wallpaper_engine\\");
}

static int session_has_audio_peak(IAudioSessionControl* control) {
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

static void fill_audio_app(AppInfo* app, DWORD pid, const char* path) {
  memset(app, 0, sizeof(*app));
  app->process_id = (uint32_t)pid;
  app->timestamp = time(NULL);
  app->active_status = true;
  copy_string(app->exec_path, sizeof(app->exec_path), path);
  copy_string(app->app_name, sizeof(app->app_name), basename_from_path(path));
  copy_string(app->display_name, sizeof(app->display_name), app->app_name);
  copy_string(app->window_title, sizeof(app->window_title), "Audio playback");
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

  IMMDeviceEnumerator* device_enumerator = NULL;
  IMMDevice* device = NULL;
  IAudioSessionManager2* session_manager = NULL;
  IAudioSessionEnumerator* session_enumerator = NULL;

  HRESULT hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL,
                                &IID_IMMDeviceEnumerator,
                                (void**)&device_enumerator);
  if (FAILED(hr) || device_enumerator == NULL) {
    return -1;
  }

  hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(
      device_enumerator, eRender, eConsole, &device);
  if (SUCCEEDED(hr) && device != NULL) {
    hr = IMMDevice_Activate(device, &IID_IAudioSessionManager2, CLSCTX_ALL,
                            NULL, (void**)&session_manager);
  }
  if (SUCCEEDED(hr) && session_manager != NULL) {
    hr = IAudioSessionManager2_GetSessionEnumerator(session_manager,
                                                    &session_enumerator);
  }

  if (FAILED(hr) || session_enumerator == NULL) {
    if (session_manager != NULL) IAudioSessionManager2_Release(session_manager);
    if (device != NULL) IMMDevice_Release(device);
    IMMDeviceEnumerator_Release(device_enumerator);
    return -1;
  }

  int session_count = 0;
  IAudioSessionEnumerator_GetCount(session_enumerator, &session_count);

  size_t added = 0;
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
    if (system_sound_hr == S_OK ||
        FAILED(IAudioSessionControl2_GetProcessId(control2, &pid)) ||
        pid == 0) {
      IAudioSessionControl2_Release(control2);
      IAudioSessionControl_Release(control);
      continue;
    }

    char path[TA_MAX_PATH_BYTES];
    if (query_process_path(pid, path, sizeof(path)) == 0 &&
        !should_ignore_audio_process(path) &&
        !app_already_added(out_apps, added, path)) {
      fill_audio_app(&out_apps[added], pid, path);
      ++added;
    }

    IAudioSessionControl2_Release(control2);
    IAudioSessionControl_Release(control);
  }

  IAudioSessionEnumerator_Release(session_enumerator);
  IAudioSessionManager2_Release(session_manager);
  IMMDevice_Release(device);
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
