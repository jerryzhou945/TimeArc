#ifndef TIMEARC_WIN_SERVICE_H
#define TIMEARC_WIN_SERVICE_H

// Windows Service Control Manager 预留接口。
//
// 当前采集程序还是前台控制台模式，这几个函数只是后续“安装为系统服务”的
// 入口占位。真正接入 SCM 时会在这里处理 install/start/stop/uninstall。
// Windows Service Control Manager integration hooks. These are placeholders
// until the foreground tracker is wrapped as an installable background service.
int timearc_win_service_run(void);
int timearc_win_service_install(void);
int timearc_win_service_uninstall(void);

#endif
