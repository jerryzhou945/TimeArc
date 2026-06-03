// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 TimeArc contributors

#include "services/daily_card_service.h"

#include <QDate>
#include <QDateTime>
#include <QHash>
#include <QStringList>
#include <QVariant>
#include <QVector>

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

// ===== 记忆湖·日视图：本地确定性文案/聚合（通用化，§5/§6）=====
// 全部只引用可度量信号（类别 + 时长/连续性/启动/时段），不出现题材专属叙事。

// 把 UsageStatManager 项（字段 path/appName/groupKey/name）适配成 classifyApp
// 需要的 {appIdentifier, displayName}。喂入 path+appName+groupKey 提高命中率。
QString categoryForUsmItem(const QVariantMap& usmItem) {
  QVariantMap proxy;
  proxy.insert(QStringLiteral("appIdentifier"),
               usmItem.value(QStringLiteral("path")).toString() +
                   QLatin1Char(' ') +
                   usmItem.value(QStringLiteral("appName")).toString() +
                   QLatin1Char(' ') +
                   usmItem.value(QStringLiteral("groupKey")).toString());
  proxy.insert(QStringLiteral("displayName"),
               usmItem.value(QStringLiteral("name")).toString());
  return classifyApp(proxy);
}

// 大号"使用总览"用十进制小时（如 8.9h），与设计稿一致；不足 1 小时给分钟。
QString decimalHoursText(qint64 seconds) {
  const qint64 s = std::max<qint64>(0, seconds);
  if (s < 3600) return QStringLiteral("%1m").arg(s / 60);
  return QStringLiteral("%1h").arg(QString::number(s / 3600.0, 'f', 1));
}

QString periodForHour(int hour) {
  if (hour >= 5 && hour < 8) return QStringLiteral("清晨");
  if (hour >= 8 && hour < 11) return QStringLiteral("上午");
  if (hour >= 11 && hour < 14) return QStringLiteral("中午");
  if (hour >= 14 && hour < 18) return QStringLiteral("下午");
  if (hour >= 18 && hour < 22) return QStringLiteral("傍晚");
  if (hour >= 22 || hour < 2) return QStringLiteral("夜间");  // 22:00–02:00
  return QStringLiteral("深夜");                              // 02:00–05:00
}

// 主要时段：按会话中点小时、以时长加权，取占比最高的时段；无会话返回空串。
QString dominantPeriod(const QVariantList& segments) {
  QHash<QString, qint64> bucket;
  for (const QVariant& v : segments) {
    const QVariantMap s = v.toMap();
    const qint64 startU = s.value(QStringLiteral("startUnixSec")).toLongLong();
    const qint64 endU = s.value(QStringLiteral("endUnixSec")).toLongLong();
    const qint64 dur = s.value(QStringLiteral("seconds")).toLongLong();
    const qint64 mid = startU + (endU - startU) / 2;
    const int hour = QDateTime::fromSecsSinceEpoch(mid).time().hour();
    bucket[periodForHour(hour)] += dur;
  }
  QString top;
  qint64 topSec = 0;
  for (auto it = bucket.constBegin(); it != bucket.constEnd(); ++it) {
    if (it.value() > topSec) {
      topSec = it.value();
      top = it.key();
    }
  }
  return top;
}

// 时段 -> 2 字代表词（"何时用它"是最有用户独特性的信号）。
QString periodWord(const QString& period) {
  if (period == QStringLiteral("清晨")) return QStringLiteral("清晨");
  if (period == QStringLiteral("上午")) return QStringLiteral("上午");
  if (period == QStringLiteral("中午")) return QStringLiteral("午间");
  if (period == QStringLiteral("下午")) return QStringLiteral("午后");
  if (period == QStringLiteral("傍晚")) return QStringLiteral("傍晚");
  if (period == QStringLiteral("夜间")) return QStringLiteral("夜间");
  if (period == QStringLiteral("深夜")) return QStringLiteral("深夜");
  return QString();
}

// 长会话的类别强度短词（2 字）。
QString intensityShort(const QString& category) {
  if (category == QStringLiteral("游戏")) return QStringLiteral("沉浸");
  if (category == QStringLiteral("开发")) return QStringLiteral("专注");
  if (category == QStringLiteral("视频")) return QStringLiteral("追剧");
  if (category == QStringLiteral("创作")) return QStringLiteral("沉浸");
  if (category == QStringLiteral("办公")) return QStringLiteral("专注");
  if (category == QStringLiteral("笔记")) return QStringLiteral("专注");
  if (category == QStringLiteral("浏览")) return QStringLiteral("深读");
  if (category == QStringLiteral("社交")) return QStringLiteral("畅聊");
  return QStringLiteral("沉浸");
}

// 心情词：只用**有代表性、有独特性**的信号——主要时段（何时）+ 单次时长强度（多投入）。
// 刻意避开"穿插/平稳/日常/切换/碎片"这类人人用电脑都会触发、不够 specialized 的词。
QString moodWord(const QString& category, const QString& period,
                 qint64 longestSec, qint64 totalSec) {
  if (totalSec < 5 * 60) return QStringLiteral("短暂一瞥");
  const bool isLong = longestSec >= 30 * 60;
  const QString pw = periodWord(period);

  if (category == QStringLiteral("音乐"))
    return isLong ? QStringLiteral("沉浸聆听")
                  : (pw.isEmpty() ? QStringLiteral("聆听陪伴")
                                  : pw + QStringLiteral("聆听"));

  if (isLong) {  // 长单次会话本身就 distinctive：主要时段 + 强度
    const QString is = intensityShort(category);
    return pw.isEmpty() ? (QStringLiteral("长时") + is) : (pw + is);
  }
  // 非长会话：以"主要时段"立意（你主要在什么时候用它）。
  if (!pw.isEmpty()) return pw + QStringLiteral("使用");
  return QStringLiteral("零星使用");
}

// 分析句：只拼**可度量事实**（时长 / 主要时段 / 单次最长 / 打开次数），不下"穿插/平稳"
// 这类通用判断；填不上的从句整句省略。
QString analysisText(const QString& name, const QString& timeText,
                     const QString& period, qint64 longestSec, int sessionCount,
                     qint64 totalSec) {
  if (totalSec < 5 * 60) {
    return QStringLiteral("%1 今天只是短暂打开了一下。").arg(name);
  }
  QString s = QStringLiteral("%1 今天使用约 %2").arg(name, timeText);
  if (!period.isEmpty()) s += QStringLiteral("，主要在%1").arg(period);
  if (longestSec > 0)
    s += QStringLiteral("，单次最长 %1").arg(formatDuration(longestSec));
  if (sessionCount > 0) s += QStringLiteral("，共打开 %1 次").arg(sessionCount);
  s += QStringLiteral("。");
  return s;
}

// 时间河流节点：合并会话段 -> {start,end,y(0..1 全天分数),dur(秒)}。
// y 与轴统一固定 0–24h 时间窗（§3.6 反错配）。碎片过多时按时长取前 8 段。
QVariantList buildRiverNodes(const QVariantList& segments, qint64 dayStart) {
  QVector<QVariantMap> segs;
  for (const QVariant& v : segments) segs.append(v.toMap());
  std::sort(segs.begin(), segs.end(),
            [](const QVariantMap& a, const QVariantMap& b) {
              return a.value(QStringLiteral("seconds")).toLongLong() >
                     b.value(QStringLiteral("seconds")).toLongLong();
            });
  if (segs.size() > 8) segs.resize(8);
  std::sort(segs.begin(), segs.end(),
            [](const QVariantMap& a, const QVariantMap& b) {
              return a.value(QStringLiteral("startUnixSec")).toLongLong() <
                     b.value(QStringLiteral("startUnixSec")).toLongLong();
            });

  QVariantList nodes;
  constexpr double kDaySec = 24.0 * 3600.0;
  for (const QVariantMap& s : segs) {
    const qint64 startU = s.value(QStringLiteral("startUnixSec")).toLongLong();
    const qint64 endU = s.value(QStringLiteral("endUnixSec")).toLongLong();
    const qint64 dur = s.value(QStringLiteral("seconds")).toLongLong();
    double y = static_cast<double>(startU - dayStart) / kDaySec;
    y = std::min(1.0, std::max(0.0, y));
    QVariantMap node;
    node.insert(QStringLiteral("start"),
                QDateTime::fromSecsSinceEpoch(startU).toString(
                    QStringLiteral("HH:mm")));
    node.insert(QStringLiteral("end"),
                QDateTime::fromSecsSinceEpoch(endU).toString(
                    QStringLiteral("HH:mm")));
    node.insert(QStringLiteral("y"), y);
    node.insert(QStringLiteral("dur"), static_cast<qlonglong>(dur));
    nodes.append(node);
  }
  return nodes;
}

// 任务块：把所有 app 的前台会话段在**统一时间轴**上合并成"连续使用块"
// （块间空闲 <12min 视为同一段），每块按时长取主类别 + 代表 app。跨 app 跳转
// 落在同一块里 = 一段任务（如开发时在 VSCode/Chrome/Terminal 间跳），不是碎片。
// 系统/外壳类别不参与命名（降权）。返回按块跨度降序 [{category,span,apps}]。
QVariantList taskBlocks(const QVariantList& segments,
                        const QHash<QString, QString>& catByKey,
                        const QHash<QString, QString>& nameByKey) {
  struct Seg { qint64 start; qint64 end; qint64 sec; QString cat; QString name; };
  QVector<Seg> segs;
  for (const QVariant& av : segments) {
    const QVariantMap a = av.toMap();
    const QString key = a.value(QStringLiteral("groupKey")).toString();
    const QString cat = catByKey.value(key, QStringLiteral("其他"));
    const QString name = nameByKey.value(key, key);
    for (const QVariant& sv : a.value(QStringLiteral("segments")).toList()) {
      const QVariantMap s = sv.toMap();
      segs.append({s.value(QStringLiteral("startUnixSec")).toLongLong(),
                   s.value(QStringLiteral("endUnixSec")).toLongLong(),
                   s.value(QStringLiteral("seconds")).toLongLong(), cat, name});
    }
  }
  std::sort(segs.begin(), segs.end(),
            [](const Seg& a, const Seg& b) { return a.start < b.start; });

  constexpr qint64 kTaskGap = 12 * 60;
  struct Block {
    qint64 start;
    qint64 end;
    QHash<QString, qint64> catSec;
    QHash<QString, qint64> appSec;
  };
  QVector<Block> blocks;
  for (const Seg& s : segs) {
    if (s.end <= s.start) continue;
    if (!blocks.isEmpty() && s.start - blocks.last().end <= kTaskGap) {
      blocks.last().end = std::max(blocks.last().end, s.end);
    } else {
      blocks.append({s.start, s.end, {}, {}});
    }
    Block& b = blocks.last();
    if (s.cat != QStringLiteral("系统")) {  // 系统/外壳不参与任务命名
      b.catSec[s.cat] += s.sec;
      b.appSec[s.name] += s.sec;
    }
  }

  struct AppT { QString name; qint64 sec; };
  QVariantList result;
  for (const Block& b : blocks) {
    const qint64 span = b.end - b.start;
    if (span < 5 * 60) continue;  // 太短不成任务
    QString topCat;
    qint64 topCatSec = 0;
    for (auto it = b.catSec.constBegin(); it != b.catSec.constEnd(); ++it) {
      if (it.key() == QStringLiteral("其他")) continue;
      if (it.value() > topCatSec) {
        topCatSec = it.value();
        topCat = it.key();
      }
    }
    if (topCat.isEmpty()) {  // 整块只有 其他/系统
      for (auto it = b.catSec.constBegin(); it != b.catSec.constEnd(); ++it)
        if (it.value() > topCatSec) {
          topCatSec = it.value();
          topCat = it.key();
        }
    }
    if (topCat.isEmpty()) continue;  // 纯系统块，不成任务
    QVector<AppT> apps;
    for (auto it = b.appSec.constBegin(); it != b.appSec.constEnd(); ++it)
      apps.append({it.key(), it.value()});
    std::sort(apps.begin(), apps.end(),
              [](const AppT& a, const AppT& c) { return a.sec > c.sec; });
    QStringList names;
    for (int i = 0; i < apps.size() && i < 3; ++i) names << apps[i].name;
    QVariantMap m;
    m.insert(QStringLiteral("category"), topCat);
    m.insert(QStringLiteral("span"), static_cast<qlonglong>(span));
    // 该块主类别的**真实前台秒数**（非整块墙钟跨度）——给头条占比用，避免把空闲
    // 桥接 + 其它类别的前台时间都算到主类别头上。
    m.insert(QStringLiteral("topCatSec"), static_cast<qlonglong>(topCatSec));
    m.insert(QStringLiteral("apps"), names.join(QStringLiteral(" / ")));
    result.append(m);
  }
  std::sort(result.begin(), result.end(),
            [](const QVariant& a, const QVariant& b) {
              return a.toMap().value(QStringLiteral("span")).toLongLong() >
                     b.toMap().value(QStringLiteral("span")).toLongLong();
            });
  return result;
}

QString themeTitle(const QString& cat) {
  if (cat.isEmpty() || cat == QStringLiteral("其他"))
    return QStringLiteral("今日无明显主线");
  return cat + QStringLiteral("为主");
}

QString themeDesc(const QString& cat, double ratio, const QString& period) {
  const int pct = qRound(ratio * 100.0);
  QString s = (cat.isEmpty() || cat == QStringLiteral("其他"))
                  ? QStringLiteral("使用较为分散，未集中在单一类别")
                  : QStringLiteral("%1类占比约 %2%").arg(cat).arg(pct);
  if (!period.isEmpty()) s += QStringLiteral("，多集中在%1").arg(period);
  s += QStringLiteral("。");
  return s;
}

// ===== 记忆湖·月度回顾 helpers（阶段二，题材中立、断言守卫）=====

QString chineseMonth(int month) {
  static const char* const names[] = {"一月", "二月",   "三月", "四月",
                                      "五月", "六月",   "七月", "八月",
                                      "九月", "十月", "十一月", "十二月"};
  if (month >= 1 && month <= 12) return QString::fromUtf8(names[month - 1]);
  return QStringLiteral("本月");
}

QString categoryKeyword(const QString& cat) {
  if (cat == QStringLiteral("游戏")) return QStringLiteral("游戏");
  if (cat == QStringLiteral("视频")) return QStringLiteral("观看");
  if (cat == QStringLiteral("音乐")) return QStringLiteral("聆听");
  if (cat == QStringLiteral("社交")) return QStringLiteral("沟通");
  if (cat == QStringLiteral("开发")) return QStringLiteral("专注");
  return QStringLiteral("日常");
}

// 主关键词：优先**有代表性**的信号——夜间/深夜（最具分享性）> 长时沉浸 > 主要时段 > 类别。
// 不再用"穿插"等通用词。peakPeriod 为原始时段串（清晨/.../深夜），topLongestSec 为月度最长单次。
QString majorKeyword(const QString& peakPeriod, qint64 topLongestSec,
                     const QString& topCat) {
  const QString pw = periodWord(peakPeriod);
  if (pw == QStringLiteral("夜间") || pw == QStringLiteral("深夜")) return pw;
  if (topLongestSec >= 60 * 60) return QStringLiteral("沉浸");
  if (!pw.isEmpty()) return pw;
  return categoryKeyword(topCat);
}

// 把所有月度会话段拍平成 24 小时直方图（按时长加权）。
QVector<qint64> monthHourHistogram(const QVariantList& monthSegments) {
  QVector<qint64> hist(24, 0);
  for (const QVariant& av : monthSegments) {
    const QVariantList segs =
        av.toMap().value(QStringLiteral("segments")).toList();
    for (const QVariant& sv : segs) {
      const QVariantMap s = sv.toMap();
      const qint64 startU = s.value(QStringLiteral("startUnixSec")).toLongLong();
      const qint64 endU = s.value(QStringLiteral("endUnixSec")).toLongLong();
      const qint64 dur = s.value(QStringLiteral("seconds")).toLongLong();
      const qint64 mid = startU + (endU - startU) / 2;
      const int h = QDateTime::fromSecsSinceEpoch(mid).time().hour();
      if (h >= 0 && h < 24) hist[h] += dur;
    }
  }
  return hist;
}

// 峰值连续 4 小时窗口 -> "HH:00–HH:00"；无数据返回空串（断言守卫）。
QString peakWindowText(const QVector<qint64>& hist) {
  qint64 totalAll = 0;
  for (qint64 v : hist) totalAll += v;
  if (totalAll <= 0) return QString();
  int bestStart = 0;
  qint64 best = -1;
  for (int start = 0; start < 24; ++start) {
    qint64 sum = 0;
    for (int k = 0; k < 4; ++k) sum += hist[(start + k) % 24];
    if (sum > best) {
      best = sum;
      bestStart = start;
    }
  }
  int endH = (bestStart + 4) % 24;
  if (endH == 0) endH = 24;
  return QStringLiteral("%1:00–%2:00")
      .arg(bestStart, 2, 10, QChar('0'))
      .arg(endH, 2, 10, QChar('0'));
}

QString dominantPeriodFromHist(const QVector<qint64>& hist) {
  QHash<QString, qint64> bucket;
  for (int h = 0; h < 24; ++h) bucket[periodForHour(h)] += hist[h];
  QString top;
  qint64 topSec = 0;
  for (auto it = bucket.constBegin(); it != bucket.constEnd(); ++it) {
    if (it.value() > topSec) {
      topSec = it.value();
      top = it.key();
    }
  }
  return top;
}

// 月趋势方向：比较前 1/3 与后 1/3 日均，返回 rising/falling/flat（断言守卫）。
QString monthTrendDir(const QVariantList& dailySeries) {
  const int n = dailySeries.size();
  if (n < 6) return QStringLiteral("flat");
  const int third = n / 3;
  if (third <= 0) return QStringLiteral("flat");
  qint64 firstSum = 0;
  qint64 lastSum = 0;
  for (int i = 0; i < third; ++i)
    firstSum += dailySeries.at(i).toMap().value(QStringLiteral("seconds")).toLongLong();
  for (int i = n - third; i < n; ++i)
    lastSum += dailySeries.at(i).toMap().value(QStringLiteral("seconds")).toLongLong();
  const double f = static_cast<double>(firstSum) / third;
  const double l = static_cast<double>(lastSum) / third;
  if (l > f * 1.2 && (l - f) > 20 * 60) return QStringLiteral("rising");
  if (l < f * 0.8 && (f - l) > 20 * 60) return QStringLiteral("falling");
  return QStringLiteral("flat");
}

// 月历柱：按天序列分桶求和（最多 7 桶；已过天数不足 7 时按实际天数出柱，
// 避免出现没有任何真实天落入的"0m 空桶"被误读成零使用日）。h 归一化到最大桶。
QVariantList monthMapBars(const QVariantList& dailySeries) {
  QVariantList bars;
  const int n = dailySeries.size();
  if (n == 0) return bars;
  const int nbins = std::min(7, n);
  qint64 binSec[7] = {0, 0, 0, 0, 0, 0, 0};
  int binFirstDay[7] = {0, 0, 0, 0, 0, 0, 0};
  bool binSet[7] = {false, false, false, false, false, false, false};
  for (int i = 0; i < n; ++i) {
    int b = i * nbins / n;
    if (b > nbins - 1) b = nbins - 1;
    const QVariantMap d = dailySeries.at(i).toMap();
    binSec[b] += d.value(QStringLiteral("seconds")).toLongLong();
    if (!binSet[b]) {
      binFirstDay[b] = d.value(QStringLiteral("day")).toInt();
      binSet[b] = true;
    }
  }
  qint64 maxBin = 1;
  for (int b = 0; b < nbins; ++b) maxBin = std::max(maxBin, binSec[b]);
  for (int b = 0; b < nbins; ++b) {
    QVariantMap m;
    m.insert(QStringLiteral("h"),
             std::max(0.06, static_cast<double>(binSec[b]) / maxBin));
    m.insert(QStringLiteral("value"), decimalHoursText(binSec[b]));
    m.insert(QStringLiteral("day"),
             QStringLiteral("%1日").arg(binSet[b] ? binFirstDay[b] : 1));
    bars.append(m);
  }
  return bars;
}

// 趋势曲线点：每天 seconds 归一到 0..1（按最大日）。
QVariantList trendSeries(const QVariantList& dailySeries) {
  QVariantList pts;
  qint64 maxDay = 1;
  for (const QVariant& v : dailySeries)
    maxDay = std::max(maxDay, v.toMap().value(QStringLiteral("seconds")).toLongLong());
  for (const QVariant& v : dailySeries) {
    pts.append(static_cast<double>(
                   v.toMap().value(QStringLiteral("seconds")).toLongLong()) /
               maxDay);
  }
  return pts;
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

// 记忆湖·日视图模型：入参为 QML 取到的首页同源只读数据；本服务只做 classify +
// 文案模板 + 聚合，产出与 MemoryLakeMock 同形的 {apps, overview, todayTheme}。
QVariantMap DailyCardService::memoryLakeDay(const QVariantList& usmApps,
                                            const QVariantList& segments) {
  QVariantMap model;
  const QDate today = QDate::currentDate();
  const qint64 dayStart = today.startOfDay().toSecsSinceEpoch();

  QVariantMap overview;
  QVariantMap theme;
  theme.insert(QStringLiteral("kicker"), QStringLiteral("今日主题"));

  QHash<QString, QVariantMap> segByKey;
  for (const QVariant& v : segments) {
    const QVariantMap m = v.toMap();
    segByKey.insert(m.value(QStringLiteral("groupKey")).toString(), m);
  }

  // 全量类别聚合（ratio 用真实占比）+ 总秒数 + 非系统/系统分桶 + key->类别/名。
  qint64 totalDaySec = 0;
  QHash<QString, qint64> catSec;
  QHash<QString, QString> catByKey;
  QHash<QString, QString> nameByKey;
  QVariantList nonSystem;
  QVariantList systemApps;
  for (const QVariant& v : usmApps) {
    const QVariantMap u = v.toMap();
    const QString key = u.value(QStringLiteral("groupKey")).toString();
    QString cat = u.value(QStringLiteral("category")).toString();
    if (cat.isEmpty()) cat = QStringLiteral("其他");
    const qlonglong sec = u.value(QStringLiteral("seconds")).toLongLong();
    totalDaySec += sec;
    catSec[cat] += sec;
    catByKey.insert(key, cat);
    nameByKey.insert(key, u.value(QStringLiteral("name")).toString());
    if (cat == QStringLiteral("系统"))
      systemApps.append(v);
    else
      nonSystem.append(v);
  }

  // 卡牌/排行：非系统优先（系统外壳降权沉底），取前 10，长尾不进 List。
  QVariantList ordered = nonSystem;
  ordered.append(systemApps);
  if (ordered.size() > 10) ordered = ordered.mid(0, 10);
  const qlonglong topSeconds =
      ordered.isEmpty()
          ? 1
          : std::max<qlonglong>(1, ordered.first().toMap()
                                       .value(QStringLiteral("seconds"))
                                       .toLongLong());

  QVariantList appsOut;
  int totalSessions = 0;
  for (const QVariant& v : ordered) {
    const QVariantMap u = v.toMap();
    const QString groupKey = u.value(QStringLiteral("groupKey")).toString();
    const QString name = u.value(QStringLiteral("name")).toString();
    const QString path = u.value(QStringLiteral("path")).toString();
    const qlonglong seconds = u.value(QStringLiteral("seconds")).toLongLong();
    const QString timeText = u.value(QStringLiteral("time")).toString();
    const QString category = catByKey.value(groupKey, QStringLiteral("其他"));

    const QVariantMap seg = segByKey.value(groupKey);
    const int sessionCount = seg.value(QStringLiteral("sessionCount"), 0).toInt();
    const qlonglong longestSec =
        seg.value(QStringLiteral("longestSec"), 0).toLongLong();
    const QVariantList segs = seg.value(QStringLiteral("segments")).toList();
    totalSessions += sessionCount;
    const QString period = dominantPeriod(segs);

    QVariantMap app;
    app.insert(QStringLiteral("appId"), groupKey);
    app.insert(QStringLiteral("name"), name);
    app.insert(QStringLiteral("appName"), u.value(QStringLiteral("appName")));
    app.insert(QStringLiteral("path"), path);
    app.insert(QStringLiteral("iconColors"), u.value(QStringLiteral("iconColors")));
    app.insert(QStringLiteral("category"), category);
    app.insert(QStringLiteral("type"), category);
    app.insert(QStringLiteral("time"), timeText);
    app.insert(QStringLiteral("seconds"), seconds);
    app.insert(QStringLiteral("progress"),
               topSeconds > 0 ? static_cast<double>(seconds) /
                                    static_cast<double>(topSeconds)
                              : 0.0);
    app.insert(QStringLiteral("mood"),
               moodWord(category, period, longestSec, seconds));
    app.insert(QStringLiteral("analysis"),
               analysisText(name, timeText, period, longestSec, sessionCount,
                            seconds));
    app.insert(QStringLiteral("launches"),
               sessionCount > 0 ? QStringLiteral("%1 次").arg(sessionCount)
                                : QString());
    app.insert(QStringLiteral("longest"),
               longestSec > 0 ? formatDuration(longestSec) : QString());
    app.insert(QStringLiteral("sessionCount"), sessionCount);
    app.insert(QStringLiteral("times"), buildRiverNodes(segs, dayStart));
    appsOut.append(app);
  }
  model.insert(QStringLiteral("apps"), appsOut);

  // 任务块（跨 app 连续使用，系统不参与命名）。
  const QVariantList tasks = taskBlocks(segments, catByKey, nameByKey);

  overview.insert(QStringLiteral("total"), decimalHoursText(totalDaySec));
  overview.insert(
      QStringLiteral("sub"),
      appsOut.isEmpty()
          ? QStringLiteral("%1月%2日 · 今天还没有记录")
                .arg(today.month())
                .arg(today.day())
          : QStringLiteral("%1月%2日 · 共 %3 次使用")
                .arg(today.month())
                .arg(today.day())
                .arg(totalSessions));
  model.insert(QStringLiteral("overview"), overview);

  if (appsOut.isEmpty() || totalDaySec <= 0) {
    theme.insert(QStringLiteral("title"), QStringLiteral("今天还很安静"));
    theme.insert(QStringLiteral("desc"),
                 QStringLiteral("还没有自动记录，开始使用后这里会生成今日主题。"));
    theme.insert(QStringLiteral("ratio"), 0.0);
  } else {
    // 头条类别取"前台任务"占比（task block 反映真实活动；背景音乐不会顶上来），
    // 无任务块时退回 active 类别占比；均排除系统/其他。
    QHash<QString, qint64> headlineSrc;
    if (!tasks.isEmpty()) {
      for (const QVariant& tv : tasks) {
        const QVariantMap t = tv.toMap();
        headlineSrc[t.value(QStringLiteral("category")).toString()] +=
            t.value(QStringLiteral("topCatSec")).toLongLong();
      }
    } else {
      headlineSrc = catSec;
    }
    qint64 srcTotal = 0;
    for (auto it = headlineSrc.constBegin(); it != headlineSrc.constEnd(); ++it)
      srcTotal += it.value();
    const auto pickTop = [&](const QString& skipA, const QString& skipB) {
      QString c;
      qint64 best = 0;
      for (auto it = headlineSrc.constBegin(); it != headlineSrc.constEnd();
           ++it) {
        if (it.key() == skipA || it.key() == skipB) continue;
        if (it.value() > best) {
          best = it.value();
          c = it.key();
        }
      }
      return c;
    };
    QString topCat = pickTop(QStringLiteral("系统"), QStringLiteral("其他"));
    if (topCat.isEmpty()) topCat = pickTop(QStringLiteral("系统"), QString());
    QString cat2 = pickTop(QStringLiteral("系统"), topCat);
    if (cat2 == QStringLiteral("其他")) cat2.clear();
    const double ratio =
        (srcTotal > 0 && !topCat.isEmpty())
            ? std::min(1.0, static_cast<double>(headlineSrc.value(topCat, 0)) /
                                srcTotal)
            : 0.0;

    theme.insert(QStringLiteral("title"), themeTitle(topCat));
    theme.insert(QStringLiteral("ratio"), ratio);
    if (!tasks.isEmpty()) {
      const qlonglong longestSpan =
          tasks.first().toMap().value(QStringLiteral("span")).toLongLong();
      QString d = QStringLiteral("今天有 %1 段连续使用，最长约 %2")
                      .arg(tasks.size())
                      .arg(decimalHoursText(longestSpan));
      if (!topCat.isEmpty()) {
        d += QStringLiteral("，主要在%1").arg(topCat);
        if (!cat2.isEmpty()) d += QStringLiteral("、%1").arg(cat2);
      }
      d += QStringLiteral("。");
      theme.insert(QStringLiteral("desc"), d);
    } else {
      theme.insert(QStringLiteral("desc"), themeDesc(topCat, ratio, QString()));
    }
  }
  model.insert(QStringLiteral("todayTheme"), theme);

  return model;
}

// 记忆湖·月度回顾模型：题材中立 + 断言守卫 + 动态屏数（§6）。
QVariantMap DailyCardService::memoryLakeRecap(const QVariantList& monthApps,
                                              const QVariantList& monthSegments,
                                              const QVariantList& lastMonthApps,
                                              const QVariantList& dailySeries) {
  QVariantMap model;
  const QDate today = QDate::currentDate();
  const int year = today.year();
  const int month = today.month();
  const QString monthCn = chineseMonth(month);

  model.insert(QStringLiteral("headerLeft"),
               QStringLiteral("Memory Lake Monthly Recap · %1.%2")
                   .arg(year)
                   .arg(month, 2, 10, QChar('0')));
  model.insert(QStringLiteral("headerRight"),
               QStringLiteral("滚轮 / 按钮逐步播放 · APP 逐个登场"));
  model.insert(
      QStringLiteral("modeNote"),
      QStringLiteral("首次播放会按顺序展开，点击画面可加速。看完后右侧目录会解锁。"));
  // 月级 apps 已由 USM 带上 iconColors（回顾背景/主角封面做多色晕染用）。
  model.insert(QStringLiteral("apps"), monthApps);

  QHash<QString, QVariantMap> segByKey;
  for (const QVariant& v : monthSegments) {
    const QVariantMap m = v.toMap();
    segByKey.insert(m.value(QStringLiteral("groupKey")).toString(), m);
  }

  // 优先用 USM 的窗口标题感知类别；缺失退回旧 classifyApp。
  const auto catOf = [](const QVariantMap& u) {
    const QString c = u.value(QStringLiteral("category")).toString();
    return c.isEmpty() ? categoryForUsmItem(u) : c;
  };
  qint64 monthTotalSec = 0;
  QHash<QString, qint64> catSec;
  for (const QVariant& v : monthApps) {
    const QVariantMap u = v.toMap();
    const qlonglong sec = u.value(QStringLiteral("seconds")).toLongLong();
    monthTotalSec += sec;
    catSec[catOf(u)] += sec;
  }
  // 头条类别排除系统/其他（系统外壳降权、不当最高类别）。
  QString topCat;
  qint64 topCatSec = 0;
  for (auto it = catSec.constBegin(); it != catSec.constEnd(); ++it) {
    if (it.key() == QStringLiteral("系统") || it.key() == QStringLiteral("其他"))
      continue;
    if (it.value() > topCatSec) {
      topCatSec = it.value();
      topCat = it.key();
    }
  }
  if (topCat.isEmpty()) {  // 全是系统/其他时退而求其次（仍排除系统）
    for (auto it = catSec.constBegin(); it != catSec.constEnd(); ++it) {
      if (it.key() == QStringLiteral("系统")) continue;
      if (it.value() > topCatSec) {
        topCatSec = it.value();
        topCat = it.key();
      }
    }
  }
  const int topPct =
      monthTotalSec > 0 ? qRound(100.0 * topCatSec / monthTotalSec) : 0;

  const QVector<qint64> hist = monthHourHistogram(monthSegments);
  const QString peakText = peakWindowText(hist);
  const QString peakPeriod = dominantPeriodFromHist(hist);

  qint64 topLongestSec = 0;
  for (const QVariant& v : monthApps) {  // 首个非系统 app 的月度最长单次
    const QVariantMap a0 = v.toMap();
    if (catOf(a0) == QStringLiteral("系统")) continue;
    topLongestSec =
        segByKey.value(a0.value(QStringLiteral("groupKey")).toString())
            .value(QStringLiteral("longestSec"), 0)
            .toLongLong();
    break;
  }
  const QString major = majorKeyword(peakPeriod, topLongestSec, topCat);

  QVariantList slides;
  int idx = 0;
  const auto addSlide = [&](QVariantMap s, const QString& step,
                            const QString& type, int bgIndex,
                            const QString& transition) {
    idx += 1;
    s.insert(QStringLiteral("step"), step);
    s.insert(QStringLiteral("kicker"),
             QStringLiteral("%1 · %2").arg(idx, 2, 10, QChar('0')).arg(step));
    s.insert(QStringLiteral("type"), type);
    s.insert(QStringLiteral("bgIndex"), bgIndex);
    s.insert(QStringLiteral("transition"), transition);
    slides.append(s);
  };

  const bool hasData = !monthApps.isEmpty() && monthTotalSec > 0;

  // 01 月度封面
  {
    QVariantMap s;
    s.insert(QStringLiteral("title"),
             hasData ? QStringLiteral("%1的记忆湖\n这个月的使用轨迹。").arg(monthCn)
                     : QStringLiteral("%1的记忆湖\n这个月还很安静。").arg(monthCn));
    s.insert(QStringLiteral("subtitle"),
             hasData ? QStringLiteral("不是单纯的时间统计，而是一段设备使用轨迹。系统会按软件、时段、趋势和变化，把这个月一点点展开。")
                     : QStringLiteral("这个月还没有足够的自动记录。继续使用后，回顾会逐渐展开。"));
    QVariantList metrics;
    metrics.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("月度总使用")},
                               {QStringLiteral("value"), decimalHoursText(monthTotalSec)}});
    if (!topCat.isEmpty() && topCatSec > 0)
      metrics.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("最高类别")},
                                 {QStringLiteral("value"), QStringLiteral("%1 %2%").arg(topCat).arg(topPct)}});
    if (!peakText.isEmpty())
      metrics.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("最活跃时段")},
                                 {QStringLiteral("value"), peakText}});
    s.insert(QStringLiteral("metrics"), metrics);
    addSlide(s, QStringLiteral("月度封面"), QStringLiteral("cover"), -1, QStringLiteral("zoom"));
  }

  if (!hasData) {
    model.insert(QStringLiteral("slides"), slides);
    return model;
  }

  // 02 月初到月末
  {
    const QString dir = monthTrendDir(dailySeries);
    QString title = dir == QStringLiteral("rising")
                        ? QStringLiteral("使用强度在月末明显抬升。")
                        : (dir == QStringLiteral("falling")
                               ? QStringLiteral("使用强度在月末逐渐回落。")
                               : QStringLiteral("整月使用强度起伏不大。"));
    QVariantMap s;
    s.insert(QStringLiteral("title"), title);
    s.insert(QStringLiteral("subtitle"),
             QStringLiteral("把整月按时间顺序排开，每根柱子是一段时间的使用总量。"));
    s.insert(QStringLiteral("monthMap"), monthMapBars(dailySeries));
    addSlide(s, QStringLiteral("月初到月末"), QStringLiteral("monthMap"), -1, QStringLiteral("rise"));
  }

  // 03–06 主角（poster/split/orbit/article 当纯模板，按月度 Top 顺序套用，不足则减屏）
  const char* const tmpls[4] = {"poster", "split", "orbit", "article"};
  const QString steps[4] = {QStringLiteral("第一个主角"), QStringLiteral("第二个主角"),
                            QStringLiteral("第三个主角"), QStringLiteral("第四个主角")};
  const char* const trans[4] = {"zoom", "wipe", "rotate", "rise"};
  int proto = 0;
  for (int i = 0; i < monthApps.size() && proto < 4; ++i) {
    const QVariantMap u = monthApps.at(i).toMap();
    const qlonglong sec = u.value(QStringLiteral("seconds")).toLongLong();
    if (sec < 5 * 60) break;  // 不足 5 分钟不立为主角
    const QString cat = catOf(u);
    if (cat == QStringLiteral("系统")) continue;  // 系统/外壳不当主角
    const QString name = u.value(QStringLiteral("name")).toString();
    const QString timeText = u.value(QStringLiteral("time")).toString();
    const QVariantMap seg = segByKey.value(u.value(QStringLiteral("groupKey")).toString());
    const qlonglong longestSec = seg.value(QStringLiteral("longestSec"), 0).toLongLong();
    const QVariantList segs = seg.value(QStringLiteral("segments")).toList();
    const QString period = dominantPeriod(segs);
    const QString mood = moodWord(cat, period, longestSec, sec);
    const QString protagKw = majorKeyword(period, longestSec, cat);

    const QString title = QStringLiteral("%1：%2").arg(name, mood);
    QString subtitle = QStringLiteral("%1 本月使用约 %2").arg(name, timeText);
    if (!period.isEmpty()) subtitle += QStringLiteral("，多集中在%1").arg(period);
    if (longestSec > 0) subtitle += QStringLiteral("，最长连续 %1").arg(formatDuration(longestSec));
    subtitle += QStringLiteral("。");
    const QString kw = QStringLiteral("%1 / %2").arg(categoryKeyword(cat), protagKw);

    QVariantList stats;
    stats.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("月度时长")}, {QStringLiteral("value"), timeText}});
    if (longestSec > 0)
      stats.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("最长连续")}, {QStringLiteral("value"), formatDuration(longestSec)}});
    if (!period.isEmpty())
      stats.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("主要时段")}, {QStringLiteral("value"), period}});
    stats.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("关键词")}, {QStringLiteral("value"), kw}});

    QVariantMap s;
    const QString tmpl = QString::fromLatin1(tmpls[proto]);
    s.insert(QStringLiteral("title"), title);
    if (tmpl == QStringLiteral("poster")) {
      s.insert(QStringLiteral("posterTitle"), name);
      s.insert(QStringLiteral("posterSub"),
               proto == 0 ? QStringLiteral("%1 · 本月最长使用").arg(timeText)
                          : QStringLiteral("%1 · 月度主角").arg(timeText));
      s.insert(QStringLiteral("subtitle"), subtitle);
      s.insert(QStringLiteral("stats"), stats);
    } else if (tmpl == QStringLiteral("split")) {
      s.insert(QStringLiteral("subtitle"), subtitle);
      s.insert(QStringLiteral("stats"), stats);
    } else if (tmpl == QStringLiteral("orbit")) {
      s.insert(QStringLiteral("subtitle"), subtitle);
      QVariantList orbit;
      orbit.append(QVariantMap{{QStringLiteral("a"), -25}, {QStringLiteral("value"), timeText}, {QStringLiteral("label"), QStringLiteral("月度使用")}});
      if (longestSec > 0)
        orbit.append(QVariantMap{{QStringLiteral("a"), 35}, {QStringLiteral("value"), formatDuration(longestSec)}, {QStringLiteral("label"), QStringLiteral("最长连续")}});
      if (!period.isEmpty())
        orbit.append(QVariantMap{{QStringLiteral("a"), 105}, {QStringLiteral("value"), period}, {QStringLiteral("label"), QStringLiteral("主要时段")}});
      orbit.append(QVariantMap{{QStringLiteral("a"), 185}, {QStringLiteral("value"), protagKw}, {QStringLiteral("label"), QStringLiteral("月度关键词")}});
      s.insert(QStringLiteral("orbit"), orbit);
    } else {  // article
      s.insert(QStringLiteral("articleTitle"),
               period.isEmpty() ? mood : (periodWord(period) + QStringLiteral("时段的常客")));
      s.insert(QStringLiteral("articleBody"), subtitle);
    }
    addSlide(s, steps[proto], tmpl, i, QString::fromLatin1(trans[proto]));
    proto += 1;
  }

  // 07 一天里的轨迹（按时段聚合代表 app）
  {
    struct PA { QString name; qint64 sec; };
    QHash<QString, QVector<PA>> byPeriod;
    QHash<QString, qint64> periodSec;
    for (int i = 0; i < monthApps.size(); ++i) {
      const QVariantMap u = monthApps.at(i).toMap();
      const QVariantMap seg = segByKey.value(u.value(QStringLiteral("groupKey")).toString());
      const QString p = dominantPeriod(seg.value(QStringLiteral("segments")).toList());
      if (p.isEmpty()) continue;
      const qint64 sec = u.value(QStringLiteral("seconds")).toLongLong();
      byPeriod[p].append({u.value(QStringLiteral("name")).toString(), sec});
      periodSec[p] += sec;
    }
    QStringList periods;
    for (auto it = periodSec.constBegin(); it != periodSec.constEnd(); ++it) periods << it.key();
    std::sort(periods.begin(), periods.end(),
              [&](const QString& a, const QString& b) { return periodSec[a] > periodSec[b]; });
    if (periods.size() > 3) periods = periods.mid(0, 3);
    qint64 maxP = 1;
    for (const QString& p : periods) maxP = std::max(maxP, periodSec[p]);
    QVariantList strips;
    for (const QString& p : periods) {
      QVector<PA>& list = byPeriod[p];
      std::sort(list.begin(), list.end(), [](const PA& a, const PA& b) { return a.sec > b.sec; });
      QStringList names;
      for (int k = 0; k < list.size() && k < 3; ++k) names << list[k].name;
      const double frac = static_cast<double>(periodSec[p]) / maxP;
      QVariantList segvis;
      segvis.append(QVariantList{0.10, 0.32 * frac + 0.08});
      segvis.append(QVariantList{0.56, 0.28 * frac + 0.06});
      strips.append(QVariantMap{{QStringLiteral("tag"), QStringLiteral("%1 · 常用").arg(p)},
                                {QStringLiteral("apps"), names.join(QStringLiteral(" / "))},
                                {QStringLiteral("segs"), segvis}});
    }
    if (!strips.isEmpty()) {
      QVariantMap s;
      s.insert(QStringLiteral("title"), QStringLiteral("不同时段，软件也不一样。"));
      s.insert(QStringLiteral("subtitle"), QStringLiteral("从时段看，每个时间段都有它常驻的软件。"));
      s.insert(QStringLiteral("strips"), strips);
      addSlide(s, QStringLiteral("一天里的轨迹"), QStringLiteral("timeline"), -1, QStringLiteral("wipe"));
    }
  }

  // 08 趋势变化（接真实按天序列，断言守卫）
  {
    const QString dir = monthTrendDir(dailySeries);
    QString title = dir == QStringLiteral("rising")
                        ? QStringLiteral("月末出现明显高峰。")
                        : (dir == QStringLiteral("falling")
                               ? QStringLiteral("使用在月末逐渐回落。")
                               : QStringLiteral("整月使用起伏不大。"));
    QVariantMap s;
    s.insert(QStringLiteral("title"), title);
    s.insert(QStringLiteral("subtitle"),
             QStringLiteral("这条曲线是本月每日使用总时长，可以看作湖面水位的变化。"));
    s.insert(QStringLiteral("series"), trendSeries(dailySeries));
    addSlide(s, QStringLiteral("趋势变化"), QStringLiteral("trend"), -1, QStringLiteral("rotate"));
  }

  // 09 月度关键词
  {
    QStringList kws;
    kws << major;
    if (!peakPeriod.isEmpty()) kws << peakPeriod + QStringLiteral("使用");
    if (!topCat.isEmpty() && topCat != QStringLiteral("其他")) kws << topCat;
    int kc = 0;
    for (int i = 0; i < monthApps.size() && kc < 3; ++i) {
      const QString c = catOf(monthApps.at(i).toMap());
      if (c == QStringLiteral("系统")) continue;
      kws << categoryKeyword(c);
      ++kc;
    }
    if (topLongestSec >= 60 * 60) kws << QStringLiteral("长时沉浸");
    QStringList uniq;
    for (const QString& k : kws)
      if (!k.isEmpty() && !uniq.contains(k)) uniq << k;
    if (uniq.size() > 7) uniq = uniq.mid(0, 7);
    QVariantList kwv;
    for (const QString& k : uniq) kwv << k;
    QVariantMap s;
    s.insert(QStringLiteral("title"), QStringLiteral("这个月的关键词。"));
    s.insert(QStringLiteral("subtitle"),
             QStringLiteral("根据软件类别、连续时长、启动次数和时段生成，代表本月最常出现的使用状态。"));
    s.insert(QStringLiteral("keywords"), kwv);
    s.insert(QStringLiteral("major"), major);
    addSlide(s, QStringLiteral("月度关键词"), QStringLiteral("keywords"), -1, QStringLiteral("rise"));
  }

  // 10 相比上月（环比类别；上月无数据则跳过该屏）
  QString topChangeStr;
  if (!lastMonthApps.isEmpty()) {
    QHash<QString, qint64> lastCat;
    for (const QVariant& v : lastMonthApps) {
      const QVariantMap u = v.toMap();
      lastCat[catOf(u)] += u.value(QStringLiteral("seconds")).toLongLong();
    }
    const auto skipCat = [](const QString& k) {
      return k == QStringLiteral("其他") || k == QStringLiteral("系统");
    };
    QStringList cats;
    for (auto it = catSec.constBegin(); it != catSec.constEnd(); ++it)
      if (!skipCat(it.key()) && !cats.contains(it.key())) cats << it.key();
    for (auto it = lastCat.constBegin(); it != lastCat.constEnd(); ++it)
      if (!skipCat(it.key()) && !cats.contains(it.key())) cats << it.key();
    struct Cmp { QString cat; qint64 cur; qint64 last; };
    QVector<Cmp> cmps;
    for (const QString& c : cats) cmps.append({c, catSec.value(c, 0), lastCat.value(c, 0)});
    std::sort(cmps.begin(), cmps.end(), [](const Cmp& a, const Cmp& b) {
      return qAbs(a.cur - a.last) > qAbs(b.cur - b.last);
    });
    if (cmps.size() > 3) cmps.resize(3);
    QVariantList comparisons;
    for (const Cmp& c : cmps) {
      const qint64 delta = c.cur - c.last;
      QString change;
      if (c.last <= 0)
        change = c.cur > 0 ? QStringLiteral("新增") : QStringLiteral("—");
      else {
        const int pct = qRound(100.0 * delta / c.last);
        change = QStringLiteral("%1%2%").arg(pct >= 0 ? QStringLiteral("+") : QString()).arg(pct);
      }
      const bool down = delta < 0;
      comparisons.append(QVariantMap{
          {QStringLiteral("label"), QStringLiteral("%1类时间").arg(c.cat)},
          {QStringLiteral("change"), change},
          {QStringLiteral("down"), down},
          {QStringLiteral("desc"), down ? QStringLiteral("%1类时间较上月减少。").arg(c.cat)
                                        : QStringLiteral("%1类时间较上月增加。").arg(c.cat)}});
      if (topChangeStr.isEmpty()) topChangeStr = QStringLiteral("%1 %2").arg(c.cat, change);
    }
    if (!comparisons.isEmpty()) {
      QVariantMap s;
      s.insert(QStringLiteral("title"), QStringLiteral("相比上个月的变化。"));
      s.insert(QStringLiteral("comparisons"), comparisons);
      addSlide(s, QStringLiteral("相比上月"), QStringLiteral("comparison"), -1, QStringLiteral("wipe"));
    }
  }

  // 11 月度标签（票根：复述前面真实值，不另造数字）
  {
    QVariantList rows;
    rows << QStringLiteral("总使用 %1").arg(decimalHoursText(monthTotalSec));
    rows << QStringLiteral("最高类别：%1").arg(topCat.isEmpty() ? QStringLiteral("—") : topCat);
    rows << QStringLiteral("关键词：%1").arg(major);
    rows << (topChangeStr.isEmpty() ? QStringLiteral("首月记录")
                                    : QStringLiteral("较上月 %1").arg(topChangeStr));
    QVariantMap ticket;
    ticket.insert(QStringLiteral("title"), QStringLiteral("%1\n记忆标签").arg(monthCn));
    ticket.insert(QStringLiteral("rows"), rows);
    QVariantMap s;
    s.insert(QStringLiteral("title"), QStringLiteral("%1标签已经生成。").arg(monthCn));
    s.insert(QStringLiteral("subtitle"),
             QStringLiteral("这张标签把本月的主要时间、最高类别和变化保存下来。"));
    s.insert(QStringLiteral("ticket"), ticket);
    addSlide(s, QStringLiteral("月度标签"), QStringLiteral("ticket"), -1, QStringLiteral("ticket"));
  }

  model.insert(QStringLiteral("slides"), slides);
  return model;
}
