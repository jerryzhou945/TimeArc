#ifndef TIMEARC_ACTIVE_APP_WIN_H
#define TIMEARC_ACTIVE_APP_WIN_H

#include "app_info.h"

// Windows 前台窗口采样接口。
//
// 输出的 AppInfo 是 tracker 的原始输入：包含窗口标题、进程路径、exe 名称
// 和 pid。tracker 会比较相邻两次 AppInfo，决定是否切分时间段。
// Fill out_app with the foreground window's process id, title, executable path,
// and display name. Returns 0 on success and -1 when Windows cannot identify the
// active window/process.
int timearc_win_get_active_app(AppInfo* out_app);

#endif  // TIMEARC_ACTIVE_APP_WIN_H
