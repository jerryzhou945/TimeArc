#ifndef TIMEARC_WIN_SERVICE_H
#define TIMEARC_WIN_SERVICE_H

// Windows Service Control Manager integration hooks. These are placeholders
// until the foreground tracker is wrapped as an installable background service.
int timearc_win_service_run(void);
int timearc_win_service_install(void);
int timearc_win_service_uninstall(void);

#endif
