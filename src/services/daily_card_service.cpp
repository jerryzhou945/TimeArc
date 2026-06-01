// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 TimeArc contributors

#include "services/daily_card_service.h"

#include <QDate>
#include <QDateTime>
#include <QHash>
#include <QStringList>
#include <QVariant>

#include <algorithm>

#include "services/frontmost_session_repository.h"
#include "services/stats_service.h"

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

// 把排名记录整理成卡片用的 app 条目（图标退回 app_identifier 全路径）。
QVariantMap makeAppEntry(const QVariantMap& src) {
  QString iconPath = src.value(QStringLiteral("appIconPath")).toString();
  if (iconPath.isEmpty()) {
    iconPath = src.value(QStringLiteral("appIdentifier")).toString();
  }
  return QVariantMap{
      {QStringLiteral("displayName"), appDisplayName(src)},
      {QStringLiteral("durationText"), src.value(QStringLiteral("durationText"))},
      {QStringLiteral("durationSec"), src.value(QStringLiteral("durationSec"))},
      {QStringLiteral("appIconPath"), iconPath},
  };
}

// 本地规则分类器（第一版硬编码，后续可搬进 SettingsRepository 做可编辑）。
// 依据 app_identifier / 显示名的关键词归类，未命中归“其他”。
QString classifyApp(const QVariantMap& app) {
  const QString hay = (app.value(QStringLiteral("appIdentifier")).toString() +
                       QLatin1Char(' ') +
                       app.value(QStringLiteral("displayName")).toString())
                          .toLower();
  auto has = [&](const char* kw) { return hay.contains(QLatin1String(kw)); };

  if (has("steam") || has("epicgames") || has("riotclient") ||
      has("leagueoflegends") || has("genshin") || has("streetfighter") ||
      has("game"))
    return QStringLiteral("游戏");
  if (has("bilibili") || has("youtube") || has("potplayer") || has("vlc.exe") ||
      has("iqiyi") || has("youku") || has("netflix") || has("tencentvideo") ||
      has("qqlive"))
    return QStringLiteral("视频");
  if (has("qqmusic") || has("cloudmusic") || has("spotify") || has("netease"))
    return QStringLiteral("音乐");
  if (has("weixin") || has("wechat") || has("discord") || has("telegram") ||
      has("slack") || has("qq.exe"))
    return QStringLiteral("社交");
  if (has("code.exe") || has("devenv") || has("clion") || has("pycharm") ||
      has("idea64") || has("qtcreator") || has("windowsterminal") ||
      has("powershell") || has("cmd.exe"))
    return QStringLiteral("开发");
  return QStringLiteral("其他");
}

// 计入“娱乐卡”的分类：游戏 + 视频。
bool isEntertainment(const QString& category) {
  return category == QStringLiteral("游戏") ||
         category == QStringLiteral("视频");
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

  const QVariantMap entertainment = buildEntertainmentCard(isoDate);
  if (!entertainment.isEmpty()) cards.append(entertainment);

  const QVariantMap contrast = buildContrastCard(isoDate);
  if (!contrast.isEmpty()) cards.append(contrast);

  const QVariantMap flip = buildFlipCard(isoDate);
  if (!flip.isEmpty()) cards.append(flip);

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
    apps.append(makeAppEntry(entry.toMap()));
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

// 娱乐卡：用本地分类器筛出今天的“游戏 + 视频”类 app，汇总时长。
QVariantMap DailyCardService::buildEntertainmentCard(const QString& isoDate) {
  const QVariantList ranking = m_statsService->getTodayAppRanking();

  QVariantList apps;
  qint64 totalSec = 0;
  QString topApp;
  for (const QVariant& entry : ranking) {
    const QVariantMap src = entry.toMap();
    if (!isEntertainment(classifyApp(src))) continue;
    totalSec += src.value(QStringLiteral("durationSec")).toLongLong();
    if (apps.size() < kTopAppLimit) apps.append(makeAppEntry(src));
    if (topApp.isEmpty()) topApp = appDisplayName(src);
  }

  if (totalSec <= 0) return QVariantMap();

  QString body = QStringLiteral("今天的娱乐时间约 %1。").arg(formatDuration(totalSec));
  if (!topApp.isEmpty()) {
    body += QStringLiteral("主要来自 %1。").arg(topApp);
  }

  QVariantList metrics;
  metrics.append(QVariantMap{{QStringLiteral("label"),
                              QStringLiteral("娱乐时长")},
                             {QStringLiteral("value"), formatDuration(totalSec)}});

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-entertainment"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("entertainment"));
  card.insert(QStringLiteral("title"), QStringLiteral("娱乐"));
  card.insert(QStringLiteral("body"), body);
  card.insert(QStringLiteral("timeRange"), QString());
  card.insert(QStringLiteral("metrics"), metrics);
  card.insert(QStringLiteral("apps"), apps);
  card.insert(QStringLiteral("tags"), QVariantList());
  card.insert(QStringLiteral("confidence"), 0.6);
  card.insert(QStringLiteral("source"), QStringLiteral("local_rule"));
  card.insert(QStringLiteral("aiGenerated"), false);
  return card;
}

// 反差卡：专注（开发类）vs 娱乐（游戏/视频类）的时间对比。
// 注：现有数据没有“计划时长”字段，所以这里用分类时间做可计算的反差，
// 等将来有计划/目标时长后再升级成真正的“计划 vs 实际”。
QVariantMap DailyCardService::buildContrastCard(const QString& isoDate) {
  const QVariantList ranking = m_statsService->getTodayAppRanking();

  qint64 focusSec = 0;
  qint64 leisureSec = 0;
  for (const QVariant& entry : ranking) {
    const QVariantMap src = entry.toMap();
    const QString cat = classifyApp(src);
    const qint64 sec = src.value(QStringLiteral("durationSec")).toLongLong();
    if (cat == QStringLiteral("开发")) {
      focusSec += sec;
    } else if (isEntertainment(cat)) {
      leisureSec += sec;
    }
  }

  if (focusSec <= 0 && leisureSec <= 0) return QVariantMap();

  QVariantList metrics;
  metrics.append(QVariantMap{{QStringLiteral("label"),
                              QStringLiteral("专注 · 开发")},
                             {QStringLiteral("value"), formatDuration(focusSec)}});
  metrics.append(QVariantMap{{QStringLiteral("label"),
                              QStringLiteral("娱乐 · 游戏视频")},
                             {QStringLiteral("value"), formatDuration(leisureSec)}});

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-contrast"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("contrast"));
  card.insert(QStringLiteral("title"), QStringLiteral("专注 vs 娱乐"));
  card.insert(QStringLiteral("body"),
              QStringLiteral("今天检测到的专注类(开发)和娱乐类(游戏/视频)时间对比。"));
  card.insert(QStringLiteral("timeRange"), QString());
  card.insert(QStringLiteral("metrics"), metrics);
  card.insert(QStringLiteral("apps"), QVariantList());
  card.insert(QStringLiteral("tags"), QVariantList());
  card.insert(QStringLiteral("confidence"), 0.55);
  card.insert(QStringLiteral("source"), QStringLiteral("local_rule"));
  card.insert(QStringLiteral("aiGenerated"), false);
  return card;
}

// 今日翻牌卡：一条轻量“小发现”。从一个确定性的事实池里按日期轮换，
// 既有变化又可复现（不用真随机），尽量和其它卡不重复。
QVariantMap DailyCardService::buildFlipCard(const QString& isoDate) {
  const QVariantList ranking = m_statsService->getTodayAppRanking();
  if (ranking.isEmpty()) return QVariantMap();

  QStringList facts;
  facts << QStringLiteral("今天你一共打开了 %1 个不同的应用。").arg(ranking.size());
  facts << QStringLiteral("今天用得最多的是 %1。")
               .arg(appDisplayName(ranking.first().toMap()));

  // 占比最高的活动类型（排除“其他”，否则没意义）。
  QHash<QString, qint64> byCategory;
  for (const QVariant& entry : ranking) {
    const QVariantMap src = entry.toMap();
    byCategory[classifyApp(src)] +=
        src.value(QStringLiteral("durationSec")).toLongLong();
  }
  QString topCategory;
  qint64 topCategorySec = 0;
  for (auto it = byCategory.constBegin(); it != byCategory.constEnd(); ++it) {
    if (it.key() == QStringLiteral("其他")) continue;
    if (it.value() > topCategorySec) {
      topCategorySec = it.value();
      topCategory = it.key();
    }
  }
  if (!topCategory.isEmpty()) {
    facts << QStringLiteral("今天占比最高的活动类型是「%1」。").arg(topCategory);
  }

  // 按一年中的第几天轮换，当天稳定。
  const int idx = QDate::currentDate().dayOfYear() % facts.size();

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-flip"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("random_flip"));
  card.insert(QStringLiteral("title"), QStringLiteral("今日翻牌"));
  card.insert(QStringLiteral("body"), facts.at(idx));
  card.insert(QStringLiteral("timeRange"), QString());
  card.insert(QStringLiteral("metrics"), QVariantList());
  card.insert(QStringLiteral("apps"), QVariantList());
  card.insert(QStringLiteral("tags"), QVariantList());
  card.insert(QStringLiteral("confidence"), 0.5);
  card.insert(QStringLiteral("source"), QStringLiteral("local_rule"));
  card.insert(QStringLiteral("aiGenerated"), false);
  return card;
}
