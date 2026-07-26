#ifndef TIMEARC_ACTIVE_APP_WIN_H
#define TIMEARC_ACTIVE_APP_WIN_H

#include "app_info.h"

// Windows foreground-window sampling.
//
// AppInfo contains the title, process path, executable name, and PID.
// The tracker compares adjacent samples to determine session boundaries.
// Fill out_app with the foreground window's process id, title, executable path,
// and display name. Returns 0 on success and -1 when Windows cannot identify the
// active window/process.
int timearc_win_get_active_app(AppInfo* out_app);

#endif  // TIMEARC_ACTIVE_APP_WIN_H
