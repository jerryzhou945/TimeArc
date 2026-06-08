// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_CHROME_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_CHROME_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition chromeAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:google-chrome");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("Chrome");
  adapter.category = QStringLiteral("浏览");
  adapter.iconLabel = QStringLiteral("C");
  adapter.brandColor = QStringLiteral("#DDE8F5");
  adapter.appIdentifiers = {QStringLiteral("com.google.chrome"),
                            QStringLiteral("google chrome")};
  adapter.processNames = {QStringLiteral("chrome.exe"),
                          QStringLiteral("Google Chrome"),
                          QStringLiteral("chrome")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_CHROME_ADAPTER_H
