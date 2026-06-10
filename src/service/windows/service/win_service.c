#include "win_service.h"

#include "../tracker/usage_tracker.h"  // TIMEARC_INSTANCE_MUTEX_NAME / TIMEARC_STOP_EVENT_NAME

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <stdio.h>
#include <wchar.h>

// B1 Route A 实现。自启机制：经 schtasks.exe 注册一个「登录触发」计划任务，让
// time-arc-service.exe 在用户登录时仍跑在交互式用户会话、以用户身份运行（Route A
// 天然满足 §0.3 的会话/profile 亲和要求，无 Session 0 陷阱、无管理员/UAC 摩擦）。
// schtasks 不可用时退回 HKCU\...\Run。停机经 Local\TimeArcStop 具名事件优雅 flush。

#define TIMEARC_TASK_NAME L"TimeArc Usage Service"
#define TIMEARC_RUN_VALUE L"TimeArc Usage Service"
#define TIMEARC_RUN_KEY \
  L"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"

enum { EXE_CAP = 1024, CMD_CAP = 1536 };

// 取当前 service.exe 的完整路径（路径含空格亦安全）。成功返回 0。
static int current_exe_path(wchar_t* buf, DWORD cap) {
  DWORD n = GetModuleFileNameW(NULL, buf, cap);
  return (n > 0 && n < cap) ? 0 : -1;
}

// 以隐藏窗口同步运行一个系统命令，返回其退出码；启动失败返回 -1。
// cmdline 会被 CreateProcessW 就地修改，调用方须传可写缓冲。CREATE_NO_WINDOW
// 避免 schtasks/reg 的控制台一闪而过（UI 经 QProcess 调动词时尤其重要）。
static int run_hidden_wait(wchar_t* cmdline) {
  STARTUPINFOW si;
  PROCESS_INFORMATION pi;
  ZeroMemory(&si, sizeof(si));
  si.cb = sizeof(si);
  ZeroMemory(&pi, sizeof(pi));

  if (!CreateProcessW(NULL, cmdline, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL,
                      NULL, &si, &pi)) {
    return -1;
  }
  WaitForSingleObject(pi.hProcess, INFINITE);
  DWORD code = 1;
  GetExitCodeProcess(pi.hProcess, &code);
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);
  return (int)code;
}

// —— 登录任务（主路） ——
// /tr 的值含空格须整体加引号，内层 exe 路径也含空格须再加引号 → /tr "\"<exe>\""。
// 不加 /rl highest：以标准用户令牌跑在用户会话（采集正确 + 无 UAC）。
// 任务/Run 动作走 "<exe>" --start：--start 以 CREATE_NO_WINDOW 拉起无窗 tracker，避免
// 控制台子系统 exe 作为登录项直接运行时长驻一个可见控制台窗口（仅 --start 启动器一闪）。
static int register_logon_task(const wchar_t* exe) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP,
             L"schtasks /create /tn \"%ls\" /tr \"\\\"%ls\\\" --start\" /sc onlogon /f",
             TIMEARC_TASK_NAME, exe);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd);
}

static int unregister_logon_task(void) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP, L"schtasks /delete /tn \"%ls\" /f", TIMEARC_TASK_NAME);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd);
}

static int logon_task_exists(void) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP, L"schtasks /query /tn \"%ls\"", TIMEARC_TASK_NAME);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd) == 0;  // 0 = 任务存在
}

// —— HKCU Run（退路，仅当 schtasks 失败时使用） ——
static int register_run_key(const wchar_t* exe) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP,
             L"reg add \"%ls\" /v \"%ls\" /t REG_SZ /d \"\\\"%ls\\\" --start\" /f",
             TIMEARC_RUN_KEY, TIMEARC_RUN_VALUE, exe);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd);
}

static int unregister_run_key(void) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP, L"reg delete \"%ls\" /v \"%ls\" /f", TIMEARC_RUN_KEY,
             TIMEARC_RUN_VALUE);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd);
}

static int run_key_exists(void) {
  wchar_t cmd[CMD_CAP];
  _snwprintf(cmd, CMD_CAP, L"reg query \"%ls\" /v \"%ls\"", TIMEARC_RUN_KEY,
             TIMEARC_RUN_VALUE);
  cmd[CMD_CAP - 1] = L'\0';
  return run_hidden_wait(cmd) == 0;
}

int timearc_win_service_install(void) {
  wchar_t exe[EXE_CAP];
  if (current_exe_path(exe, EXE_CAP) != 0) {
    fprintf(stderr, "install: cannot resolve service exe path\n");
    return 1;
  }
  if (register_logon_task(exe) == 0) {
    // 主路成功：清掉可能残留的 Run 退路，避免双重拉起（虽有 Local\ 单例幂等兜底）。
    unregister_run_key();
    printf("autostart registered (logon task)\n");
    return 0;
  }
  if (register_run_key(exe) == 0) {
    printf("autostart registered (run key)\n");
    return 0;
  }
  fprintf(stderr, "install: failed to register autostart\n");
  return 1;
}

int timearc_win_service_uninstall(void) {
  // 两条都尝试删除；「本就不存在」也算干净卸载，故不据其退出码判失败。
  unregister_logon_task();
  unregister_run_key();
  printf("autostart unregistered\n");
  return 0;
}

int timearc_win_service_start(void) {
  wchar_t exe[EXE_CAP];
  if (current_exe_path(exe, EXE_CAP) != 0) {
    fprintf(stderr, "start: cannot resolve service exe path\n");
    return 1;
  }
  // 在当前用户会话拉起一个无参 tracker。Local\ 单例保证幂等：若已在跑，新实例
  // 命中 ERROR_ALREADY_EXISTS 立即静默退出（main.c）。
  wchar_t cmd[EXE_CAP + 4];
  _snwprintf(cmd, EXE_CAP + 4, L"\"%ls\"", exe);
  cmd[EXE_CAP + 3] = L'\0';

  STARTUPINFOW si;
  PROCESS_INFORMATION pi;
  ZeroMemory(&si, sizeof(si));
  si.cb = sizeof(si);
  ZeroMemory(&pi, sizeof(pi));
  if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE,
                      CREATE_NO_WINDOW, NULL, NULL, &si,  // 不叠 DETACHED_PROCESS（叠加会令 CREATE_NO_WINDOW 被忽略→子进程无控制台→收不到 Ctrl 事件）
                      &pi)) {
    fprintf(stderr, "start: failed to launch tracker\n");
    return 1;
  }
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);
  printf("tracker started\n");
  return 0;
}

int timearc_win_service_stop(void) {
  // 置位停机事件让运行中的 tracker 优雅收尾（flush 当前 session + audio）。
  // 非 taskkill /F——硬杀会跳过 flush 丢当前 open session（§4.4）。
  HANDLE ev = OpenEventA(EVENT_MODIFY_STATE, FALSE, TIMEARC_STOP_EVENT_NAME);
  if (ev == NULL) {
    printf("tracker not running\n");
    return 0;
  }
  SetEvent(ev);
  CloseHandle(ev);
  printf("stop requested\n");
  return 0;
}

int timearc_win_service_status(void) {
  int registered = logon_task_exists() || run_key_exists();

  // 运行态＝单实例 mutex 是否已被某个会话内 tracker 持有。OpenMutex 成功即在跑。
  HANDLE m = OpenMutexA(SYNCHRONIZE, FALSE, TIMEARC_INSTANCE_MUTEX_NAME);
  int running = (m != NULL);
  if (m != NULL) {
    CloseHandle(m);
  }

  printf("autostart=%s\n", registered ? "on" : "off");
  printf("running=%s\n", running ? "yes" : "no");
  return registered ? 0 : 1;
}

int timearc_win_service_run(void) {
  // Route B（SCM session-broker 真服务）暂缓。朴素 CreateService + LocalSystem 会
  // 落 Session 0 → 打碎采集，故 Route A 不实装此入口（详见 kickoff §1.2 / SB1-SB3）。
  fprintf(stderr, "--run-service (SCM mode) is not implemented in Route A\n");
  return 1;
}
