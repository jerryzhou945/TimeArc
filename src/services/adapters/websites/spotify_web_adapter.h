// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_WEBSITES_SPOTIFY_WEB_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_WEBSITES_SPOTIFY_WEB_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition spotifyWebAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("site:spotify-web");
  adapter.sourceType = QStringLiteral("website");
  adapter.displayName = QStringLiteral("Spotify Web");
  adapter.category = QStringLiteral("音乐");
  adapter.domain = QStringLiteral("open.spotify.com");
  adapter.iconLabel = QStringLiteral("S");
  adapter.brandColor = QStringLiteral("#CFE8D8");
  adapter.supportsMediaDetection = true;
  adapter.hostnames = {QStringLiteral("open.spotify.com"),
                       QStringLiteral("spotify.com")};
  adapter.urlPatterns = {
      QStringLiteral(R"(https?://open\.spotify\.com/(album|artist|playlist|track|show|episode).*)")};
  adapter.titleHints = {QStringLiteral("spotify"),
                        QStringLiteral("open.spotify.com")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_WEBSITES_SPOTIFY_WEB_ADAPTER_H
