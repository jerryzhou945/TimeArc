// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_DESKTOP_APP_ADAPTER_REGISTRY_H
#define TIMEARC_SERVICES_ADAPTERS_DESKTOP_APP_ADAPTER_REGISTRY_H

#include <QVector>

#include "services/adapters/adapter_metadata.h"
#include "services/adapters/apps/chrome_adapter.h"
#include "services/adapters/apps/codex_adapter.h"
#include "services/adapters/apps/edge_adapter.h"
#include "services/adapters/apps/gacha_game_adapters.h"
#include "services/adapters/apps/jianying_adapter.h"
#include "services/adapters/apps/qq_adapter.h"
#include "services/adapters/apps/spotify_adapter.h"
#include "services/adapters/apps/timearc_adapter.h"
#include "services/adapters/apps/vscode_adapter.h"
#include "services/adapters/apps/wallpaper_engine_adapter.h"
#include "services/adapters/apps/wechat_adapter.h"

namespace TimeArcAdapters {

inline QVector<AdapterDefinition> registeredDesktopAppAdapters() {
  return {genshinImpactAppAdapter(), honkaiStarRailAppAdapter(),
          zenlessZoneZeroAppAdapter(), wutheringWavesAppAdapter(),
          timearcAppAdapter(), chromeAppAdapter(), edgeAppAdapter(),
          codexAppAdapter(), vscodeAppAdapter(), spotifyAppAdapter(), wechatAppAdapter(),
          qqAppAdapter(), jianyingAppAdapter(), wallpaperEngineAppAdapter()};
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_DESKTOP_APP_ADAPTER_REGISTRY_H
