// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 TimeArc contributors

#include "DailyCardService.h"

#include <QDate>
#include <QDateTime>
#include <QVariant>

#include <algorithm>

#include "FrontmostSessionRepository.h"
#include "StatsService.h"

namespace {

constexpr int kTopAppLimit = 5;
// 两个活跃区间间断不超过该秒数，视为同一个连续专注块（10 分钟）。
constexpr qint64 kFocusGapSec = 10 * 60;
// 专注块至少要这么长才值得单独成卡（5 分钟），避免琐碎短块。
constexpr qint64 kFocusMinSpanSec = 5 * 60;

// 取一条 app 记录的显示名，displayName 为空时退回到 appIdentifier。
QString appDisplayName(const QVariantMap& app) {
  const QString name = app.value(QStringLiteral("displayName")).toString();
  if (!name.isEmpty()) return name;
  return app.value(QStringLiteral("appIdentifier")).toString();
}

// 本地化的时长文案，规则与 StatsService::formatDuration 对齐。
QString formatDuration(qint64 seconds) {
  const qint64 safe = std::max<qint64>(0, seconds);
  if (safe < 60) return QStringLiteral("%1s").arg(safe);
  const qint64 minutes = safe / 60;
  if (minutes < 60) return QStringLiteral("%1m").arg(minutes);
  const qint64 hours = minutes / 60;
  const qint64 rem = minutes % 60;
  if (rem == 0) return QStringLiteral("%1h").arg(hours);
  return QStringLiteral("%1h %2m").arg(hours).arg(rem);
}

// unix 秒 -> 本地 HH:mm。
QString formatClock(qint64 unixSec) {
  return QDateTime::fromSecsSinceEpoch(unixSec).toString(QStringLiteral("HH:mm"));
}

struct Block {
  qint64 start;
  qint64 end;
};

// 把今天的前台活跃区间合并成连续专注块：先按起点排序，间断 <= gap
// 的相邻区间桥接进同一块。返回按起点排序的块列表。
QList<Block> segmentFocusBlocks(const QVariantList& intervals, qint64 gap) {
  QList<Block> raw;
  for (const QVariant& item : intervals) {
    const QVariantMap m = item.toMap();
    const qint64 s = m.value(QStringLiteral("startUnixSec")).toLongLong();
    const qint64 e = m.value(QStringLiteral("endUnixSec")).toLongLong();
    if (e > s) raw.append({s, e});
  }
  std::sort(raw.begin(), raw.end(),
            [](const Block& a, const Block& b) { return a.start < b.start; });

  QList<Block> blocks;
  for (const Block& b : raw) {
    if (!blocks.isEmpty() && b.start - blocks.last().end <= gap) {
      blocks.last().end = std::max(blocks.last().end, b.end);
    } else {
      blocks.append(b);
    }
  }
  return blocks;
}

}  // namespace

DailyCardService::DailyCardService(
    StatsService* statsService, FrontmostSessionRepository* frontmostRepository,
    QObject* parent)
    : QObject(parent),
      m_statsService(statsService),
      m_frontmostRepository(frontmostRepository) {}

QVariantList DailyCardService::getTodayCards() {
  QVariantList cards;
  if (!m_statsService) return cards;

  const QString isoDate = QDate::currentDate().toString(Qt::ISODate);

  const QVariantMap mainline = buildMainlineCard(isoDate);
  if (!mainline.isEmpty()) cards.append(mainline);

  const QVariantMap topApps = buildTopAppsCard(isoDate);
  if (!topApps.isEmpty()) cards.append(topApps);

  const QVariantMap focusBlock = buildFocusBlockCard(isoDate);
  if (!focusBlock.isEmpty()) cards.append(focusBlock);

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

// 专注块卡：把今天的前台活跃区间按 10 分钟间断阈值分段，取最长的连续块。
QVariantMap DailyCardService::buildFocusBlockCard(const QString& isoDate) {
  if (!m_frontmostRepository) return QVariantMap();

  const qint64 dayStart =
      QDate::currentDate().startOfDay().toSecsSinceEpoch();
  const qint64 now = QDateTime::currentSecsSinceEpoch();
  if (now <= dayStart) return QVariantMap();

  const QList<Block> blocks = segmentFocusBlocks(
      m_frontmostRepository->getIntervalsByRange(dayStart, now), kFocusGapSec);
  if (blocks.isEmpty()) return QVariantMap();

  const Block longest = *std::max_element(
      blocks.begin(), blocks.end(), [](const Block& a, const Block& b) {
        return (a.end - a.start) < (b.end - b.start);
      });

  const qint64 span = longest.end - longest.start;
  if (span < kFocusMinSpanSec) return QVariantMap();

  const QString range =
      formatClock(longest.start) + QStringLiteral("–") + formatClock(longest.end);

  QVariantList metrics;
  metrics.append(QVariantMap{{QStringLiteral("label"),
                              QStringLiteral("持续时长")},
                             {QStringLiteral("value"), formatDuration(span)}});

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-focus-block"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("focus_block"));
  card.insert(QStringLiteral("title"), QStringLiteral("专注块"));
  card.insert(QStringLiteral("body"),
              QStringLiteral("这是你今天最长的一段连续活跃,中途没有长时间离开。"));
  card.insert(QStringLiteral("timeRange"), range);
  card.insert(QStringLiteral("metrics"), metrics);
  card.insert(QStringLiteral("apps"), QVariantList());
  card.insert(QStringLiteral("tags"), QVariantList());
  card.insert(QStringLiteral("confidence"), 0.7);
  card.insert(QStringLiteral("source"), QStringLiteral("local_rule"));
  card.insert(QStringLiteral("aiGenerated"), false);
  return card;
}
