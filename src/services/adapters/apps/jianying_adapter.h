// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_JIANYING_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_JIANYING_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition jianyingAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:jianying-pro");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QString::fromUtf8(u8"剪映专业版");
  adapter.category = QStringLiteral("创作");
  adapter.iconLabel = QString::fromUtf8(u8"剪");
  adapter.brandColor = QStringLiteral("#D7EEF1");
  adapter.appIdentifiers = {QStringLiteral("com.lemon.lvpro"),
                            QStringLiteral("jianying"),
                            QStringLiteral("capcut")};
  adapter.processNames = {QStringLiteral("JianyingPro.exe"),
                          QStringLiteral("JianyingPro"),
                          QStringLiteral("CapCut.exe"),
                          QStringLiteral("CapCut")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_JIANYING_ADAPTER_H
