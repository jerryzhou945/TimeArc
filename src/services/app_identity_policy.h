// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QRegularExpression>
#include <QString>
#include <QtGlobal>

namespace TimeArc::AppIdentityPolicy {

struct ValidationResult {
  bool ok = false;
  QString normalized;
  QString error;
};

inline QString normalizeCustomId(const QString& value) {
  QString slug = value.trimmed().toLower();
  if (slug.startsWith(QStringLiteral("app:"))) slug.remove(0, 4);
  slug.replace(QRegularExpression(QStringLiteral("[^a-z0-9._-]+")),
               QStringLiteral("-"));
  slug.replace(QRegularExpression(QStringLiteral("-+")),
               QStringLiteral("-"));
  slug.remove(QRegularExpression(QStringLiteral("^[._-]+|[._-]+$")));
  return slug.isEmpty() ? QString() : QStringLiteral("app:") + slug;
}

inline ValidationResult validateCustomId(const QString& value) {
  ValidationResult result;
  const QString trimmed = value.trimmed().toLower();
  if (trimmed.startsWith(QStringLiteral("site:")) ||
      trimmed.startsWith(QStringLiteral("path:")) ||
      trimmed.startsWith(QStringLiteral("exe:"))) {
    result.error = QStringLiteral("reserved_namespace");
    return result;
  }

  result.normalized = normalizeCustomId(value);
  static const QRegularExpression pattern(
      QStringLiteral("^app:[a-z0-9][a-z0-9._-]*$"));
  result.ok = pattern.match(result.normalized).hasMatch();
  if (!result.ok) result.error = QStringLiteral("invalid_custom_id");
  return result;
}

inline qint64 representativePathScore(const QString& groupKey,
                                      const QString& path,
                                      bool exists,
                                      qint64 recency) {
  const QString fileName = path.section(QLatin1Char('/'), -1).section(
      QLatin1Char('\\'), -1).toLower();
  const QString group = groupKey.toLower();
  qint64 score = exists ? 4'000'000'000'000'000LL : 0;

  const bool isWechat = group == QStringLiteral("app:wechat") ||
                        group == QStringLiteral("app:weixin");
  if (isWechat) {
    if (fileName == QStringLiteral("weixin.exe") ||
        fileName == QStringLiteral("wechat.exe")) {
      score += 2'000'000'000'000'000LL;
    } else if (fileName.contains(QStringLiteral("appex")) ||
               fileName.contains(QStringLiteral("update")) ||
               fileName.contains(QStringLiteral("helper"))) {
      score -= 2'000'000'000'000'000LL;
    }
  }

  return score + qBound<qint64>(0, recency, 1'000'000'000'000LL);
}

}  // namespace TimeArc::AppIdentityPolicy
