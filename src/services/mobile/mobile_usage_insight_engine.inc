#include "mobile_usage_insight_engine.h"

#include <QDateTime>
#include <QMap>
#include <QPair>
#include <QSet>
#include <QStringList>
#include <QTime>
#include <QVector>
#include <QtMath>

#include <algorithm>

namespace {

QString formatDuration(int seconds) {
  const int safeSeconds = qMax(0, seconds);
  const int hours = safeSeconds / 3600;
  const int minutes = (safeSeconds % 3600) / 60;
  if (hours > 0 && minutes > 0) {
    return QStringLiteral("%1 小时 %2 分").arg(hours).arg(minutes);
  }
  if (hours > 0) return QStringLiteral("%1 小时").arg(hours);
  if (minutes > 0) return QStringLiteral("%1 分钟").arg(minutes);
  return QStringLiteral("不足 1 分钟");
}

QString appKey(const QVariantMap& row) {
  QString key = row.value(QStringLiteral("appIdentifier")).toString();
  if (key.isEmpty()) key = row.value(QStringLiteral("packageName")).toString();
  return key;
}

QString appName(const QVariantMap& row) {
  QString name = row.value(QStringLiteral("displayName")).toString().trimmed();
  if (name.isEmpty()) name = row.value(QStringLiteral("appName")).toString();
  if (name.isEmpty()) name = appKey(row);
  return name;
}

QVariantMap candidate(const QString& kind,
                      const QString& headline,
                      const QString& body,
                      const QString& confidence,
                      int score,
                      const QString& evidenceDate = QString()) {
  QVariantMap result;
  result.insert(QStringLiteral("kind"), kind);
  result.insert(QStringLiteral("headline"), headline);
  result.insert(QStringLiteral("body"), body);
  result.insert(QStringLiteral("confidence"), confidence);
  result.insert(QStringLiteral("score"), score);
  result.insert(QStringLiteral("evidenceDate"), evidenceDate);
  result.insert(QStringLiteral("shareSafe"), true);
  return result;
}

int longestStreak(const QSet<QDate>& activeDates) {
  if (activeDates.isEmpty()) return 0;
  QList<QDate> dates = activeDates.values();
  std::sort(dates.begin(), dates.end());
  int longest = 1;
  int current = 1;
  for (int i = 1; i < dates.size(); ++i) {
    if (dates.at(i - 1).daysTo(dates.at(i)) == 1) {
      ++current;
      longest = qMax(longest, current);
    } else if (dates.at(i - 1) != dates.at(i)) {
      current = 1;
    }
  }
  return longest;
}

QString monthAtmosphere(int monthNumber) {
  static const QStringList phrases = {
      QStringLiteral("霜面下仍留着微光"),
      QStringLiteral("融雪让时间重新有了流向"),
      QStringLiteral("雨后长出了自己的形状"),
      QStringLiteral("花影缓慢走过桌面"),
      QStringLiteral("长日光照见连续的日子"),
      QStringLiteral("雷雨之间仍有清晰的刻度"),
      QStringLiteral("夜色里亮起许多细小片段"),
      QStringLiteral("阵雨让时间慢了一拍"),
      QStringLiteral("风打开了新的时间入口"),
      QStringLiteral("落叶把许多日子连成一条路"),
      QStringLiteral("初霜让留下的部分更清楚"),
      QStringLiteral("雪灯下，一年的时间开始归档")};
  return phrases.value(qBound(1, monthNumber, 12) - 1);
}

QString segmentLabel(int hour) {
  if (hour >= 5 && hour < 8) return QStringLiteral("清晨");
  if (hour >= 8 && hour < 12) return QStringLiteral("上午");
  if (hour >= 12 && hour < 18) return QStringLiteral("下午");
  if (hour >= 18) return QStringLiteral("夜晚");
  return QStringLiteral("深夜");
}

}  // namespace

inline QVariantMap MobileUsageInsightEngine::buildMonthlyReport(
    const QDate& month,
    const QVariantList& dailyRows,
    const QVariantList& sessions,
    const QVariantList& previousRows) {
  const QDate monthStart(month.year(), month.month(), 1);
  QVariantMap report;
  report.insert(QStringLiteral("monthKey"),
                monthStart.toString(QStringLiteral("yyyy-MM")));
  report.insert(QStringLiteral("monthLabel"),
                monthStart.toString(QStringLiteral("yyyy年M月")));

  int totalSec = 0;
  QSet<QDate> activeDates;
  QMap<QString, QVariantMap> apps;
  QMap<QString, QSet<QString>> appsByDate;
  QMap<QString, QString> firstDateByApp;

  for (const QVariant& value : dailyRows) {
    const QVariantMap row = value.toMap();
    const int seconds = qMax(0, row.value(QStringLiteral("foregroundSec")).toInt());
    const QDate date =
        QDate::fromString(row.value(QStringLiteral("dateLocal")).toString(),
                          Qt::ISODate);
    const QString key = appKey(row);
    if (seconds <= 0 || !date.isValid() || key.isEmpty()) continue;

    totalSec += seconds;
    activeDates.insert(date);
    appsByDate[date.toString(Qt::ISODate)].insert(key);
    if (firstDateByApp.value(key).isEmpty() ||
        date.toString(Qt::ISODate) < firstDateByApp.value(key)) {
      firstDateByApp.insert(key, date.toString(Qt::ISODate));
    }

    QVariantMap aggregate = apps.value(key);
    if (aggregate.isEmpty()) {
      aggregate.insert(QStringLiteral("appIdentifier"), key);
      aggregate.insert(QStringLiteral("packageName"),
                       row.value(QStringLiteral("packageName")));
      aggregate.insert(QStringLiteral("displayName"), appName(row));
      aggregate.insert(QStringLiteral("appIconPath"),
                       row.value(QStringLiteral("appIconPath")));
      aggregate.insert(QStringLiteral("foregroundSec"), 0);
      aggregate.insert(QStringLiteral("dates"), QStringList());
    }
    aggregate.insert(
        QStringLiteral("foregroundSec"),
        aggregate.value(QStringLiteral("foregroundSec")).toInt() + seconds);
    QStringList dates = aggregate.value(QStringLiteral("dates")).toStringList();
    const QString dateText = date.toString(Qt::ISODate);
    if (!dates.contains(dateText)) dates.append(dateText);
    aggregate.insert(QStringLiteral("dates"), dates);
    apps.insert(key, aggregate);
  }

  QVector<QVariantMap> sortedApps;
  sortedApps.reserve(apps.size());
  for (QVariantMap app : apps) {
    const int seconds = app.value(QStringLiteral("foregroundSec")).toInt();
    const QStringList dates = app.value(QStringLiteral("dates")).toStringList();
    app.insert(QStringLiteral("durationSec"), seconds);
    app.insert(QStringLiteral("durationText"), formatDuration(seconds));
    app.insert(QStringLiteral("recordedDays"), dates.size());
    app.insert(QStringLiteral("firstDateLocal"),
               firstDateByApp.value(app.value(QStringLiteral("appIdentifier"))
                                        .toString()));
    sortedApps.append(app);
  }
  std::stable_sort(sortedApps.begin(), sortedApps.end(),
                   [](const QVariantMap& left, const QVariantMap& right) {
                     return left.value(QStringLiteral("foregroundSec")).toInt() >
                            right.value(QStringLiteral("foregroundSec")).toInt();
                   });

  QVariantList topApps;
  const int leaderSec =
      sortedApps.isEmpty()
          ? 0
          : sortedApps.first().value(QStringLiteral("foregroundSec")).toInt();
  for (int index = 0; index < sortedApps.size(); ++index) {
    QVariantMap app = sortedApps.at(index);
    const int seconds = app.value(QStringLiteral("foregroundSec")).toInt();
    app.insert(QStringLiteral("rank"), index + 1);
    app.insert(QStringLiteral("sharePct"),
               totalSec > 0 ? qRound(seconds * 100.0 / totalSec) : 0);
    app.insert(QStringLiteral("relativePct"),
               leaderSec > 0 ? qRound(seconds * 100.0 / leaderSec) : 0);
    topApps.append(app);
  }

  int previousTotalSec = 0;
  QSet<QString> previousApps;
  for (const QVariant& value : previousRows) {
    const QVariantMap row = value.toMap();
    previousTotalSec +=
        qMax(0, row.value(QStringLiteral("foregroundSec")).toInt());
    const QString key = appKey(row);
    if (!key.isEmpty()) previousApps.insert(key);
  }

  QVariantMap longestObserved;
  QVariantMap longestEstimated;
  int lateCount = 0;
  int latestMinute = -1;
  QMap<QString, int> segmentSeconds;
  for (const QVariant& value : sessions) {
    const QVariantMap session = value.toMap();
    const int duration =
        qMax(0, session.value(QStringLiteral("durationSec")).toInt());
    const qint64 startUnix =
        session.value(QStringLiteral("sessionStartUnixSec")).toLongLong();
    const qint64 endUnix =
        session.value(QStringLiteral("sessionEndUnixSec")).toLongLong();
    if (duration <= 0 || startUnix <= 0 || endUnix <= startUnix) continue;
    const QDateTime start = QDateTime::fromSecsSinceEpoch(startUnix);
    const QDateTime end = QDateTime::fromSecsSinceEpoch(endUnix);
    segmentSeconds[segmentLabel(start.time().hour())] += duration;

    const QString confidence =
        session.value(QStringLiteral("confidence")).toString().toLower();
    if (confidence == QStringLiteral("observed") &&
        duration >
            longestObserved.value(QStringLiteral("durationSec")).toInt()) {
      longestObserved = session;
    } else if (confidence != QStringLiteral("observed") &&
               duration >
                   longestEstimated.value(QStringLiteral("durationSec")).toInt()) {
      longestEstimated = session;
    }

    if (start.date() != end.date() || start.time().hour() < 5 ||
        end.time().hour() < 5) {
      ++lateCount;
      const int minute = end.time().hour() * 60 + end.time().minute();
      if (end.date() != start.date() || end.time().hour() < 5) {
        latestMinute = qMax(latestMinute, minute);
      }
    }
  }

  QVariantMap longestSession =
      longestObserved.isEmpty() ? longestEstimated : longestObserved;
  if (!longestSession.isEmpty()) {
    const int duration =
        longestSession.value(QStringLiteral("durationSec")).toInt();
    const QDateTime start = QDateTime::fromSecsSinceEpoch(
        longestSession.value(QStringLiteral("sessionStartUnixSec")).toLongLong());
    const QString confidence =
        longestObserved.isEmpty() ? QStringLiteral("estimated")
                                  : QStringLiteral("observed");
    longestSession.insert(QStringLiteral("durationText"),
                          formatDuration(duration));
    longestSession.insert(QStringLiteral("startLocal"),
                          start.toString(QStringLiteral("yyyy-MM-dd HH:mm")));
    longestSession.insert(QStringLiteral("dateLocal"),
                          start.date().toString(Qt::ISODate));
    longestSession.insert(QStringLiteral("confidence"), confidence);
  }

  QPair<QString, QString> bestPair;
  int bestPairDays = 0;
  QMap<QPair<QString, QString>, int> pairDays;
  for (const QSet<QString>& dayApps : appsByDate) {
    QStringList keys = dayApps.values();
    std::sort(keys.begin(), keys.end());
    for (int left = 0; left < keys.size(); ++left) {
      for (int right = left + 1; right < keys.size(); ++right) {
        const QPair<QString, QString> pair(keys.at(left), keys.at(right));
        const int count = ++pairDays[pair];
        if (count > bestPairDays ||
            (count == bestPairDays && pair < bestPair)) {
          bestPair = pair;
          bestPairDays = count;
        }
      }
    }
  }

  QVariantMap companion;
  if (bestPairDays > 0) {
    companion.insert(QStringLiteral("firstApp"),
                     apps.value(bestPair.first));
    companion.insert(QStringLiteral("secondApp"),
                     apps.value(bestPair.second));
    companion.insert(QStringLiteral("daysTogether"), bestPairDays);
    companion.insert(
        QStringLiteral("body"),
        QStringLiteral("%1 与 %2 在 %3 个日子里共同出现。")
            .arg(apps.value(bestPair.first)
                     .value(QStringLiteral("displayName"))
                     .toString(),
                 apps.value(bestPair.second)
                     .value(QStringLiteral("displayName"))
                     .toString())
            .arg(bestPairDays));
  }

  QString dominantSegment;
  int dominantSegmentSec = 0;
  for (auto it = segmentSeconds.cbegin(); it != segmentSeconds.cend(); ++it) {
    if (it.value() > dominantSegmentSec) {
      dominantSegment = it.key();
      dominantSegmentSec = it.value();
    }
  }

  QVariantList candidates;
  const int streak = longestStreak(activeDates);
  if (streak >= 2) {
    candidates.append(candidate(
        QStringLiteral("streak"), QStringLiteral("连续 %1 天").arg(streak),
        QStringLiteral("%1 个连续的日子都留下了真实记录。").arg(streak),
        QStringLiteral("daily"), 70 + qMin(streak, 20)));
  }

  if (!longestSession.isEmpty()) {
    const bool observed =
        longestSession.value(QStringLiteral("confidence")).toString() ==
        QStringLiteral("observed");
    const QString dateText =
        QDate::fromString(
            longestSession.value(QStringLiteral("dateLocal")).toString(),
            Qt::ISODate)
            .toString(QStringLiteral("M 月 d 日"));
    candidates.append(candidate(
        QStringLiteral("longestSession"),
        longestSession.value(QStringLiteral("durationText")).toString(),
        observed
            ? QStringLiteral("%1，最长的一次已观测记录持续了 %2。")
                  .arg(dateText,
                       longestSession.value(QStringLiteral("durationText"))
                           .toString())
            : QStringLiteral("可确认记录中，%1 有一段较长的 %2。")
                  .arg(dateText,
                       longestSession.value(QStringLiteral("durationText"))
                           .toString()),
        observed ? QStringLiteral("observed") : QStringLiteral("estimated"),
        observed ? 96 : 55,
        longestSession.value(QStringLiteral("dateLocal")).toString()));
  }

  if (lateCount > 0) {
    const QString latestText =
        latestMinute >= 0
            ? QStringLiteral("，最晚停在 %1:%2")
                  .arg(latestMinute / 60, 2, 10, QLatin1Char('0'))
                  .arg(latestMinute % 60, 2, 10, QLatin1Char('0'))
            : QString();
    candidates.append(candidate(
        QStringLiteral("lateNight"), QStringLiteral("深夜 %1 次").arg(lateCount),
        QStringLiteral("%1 段记录越过零点或发生在凌晨%2。")
            .arg(lateCount)
            .arg(latestText),
        QStringLiteral("session"), 80 + qMin(lateCount, 12)));
  }

  if (!dominantSegment.isEmpty()) {
    const int pct =
        totalSec > 0 ? qRound(dominantSegmentSec * 100.0 / totalSec) : 0;
    candidates.append(candidate(
        QStringLiteral("timeSegment"), dominantSegment,
        QStringLiteral("%1承接了可确认会话中的 %2% 使用时间。")
            .arg(dominantSegment)
            .arg(pct),
        QStringLiteral("session"), 60 + qMin(pct, 30)));
  }

  if (bestPairDays > 0) {
    candidates.append(candidate(
        QStringLiteral("appCombination"),
        QStringLiteral("共同 %1 天").arg(bestPairDays),
        companion.value(QStringLiteral("body")).toString(),
        QStringLiteral("daily"), 66 + qMin(bestPairDays, 20)));
  }

  QString firstNewKey;
  QString firstNewDate;
  for (auto it = firstDateByApp.cbegin(); it != firstDateByApp.cend(); ++it) {
    if (!previousApps.contains(it.key()) &&
        (firstNewDate.isEmpty() || it.value() < firstNewDate)) {
      firstNewKey = it.key();
      firstNewDate = it.value();
    }
  }
  if (!firstNewKey.isEmpty()) {
    const QString name =
        apps.value(firstNewKey).value(QStringLiteral("displayName")).toString();
    candidates.append(candidate(
        QStringLiteral("firstAppearance"), QStringLiteral("第一次出现"),
        QStringLiteral("%1 从 %2 开始进入可追溯的月度记录。")
            .arg(name,
                 QDate::fromString(firstNewDate, Qt::ISODate)
                     .toString(QStringLiteral("M 月 d 日"))),
        QStringLiteral("daily"), 72, firstNewDate));
  }

  int deltaSec = totalSec - previousTotalSec;
  int deltaPct = 0;
  QString deltaBody;
  if (previousTotalSec > 0) {
    deltaPct = qRound(deltaSec * 100.0 / previousTotalSec);
    deltaBody =
        deltaSec >= 0
            ? QStringLiteral("比上月多 %1，变化为 +%2%。")
                  .arg(formatDuration(deltaSec))
                  .arg(deltaPct)
            : QStringLiteral("比上月少 %1，变化为 %2%。")
                  .arg(formatDuration(-deltaSec))
                  .arg(deltaPct);
    candidates.append(candidate(
        QStringLiteral("monthlyDelta"),
        QStringLiteral("%1%2%")
            .arg(deltaPct >= 0 ? QStringLiteral("+") : QString())
            .arg(deltaPct),
        deltaBody, QStringLiteral("daily"), 64 + qMin(qAbs(deltaPct), 30)));
  } else if (totalSec > 0) {
    deltaBody = QStringLiteral("这是当前可追溯范围内第一次形成完整月度记录。");
  }

  std::stable_sort(candidates.begin(), candidates.end(),
                   [](const QVariant& leftValue, const QVariant& rightValue) {
                     const QVariantMap left = leftValue.toMap();
                     const QVariantMap right = rightValue.toMap();
                     const int leftScore =
                         left.value(QStringLiteral("score")).toInt();
                     const int rightScore =
                         right.value(QStringLiteral("score")).toInt();
                     if (leftScore != rightScore) return leftScore > rightScore;
                     return left.value(QStringLiteral("kind")).toString() <
                            right.value(QStringLiteral("kind")).toString();
                   });

  QVariantList selected;
  for (const QVariant& value : candidates) {
    if (selected.size() >= 3) break;
    selected.append(value);
  }

  const QDate today = QDate::currentDate();
  const QDate monthEnd =
      monthStart.addMonths(1).addDays(-1) < today
          ? monthStart.addMonths(1).addDays(-1)
          : today;
  QVariantMap coverage;
  coverage.insert(QStringLiteral("startDate"),
                  monthStart.toString(Qt::ISODate));
  coverage.insert(QStringLiteral("endDate"), monthEnd.toString(Qt::ISODate));
  coverage.insert(QStringLiteral("activeDays"), activeDates.size());
  coverage.insert(QStringLiteral("calendarDays"),
                  monthStart.daysTo(monthEnd) + 1);
  coverage.insert(QStringLiteral("complete"),
                  activeDates.size() >= qMin(7, monthStart.daysTo(monthEnd) + 1));

  report.insert(QStringLiteral("totalSec"), totalSec);
  report.insert(QStringLiteral("totalText"), formatDuration(totalSec));
  report.insert(QStringLiteral("activeDays"), activeDates.size());
  report.insert(QStringLiteral("longestStreakDays"), streak);
  report.insert(QStringLiteral("previousTotalSec"), previousTotalSec);
  report.insert(QStringLiteral("deltaSec"), deltaSec);
  report.insert(QStringLiteral("deltaPct"), deltaPct);
  report.insert(QStringLiteral("deltaText"), deltaBody);
  report.insert(QStringLiteral("topApps"), topApps);
  report.insert(QStringLiteral("longestSession"), longestSession);
  report.insert(QStringLiteral("lateNightCount"), lateCount);
  report.insert(QStringLiteral("dominantSegment"), dominantSegment);
  report.insert(QStringLiteral("companion"), companion);
  report.insert(QStringLiteral("coverage"), coverage);
  report.insert(QStringLiteral("insights"), selected);
  report.insert(QStringLiteral("empty"), totalSec <= 0);
  report.insert(
      QStringLiteral("summary"),
      totalSec > 0
          ? QStringLiteral("%1 个有记录的日子，%2。")
                .arg(activeDates.size())
                .arg(monthAtmosphere(monthStart.month()))
          : QStringLiteral("同步后，这个月的真实时间会在这里形成报告。"));
  return report;
}
