// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_WEBSITES_YOUTUBE_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_WEBSITES_YOUTUBE_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition youtubeWebsiteAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("site:youtube");
  adapter.sourceType = QStringLiteral("website");
  adapter.displayName = QStringLiteral("YouTube");
  adapter.category = QStringLiteral("视频");
  adapter.domain = QStringLiteral("youtube.com");
  adapter.iconPath =
      QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/youtube.ico");
  adapter.iconLabel = QStringLiteral("Y");
  adapter.brandColor = QStringLiteral("#F2D4D4");
  adapter.supportsMediaDetection = true;
  adapter.hostnames = {QStringLiteral("youtube.com"),
                       QStringLiteral("youtu.be"),
                       QStringLiteral("music.youtube.com")};
  adapter.urlPatterns = {
      QStringLiteral(R"(https?://([^/]+\.)?youtube\.com/(watch|shorts|playlist|live).*)"),
      QStringLiteral(R"(https?://youtu\.be/.*)")};
  adapter.titleHints = {QStringLiteral("youtube"), QStringLiteral("youtu.be")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_WEBSITES_YOUTUBE_ADAPTER_H
