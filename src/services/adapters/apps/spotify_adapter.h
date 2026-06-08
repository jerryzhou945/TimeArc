// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_SPOTIFY_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_SPOTIFY_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition spotifyAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:spotify");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("Spotify");
  adapter.category = QStringLiteral("音乐");
  adapter.iconLabel = QStringLiteral("S");
  adapter.brandColor = QStringLiteral("#CFE8D8");
  adapter.supportsMediaDetection = true;
  adapter.appIdentifiers = {QStringLiteral("com.spotify.client"),
                            QStringLiteral("spotify")};
  adapter.processNames = {QStringLiteral("Spotify.exe"),
                          QStringLiteral("Spotify")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_SPOTIFY_ADAPTER_H
