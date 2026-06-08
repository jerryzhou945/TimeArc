// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_DESKTOP_APP_ADAPTER_REGISTRY_H
#define TIMEARC_SERVICES_ADAPTERS_DESKTOP_APP_ADAPTER_REGISTRY_H

#include <QVector>

#include "services/adapters/adapter_metadata.h"
#include "services/adapters/apps/chrome_adapter.h"
#include "services/adapters/apps/edge_adapter.h"
#include "services/adapters/apps/qq_adapter.h"
#include "services/adapters/apps/spotify_adapter.h"
#include "services/adapters/apps/vscode_adapter.h"
#include "services/adapters/apps/wechat_adapter.h"

namespace TimeArcAdapters {

inline QVector<AdapterDefinition> registeredDesktopAppAdapters() {
  return {chromeAppAdapter(), edgeAppAdapter(), vscodeAppAdapter(),
          spotifyAppAdapter(), wechatAppAdapter(), qqAppAdapter()};
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_DESKTOP_APP_ADAPTER_REGISTRY_H
