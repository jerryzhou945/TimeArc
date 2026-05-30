// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 TimeArc contributors

#include "DailyCardService.h"

#include <QDate>
#include <QVariant>

#include "StatsService.h"

namespace {

constexpr int kTopAppLimit = 5;

// 取一条 app 记录的显示名，displayName 为空时退回到 appIdentifier。
QString appDisplayName(const QVariantMap& app) {
  const QString name = app.value(QStringLiteral("displayName")).toString();
  if (!name.isEmpty()) return name;
  return app.value(QStringLiteral("appIdentifier")).toString();
}

}  // namespace

DailyCardService::DailyCardService(StatsService* statsService, QObject* parent)
    : QObject(parent), m_statsService(statsService) {}

QVariantList DailyCardService::getTodayCards() {
  QVariantList cards;
  if (!m_statsService) return cards;

  const QString isoDate = QDate::currentDate().toString(Qt::ISODate);

  const QVariantMap mainline = buildMainlineCard(isoDate);
  if (!mainline.isEmpty()) cards.append(mainline);

  const QVariantMap topApps = buildTopAppsCard(isoDate);
  if (!topApps.isEmpty()) cards.append(topApps);

  return cards;
}

// 今日主线卡：用前台活跃总时长 + 排名第一的 app 套模板。
QVariantMap DailyCardService::buildMainlineCard(const QString& isoDate) {
  const int totalSec = m_statsService->getTodayFrontmostActiveSeconds();
  if (totalSec <= 0) return QVariantMap();

  const QString totalText = m_statsService->getTodayFrontmostActiveText();
  const QVariantList ranking = m_statsService->getTodayAppRanking();

  QString topApp;
  if (!ranking.isEmpty()) {
    topApp = appDisplayName(ranking.first().toMap());
  }

  QString body = QStringLiteral("你今天的前台活跃时间约 %1。").arg(totalText);
  if (!topApp.isEmpty()) {
    body += QStringLiteral("主要花在 %1 上。").arg(topApp);
  }

  QVariantList metrics;
  metrics.append(QVariantMap{{QStringLiteral("label"),
                              QStringLiteral("前台活跃")},
                             {QStringLiteral("value"), totalText}});

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-mainline"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("mainline"));
  card.insert(QStringLiteral("title"), QStringLiteral("今日主线"));
  card.insert(QStringLiteral("body"), body);
  card.insert(QStringLiteral("timeRange"), QString());
  card.insert(QStringLiteral("metrics"), metrics);
  card.insert(QStringLiteral("apps"), QVariantList());
  card.insert(QStringLiteral("tags"), QVariantList());
  card.insert(QStringLiteral("confidence"), 0.8);
  card.insert(QStringLiteral("source"), QStringLiteral("local_template"));
  card.insert(QStringLiteral("aiGenerated"), false);
  return card;
}

// App 使用卡：直接复用今日排名前 N 条（已含 displayName / durationText /
// appIconPath / durationSec），交给 QML 画图标 + 时长 + 进度条。
QVariantMap DailyCardService::buildTopAppsCard(const QString& isoDate) {
  const QVariantList ranking = m_statsService->getTodayAppRanking();
  if (ranking.isEmpty()) return QVariantMap();

  QVariantList apps;
  for (const QVariant& entry : ranking) {
    if (apps.size() >= kTopAppLimit) break;
    const QVariantMap src = entry.toMap();
    // app_icon_path 在库里通常为空；退回到 app_identifier(即可执行文件
    // 全路径),交给 QFileIconProvider 抽取系统图标。
    QString iconPath = src.value(QStringLiteral("appIconPath")).toString();
    if (iconPath.isEmpty()) {
      iconPath = src.value(QStringLiteral("appIdentifier")).toString();
    }
    QVariantMap app;
    app.insert(QStringLiteral("displayName"), appDisplayName(src));
    app.insert(QStringLiteral("durationText"),
               src.value(QStringLiteral("durationText")));
    app.insert(QStringLiteral("durationSec"),
               src.value(QStringLiteral("durationSec")));
    app.insert(QStringLiteral("appIconPath"), iconPath);
    apps.append(app);
  }

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-top-apps"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("top_apps"));
  card.insert(QStringLiteral("title"), QStringLiteral("App 使用"));
  card.insert(QStringLiteral("body"),
              QStringLiteral("今天使用时间最长的应用"));
  card.insert(QStringLiteral("timeRange"), QString());
  card.insert(QStringLiteral("metrics"), QVariantList());
  card.insert(QStringLiteral("apps"), apps);
  card.insert(QStringLiteral("tags"), QVariantList());
  card.insert(QStringLiteral("confidence"), 0.9);
  card.insert(QStringLiteral("source"), QStringLiteral("local_template"));
  card.insert(QStringLiteral("aiGenerated"), false);
  return card;
}
