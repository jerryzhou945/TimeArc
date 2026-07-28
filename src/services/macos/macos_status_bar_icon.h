// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_MACOS_MACOS_STATUS_BAR_ICON_H_
#define TIMEARC_SERVICES_MACOS_MACOS_STATUS_BAR_ICON_H_

#include <memory>

class QObject;
class SettingsRepository;
class TimerManager;

class MacStatusBarIcon final {
 public:
  MacStatusBarIcon();
  ~MacStatusBarIcon();

  MacStatusBarIcon(const MacStatusBarIcon&) = delete;
  MacStatusBarIcon& operator=(const MacStatusBarIcon&) = delete;

  QObject* qmlObject() const;

  // Wires the timer rows and the language lookup. Both may be null; the menu
  // then keeps its rows but leaves the timer actions disabled.
  void attach(TimerManager* timerManager, SettingsRepository* settings);

  void connectToRoot(QObject* rootObject);

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // TIMEARC_SERVICES_MACOS_MACOS_STATUS_BAR_ICON_H_
