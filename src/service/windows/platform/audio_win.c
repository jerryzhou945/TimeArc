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
#define TIMEARC_GSMTC_TITLE_CACHE_SEC 10
// Browser playback state is activity evidence, so never carry it into a later
// sampling second. Calls within the same second can still share the result.
#define TIMEARC_GSMTC_PLAYBACK_CACHE_SEC 0
#define TIMEARC_BROWSER_MEDIA_CACHE_SEC 30
#define TIMEARC_BROWSER_MEDIA_CACHE_SIZE 4

static const char* kGsmtcTitleOnlyQueryCommand =
    "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass "
    "-EncodedCommand "
    "WwBDAG8AbgBzAG8AbABlAF0AOgA6AE8AdQB0AHAAdQB0AEUAbgBjAG8AZABpAG4AZwA9AFsAUwB5AHMAdABlAG0ALgBUAGUAeAB0AC4AVQBUAEYAOABFAG4AYwBvAGQAaQBuAGcAXQA6ADoAbgBlAHcAKAAkAGYAYQBsAHMAZQApAAoAJABuAHUAbABsACAAPQAgAFsAVwBpAG4AZABvAHcAcwAuAE0AZQBkAGkAYQAuAEMAbwBuAHQAcgBvAGwALgBHAGwAbwBiAGEAbABTAHkAcwB0AGUAbQBNAGUAZABpAGEAVAByAGEAbgBzAHAAbwByAHQAQwBvAG4AdAByAG8AbABzAFMAZQBzAHMAaQBvAG4ATQBhAG4AYQBnAGUAcgAsACAAVwBpAG4AZABvAHcAcwAuAE0AZQBkAGkAYQAuAEMAbwBuAHQAcgBvAGwALAAgAEMAbwBuAHQAZQBuAHQAVAB5AHAAZQA9AFcAaQBuAGQAbwB3AHMAUgB1AG4AdABpAG0AZQBdAAoAJABuAHUAbABsACAAPQAgAFsAVwBpAG4AZABvAHcAcwAuAE0AZQBkAGkAYQAuAEMAbwBuAHQAcgBvAGwALgBHAGwAbwBiAGEAbABTAHkAcwB0AGUAbQBNAGUAZABpAGEAVAByAGEAbgBzAHAAbwByAHQAQwBvAG4AdAByAG8AbABzAFMAZQBzAHMAaQBvAG4ATQBlAGQAaQBhAFAAcgBvAHAAZQByAHQAaQBlAHMALAAgAFcAaQBuAGQAbwB3AHMALgBNAGUAZABpAGEALgBDAG8AbgB0AHIAbwBsACwAIABDAG8AbgB0AGUAbgB0AFQAeQBwAGUAPQBXAGkAbgBkAG8AdwBzAFIAdQBuAHQAaQBtAGUAXQAKAEEAZABkAC0AVAB5AHAAZQAgAC0AQQBzAHMAZQBtAGIAbAB5AE4AYQBtAGUAIABTAHkAcwB0AGUAbQAuAFIAdQBuAHQAaQBtAGUALgBXAGkAbgBkAG8AdwBzAFIAdQBuAHQAaQBtAGUACgBmAHUAbgBjAHQAaQBvAG4AIABBAHcAYQBpAHQAKAAkAG8AcAAsACAAWwBUAHkAcABlAF0AJAByAGUAcwB1AGwAdABUAHkAcABlACkAIAB7AAoAIAAgACQAbQBlAHQAaABvAGQAcwAgAD0AIABbAFMAeQBzAHQAZQBtAC4AVwBpAG4AZABvAHcAcwBSAHUAbgB0AGkAbQBlAFMAeQBzAHQAZQBtAEUAeAB0AGUAbgBzAGkAbwBuAHMAXQAuAEcAZQB0AE0AZQB0AGgAbwBkAHMAKAApACAAfAAgAFcAaABlAHIAZQAtAE8AYgBqAGUAYwB0ACAAewAgACQAXwAuAE4AYQBtAGUAIAAtAGUAcQAgACcAQQBzAFQAYQBzAGsAJwAgAC0AYQBuAGQAIAAkAF8ALgBJAHMARwBlAG4AZQByAGkAYwBNAGUAdABoAG8AZABEAGUAZgBpAG4AaQB0AGkAbwBuACAALQBhAG4AZAAgACQAXwAuAEcAZQB0AFAAYQByAGEAbQBlAHQAZQByAHMAKAApAC4AQwBvAHUAbgB0ACAALQBlAHEAIAAxACAAfQAKACAAIAAkAG0AZQB0AGgAbwBkACAAPQAgACQAbQBlAHQAaABvAGQAcwBbADAAXQAuAE0AYQBrAGUARwBlAG4AZQByAGkAYwBNAGUAdABoAG8AZAAoACQAcgBlAHMAdQBsAHQAVAB5AHAAZQApAAoAIAAgACQAdABhAHMAawAgAD0AIAAkAG0AZQB0AGgAbwBkAC4ASQBuAHYAbwBrAGUAKAAkAG4AdQBsAGwALAAgAEAAKAAkAG8AcAApACkACgAgACAAJAB0AGEAcwBrAC4AVwBhAGkAdAAoADEAMgAwADAAKQAgAHwAIABPAHUAdAAtAE4AdQBsAGwACgAgACAAaQBmACAAKAAtAG4AbwB0ACAAJAB0AGEAcwBrAC4ASQBzAEMAbwBtAHAAbABlAHQAZQBkACkAIAB7ACAAcgBlAHQAdQByAG4AIAAkAG4AdQBsAGwAIAB9AAoAIAAgACQAdABhAHMAawAuAFIAZQBzAHUAbAB0AAoAfQAKACQAbQBhAG4AYQBnAGUAcgAgAD0AIABBAHcAYQBpAHQAIAAoAFsAVwBpAG4AZABvAHcAcwAuAE0AZQBkAGkAYQAuAEMAbwBuAHQAcgBvAGwALgBHAGwAbwBiAGEAbABTAHkAcwB0AGUAbQBNAGUAZABpAGEAVAByAGEAbgBzAHAAbwByAHQAQwBvAG4AdAByAG8AbABzAFMAZQBzAHMAaQBvAG4ATQBhAG4AYQBnAGUAcgBdADoAOgBSAGUAcQB1AGUAcwB0AEEAcwB5AG4AYwAoACkAKQAgACgAWwBXAGkAbgBkAG8AdwBzAC4ATQBlAGQAaQBhAC4AQwBvAG4AdAByAG8AbAAuAEcAbABvAGIAYQBsAFMAeQBzAHQAZQBtAE0AZQBkAGkAYQBUAHIAYQBuAHMAcABvAHIAdABDAG8AbgB0AHIAbwBsAHMAUwBlAHMAcwBpAG8AbgBNAGEAbgBhAGcAZQByAF0AKQAKAGkAZgAgACgAJABuAHUAbABsACAALQBlAHEAIAAkAG0AYQBuAGEAZwBlAHIAKQAgAHsAIABlAHgAaQB0ACAAMAAgAH0ACgBmAG8AcgBlAGEAYwBoACAAKAAkAHMAZQBzAHMAaQBvAG4AIABpAG4AIAAkAG0AYQBuAGEAZwBlAHIALgBHAGUAdABTAGUAcwBzAGkAbwBuAHMAKAApACkAIAB7AAoAIAAgACQAcAByAG8AcABzACAAPQAgAEEAdwBhAGkAdAAgACgAJABzAGUAcwBzAGkAbwBuAC4AVAByAHkARwBlAHQATQBlAGQAaQBhAFAAcgBvAHAAZQByAHQAaQBlAHMAQQBzAHkAbgBjACgAKQApACAAKABbAFcAaQBuAGQAbwB3AHMALgBNAGUAZABpAGEALgBDAG8AbgB0AHIAbwBsAC4ARwBsAG8AYgBhAGwAUwB5AHMAdABlAG0ATQBlAGQAaQBhAFQAcgBhAG4AcwBwAG8AcgB0AEMAbwBuAHQAcgBvAGwAcwBTAGUAcwBzAGkAbwBuAE0AZQBkAGkAYQBQAHIAbwBwAGUAcgB0AGkAZQBzAF0AKQAKACAAIABpAGYAIAAoACQAbgB1AGwAbAAgAC0AZQBxACAAJABwAHIAbwBwAHMAKQAgAHsAIABjAG8AbgB0AGkAbgB1AGUAIAB9AAoAIAAgACQAcwBvAHUAcgBjAGUAIAA9ACAAJABzAGUAcwBzAGkAbwBuAC4AUwBvAHUAcgBjAGUAQQBwAHAAVQBzAGUAcgBNAG8AZABlAGwASQBkAAoAIAAgACQAdABpAHQAbABlACAAPQAgACQAcAByAG8AcABzAC4AVABpAHQAbABlAAoAIAAgACQAYQByAHQAaQBzAHQAIAA9ACAAJABwAHIAbwBwAHMALgBBAHIAdABpAHMAdAAKACAAIABpAGYAIAAoAC0AbgBvAHQAIABbAHMAdAByAGkAbgBnAF0AOgA6AEkAcwBOAHUAbABsAE8AcgBXAGgAaQB0AGUAUwBwAGEAYwBlACgAJAB0AGkAdABsAGUAKQApACAAewAKACAAIAAgACAAIgAkAHMAbwB1AHIAYwBlAGAAdAAkAHQAaQB0AGwAZQBgAHQAJABhAHIAdABpAHMAdAAiAAoAIAAgAH0ACgB9AAoA";

static const char* kGsmtcQueryCommand =
    "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass "
    "-EncodedCommand "
    "WwBDAG8AbgBzAG8AbABlAF0AOgA6AE8AdQB0AHAAdQB0AEUAbgBjAG8AZABpAG4AZwA9AFsAUwB5AHMAdABlAG0ALgBUAGUA"
    "eAB0AC4AVQBUAEYAOABFAG4AYwBvAGQAaQBuAGcAXQA6ADoAbgBlAHcAKAAkAGYAYQBsAHMAZQApAAoAJABuAHUAbABsAD0A"
    "WwBXAGkAbgBkAG8AdwBzAC4ATQBlAGQAaQBhAC4AQwBvAG4AdAByAG8AbAAuAEcAbABvAGIAYQBsAFMAeQBzAHQAZQBtAE0A"
    "ZQBkAGkAYQBUAHIAYQBuAHMAcABvAHIAdABDAG8AbgB0AHIAbwBsAHMAUwBlAHMAcwBpAG8AbgBNAGEAbgBhAGcAZQByACwA"
    "VwBpAG4AZABvAHcAcwAuAE0AZQBkAGkAYQAuAEMAbwBuAHQAcgBvAGwALABDAG8AbgB0AGUAbgB0AFQAeQBwAGUAPQBXAGkA"
    "bgBkAG8AdwBzAFIAdQBuAHQAaQBtAGUAXQAKACQAbgB1AGwAbAA9AFsAVwBpAG4AZABvAHcAcwAuAE0AZQBkAGkAYQAuAEMA"
    "bwBuAHQAcgBvAGwALgBHAGwAbwBiAGEAbABTAHkAcwB0AGUAbQBNAGUAZABpAGEAVAByAGEAbgBzAHAAbwByAHQAQwBvAG4A"
    "dAByAG8AbABzAFMAZQBzAHMAaQBvAG4ATQBlAGQAaQBhAFAAcgBvAHAAZQByAHQAaQBlAHMALABXAGkAbgBkAG8AdwBzAC4A"
    "TQBlAGQAaQBhAC4AQwBvAG4AdAByAG8AbAAsAEMAbwBuAHQAZQBuAHQAVAB5AHAAZQA9AFcAaQBuAGQAbwB3AHMAUgB1AG4A"
    "dABpAG0AZQBdAAoAQQBkAGQALQBUAHkAcABlACAALQBBAHMAcwBlAG0AYgBsAHkATgBhAG0AZQAgAFMAeQBzAHQAZQBtAC4A"
    "UgB1AG4AdABpAG0AZQAuAFcAaQBuAGQAbwB3AHMAUgB1AG4AdABpAG0AZQAKAGYAdQBuAGMAdABpAG8AbgAgAEEAdwBhAGkA"
    "dAAoACQAbwBwACwAWwBUAHkAcABlAF0AJAByAGUAcwB1AGwAdABUAHkAcABlACkAewAkAG0AZQB0AGgAbwBkAHMAPQBbAFMA"
    "eQBzAHQAZQBtAC4AVwBpAG4AZABvAHcAcwBSAHUAbgB0AGkAbQBlAFMAeQBzAHQAZQBtAEUAeAB0AGUAbgBzAGkAbwBuAHMA"
    "XQAuAEcAZQB0AE0AZQB0AGgAbwBkAHMAKAApAHwAVwBoAGUAcgBlAC0ATwBiAGoAZQBjAHQAewAkAF8ALgBOAGEAbQBlACAA"
    "LQBlAHEAIAAnAEEAcwBUAGEAcwBrACcAIAAtAGEAbgBkACAAJABfAC4ASQBzAEcAZQBuAGUAcgBpAGMATQBlAHQAaABvAGQA"
    "RABlAGYAaQBuAGkAdABpAG8AbgAgAC0AYQBuAGQAIAAkAF8ALgBHAGUAdABQAGEAcgBhAG0AZQB0AGUAcgBzACgAKQAuAEMA"
    "bwB1AG4AdAAgAC0AZQBxACAAMQB9ADsAJABtAGUAdABoAG8AZAA9ACQAbQBlAHQAaABvAGQAcwBbADAAXQAuAE0AYQBrAGUA"
    "RwBlAG4AZQByAGkAYwBNAGUAdABoAG8AZAAoACQAcgBlAHMAdQBsAHQAVAB5AHAAZQApADsAJAB0AGEAcwBrAD0AJABtAGUA"
    "dABoAG8AZAAuAEkAbgB2AG8AawBlACgAJABuAHUAbABsACwAQAAoACQAbwBwACkAKQA7ACQAdABhAHMAawAuAFcAYQBpAHQA"
    "KAAxADIAMAAwACkAfABPAHUAdAAtAE4AdQBsAGwAOwBpAGYAKAAtAG4AbwB0ACAAJAB0AGEAcwBrAC4ASQBzAEMAbwBtAHAA"
    "bABlAHQAZQBkACkAewByAGUAdAB1AHIAbgAgACQAbgB1AGwAbAB9ADsAJAB0AGEAcwBrAC4AUgBlAHMAdQBsAHQAfQAKACQA"
    "bQBhAG4AYQBnAGUAcgA9AEEAdwBhAGkAdAAgACgAWwBXAGkAbgBkAG8AdwBzAC4ATQBlAGQAaQBhAC4AQwBvAG4AdAByAG8A"
    "bAAuAEcAbABvAGIAYQBsAFMAeQBzAHQAZQBtAE0AZQBkAGkAYQBUAHIAYQBuAHMAcABvAHIAdABDAG8AbgB0AHIAbwBsAHMA"
    "UwBlAHMAcwBpAG8AbgBNAGEAbgBhAGcAZQByAF0AOgA6AFIAZQBxAHUAZQBzAHQAQQBzAHkAbgBjACgAKQApACAAKABbAFcA"
    "aQBuAGQAbwB3AHMALgBNAGUAZABpAGEALgBDAG8AbgB0AHIAbwBsAC4ARwBsAG8AYgBhAGwAUwB5AHMAdABlAG0ATQBlAGQA"
    "aQBhAFQAcgBhAG4AcwBwAG8AcgB0AEMAbwBuAHQAcgBvAGwAcwBTAGUAcwBzAGkAbwBuAE0AYQBuAGEAZwBlAHIAXQApAAoA"
    "aQBmACgAJABuAHUAbABsACAALQBlAHEAIAAkAG0AYQBuAGEAZwBlAHIAKQB7AGUAeABpAHQAIAAwAH0ACgBmAG8AcgBlAGEA"
    "YwBoACgAJABzAGUAcwBzAGkAbwBuACAAaQBuACAAJABtAGEAbgBhAGcAZQByAC4ARwBlAHQAUwBlAHMAcwBpAG8AbgBzACgA"
    "KQApAHsAJABwAHIAbwBwAHMAPQBBAHcAYQBpAHQAIAAoACQAcwBlAHMAcwBpAG8AbgAuAFQAcgB5AEcAZQB0AE0AZQBkAGkA"
    "YQBQAHIAbwBwAGUAcgB0AGkAZQBzAEEAcwB5AG4AYwAoACkAKQAgACgAWwBXAGkAbgBkAG8AdwBzAC4ATQBlAGQAaQBhAC4A"
    "QwBvAG4AdAByAG8AbAAuAEcAbABvAGIAYQBsAFMAeQBzAHQAZQBtAE0AZQBkAGkAYQBUAHIAYQBuAHMAcABvAHIAdABDAG8A"
    "bgB0AHIAbwBsAHMAUwBlAHMAcwBpAG8AbgBNAGUAZABpAGEAUAByAG8AcABlAHIAdABpAGUAcwBdACkAOwBpAGYAKAAkAG4A"
    "dQBsAGwAIAAtAGUAcQAgACQAcAByAG8AcABzACkAewBjAG8AbgB0AGkAbgB1AGUAfQA7ACQAcwBvAHUAcgBjAGUAPQAkAHMA"
    "ZQBzAHMAaQBvAG4ALgBTAG8AdQByAGMAZQBBAHAAcABVAHMAZQByAE0AbwBkAGUAbABJAGQAOwAkAHQAaQB0AGwAZQA9ACQA"
    "cAByAG8AcABzAC4AVABpAHQAbABlADsAJABhAHIAdABpAHMAdAA9ACQAcAByAG8AcABzAC4AQQByAHQAaQBzAHQAOwAkAHMA"
    "dABhAHQAdQBzAD0AJwAnADsAdAByAHkAewAkAHMAdABhAHQAdQBzAD0AJABzAGUAcwBzAGkAbwBuAC4ARwBlAHQAUABsAGEA"
    "eQBiAGEAYwBrAEkAbgBmAG8AKAApAC4AUABsAGEAeQBiAGEAYwBrAFMAdABhAHQAdQBzAC4AVABvAFMAdAByAGkAbgBnACgA"
    "KQB9AGMAYQB0AGMAaAB7AH0AOwBpAGYAKAAtAG4AbwB0ACAAWwBzAHQAcgBpAG4AZwBdADoAOgBJAHMATgB1AGwAbABPAHIA"
    "VwBoAGkAdABlAFMAcABhAGMAZQAoACQAdABpAHQAbABlACkAKQB7ACIAJABzAG8AdQByAGMAZQBgAHQAJAB0AGkAdABsAGUA"
    "YAB0ACQAYQByAHQAaQBzAHQAYAB0ACQAcwB0AGEAdAB1AHMAIgB9AH0A";

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

static char* next_tsv_field(char** cursor) {
  if (cursor == NULL || *cursor == NULL) {
    return NULL;
  }

  char* field = *cursor;
  char* separator = strchr(field, '\t');
  if (separator == NULL) {
    *cursor = NULL;
  } else {
    *separator = '\0';
    *cursor = separator + 1;
  }
  return field;
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

static int query_gsmtc_command(const char* command,
                               int includes_playback_status,
                               const char* app_name,
                               char* out_title,
                               size_t out_title_size,
                               TimeArcWinPlaybackState* out_playback_state) {
  FILE* pipe = _popen(command, "r");
  if (pipe == NULL) {
    return -1;
  }

  char line[1024];
  char selected_source[TA_MAX_NAME_BYTES] = {0};
  int matched = 0;
  while (fgets(line, sizeof(line), pipe) != NULL) {
    trim_line_end(line);
    char* cursor = line;
    char* source = next_tsv_field(&cursor);
    char* title = next_tsv_field(&cursor);
    char* artist = next_tsv_field(&cursor);
    char* status = includes_playback_status ? next_tsv_field(&cursor) : NULL;
    if (source == NULL || title == NULL ||
        !gsmtc_source_matches_app(source, app_name)) {
      continue;
    }

    char candidate_title[TA_MAX_TITLE_BYTES];
    format_gsmtc_title(title, artist, candidate_title, sizeof(candidate_title));
    if (candidate_title[0] != '\0') {
      const TimeArcWinPlaybackState candidate_state =
          timearc_win_parse_playback_status(status);
      const TimeArcWinPlaybackState merged_state =
          timearc_win_merge_playback_state(*out_playback_state,
                                           candidate_state);
      if (!matched || merged_state != *out_playback_state) {
        copy_string(selected_source, sizeof(selected_source), source);
        copy_string(out_title, out_title_size, candidate_title);
        *out_playback_state = merged_state;
      }
      matched = 1;
      if (!includes_playback_status ||
          *out_playback_state == TIMEARC_WIN_PLAYBACK_PLAYING) {
        break;
      }
    }
  }

  if (matched) {
    copy_string(g_gsmtc_cache_app, sizeof(g_gsmtc_cache_app), selected_source);
    copy_string(g_gsmtc_cache_title, sizeof(g_gsmtc_cache_title), out_title);
    g_gsmtc_cache_playback_state = *out_playback_state;
    g_gsmtc_cache_time = time(NULL);
  }

  _pclose(pipe);
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

  if (query_gsmtc_command(kGsmtcQueryCommand, 1, app_name, out_title,
                          out_title_size, out_playback_state) == 0) {
    return 0;
  }

  // Older Windows builds may expose metadata but not playback status. Keep the
  // previous title-only query as a compatibility fallback; activity then uses
  // the WASAPI peak path because the status remains UNKNOWN.
  return query_gsmtc_command(kGsmtcTitleOnlyQueryCommand, 0, app_name,
                             out_title, out_title_size, out_playback_state);
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

static int is_discord_path(const char* path) {
  return contains_ascii_case_insensitive(path, "discord.exe");
}

int timearc_win_should_record_audio_session(
    const char* path, int session_active, int muted, float volume, float peak,
    TimeArcWinPlaybackState playback_state) {
  if (is_browser_path(path) &&
      playback_state != TIMEARC_WIN_PLAYBACK_UNKNOWN) {
    return playback_state == TIMEARC_WIN_PLAYBACK_PLAYING;
  }
  if (is_discord_path(path)) {
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
}

static const char* stable_browser_media_title(
    const char* path, uint32_t process_id, const char* system_media_title,
    const char* matching_foreground_title) {
  const time_t now = time(NULL);
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
        copy_string(entry->observed_title, sizeof(entry->observed_title),
                    matching_foreground_title);
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
  copy_string(entry->observed_title, sizeof(entry->observed_title),
              initial_title);
  entry->last_seen_time = now;
  return entry->observed_title;
}

const char* timearc_win_preferred_observed_media_title(
    const char* path, uint32_t process_id, const char* system_media_title,
    const char* matching_foreground_title) {
  if (system_media_title != NULL && system_media_title[0] != '\0') {
    if (is_browser_path(path)) {
      return stable_browser_media_title(path, process_id, system_media_title,
                                        matching_foreground_title);
    }
    return system_media_title;
  }
  if (is_browser_path(path) && matching_foreground_title != NULL &&
      matching_foreground_title[0] != '\0') {
    return matching_foreground_title;
  }
  return matching_foreground_title;
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
        const int discord = is_discord_path(path);
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
          // spawning the GSMTC query. Discord needs no media metadata at all.
          title = choose_media_title(
              control, foreground_ptr, pid, path, app_name, !discord,
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
  if (g_com_initialized && g_should_uninitialize_com) {
    CoUninitialize();
  }
  g_com_initialized = 0;
  g_should_uninitialize_com = 0;
  timearc_win_reset_observed_media_title_cache();
}
