#ifndef TIMEARC_AUDIO_WIN_H
#define TIMEARC_AUDIO_WIN_H

#include <stddef.h>

#include "app_info.h"

// Windows 音频会话采样接口。
//
// WASAPI 按“正在渲染音频的进程”暴露会话。这里会把可听见的会话转换成
// AppInfo，供 audio_tracker 独立累计播放时长。
#define TIMEARC_AUDIO_MAX_APPS 64

// Enumerates per-process render sessions that Windows currently reports as
// active audio sessions. Results are deduplicated by executable path.
int timearc_win_get_audio_apps(AppInfo* out_apps,
                               size_t max_apps,
                               size_t* out_count);

void timearc_win_audio_shutdown(void);

#endif  // TIMEARC_AUDIO_WIN_H
