#ifndef TIMEARC_WIN_SERVICE_H
#define TIMEARC_WIN_SERVICE_H

// Windows 生命周期动词（B1 Route A：用户会话登录自启）。
//
// 设计要点：真正采集的进程必须恒在交互式用户会话、以用户身份运行——朴素的
// SCM + LocalSystem 会把进程落进 Session 0，使前台窗口/空闲/音频/媒体采集全部
// 失效、数据写错 profile（见 docs/b1-windows-service-scm-kickoff.md §0.3）。因此
// Route A 用「登录触发计划任务」（schtasks，退路 HKCU Run）让采集留在用户会话，
// 全部经系统自带 exe shell-out，不链新库、不动冻结 CMake。
//
// 由 main.c 据命令行动词分派；无参时仍走今天的前台/会话内 tracker（向后兼容）。

// 注册「开机/登录自启」（登录任务优先，HKCU Run 退路）。成功返回 0。
int timearc_win_service_install(void);

// 反注册自启项（删任务 + 删 Run 值，皆「本就不存在」也算干净）。返回 0。
int timearc_win_service_uninstall(void);

// 在当前用户会话拉起一个 tracker（无参子进程）。Local\ 单例保证幂等。返回 0。
int timearc_win_service_start(void);

// 请求正在运行的 tracker 优雅停机（置位 Local\TimeArcStop 事件，走既有 flush）。
int timearc_win_service_stop(void);

// 打印注册态/运行态（机器可读：autostart=on|off / running=yes|no），供 UI 回显。
// 退出码：已注册 0，未注册 1。
int timearc_win_service_status(void);

// Route B（SCM session-broker 真服务）入口——暂缓未实装（见 kickoff §1.2 / SB1）。
int timearc_win_service_run(void);

#endif
