// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

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
  // Updates window_title, app_name, and current_pid.
  void (*Update)(AppEnv* env);

  // Returns the number of seconds the user has been idle. Generally, this is
  // the time since the last input event (mouse movement, key press, etc.). But
  // the exact definition of "idle" can vary based on the platform.
  double (*GetIdleSeconds)(AppEnv* env);

  // Retrieves the executable path of the current app and fills it into
  // exec_path. The exec_path buffer has a size of exec_path_size bytes. It uses
  // current_pid to determine which process's executable path to retrieve.
  void (*GetExecPath)(AppEnv* env, char* exec_path, size_t exec_path_size);

  // Cleans up any resources associated with the AppEnv instance.
  void (*Destroy)(AppEnv* env);

} AppEnvOps;

struct AppEnv {
  // The title of the currently active window.
  char window_title[TA_MAX_TITLE_BYTES];

  // The name of the currently active application.
  char app_name[TA_MAX_NAME_BYTES];

  // The process ID of the currently active application.
  uint32_t current_pid;

  // Function pointers for platform-specific operations.
  const AppEnvOps* ops;
};

AppEnv* app_env_init();

#if defined(__cplusplus)
}
#endif

#endif  // TIMEARC_SRC_SERVICE_SHARED_APP_ENV_H
