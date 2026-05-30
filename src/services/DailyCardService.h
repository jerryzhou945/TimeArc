// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 TimeArc contributors

#ifndef DAILYCARDSERVICE_H
#define DAILYCARDSERVICE_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class StatsService;
class FrontmostSessionRepository;

// 生活时间线的卡片生成器。本地确定性卡片（今日主线 / App 使用 / 专注块），
// 数据复用 StatsService 的聚合结果与 FrontmostSessionRepository 的活跃区间，
// 不重复实现统计，也不落库。卡片是 UI 无关的 QVariantMap，字段见
// docs/card-ai-development-spec.md。
class DailyCardService : public QObject {
  Q_OBJECT

 public:
  explicit DailyCardService(StatsService* statsService,
                            FrontmostSessionRepository* frontmostRepository,
                            QObject* parent = nullptr);

  // 返回今天的卡片列表（QVariantMap 列表）。无任何记录时返回空列表，
  // 由 QML 显示空态。
  Q_INVOKABLE QVariantList getTodayCards();

 private:
  QVariantMap buildMainlineCard(const QString& isoDate);
  QVariantMap buildTopAppsCard(const QString& isoDate);
  QVariantMap buildFocusBlockCard(const QString& isoDate);
  QVariantMap buildEntertainmentCard(const QString& isoDate);
  QVariantMap buildContrastCard(const QString& isoDate);

  StatsService* m_statsService;
  FrontmostSessionRepository* m_frontmostRepository;
};

#endif
