// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_APPS_GACHA_GAME_ADAPTERS_H
#define TIMEARC_SERVICES_ADAPTERS_APPS_GACHA_GAME_ADAPTERS_H

#include "services/adapters/adapter_metadata.h"

namespace TimeArcAdapters {

inline AdapterDefinition genshinImpactAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:genshin-impact");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("原神");
  adapter.category = QStringLiteral("游戏");
  adapter.iconLabel = QStringLiteral("原");
  adapter.brandColor = QStringLiteral("#77A9D8");
  adapter.appIdentifiers = {QStringLiteral("yuanshen.exe"),
                            QStringLiteral("genshinimpact.exe")};
  adapter.processNames = adapter.appIdentifiers;
  return adapter;
}

inline AdapterDefinition honkaiStarRailAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:honkai-star-rail");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("崩坏：星穹铁道");
  adapter.category = QStringLiteral("游戏");
  adapter.iconLabel = QStringLiteral("铁");
  adapter.brandColor = QStringLiteral("#8A78C8");
  adapter.appIdentifiers = {QStringLiteral("starrail.exe")};
  adapter.processNames = adapter.appIdentifiers;
  return adapter;
}

inline AdapterDefinition zenlessZoneZeroAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:zenless-zone-zero");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("绝区零");
  adapter.category = QStringLiteral("游戏");
  adapter.iconLabel = QStringLiteral("绝");
  adapter.brandColor = QStringLiteral("#E7C752");
  adapter.appIdentifiers = {QStringLiteral("zenlesszonezero.exe")};
  adapter.processNames = adapter.appIdentifiers;
  return adapter;
}

inline AdapterDefinition wutheringWavesAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:wuthering-waves");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("鸣潮");
  adapter.category = QStringLiteral("游戏");
  adapter.iconLabel = QStringLiteral("鸣");
  adapter.brandColor = QStringLiteral("#5EA9A4");
  // The executable basename is shared by many Unreal games, so require the
  // installation path/name hint instead of matching Client-Win64 globally.
  adapter.appIdentifiers = {QStringLiteral("wuthering waves"),
                            QStringLiteral("wutheringwaves")};
  return adapter;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_APPS_GACHA_GAME_ADAPTERS_H
