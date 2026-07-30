// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_MACOS_MACOS_STATUS_BAR_ICON_H_
#define TIMEARC_SERVICES_MACOS_MACOS_STATUS_BAR_ICON_H_

#include <memory>

class QObject;
class PomodoroManager;
class SettingsRepository;

class MacStatusBarIcon final {
 public:
  MacStatusBarIcon();
  ~MacStatusBarIcon();

  MacStatusBarIcon(const MacStatusBarIcon&) = delete;
  MacStatusBarIcon& operator=(const MacStatusBarIcon&) = delete;

  QObject* qmlObject() const;

  // Supplies the language lookup and the pomodoro engine the timer rows drive.
  // Either may be null: without settings the menu stays on its English default,
  // without an engine the three pomodoro rows are disabled.
  void attach(SettingsRepository* settings, PomodoroManager* pomodoro);

  void connectToRoot(QObject* rootObject);

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // TIMEARC_SERVICES_MACOS_MACOS_STATUS_BAR_ICON_H_
