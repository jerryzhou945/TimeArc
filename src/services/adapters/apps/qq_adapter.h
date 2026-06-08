// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_QQ_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_QQ_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition qqAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:qq");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("QQ");
  adapter.category = QStringLiteral("社交");
  adapter.iconLabel = QStringLiteral("Q");
  adapter.brandColor = QStringLiteral("#DDE8F5");
  adapter.appIdentifiers = {QStringLiteral("com.tencent.qq"),
                            QStringLiteral("tencent qq")};
  adapter.processNames = {QStringLiteral("QQ.exe"),
                          QStringLiteral("Tencent QQ")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_QQ_ADAPTER_H
