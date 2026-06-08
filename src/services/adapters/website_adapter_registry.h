// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_WEBSITE_ADAPTER_REGISTRY_H
#define TIMEARC_SERVICES_ADAPTERS_WEBSITE_ADAPTER_REGISTRY_H

#include <QVector>

#include "services/adapters/adapter_metadata.h"
#include "services/adapters/websites/bilibili_adapter.h"
#include "services/adapters/websites/qq_music_web_adapter.h"
#include "services/adapters/websites/spotify_web_adapter.h"
#include "services/adapters/websites/youtube_adapter.h"

namespace TimeArcAdapters {

inline QVector<AdapterDefinition> registeredWebsiteAdapters() {
  return {youtubeWebsiteAdapter(), bilibiliWebsiteAdapter(), spotifyWebAdapter(),
          qqMusicWebAdapter()};
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_WEBSITE_ADAPTER_REGISTRY_H
