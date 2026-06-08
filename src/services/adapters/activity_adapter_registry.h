// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_ACTIVITY_ADAPTER_REGISTRY_H
#define TIMEARC_SERVICES_ADAPTERS_ACTIVITY_ADAPTER_REGISTRY_H

#include <QVector>

#include "adapter_metadata.h"

namespace TimeArcAdapters {

inline QVector<AdapterDefinition> registeredWebsiteAdapters() {
  return {};
}

inline QVector<AdapterDefinition> registeredDesktopAppAdapters() {
  return {};
}

inline bool hasWebsiteSignal(const AdapterInput& input) {
  return !hostFromInput(input).isEmpty() || !input.url.trimmed().isEmpty();
}

inline AdapterMetadata resolveWebsite(const AdapterInput& input) {
  const QString host = hostFromInput(input);
  const QString url = urlForMatching(input);
  const QVector<AdapterDefinition> adapters = registeredWebsiteAdapters();

  for (const AdapterDefinition& adapter : adapters) {
    for (const QString& candidateHost : adapter.hostnames) {
      if (hostMatches(host, candidateHost)) {
        return metadataFromDefinition(adapter, 0.95, input);
      }
    }
    if (urlMatchesAny(url, adapter.urlPatterns)) {
      return metadataFromDefinition(adapter, 0.90, input);
    }
    if (containsAnyLower(input.title, adapter.titleHints)) {
      return metadataFromDefinition(adapter, 0.58, input);
    }
  }

  return genericWebsiteMetadata(input);
}

inline AdapterMetadata resolveDesktopApp(const AdapterInput& input) {
  const QString identity = appIdentityText(input);
  const QVector<AdapterDefinition> adapters = registeredDesktopAppAdapters();

  for (const AdapterDefinition& adapter : adapters) {
    if (containsAnyLower(identity, adapter.appIdentifiers) ||
        containsAnyLower(identity, adapter.processNames)) {
      return metadataFromDefinition(adapter, 0.92, input);
    }
  }

  return genericDesktopAppMetadata(input);
}

inline AdapterMetadata resolveActivity(const AdapterInput& input) {
  if (hasWebsiteSignal(input)) {
    return resolveWebsite(input);
  }
  return resolveDesktopApp(input);
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_ACTIVITY_ADAPTER_REGISTRY_H
