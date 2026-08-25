// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QString>
#include <QtGlobal>

namespace TimeArc::AppIdentityPolicy {

struct DisplayIdentity {
  QString groupKey;
  QString displayName;
};

inline DisplayIdentity applyDisplayName(const QString& groupKey,
                                        const QString& defaultName,
                                        const QString& customName) {
  const QString trimmed = customName.trimmed();
  return {groupKey, trimmed.isEmpty() ? defaultName : trimmed.left(80)};
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
