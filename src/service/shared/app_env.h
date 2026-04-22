// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

// AppEnv 是较早的跨平台前台应用抽象。
//
// 当前 Windows 新实现已经拆到了 windows/platform/*，但这个接口仍然保留给
// macOS/旧代码路径参考：平台层填充窗口标题、应用名、pid，tracker 只消费统一字段。
// AppEnv represents the environment for retrieving app information. It
// abstracts away window-manager-specific details and provides a consistent
// interface for the rest of the service to interact with.

#ifndef TIMEARC_SRC_SERVICE_SHARED_APP_ENV_H
#define TIMEARC_SRC_SERVICE_SHARED_APP_ENV_H

#if defined(__cplusplus)
extern "C" {
#endif

#include <stdint.h>
#include <time.h>

#include "util.h"

typedef struct AppEnv AppEnv;

typedef struct AppEnvOps {
  // 刷新 window_title、app_name 和 current_pid。
  void (*Update)(AppEnv* env);

  // 返回用户空闲秒数。不同平台对“空闲”的底层定义略有差异。
  double (*GetIdleSeconds)(AppEnv* env);

  // 根据 current_pid 查询当前应用可执行路径，写入调用方提供的 buffer。
  void (*GetExecPath)(AppEnv* env, char* exec_path, size_t exec_path_size);

  // 清理平台实现持有的资源。
  void (*Destroy)(AppEnv* env);

} AppEnvOps;

struct AppEnv {
  // 当前前台窗口标题。
  char window_title[TA_MAX_TITLE_BYTES];

  // 当前前台应用名。
  char app_name[TA_MAX_NAME_BYTES];

  // 当前前台应用 pid。
  uint32_t current_pid;

  // 平台相关操作表。
  const AppEnvOps* ops;
};

AppEnv* app_env_init();

#if defined(__cplusplus)
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_APP_ENV_H
