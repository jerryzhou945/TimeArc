// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_VSCODE_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_VSCODE_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition vscodeAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:vscode");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("VSCode");
  adapter.category = QStringLiteral("开发");
  adapter.iconLabel = QStringLiteral("V");
  adapter.brandColor = QStringLiteral("#D8E4F2");
  adapter.appIdentifiers = {QStringLiteral("com.microsoft.vscode"),
                            QStringLiteral("visual studio code"),
                            QStringLiteral("vscode")};
  adapter.processNames = {QStringLiteral("Code.exe"),
                          QStringLiteral("Visual Studio Code"),
                          QStringLiteral("code")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_VSCODE_ADAPTER_H
