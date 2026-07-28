// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_MACOS_MACOS_STATUS_BAR_ICON_H_
#define TIMEARC_SERVICES_MACOS_MACOS_STATUS_BAR_ICON_H_

#include <memory>

class QObject;
class SettingsRepository;

class MacStatusBarIcon final {
 public:
  MacStatusBarIcon();
  ~MacStatusBarIcon();

  MacStatusBarIcon(const MacStatusBarIcon&) = delete;
  MacStatusBarIcon& operator=(const MacStatusBarIcon&) = delete;

  QObject* qmlObject() const;

  // Supplies the language lookup for the menu rows. May be null; the menu
  // then stays on its Chinese default.
  void attach(SettingsRepository* settings);

  void connectToRoot(QObject* rootObject);

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // TIMEARC_SERVICES_MACOS_MACOS_STATUS_BAR_ICON_H_
