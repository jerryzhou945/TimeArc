// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_WECHAT_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_WECHAT_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition wechatAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:wechat");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QString::fromUtf8(u8"微信");
  adapter.category = QStringLiteral("社交");
  adapter.iconLabel = QString::fromUtf8(u8"微");
  adapter.brandColor = QStringLiteral("#DDF1E5");
  adapter.appIdentifiers = {QStringLiteral("com.tencent.xinwechat"),
                            QStringLiteral("wechat"),
                            QStringLiteral("weixin")};
  adapter.processNames = {QStringLiteral("WeChat.exe"),
                          QStringLiteral("WeChat"),
                          QStringLiteral("Weixin")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_WECHAT_ADAPTER_H
