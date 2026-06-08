// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_ADAPTERS_ADAPTER_METADATA_H
#define TIMEARC_SERVICES_ADAPTERS_ADAPTER_METADATA_H

#include <QFileInfo>
#include <QRegularExpression>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>

namespace TimeArcAdapters {

struct AdapterInput {
  QString source;
  QString appId;
  QString appName;
  QString path;
  QString title;
  QString url;
  QString hostname;
  QString domain;
};

struct AdapterMetadata {
  bool matched = false;
  QString sourceType;
  QString identifier;
  QString displayName;
  QString title;
  QString domain;
  QString iconUrl;
  QString iconPath;
  QString iconLabel;
  QString brandColor;
  QString category;
  bool supportsMediaDetection = false;
  double confidence = 0.0;

  QVariantMap toVariantMap() const {
    QVariantMap map;
    map.insert(QStringLiteral("sourceType"), sourceType);
    map.insert(QStringLiteral("identifier"), identifier);
    map.insert(QStringLiteral("displayName"), displayName);
    map.insert(QStringLiteral("title"), title);
    map.insert(QStringLiteral("domain"), domain);
    map.insert(QStringLiteral("iconUrl"), iconUrl);
    map.insert(QStringLiteral("iconPath"), iconPath);
    map.insert(QStringLiteral("iconLabel"), iconLabel);
    map.insert(QStringLiteral("brandColor"), brandColor);
    map.insert(QStringLiteral("category"), category);
    map.insert(QStringLiteral("supportsMediaDetection"),
               supportsMediaDetection);
    map.insert(QStringLiteral("confidence"), confidence);
    return map;
  }
};

struct AdapterDefinition {
  QString identifier;
  QString sourceType;
  QString displayName;
  QString category;
  QString domain;
  QString iconUrl;
  QString iconPath;
  QString iconLabel;
  QString brandColor;
  bool supportsMediaDetection = false;
  QStringList hostnames;
  QStringList urlPatterns;
  QStringList titleHints;
  QStringList appIdentifiers;
  QStringList processNames;
};

inline QString normalizedLower(const QString& value) {
  return value.trimmed().toLower();
}

inline QString hostFromInput(const AdapterInput& input) {
  QString host = normalizedLower(input.hostname);
  if (host.isEmpty()) host = normalizedLower(input.domain);
  if (host.isEmpty() && !input.url.trimmed().isEmpty()) {
    QUrl url(input.url.trimmed());
    if (!url.isValid() || url.host().isEmpty()) {
      url = QUrl(QStringLiteral("https://") + input.url.trimmed());
    }
    host = normalizedLower(url.host());
  }
  while (host.startsWith(QStringLiteral("www."))) {
    host = host.mid(4);
  }
  return host;
}

inline QString urlForMatching(const AdapterInput& input) {
  return input.url.trimmed();
}

inline bool hostMatches(const QString& host, const QString& pattern) {
  const QString normalizedHost = normalizedLower(host);
  QString normalizedPattern = normalizedLower(pattern);
  while (normalizedPattern.startsWith(QStringLiteral("www."))) {
    normalizedPattern = normalizedPattern.mid(4);
  }
  if (normalizedHost.isEmpty() || normalizedPattern.isEmpty()) return false;
  return normalizedHost == normalizedPattern ||
         normalizedHost.endsWith(QStringLiteral(".") + normalizedPattern);
}

inline bool containsAnyLower(const QString& text, const QStringList& needles) {
  const QString normalized = normalizedLower(text);
  if (normalized.isEmpty()) return false;
  for (const QString& needle : needles) {
    const QString n = normalizedLower(needle);
    if (!n.isEmpty() && normalized.contains(n)) return true;
  }
  return false;
}

inline bool urlMatchesAny(const QString& url, const QStringList& patterns) {
  if (url.trimmed().isEmpty()) return false;
  for (const QString& pattern : patterns) {
    QRegularExpression re(pattern,
                          QRegularExpression::CaseInsensitiveOption);
    if (re.isValid() && re.match(url).hasMatch()) return true;
  }
  return false;
}

inline QString displayNameFromHost(const QString& host) {
  const QString normalizedHost = hostFromInput(AdapterInput{QString(),
                                                            QString(),
                                                            QString(),
                                                            QString(),
                                                            QString(),
                                                            QString(),
                                                            host,
                                                            QString()});
  return normalizedHost.isEmpty() ? QStringLiteral("Website") : normalizedHost;
}

inline QString displayNameFromApp(const AdapterInput& input) {
  QString name = !input.appName.trimmed().isEmpty()
                     ? input.appName.trimmed()
                     : QFileInfo(input.path).fileName();
  if (name.endsWith(QStringLiteral(".exe"), Qt::CaseInsensitive)) {
    name.chop(4);
  }
  return name.trimmed().isEmpty() ? QStringLiteral("Application") : name;
}

inline QString appIdentityText(const AdapterInput& input) {
  return (input.appId + QStringLiteral(" ") + input.appName +
          QStringLiteral(" ") + input.path)
      .toLower();
}

inline QString fallbackAppIdentifier(const AdapterInput& input) {
  QString appName = displayNameFromApp(input).toLower();
  if (!appName.isEmpty() && appName != QStringLiteral("application")) {
    return QStringLiteral("app:") + appName.replace(QStringLiteral(" "),
                                                    QStringLiteral("-"));
  }
  const QString fallback = !input.appId.trimmed().isEmpty() ? input.appId
                                                            : input.path;
  return fallback.trimmed().isEmpty()
             ? QStringLiteral("app:unknown")
             : QStringLiteral("path:") + fallback.toLower();
}

inline AdapterMetadata metadataFromDefinition(const AdapterDefinition& def,
                                              double confidence,
                                              const AdapterInput& input) {
  AdapterMetadata metadata;
  metadata.matched = true;
  metadata.sourceType = def.sourceType;
  metadata.identifier = def.identifier;
  metadata.displayName = def.displayName;
  metadata.title = input.title;
  metadata.domain = def.domain;
  metadata.iconUrl = def.iconUrl;
  metadata.iconPath = def.iconPath;
  metadata.iconLabel = def.iconLabel;
  metadata.brandColor = def.brandColor;
  metadata.category = def.category;
  metadata.supportsMediaDetection = def.supportsMediaDetection;
  metadata.confidence = confidence;
  return metadata;
}

inline AdapterMetadata genericWebsiteMetadata(const AdapterInput& input) {
  const QString host = hostFromInput(input);
  AdapterMetadata metadata;
  metadata.matched = !host.isEmpty();
  metadata.sourceType = QStringLiteral("website");
  metadata.identifier = host.isEmpty() ? QStringLiteral("site:unknown")
                                       : QStringLiteral("site:") + host;
  metadata.displayName = displayNameFromHost(host);
  metadata.title = input.title;
  metadata.domain = host;
  metadata.iconLabel = host.isEmpty() ? QStringLiteral("W")
                                      : host.left(1).toUpper();
  metadata.brandColor = QStringLiteral("#BFD7EA");
  metadata.category = QStringLiteral("网站");
  metadata.confidence = host.isEmpty() ? 0.0 : 0.72;
  return metadata;
}

inline AdapterMetadata genericDesktopAppMetadata(const AdapterInput& input) {
  AdapterMetadata metadata;
  metadata.matched = false;
  metadata.sourceType = QStringLiteral("desktopApp");
  metadata.identifier = fallbackAppIdentifier(input);
  metadata.displayName = displayNameFromApp(input);
  metadata.title = input.title;
  metadata.iconPath = input.path;
  metadata.iconLabel = metadata.displayName.left(1).toUpper();
  metadata.brandColor = QStringLiteral("#D8D1CA");
  metadata.category = QStringLiteral("应用");
  metadata.confidence = 0.40;
  return metadata;
}

}  // namespace TimeArcAdapters

#endif  // TIMEARC_SERVICES_ADAPTERS_ADAPTER_METADATA_H
