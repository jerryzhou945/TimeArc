#include "win_service.h"

int timearc_win_service_run(void) {
  // TODO: 注册 SERVICE_MAIN_FUNCTION，并把 stop/pause 信号转给 tracker。
  return -1;
}

int timearc_win_service_install(void) {
  // TODO: 通过 OpenSCManager/CreateService 写入 Windows 服务表。
  return -1;
}

int timearc_win_service_uninstall(void) {
  // TODO: 先停止运行中的服务，再通过 Service Control Manager 删除服务。
  return -1;
}
