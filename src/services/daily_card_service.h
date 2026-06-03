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

  // 记忆湖·日视图模型（本地确定性）。入参是 QML 从 UsageStatManager 取到的
  // 同首页只读数据：usmApps = activeSoftwareForRange("day")，
  // segments = foregroundSegmentsForRange("day")。本服务只做 classify + 文案
  // 模板 + 聚合，产出与 MemoryLakeMock 同形的结构，QML 只渲染：
  //   { apps:[{appId,name,path,category,type,time,seconds,progress,mood,
  //            analysis,launches,longest,times,sessionCount}],
  //     overview:{total,sub}, todayTheme:{kicker,title,desc,ratio} }
  // 无当日数据时返回空 apps，由 QML 走兜底/空态。把取数留在 QML（首页同款路径）
  // 让本服务与 UsageStatManager 解耦（测试目标 db_smoke 不链接 USM）。
  Q_INVOKABLE QVariantMap memoryLakeDay(const QVariantList& usmApps,
                                        const QVariantList& segments);

  // 记忆湖·月度回顾模型（阶段二，本地确定性、题材中立、防错配）。入参均为 QML
  // 从 UsageStatManager 取到的只读月度数据：
  //   monthApps      = activeSoftwareForRange("month")（当月 Top，已按时长降序）
  //   monthSegments  = foregroundSegmentsForRange("month")（当月每 app 会话段）
  //   lastMonthApps  = activeSoftwareForMonth(上月)（环比用，可空）
  //   dailySeries    = dailySecondsForMonth(当月)（趋势/月历柱）
  // 产出 { headerLeft, headerRight, modeNote, apps, slides:[...] }，slides 条数
  // 随真实主角数量动态变化；无当月数据时只给封面空态。QML 只渲染。
  Q_INVOKABLE QVariantMap memoryLakeRecap(const QVariantList& monthApps,
                                          const QVariantList& monthSegments,
                                          const QVariantList& lastMonthApps,
                                          const QVariantList& dailySeries);

 private:
  QVariantMap buildMainlineCard(const QString& isoDate);
  QVariantMap buildTopAppsCard(const QString& isoDate);
  QVariantMap buildFocusBlockCard(const QString& isoDate);
  QVariantMap buildEntertainmentCard(const QString& isoDate);
  QVariantMap buildContrastCard(const QString& isoDate);
  QVariantMap buildFlipCard(const QString& isoDate);

  StatsService* m_statsService;
  FrontmostSessionRepository* m_frontmostRepository;
};

#endif
