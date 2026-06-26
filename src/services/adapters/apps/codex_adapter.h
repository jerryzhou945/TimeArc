// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_CODEX_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_CODEX_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition codexAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:codex");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("Codex");
  adapter.category = QStringLiteral("开发");
  adapter.iconLabel = QStringLiteral("C");
  adapter.brandColor = QStringLiteral("#BFD7EA");
  adapter.appIdentifiers = {QStringLiteral("app:codex"),
                            QStringLiteral("openai codex"),
                            QStringLiteral("codex")};
  adapter.processNames = {QStringLiteral("Codex.exe"),
                          QStringLiteral("codex")};
  adapter.titleHints = {QStringLiteral("codex")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_CODEX_ADAPTER_H
