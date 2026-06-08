// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_WEBSITES_QQ_MUSIC_WEB_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_WEBSITES_QQ_MUSIC_WEB_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition qqMusicWebAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("site:qq-music-web");
  adapter.sourceType = QStringLiteral("website");
  adapter.displayName = QStringLiteral("QQ Music Web");
  adapter.category = QStringLiteral("音乐");
  adapter.domain = QStringLiteral("y.qq.com");
  adapter.iconLabel = QStringLiteral("Q");
  adapter.brandColor = QStringLiteral("#DDF1E5");
  adapter.supportsMediaDetection = true;
  adapter.hostnames = {QStringLiteral("y.qq.com"),
                       QStringLiteral("music.qq.com")};
  adapter.urlPatterns = {
      QStringLiteral(R"(https?://y\.qq\.com/(n/ryqq|portal|musicmac|download).*)"),
      QStringLiteral(R"(https?://music\.qq\.com/.*)")};
  adapter.titleHints = {QStringLiteral("qq音乐"), QStringLiteral("qq music"),
                        QStringLiteral("y.qq.com"),
                        QStringLiteral("music.qq.com")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_WEBSITES_QQ_MUSIC_WEB_ADAPTER_H
