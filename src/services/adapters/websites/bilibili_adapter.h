// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_WEBSITES_BILIBILI_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_WEBSITES_BILIBILI_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition bilibiliWebsiteAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("site:bilibili");
  adapter.sourceType = QStringLiteral("website");
  adapter.displayName = QStringLiteral("哔哩哔哩");
  adapter.category = QStringLiteral("视频");
  adapter.domain = QStringLiteral("bilibili.com");
  adapter.iconPath =
      QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/bilibili.png");
  adapter.iconLabel = QStringLiteral("B");
  adapter.brandColor = QStringLiteral("#FABECF");
  adapter.supportsMediaDetection = true;
  adapter.hostnames = {QStringLiteral("bilibili.com"),
                       QStringLiteral("b23.tv")};
  adapter.urlPatterns = {
      QStringLiteral(R"(https?://([^/]+\.)?bilibili\.com/(video|bangumi|space|list|medialist).*)"),
      QStringLiteral(R"(https?://b23\.tv/.*)")};
  adapter.titleHints = {QStringLiteral("bilibili"), QStringLiteral("b23.tv"),
                        QStringLiteral("哔哩哔哩"),
                        QStringLiteral("bilibili.com")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_WEBSITES_BILIBILI_ADAPTER_H
