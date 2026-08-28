// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 TimeArc contributors

#include "services/daily_card_service.h"

#include "services/categorization_manager.h"

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

// 记忆湖文案改为「模板名 + 字段」下发，句子由 QML 按语言拼装。这里仍要把类别的
// ASCII id 换回可读名（英文源串），再作为字段传出。优先问规则表（用户自建类别也能
// 拿到名字），没有就退回出厂表的名字。指针在构造时设置一次；本服务是单实例。
const CategorizationManager* g_categorization = nullptr;

// StatsService 的排行行只有 appIdentifier + displayName（没有窗口标题、也没有
// 类别字段），照样走同一张规则表——不再有第二套判定，"game" 这种泛词误命中的
// 老毛病也一并消失。
QString classifyRankingRow(const QVariantMap& app) {
  const QString identifier =
      app.value(QStringLiteral("appIdentifier")).toString();
  const QString name = app.value(QStringLiteral("displayName")).toString();
  if (g_categorization != nullptr) {
    return g_categorization->matcher()
        .resolve(identifier, name, QString(), g_categorization->options())
        .category;
  }
  static const TimeArc::Categorization::Matcher fallback{
      TimeArc::Categorization::defaultRuleSet()};
  return fallback.resolve(identifier, name, QString()).category;
}

// Returns the ENGLISH label, because that is the source language the card
// fields travel in; QML translates it for the reader. This asked for "zh" while
// the cards shipped finished Chinese prose that the QML side re-translated. Now
// that the fields cross as data, a Chinese label here is a Chinese word pasted
// into an English sentence with nothing left to catch it.
QString categoryName(const QString& id) {
  if (id.trimmed().isEmpty()) return id;
  if (g_categorization != nullptr) {
    const TimeArc::Categorization::CategoryDef* definition =
        g_categorization->matcher().ruleSet().category(id);
    if (definition != nullptr) {
      return TimeArc::Categorization::displayLabel(
          *definition, QStringLiteral("en"));
    }
  }
  static const TimeArc::Categorization::RuleSet shipped =
      TimeArc::Categorization::defaultRuleSet();
  const TimeArc::Categorization::CategoryDef* fallback = shipped.category(id);
  return fallback != nullptr
             ? TimeArc::Categorization::displayLabel(*fallback,
                                                     QStringLiteral("en"))
             : id;
}

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

// 计入“娱乐卡”的分类：游戏 + 视频。
bool isEntertainment(const QString& category) {
  return category == QStringLiteral("game") ||
         category == QStringLiteral("video");
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

// 大号"使用总览"用十进制小时（如 8.9h），与设计稿一致；不足 1 小时给分钟。
QString decimalHoursText(qint64 seconds) {
  const qint64 s = std::max<qint64>(0, seconds);
  if (s < 3600) return QStringLiteral("%1m").arg(s / 60);
  return QStringLiteral("%1h").arg(QString::number(s / 3600.0, 'f', 1));
}

QString periodForHour(int hour) {
  if (hour >= 5 && hour < 8) return QStringLiteral("Early Morning");
  if (hour >= 8 && hour < 11) return QStringLiteral("Morning");
  if (hour >= 11 && hour < 14) return QStringLiteral("Noon");
  if (hour >= 14 && hour < 18) return QStringLiteral("Afternoon");
  if (hour >= 18 && hour < 22) return QStringLiteral("Evening");
  if (hour >= 22 || hour < 2) return QStringLiteral("Night");  // 22:00–02:00
  return QStringLiteral("Late Night");                              // 02:00–05:00
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
  if (period == QStringLiteral("Early Morning")) return QStringLiteral("Early Morning");
  if (period == QStringLiteral("Morning")) return QStringLiteral("Morning");
  if (period == QStringLiteral("Noon")) return QStringLiteral("Midday");
  if (period == QStringLiteral("Afternoon")) return QStringLiteral("Afternoon");
  if (period == QStringLiteral("Evening")) return QStringLiteral("Evening");
  if (period == QStringLiteral("Night")) return QStringLiteral("Night");
  if (period == QStringLiteral("Late Night")) return QStringLiteral("Late Night");
  return QString();
}

// 长会话的类别强度短词（2 字）。
QString intensityShort(const QString& category) {
  if (category == QStringLiteral("game")) return QStringLiteral("Immersed");
  if (category == QStringLiteral("dev")) return QStringLiteral("Focus");
  if (category == QStringLiteral("video")) return QStringLiteral("Binge-watching");
  if (category == QStringLiteral("create")) return QStringLiteral("Immersed");
  if (category == QStringLiteral("office")) return QStringLiteral("Focus");
  if (category == QStringLiteral("notes")) return QStringLiteral("Focus");
  if (category == QStringLiteral("browse")) return QStringLiteral("Deep reading");
  if (category == QStringLiteral("social")) return QStringLiteral("Chatting");
  return QStringLiteral("Immersed");
}

// 心情词：只用**有代表性、有独特性**的信号——主要时段（何时）+ 单次时长强度（多投入）。
// 刻意避开"穿插/平稳/日常/切换/碎片"这类人人用电脑都会触发、不够 specialized 的词。
QString moodWord(const QString& category, const QString& period,
                 qint64 longestSec, qint64 totalSec) {
  if (totalSec < 5 * 60) return QStringLiteral("A quick glance");
  const bool isLong = longestSec >= 30 * 60;
  const QString pw = periodWord(period);

  if (category == QStringLiteral("music"))
    return isLong ? QStringLiteral("Immersive listening")
                  : (pw.isEmpty() ? QStringLiteral("Listening along")
                                  : pw + QStringLiteral("Listening"));

  if (isLong) {  // 长单次会话本身就 distinctive：主要时段 + 强度
    const QString is = intensityShort(category);
    return pw.isEmpty() ? (QStringLiteral("Extended") + is) : (pw + is);
  }
  // 非长会话：以"主要时段"立意（你主要在什么时候用它）。
  if (!pw.isEmpty()) return pw + QStringLiteral("Use");
  return QStringLiteral("Occasional use");
}

// 分析句：只拼**可度量事实**（时长 / 主要时段 / 单次最长 / 打开次数），不下"穿插/平稳"
// 这类通用判断；填不上的从句整句省略。
// Emits the template name and its fields rather than a finished sentence.
//
// This used to compose the sentence here and the QML side recovered the fields
// with a stack of regular expressions (I18n.smartText) so it could rebuild them
// in another language. Any wording change on this side silently stopped
// matching, and the raw source language fell through to the screen. Handing the
// key and the parts across leaves grammar and word order to the language that
// owns them; note the clause order differs between the templates precisely
// because it cannot be assembled positionally here.
QVariantMap analysisModel(const QString& name, const QString& timeText,
                          const QString& period, qint64 longestSec,
                          int sessionCount, qint64 totalSec) {
  QVariantMap params;
  params.insert(QStringLiteral("app"), name);

  if (totalSec < 5 * 60) {
    QVariantMap out;
    out.insert(QStringLiteral("key"), QStringLiteral("appOpenedBriefly"));
    out.insert(QStringLiteral("params"), params);
    return out;
  }

  params.insert(QStringLiteral("time"), timeText);
  params.insert(QStringLiteral("period"), period);
  params.insert(QStringLiteral("longest"),
                longestSec > 0 ? formatDuration(longestSec) : QString());

  QString key = QStringLiteral("todayAppAnalysis");
  if (sessionCount > 0) {
    params.insert(QStringLiteral("launches"), sessionCount);
    key = QStringLiteral("todayAppAnalysisWithLaunches");
  }

  QVariantMap out;
  out.insert(QStringLiteral("key"), key);
  out.insert(QStringLiteral("params"), params);
  return out;
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
    const QString cat = catByKey.value(key, QStringLiteral("other"));
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
    if (s.cat != QStringLiteral("system")) {  // 系统/外壳不参与任务命名
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
      if (it.key() == QStringLiteral("other")) continue;
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

// Title and description travel as a template name plus its fields. "{category}
// Focus" and "开发为主" put the category on opposite sides of the word, so the
// sentence cannot be concatenated here and re-parsed on the other side.
bool themeIsUnclear(const QString& cat) {
  return cat.isEmpty() || cat == QStringLiteral("other");
}

QVariantMap themeTitleModel(const QString& cat) {
  QVariantMap out;
  if (themeIsUnclear(cat)) {
    out.insert(QStringLiteral("key"), QStringLiteral("themeNone"));
    out.insert(QStringLiteral("params"), QVariantMap());
    return out;
  }
  QVariantMap params;
  params.insert(QStringLiteral("category"), categoryName(cat));
  out.insert(QStringLiteral("key"), QStringLiteral("themeFocus"));
  out.insert(QStringLiteral("params"), params);
  return out;
}

QVariantMap themeDescModel(const QString& cat, double ratio,
                           const QString& period) {
  QVariantMap params;
  const bool unclear = themeIsUnclear(cat);
  if (!unclear) {
    params.insert(QStringLiteral("category"), categoryName(cat));
    params.insert(QStringLiteral("percent"), qRound(ratio * 100.0));
  }
  QString key = unclear ? QStringLiteral("themeSpread")
                        : QStringLiteral("themeShare");
  if (!period.isEmpty()) {
    params.insert(QStringLiteral("period"), period);
    key = unclear ? QStringLiteral("themeSpreadIn")
                  : QStringLiteral("themeShareIn");
  }
  QVariantMap out;
  out.insert(QStringLiteral("key"), key);
  out.insert(QStringLiteral("params"), params);
  return out;
}

// ===== 记忆湖·月度回顾 helpers（阶段二，题材中立、断言守卫）=====

QString chineseMonth(int month) {
  static const char* const names[] = {"January", "February",   "March", "April",
                                      "May", "June",   "July", "August",
                                      "September", "October", "November", "December"};
  if (month >= 1 && month <= 12) return QString::fromUtf8(names[month - 1]);
  return QStringLiteral("This Month");
}

QString categoryKeyword(const QString& cat) {
  if (cat == QStringLiteral("game")) return QStringLiteral("Games");
  if (cat == QStringLiteral("video")) return QStringLiteral("Watching");
  if (cat == QStringLiteral("music")) return QStringLiteral("Listening");
  if (cat == QStringLiteral("social")) return QStringLiteral("Communication");
  if (cat == QStringLiteral("dev")) return QStringLiteral("Focus");
  return QStringLiteral("Daily");
}

// 主关键词：优先**有代表性**的信号——夜间/深夜（最具分享性）> 长时沉浸 > 主要时段 > 类别。
// 不再用"穿插"等通用词。peakPeriod 为原始时段串（清晨/.../深夜），topLongestSec 为月度最长单次。
QString majorKeyword(const QString& peakPeriod, qint64 topLongestSec,
                     const QString& topCat) {
  const QString pw = periodWord(peakPeriod);
  if (pw == QStringLiteral("Night") || pw == QStringLiteral("Late Night")) return pw;
  if (topLongestSec >= 60 * 60) return QStringLiteral("Immersed");
  if (!pw.isEmpty()) return pw;
  return categoryKeyword(topCat);
}

QString nonRepeatingKeyword(const QString& period, qint64 longestSec,
                            const QString& cat) {
  const QString raw = majorKeyword(period, longestSec, cat);
  const QString pw = periodWord(period);
  if (!period.isEmpty() && (raw == period || raw == pw)) {
    return longestSec >= 60 * 60 ? QStringLiteral("Immersed") : categoryKeyword(cat);
  }
  return raw;
}

QString combinedKeyword(const QString& cat, const QString& keyword) {
  const QString catKw = categoryKeyword(cat);
  if (keyword.trimmed().isEmpty() || keyword == catKw) return catKw;
  return QStringLiteral("%1 / %2").arg(catKw, keyword);
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
             QStringLiteral("day %1").arg(binSet[b] ? binFirstDay[b] : 1));
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
    CategorizationManager* categorization, QObject* parent)
    : QObject(parent),
      m_statsService(statsService),
      m_frontmostRepository(frontmostRepository) {
  g_categorization = categorization;
}

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

  QString body = QStringLiteral("You were active on screen for about %1 today.").arg(totalText);
  if (!topApp.isEmpty()) {
    body += QStringLiteral("Mostly spent on %1.").arg(topApp);
  }

  QVariantList metrics;
  metrics.append(QVariantMap{{QStringLiteral("label"),
                              QStringLiteral("Active on screen")},
                             {QStringLiteral("value"), totalText}});

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-mainline"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("mainline"));
  card.insert(QStringLiteral("title"), QStringLiteral("Today's theme"));
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
  card.insert(QStringLiteral("title"), QStringLiteral("App use"));
  card.insert(QStringLiteral("body"),
              QStringLiteral("The app you used longest today"));
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
                              QStringLiteral("Duration")},
                             {QStringLiteral("value"), formatDuration(span)}});

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-focus-block"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("focus_block"));
  card.insert(QStringLiteral("title"), QStringLiteral("Focus Blocks"));
  card.insert(QStringLiteral("body"),
              QStringLiteral("This was your longest unbroken stretch of activity today, with no long breaks."));
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
    if (!isEntertainment(classifyRankingRow(src))) continue;
    totalSec += src.value(QStringLiteral("durationSec")).toLongLong();
    if (apps.size() < kTopAppLimit) apps.append(makeAppEntry(src));
    if (topApp.isEmpty()) topApp = appDisplayName(src);
  }

  if (totalSec <= 0) return QVariantMap();

  QString body = QStringLiteral("About %1 of entertainment today.").arg(formatDuration(totalSec));
  if (!topApp.isEmpty()) {
    body += QStringLiteral("Mostly from %1.").arg(topApp);
  }

  QVariantList metrics;
  metrics.append(QVariantMap{{QStringLiteral("label"),
                              QStringLiteral("Entertainment time")},
                             {QStringLiteral("value"), formatDuration(totalSec)}});

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-entertainment"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("entertainment"));
  card.insert(QStringLiteral("title"), QStringLiteral("Entertainment"));
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
    const QString cat = classifyRankingRow(src);
    const qint64 sec = src.value(QStringLiteral("durationSec")).toLongLong();
    if (cat == QStringLiteral("dev")) {
      focusSec += sec;
    } else if (isEntertainment(cat)) {
      leisureSec += sec;
    }
  }

  if (focusSec <= 0 && leisureSec <= 0) return QVariantMap();

  QVariantList metrics;
  metrics.append(QVariantMap{{QStringLiteral("label"),
                              QStringLiteral("Focus · Development")},
                             {QStringLiteral("value"), formatDuration(focusSec)}});
  metrics.append(QVariantMap{{QStringLiteral("label"),
                              QStringLiteral("Entertainment · Games & video")},
                             {QStringLiteral("value"), formatDuration(leisureSec)}});

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-contrast"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("contrast"));
  card.insert(QStringLiteral("title"), QStringLiteral("Focus vs entertainment"));
  card.insert(QStringLiteral("body"),
              QStringLiteral("Focus time (development) compared with entertainment time (games and video) detected today."));
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
  facts << QStringLiteral("You opened %1 different apps today.").arg(ranking.size());
  facts << QStringLiteral("You used %1 most today.")
               .arg(appDisplayName(ranking.first().toMap()));

  // 占比最高的活动类型（排除“其他”，否则没意义）。
  QHash<QString, qint64> byCategory;
  for (const QVariant& entry : ranking) {
    const QVariantMap src = entry.toMap();
    byCategory[classifyRankingRow(src)] +=
        src.value(QStringLiteral("durationSec")).toLongLong();
  }
  QString topCategory;
  qint64 topCategorySec = 0;
  for (auto it = byCategory.constBegin(); it != byCategory.constEnd(); ++it) {
    if (it.key() == QStringLiteral("other")) continue;
    if (it.value() > topCategorySec) {
      topCategorySec = it.value();
      topCategory = it.key();
    }
  }
  if (!topCategory.isEmpty()) {
    facts << QStringLiteral("Your largest activity type today was \u201c%1\u201d.").arg(topCategory);
  }

  // 按一年中的第几天轮换，当天稳定。
  const int idx = QDate::currentDate().dayOfYear() % facts.size();

  QVariantMap card;
  card.insert(QStringLiteral("id"), isoDate + QStringLiteral("-flip"));
  card.insert(QStringLiteral("date"), isoDate);
  card.insert(QStringLiteral("type"), QStringLiteral("random_flip"));
  card.insert(QStringLiteral("title"), QStringLiteral("Today's card"));
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
// 当天前台用量按小时分桶，取峰值小时并向相邻 ≥45% 峰值的小时扩展，
// 得到形如 "20:00–23:00" 的高峰区间（无数据返回空串）。
static QString peakHourLabel(const QVariantList& segments, qint64 dayStart) {
  double buckets[24] = {0};
  for (const QVariant& gv : segments) {
    const QVariantList segs =
        gv.toMap().value(QStringLiteral("segments")).toList();
    for (const QVariant& sv : segs) {
      const QVariantMap s = sv.toMap();
      const qint64 st = s.value(QStringLiteral("startUnixSec")).toLongLong();
      const qint64 en = s.value(QStringLiteral("endUnixSec")).toLongLong();
      if (en <= st) continue;
      qint64 cur = std::max<qint64>(st, dayStart);
      while (cur < en) {
        const int h = static_cast<int>((cur - dayStart) / 3600);
        if (h < 0 || h > 23) break;
        const qint64 hourEnd = dayStart + static_cast<qint64>(h + 1) * 3600;
        const qint64 chunkEnd = std::min(en, hourEnd);
        buckets[h] += static_cast<double>(chunkEnd - cur);
        cur = chunkEnd;
      }
    }
  }
  int peak = -1;
  double best = 0.0;
  for (int h = 0; h < 24; ++h)
    if (buckets[h] > best) {
      best = buckets[h];
      peak = h;
    }
  if (peak < 0 || best <= 0.0) return QString();
  int lo = peak, hi = peak;
  const double thresh = best * 0.45;
  while (lo - 1 >= 0 && buckets[lo - 1] >= thresh) --lo;
  while (hi + 1 <= 23 && buckets[hi + 1] >= thresh) ++hi;
  return QStringLiteral("%1:00–%2:00")
      .arg(lo, 2, 10, QLatin1Char('0'))
      .arg(hi + 1, 2, 10, QLatin1Char('0'));
}

// 文案模板 + 聚合，产出 QML 渲染所需同形的
// {apps, overview, todayTheme, usageShare, todayConclusion}。
QVariantMap DailyCardService::memoryLakeDay(const QVariantList& usmApps,
                                            const QVariantList& segments) {
  QVariantMap model;
  const QDate today = QDate::currentDate();
  const qint64 dayStart = today.startOfDay().toSecsSinceEpoch();

  QVariantMap overview;
  QVariantMap theme;
  theme.insert(QStringLiteral("kicker"), QStringLiteral("Today's Theme"));

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
    if (cat.isEmpty()) cat = QStringLiteral("other");
    const qlonglong sec = u.value(QStringLiteral("seconds")).toLongLong();
    totalDaySec += sec;
    catSec[cat] += sec;
    catByKey.insert(key, cat);
    nameByKey.insert(key, u.value(QStringLiteral("name")).toString());
    const bool homeVisible =
        !u.contains(QStringLiteral("homeRankVisible")) ||
        u.value(QStringLiteral("homeRankVisible")).toBool();
    if (!homeVisible) {
      continue;
    }
    if (cat == QStringLiteral("system"))
      systemApps.append(v);
    else
      nonSystem.append(v);
  }

  // 卡牌/排行：只展示主流/高信号应用；系统外壳、截图助手等低信号项仍保留在设置页全量列表。
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
    const QString category = catByKey.value(groupKey, QStringLiteral("other"));

    const QVariantMap seg = segByKey.value(groupKey);
    const int sessionCount = seg.value(QStringLiteral("sessionCount"), 0).toInt();
    const qlonglong longestSec =
        seg.value(QStringLiteral("longestSec"), 0).toLongLong();
    const QVariantList segs = seg.value(QStringLiteral("segments")).toList();
    totalSessions += sessionCount;
    const QString period = dominantPeriod(segs);

    QVariantMap app;
    app.insert(QStringLiteral("appId"), groupKey);
    app.insert(QStringLiteral("sourceAppId"), u.value(QStringLiteral("appId")));
    app.insert(QStringLiteral("name"), name);
    app.insert(QStringLiteral("appName"), u.value(QStringLiteral("appName")));
    app.insert(QStringLiteral("path"), path);
    app.insert(QStringLiteral("iconColors"), u.value(QStringLiteral("iconColors")));
    app.insert(QStringLiteral("brandColor"), u.value(QStringLiteral("brandColor")));
    app.insert(QStringLiteral("iconLabel"), u.value(QStringLiteral("iconLabel")));
    app.insert(QStringLiteral("iconSource"), u.value(QStringLiteral("iconSource")));
    app.insert(QStringLiteral("siteDomain"), u.value(QStringLiteral("siteDomain")));
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
    const QVariantMap analysis = analysisModel(name, timeText, period,
                                              longestSec, sessionCount, seconds);
    app.insert(QStringLiteral("analysisKey"),
               analysis.value(QStringLiteral("key")));
    app.insert(QStringLiteral("analysisParams"),
               analysis.value(QStringLiteral("params")));
    app.insert(QStringLiteral("launches"),
               sessionCount > 0 ? QStringLiteral("%1 times").arg(sessionCount)
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
          ? QStringLiteral("%1/%2 · nothing recorded yet")
                .arg(today.month())
                .arg(today.day())
          : QStringLiteral("%1/%2 · %3 sessions")
                .arg(today.month())
                .arg(today.day())
                .arg(totalSessions));
  model.insert(QStringLiteral("overview"), overview);

  // 今日结论/饼图复用：头条类别与占比（在 theme 分支内赋值，函数级可见）。
  QString topCat;
  double ratio = 0.0;

  if (appsOut.isEmpty() || totalDaySec <= 0) {
    theme.insert(QStringLiteral("title"), QStringLiteral("Today is still quiet"));
    theme.insert(QStringLiteral("desc"),
                 QStringLiteral("No automatic records yet. Once you start using the computer, today's theme appears here."));
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
    topCat = pickTop(QStringLiteral("system"), QStringLiteral("other"));
    if (topCat.isEmpty()) topCat = pickTop(QStringLiteral("system"), QString());
    QString cat2 = pickTop(QStringLiteral("system"), topCat);
    if (cat2 == QStringLiteral("other")) cat2.clear();
    ratio =
        (srcTotal > 0 && !topCat.isEmpty())
            ? std::min(1.0, static_cast<double>(headlineSrc.value(topCat, 0)) /
                                srcTotal)
            : 0.0;

    const QVariantMap themeTitleParts = themeTitleModel(topCat);
    theme.insert(QStringLiteral("titleKey"),
                 themeTitleParts.value(QStringLiteral("key")));
    theme.insert(QStringLiteral("titleParams"),
                 themeTitleParts.value(QStringLiteral("params")));
    theme.insert(QStringLiteral("ratio"), ratio);
    if (!tasks.isEmpty()) {
      const qlonglong longestSpan =
          tasks.first().toMap().value(QStringLiteral("span")).toLongLong();
      QVariantMap params;
      params.insert(QStringLiteral("count"), tasks.size());
      params.insert(QStringLiteral("longest"), decimalHoursText(longestSpan));
      QStringList cats;
      if (!topCat.isEmpty()) cats << categoryName(topCat);
      if (!cat2.isEmpty()) cats << categoryName(cat2);
      params.insert(QStringLiteral("category"), cats.join(QStringLiteral(",")));
      theme.insert(QStringLiteral("descKey"),
                   cats.isEmpty() ? QStringLiteral("continuousSessionsPlain")
                                  : QStringLiteral("continuousSessions"));
      theme.insert(QStringLiteral("descParams"), params);
    } else {
      const QVariantMap themeDescParts =
          themeDescModel(topCat, ratio, QString());
      theme.insert(QStringLiteral("descKey"),
                   themeDescParts.value(QStringLiteral("key")));
      theme.insert(QStringLiteral("descParams"),
                   themeDescParts.value(QStringLiteral("params")));
    }
  }
  model.insert(QStringLiteral("todayTheme"), theme);

  // —— Daily Theme Share（今日主题使用占比）：按本地分类器的「主题分类」(开发/社交/游戏/视频…)
  //    汇总，前 4 个主题类切片 + 其他。复用上面 catSec（类别→秒）；系统/其他不作具名切片，
  //    统一并入「其他」滚动项。denominator 仍取 totalDaySec，使各切片 % 加总≈100。——
  {
    struct CatSlice { QString cat; qint64 sec; };
    QVector<CatSlice> cats;
    for (auto it = catSec.constBegin(); it != catSec.constEnd(); ++it) {
      if (it.key() == QStringLiteral("system") || it.key() == QStringLiteral("other"))
        continue;
      cats.append({it.key(), it.value()});
    }
    std::sort(cats.begin(), cats.end(),
              [](const CatSlice& a, const CatSlice& b) { return a.sec > b.sec; });

    QVariantList share;
    const int topN = std::min<int>(4, static_cast<int>(cats.size()));
    qlonglong shown = 0;
    for (int i = 0; i < topN; ++i) {
      shown += cats.at(i).sec;
      QVariantMap slice;
      slice.insert(QStringLiteral("name"), cats.at(i).cat);
      slice.insert(QStringLiteral("seconds"), cats.at(i).sec);
      slice.insert(QStringLiteral("percent"),
                   totalDaySec > 0
                       ? qRound(100.0 * static_cast<double>(cats.at(i).sec) /
                                static_cast<double>(totalDaySec))
                       : 0);
      slice.insert(QStringLiteral("isOther"), false);
      share.append(slice);
    }
    const qlonglong rest = totalDaySec - shown;
    if (rest > 0) {
      QVariantMap other;
      other.insert(QStringLiteral("name"), QStringLiteral("other"));
      other.insert(QStringLiteral("seconds"), rest);
      other.insert(QStringLiteral("percent"),
                   totalDaySec > 0
                       ? qRound(100.0 * static_cast<double>(rest) /
                                static_cast<double>(totalDaySec))
                       : 0);
      other.insert(QStringLiteral("isOther"), true);
      share.append(other);
    }
    model.insert(QStringLiteral("usageShare"), share);
  }

  // —— Today Conclusion：复用 theme 头条 + 高峰时段 + 中立建议；
  //    待办剩余数由 QML 从 calendarManager 叠加（DCS 不链接日历符号）。——
  {
    QVariantMap conclusion;
    conclusion.insert(QStringLiteral("kicker"), QStringLiteral("Today Conclusion"));
    conclusion.insert(QStringLiteral("total"),
                      overview.value(QStringLiteral("total")));
    if (appsOut.isEmpty() || totalDaySec <= 0) {
      conclusion.insert(QStringLiteral("titleKey"),
                        QStringLiteral("todayStillQuiet"));
      conclusion.insert(QStringLiteral("titleParams"), QVariantMap());
      conclusion.insert(QStringLiteral("descKey"),
                        QStringLiteral("todayNoRecordsYet"));
      conclusion.insert(QStringLiteral("descParams"), QVariantMap());
      conclusion.insert(QStringLiteral("chips"), QVariantList());
    } else {
      // The conclusion headline restates the theme, so it carries the theme's
      // own fields rather than the theme's already-rendered sentence.
      QVariantMap titleParams;
      if (!themeIsUnclear(topCat))
        titleParams.insert(QStringLiteral("category"), categoryName(topCat));
      conclusion.insert(
          QStringLiteral("titleKey"),
          themeIsUnclear(topCat) ? QStringLiteral("todayMainThemeNone")
                                 : QStringLiteral("todayMainThemeFocus"));
      conclusion.insert(QStringLiteral("titleParams"), titleParams);
      conclusion.insert(QStringLiteral("descKey"),
                        theme.value(QStringLiteral("descKey")));
      conclusion.insert(QStringLiteral("descParams"),
                        theme.value(QStringLiteral("descParams")));
      QVariantList chips;
      const auto chip = [](const QString& label, const QString& value) {
        QVariantMap c;
        c.insert(QStringLiteral("label"), label);
        c.insert(QStringLiteral("value"), value);
        return c;
      };
      // The share chip mixes a translatable category with a number, so it
      // travels as a template rather than a glued-together string: a composed
      // value can never match a dictionary key on the other side.
      if (!topCat.isEmpty()) {
        QVariantMap shareParams;
        shareParams.insert(QStringLiteral("category"), categoryName(topCat));
        shareParams.insert(QStringLiteral("percent"), qRound(ratio * 100.0));
        QVariantMap shareChip;
        shareChip.insert(QStringLiteral("label"), QStringLiteral("Top Share"));
        shareChip.insert(QStringLiteral("valueKey"),
                         QStringLiteral("categoryPercent"));
        shareChip.insert(QStringLiteral("valueParams"), shareParams);
        chips.append(shareChip);
      }
      const QString peak = peakHourLabel(segments, dayStart);
      if (!peak.isEmpty()) chips.append(chip(QStringLiteral("Peak"), peak));
      QString suggestion = QStringLiteral("Keep it up");
      if (topCat == QStringLiteral("game"))
        suggestion = QStringLiteral("Clear the short tasks first");
      else if (topCat == QStringLiteral("office") ||
               topCat == QStringLiteral("create") ||
               topCat == QStringLiteral("dev"))
        suggestion = QStringLiteral("Keep your focus rhythm");
      else if (topCat == QStringLiteral("notes") ||
               topCat == QStringLiteral("read"))
        suggestion = QStringLiteral("Remember to take breaks");
      chips.append(chip(QStringLiteral("Suggestions"), suggestion));
      conclusion.insert(QStringLiteral("chips"), chips);
    }
    model.insert(QStringLiteral("todayConclusion"), conclusion);
  }

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
               QStringLiteral("Scroll or click to step through · apps appear one by one"));
  model.insert(
      QStringLiteral("modeNote"),
      QStringLiteral("The first play runs in order; click to speed it up. The contents unlock on the right when it finishes."));
  // 月级 apps 已由 USM 带上 iconColors（回顾背景/主角封面做多色晕染用）。
  model.insert(QStringLiteral("apps"), monthApps);

  QHash<QString, QVariantMap> segByKey;
  for (const QVariant& v : monthSegments) {
    const QVariantMap m = v.toMap();
    segByKey.insert(m.value(QStringLiteral("groupKey")).toString(), m);
  }

  // 类别由 USM 依规则表算好；缺失只可能是空行，按 other 记。
  const auto catOf = [](const QVariantMap& u) {
    const QString c = u.value(QStringLiteral("category")).toString();
    return c.isEmpty() ? QStringLiteral("other") : c;
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
    if (it.key() == QStringLiteral("system") || it.key() == QStringLiteral("other"))
      continue;
    if (it.value() > topCatSec) {
      topCatSec = it.value();
      topCat = it.key();
    }
  }
  if (topCat.isEmpty()) {  // 全是系统/其他时退而求其次（仍排除系统）
    for (auto it = catSec.constBegin(); it != catSec.constEnd(); ++it) {
      if (it.key() == QStringLiteral("system")) continue;
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
    if (catOf(a0) == QStringLiteral("system")) continue;
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
             hasData ? QStringLiteral("%1's Memory Lake\nThis month's trail of use.").arg(monthCn)
                     : QStringLiteral("%1's Memory Lake\nThis month is still quiet.").arg(monthCn));
    s.insert(QStringLiteral("subtitle"),
             hasData ? QStringLiteral("Not just totals, but the shape of how you used your device. The month unfolds by app, time of day, trend and change.")
                     : QStringLiteral("Not enough automatic records this month yet. Keep going and the recap will fill in."));
    QVariantList metrics;
    metrics.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("Monthly total")},
                               {QStringLiteral("value"), decimalHoursText(monthTotalSec)}});
    if (!topCat.isEmpty() && topCatSec > 0)
      metrics.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("Top category")},
                                 {QStringLiteral("value"), QStringLiteral("%1 %2%").arg(topCat).arg(topPct)}});
    if (!peakText.isEmpty())
      metrics.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("Most active period")},
                                 {QStringLiteral("value"), peakText}});
    s.insert(QStringLiteral("metrics"), metrics);
    addSlide(s, QStringLiteral("Monthly cover"), QStringLiteral("cover"), -1, QStringLiteral("zoom"));
  }

  if (!hasData) {
    model.insert(QStringLiteral("slides"), slides);
    return model;
  }

  // 02 月初到月末
  {
    const QString dir = monthTrendDir(dailySeries);
    QString title = dir == QStringLiteral("rising")
                        ? QStringLiteral("Usage rose sharply toward the end of the month.")
                        : (dir == QStringLiteral("falling")
                               ? QStringLiteral("Usage eased off toward the end of the month.")
                               : QStringLiteral("Usage stayed fairly even all month."));
    QVariantMap s;
    s.insert(QStringLiteral("title"), title);
    s.insert(QStringLiteral("subtitle"),
             QStringLiteral("The whole month in order, each bar the total for one stretch of time."));
    s.insert(QStringLiteral("monthMap"), monthMapBars(dailySeries));
    addSlide(s, QStringLiteral("Start to end of month"), QStringLiteral("monthMap"), -1, QStringLiteral("rise"));
  }

  // 03–06 主角（poster/split/orbit/article 当纯模板，按月度 Top 顺序套用，不足则减屏）
  const char* const tmpls[4] = {"poster", "split", "orbit", "article"};
  const QString steps[4] = {QStringLiteral("Lead app"), QStringLiteral("Second lead"),
                            QStringLiteral("Third lead"), QStringLiteral("Fourth lead")};
  const char* const trans[4] = {"zoom", "wipe", "rotate", "rise"};
  int proto = 0;
  for (int i = 0; i < monthApps.size() && proto < 4; ++i) {
    const QVariantMap u = monthApps.at(i).toMap();
    const qlonglong sec = u.value(QStringLiteral("seconds")).toLongLong();
    if (sec < 5 * 60) break;  // 不足 5 分钟不立为主角
    const QString cat = catOf(u);
    if (cat == QStringLiteral("system")) continue;  // 系统/外壳不当主角
    const QString name = u.value(QStringLiteral("name")).toString();
    const QString timeText = u.value(QStringLiteral("time")).toString();
    const QVariantMap seg = segByKey.value(u.value(QStringLiteral("groupKey")).toString());
    const qlonglong longestSec = seg.value(QStringLiteral("longestSec"), 0).toLongLong();
    const QVariantList segs = seg.value(QStringLiteral("segments")).toList();
    const QString period = dominantPeriod(segs);
    const QString mood = moodWord(cat, period, longestSec, sec);
    const QString protagKw = nonRepeatingKeyword(period, longestSec, cat);

    QVariantMap titleParams;
    titleParams.insert(QStringLiteral("app"), name);
    titleParams.insert(QStringLiteral("mood"), mood);

    QVariantMap subtitleParams;
    subtitleParams.insert(QStringLiteral("app"), name);
    subtitleParams.insert(QStringLiteral("time"), timeText);
    const bool detailed = !period.isEmpty() && longestSec > 0;
    if (detailed) {
      subtitleParams.insert(QStringLiteral("period"), period);
      subtitleParams.insert(QStringLiteral("longest"), formatDuration(longestSec));
    }
    const QString subtitleKey = detailed
                                    ? QStringLiteral("monthlyAppSubtitle")
                                    : QStringLiteral("monthlyAppSubtitlePlain");
    const QString kw = combinedKeyword(cat, protagKw);

    QVariantList stats;
    stats.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("Monthly Time")}, {QStringLiteral("value"), timeText}});
    if (longestSec > 0)
      stats.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("Longest Streak")}, {QStringLiteral("value"), formatDuration(longestSec)}});
    if (!period.isEmpty())
      stats.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("Main Period")}, {QStringLiteral("value"), period}});
    stats.append(QVariantMap{{QStringLiteral("label"), QStringLiteral("Keywords")}, {QStringLiteral("value"), kw}});

    QVariantMap s;
    const QString tmpl = QString::fromLatin1(tmpls[proto]);
    s.insert(QStringLiteral("titleKey"), QStringLiteral("protagonistTitle"));
    s.insert(QStringLiteral("titleParams"), titleParams);
    if (tmpl == QStringLiteral("poster")) {
      s.insert(QStringLiteral("posterTitle"), name);
      s.insert(QStringLiteral("posterSub"),
               proto == 0 ? QStringLiteral("%1 · longest use this month").arg(timeText)
                          : QStringLiteral("%1 · app of the month").arg(timeText));
      s.insert(QStringLiteral("subtitleKey"), subtitleKey);
      s.insert(QStringLiteral("subtitleParams"), subtitleParams);
      s.insert(QStringLiteral("stats"), stats);
    } else if (tmpl == QStringLiteral("split")) {
      s.insert(QStringLiteral("subtitleKey"), subtitleKey);
      s.insert(QStringLiteral("subtitleParams"), subtitleParams);
      s.insert(QStringLiteral("stats"), stats);
    } else if (tmpl == QStringLiteral("orbit")) {
      s.insert(QStringLiteral("subtitleKey"), subtitleKey);
      s.insert(QStringLiteral("subtitleParams"), subtitleParams);
      QVariantList orbit;
      orbit.append(QVariantMap{{QStringLiteral("a"), -25}, {QStringLiteral("value"), timeText}, {QStringLiteral("label"), QStringLiteral("Monthly use")}});
      if (longestSec > 0)
        orbit.append(QVariantMap{{QStringLiteral("a"), 35}, {QStringLiteral("value"), formatDuration(longestSec)}, {QStringLiteral("label"), QStringLiteral("Longest Streak")}});
      if (!period.isEmpty())
        orbit.append(QVariantMap{{QStringLiteral("a"), 105}, {QStringLiteral("value"), period}, {QStringLiteral("label"), QStringLiteral("Main Period")}});
      orbit.append(QVariantMap{{QStringLiteral("a"), 185}, {QStringLiteral("value"), protagKw}, {QStringLiteral("label"), QStringLiteral("Keyword of the month")}});
      s.insert(QStringLiteral("orbit"), orbit);
    } else {  // article
      if (period.isEmpty()) {
        s.insert(QStringLiteral("articleTitleKey"), QString());
        s.insert(QStringLiteral("articleTitle"), mood);
      } else {
        QVariantMap articleParams;
        articleParams.insert(QStringLiteral("period"), periodWord(period));
        s.insert(QStringLiteral("articleTitleKey"),
                 QStringLiteral("periodRegulars"));
        s.insert(QStringLiteral("articleTitleParams"), articleParams);
      }
      s.insert(QStringLiteral("articleBodyKey"), subtitleKey);
      s.insert(QStringLiteral("articleBodyParams"), subtitleParams);
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
      strips.append(QVariantMap{{QStringLiteral("tag"), QStringLiteral("%1 · frequent").arg(p)},
                                {QStringLiteral("apps"), names.join(QStringLiteral(" / "))},
                                {QStringLiteral("segs"), segvis}});
    }
    if (!strips.isEmpty()) {
      QVariantMap s;
      s.insert(QStringLiteral("title"), QStringLiteral("Different hours, different apps."));
      s.insert(QStringLiteral("subtitle"), QStringLiteral("Seen by time of day, each stretch has its own regulars."));
      s.insert(QStringLiteral("strips"), strips);
      addSlide(s, QStringLiteral("A day's trail"), QStringLiteral("timeline"), -1, QStringLiteral("wipe"));
    }
  }

  // 08 趋势变化（接真实按天序列，断言守卫）
  {
    const QString dir = monthTrendDir(dailySeries);
    QString title = dir == QStringLiteral("rising")
                        ? QStringLiteral("A clear peak at the end of the month.")
                        : (dir == QStringLiteral("falling")
                               ? QStringLiteral("Use tapered off at the end of the month.")
                               : QStringLiteral("Use stayed fairly even all month."));
    QVariantMap s;
    s.insert(QStringLiteral("title"), title);
    s.insert(QStringLiteral("subtitle"),
             QStringLiteral("This curve is your daily total across the month, like the water level of the lake."));
    s.insert(QStringLiteral("series"), trendSeries(dailySeries));
    addSlide(s, QStringLiteral("Trend"), QStringLiteral("trend"), -1, QStringLiteral("rotate"));
  }

  // 09 月度关键词
  {
    QStringList kws;
    kws << major;
    if (!peakPeriod.isEmpty()) kws << peakPeriod + QStringLiteral("Use");
    if (!topCat.isEmpty() && topCat != QStringLiteral("other"))
      kws << categoryName(topCat);
    int kc = 0;
    for (int i = 0; i < monthApps.size() && kc < 3; ++i) {
      const QString c = catOf(monthApps.at(i).toMap());
      if (c == QStringLiteral("system")) continue;
      kws << categoryKeyword(c);
      ++kc;
    }
    if (topLongestSec >= 60 * 60) kws << QStringLiteral("Long immersion");
    QStringList uniq;
    for (const QString& k : kws)
      if (!k.isEmpty() && !uniq.contains(k)) uniq << k;
    if (uniq.size() > 7) uniq = uniq.mid(0, 7);
    QVariantList kwv;
    for (const QString& k : uniq) kwv << k;
    QVariantMap s;
    s.insert(QStringLiteral("title"), QStringLiteral("The keyword for this month."));
    s.insert(QStringLiteral("subtitle"),
             QStringLiteral("Derived from app category, stretch length, launch count and time of day: the state you were in most this month."));
    s.insert(QStringLiteral("keywords"), kwv);
    s.insert(QStringLiteral("major"), major);
    addSlide(s, QStringLiteral("Keyword of the month"), QStringLiteral("keywords"), -1, QStringLiteral("rise"));
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
      return k == QStringLiteral("other") || k == QStringLiteral("system");
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
        change = c.cur > 0 ? QStringLiteral("New") : QStringLiteral("—");
      else {
        const int pct = qRound(100.0 * delta / c.last);
        change = QStringLiteral("%1%2%").arg(pct >= 0 ? QStringLiteral("+") : QString()).arg(pct);
      }
      const bool down = delta < 0;
      comparisons.append(QVariantMap{
          {QStringLiteral("label"), QStringLiteral("%1 time").arg(c.cat)},
          {QStringLiteral("change"), change},
          {QStringLiteral("down"), down},
          {QStringLiteral("desc"), down ? QStringLiteral("%1 time fell compared with last month.").arg(c.cat)
                                        : QStringLiteral("%1 time rose compared with last month.").arg(c.cat)}});
      if (topChangeStr.isEmpty()) topChangeStr = QStringLiteral("%1 %2").arg(c.cat, change);
    }
    if (!comparisons.isEmpty()) {
      QVariantMap s;
      s.insert(QStringLiteral("title"), QStringLiteral("Change from last month."));
      s.insert(QStringLiteral("comparisons"), comparisons);
      addSlide(s, QStringLiteral("vs last month"), QStringLiteral("comparison"), -1, QStringLiteral("wipe"));
    }
  }

  // 11 月度标签（票根：复述前面真实值，不另造数字）
  {
    QVariantList rows;
    rows << QStringLiteral("Total use %1").arg(decimalHoursText(monthTotalSec));
    rows << QStringLiteral("Top category: %1").arg(topCat.isEmpty() ? QStringLiteral("—") : topCat);
    rows << QStringLiteral("Keyword: %1").arg(major);
    rows << (topChangeStr.isEmpty() ? QStringLiteral("First month recorded")
                                    : QStringLiteral("%1 vs last month").arg(topChangeStr));
    QVariantMap ticket;
    ticket.insert(QStringLiteral("title"), QStringLiteral("%1\nMemory tag").arg(monthCn));
    ticket.insert(QStringLiteral("rows"), rows);
    QVariantMap s;
    s.insert(QStringLiteral("title"), QStringLiteral("Your %1 tag is ready.").arg(monthCn));
    s.insert(QStringLiteral("subtitle"),
             QStringLiteral("This tag keeps the month's main hours, top category and change."));
    s.insert(QStringLiteral("ticket"), ticket);
    addSlide(s, QStringLiteral("Monthly tag"), QStringLiteral("ticket"), -1, QStringLiteral("ticket"));
  }

  model.insert(QStringLiteral("slides"), slides);
  return model;
}
