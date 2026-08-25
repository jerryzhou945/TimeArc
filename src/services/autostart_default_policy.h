// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_AUTOSTART_DEFAULT_POLICY_H
#define TIMEARC_SERVICES_AUTOSTART_DEFAULT_POLICY_H

namespace TimeArc::AutostartDefaultPolicy {

enum class Action {
  NoChange,
  RememberExisting,
  EnableAndRemember,
};

inline Action decide(bool decisionRecorded, bool currentlyEnabled) {
  if (decisionRecorded) return Action::NoChange;
  return currentlyEnabled ? Action::RememberExisting
                          : Action::EnableAndRemember;
}

}  // namespace TimeArc::AutostartDefaultPolicy

#endif  // TIMEARC_SERVICES_AUTOSTART_DEFAULT_POLICY_H
