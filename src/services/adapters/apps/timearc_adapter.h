// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_TIMEARC_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_TIMEARC_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition timearcAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:timearc");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("TimeArc");
  adapter.category = QStringLiteral("\u5E94\u7528");
  adapter.iconPath =
      QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/app_icon.svg");
  adapter.iconLabel = QStringLiteral("T");
  adapter.brandColor = QStringLiteral("#C9DDF4");
  adapter.appIdentifiers = {QStringLiteral("app:timearc")};
  adapter.processNames = {QStringLiteral("TimeArc.exe"),
                          QStringLiteral("time-arc.exe")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_TIMEARC_ADAPTER_H
