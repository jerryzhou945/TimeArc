// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_EDGE_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_EDGE_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition edgeAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:microsoft-edge");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("Edge");
  adapter.category = QStringLiteral("浏览");
  adapter.iconLabel = QStringLiteral("E");
  adapter.brandColor = QStringLiteral("#CFE8E8");
  adapter.appIdentifiers = {QStringLiteral("microsoftedge"),
                            QStringLiteral("microsoft edge"),
                            QStringLiteral("com.microsoft.edge")};
  adapter.processNames = {QStringLiteral("msedge.exe"),
                          QStringLiteral("Microsoft Edge"),
                          QStringLiteral("msedge")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_EDGE_ADAPTER_H
