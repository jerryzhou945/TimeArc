// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_MACOS_MACOS_LAUNCH_AGENT_H_
#define TIMEARC_SERVICES_MACOS_MACOS_LAUNCH_AGENT_H_

#include <QString>

struct MacLaunchAgentRegistration {
  bool registered = false;
  bool requiresApproval = false;
  QString errorMessage;
};

MacLaunchAgentRegistration registerMacLaunchAgent();

#endif  // TIMEARC_SERVICES_MACOS_MACOS_LAUNCH_AGENT_H_
