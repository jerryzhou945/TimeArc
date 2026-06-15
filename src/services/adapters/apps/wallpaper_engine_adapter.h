// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_WALLPAPER_ENGINE_ADAPTER_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_WALLPAPER_ENGINE_ADAPTER_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition wallpaperEngineAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:wallpaper-engine");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("Wallpaper Engine");
  adapter.category = QStringLiteral("创作");
  adapter.iconLabel = QStringLiteral("W");
  adapter.brandColor = QStringLiteral("#C7E2EC");
  adapter.appIdentifiers = {QStringLiteral("wallpaperengine"),
                            QStringLiteral("wallpaper engine")};
  adapter.processNames = {QStringLiteral("wallpaper32.exe"),
                          QStringLiteral("wallpaper64.exe"),
                          QStringLiteral("wallpaperui.exe"),
                          QStringLiteral("webwallpaper32.exe"),
                          QStringLiteral("wallpaper32"),
                          QStringLiteral("wallpaper64"),
                          QStringLiteral("wallpaperui")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_WALLPAPER_ENGINE_ADAPTER_H
