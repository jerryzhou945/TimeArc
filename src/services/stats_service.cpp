#include "services/stats_service.h"

#include <QDateTime>
#include <QDebug>
#include <QVariantMap>

#include <algorithm>
#include <limits>

#include "services/frontmost_session_repository.h"
#include "services/manual_project_repository.h"
#include "services/media_session_repository.h"

StatsService::StatsService(FrontmostSessionRepository* frontmostRepository,
                           MediaSessionRepository* mediaRepository,
                           ManualProjectRepository* manualProjectRepository,
                           QObject* parent)
    : QObject(parent),
      m_frontmostRepository(frontmostRepository),
      m_mediaRepository(mediaRepository),
      m_manualProjectRepository(manualProjectRepository) {}

int StatsService::getTodayFrontmostActiveSeconds() {
  if (!m_frontmostRepository) {
    qWarning() << "FrontmostSessionRepository is not available.";
    return 0;
  }

  return m_frontmostRepository->getTotalActiveSecondsByRange(todayStartUnix(),
                                                            nowUnix());
}

QString StatsService::getTodayFrontmostActiveText() {
  return formatDuration(getTodayFrontmostActiveSeconds());
}

int StatsService::getTodayMediaPlaybackSeconds() {
  if (!m_mediaRepository) {
    qWarning() << "MediaSessionRepository is not available.";
    return 0;
  }

  return m_mediaRepository->getTotalPlaybackSecondsByRange(todayStartUnix(),
                                                          nowUnix());
}

QString StatsService::getTodayMediaPlaybackText() {
  return formatDuration(getTodayMediaPlaybackSeconds());
}

int StatsService::getTodayManualProjectSeconds() {
  if (!m_manualProjectRepository) {
    qWarning() << "ManualProjectRepository is not available.";
    return 0;
  }

  return m_manualProjectRepository->getTotalManualSecondsByRange(
      todayStartUnix(), nowUnix());
}

QString StatsService::getTodayManualProjectText() {
  return formatDuration(getTodayManualProjectSeconds());
}

int StatsService::getTodayRecordedCoverageSeconds() {
  if (!m_frontmostRepository || !m_mediaRepository) {
    qWarning() << "Repositories required for recorded coverage are missing.";
    return 0;
  }

  const qint64 start = todayStartUnix();
  const qint64 end = nowUnix();
  if (end <= start) return 0;

  QList<TimeInterval> intervals;

  const QVariantList frontmostIntervals =
      m_frontmostRepository->getIntervalsByRange(start, end);
  for (const QVariant& item : frontmostIntervals) {
    const QVariantMap interval = item.toMap();
    intervals.append({std::max(start,
                               interval.value(QStringLiteral("startUnixSec"))
                                   .toLongLong()),
                      std::min(end,
                               interval.value(QStringLiteral("endUnixSec"))
                                   .toLongLong())});
  }

  const QVariantList mediaIntervals =
      m_mediaRepository->getIntervalsByRange(start, end);
  for (const QVariant& item : mediaIntervals) {
    const QVariantMap interval = item.toMap();
    intervals.append({std::max(start,
                               interval.value(QStringLiteral("startUnixSec"))
                                   .toLongLong()),
                      std::min(end,
                               interval.value(QStringLiteral("endUnixSec"))
                                   .toLongLong())});
  }

  return calculateUnionDuration(intervals);
}

QString StatsService::getTodayRecordedCoverageText() {
  return formatDuration(getTodayRecordedCoverageSeconds());
}

QVariantList StatsService::getTodayAppRanking() {
  if (!m_frontmostRepository) {
    qWarning() << "FrontmostSessionRepository is not available.";
    return QVariantList();
  }

  return m_frontmostRepository->getTodayFrontmostRanking();
}

QVariantList StatsService::getTodayMediaRanking() {
  if (!m_mediaRepository) {
    qWarning() << "MediaSessionRepository is not available.";
    return QVariantList();
  }

  return m_mediaRepository->getTodayMediaRanking();
}

QVariantList StatsService::getTodayProjectRanking() {
  if (!m_manualProjectRepository) {
    qWarning() << "ManualProjectRepository is not available.";
    return QVariantList();
  }

  return m_manualProjectRepository->getTodayProjectRanking();
}

QVariantMap StatsService::getHomeSummary() {
  const int frontmostActiveSec = getTodayFrontmostActiveSeconds();
  const int mediaPlaybackSec = getTodayMediaPlaybackSeconds();
  const int manualProjectSec = getTodayManualProjectSeconds();
  const int recordedCoverageSec = getTodayRecordedCoverageSeconds();

  QVariantMap summary;
  summary.insert(QStringLiteral("frontmostActiveSec"), frontmostActiveSec);
  summary.insert(QStringLiteral("frontmostActiveText"),
                 formatDuration(frontmostActiveSec));
  summary.insert(QStringLiteral("mediaPlaybackSec"), mediaPlaybackSec);
  summary.insert(QStringLiteral("mediaPlaybackText"),
                 formatDuration(mediaPlaybackSec));
  summary.insert(QStringLiteral("manualProjectSec"), manualProjectSec);
  summary.insert(QStringLiteral("manualProjectText"),
                 formatDuration(manualProjectSec));
  summary.insert(QStringLiteral("recordedCoverageSec"), recordedCoverageSec);
  summary.insert(QStringLiteral("recordedCoverageText"),
                 formatDuration(recordedCoverageSec));
  return summary;
}

qint64 StatsService::todayStartUnix() const {
  return QDateTime::currentDateTime().date().startOfDay().toSecsSinceEpoch();
}

qint64 StatsService::nowUnix() const {
  return QDateTime::currentSecsSinceEpoch();
}

int StatsService::calculateUnionDuration(QList<TimeInterval> intervals) const {
  intervals.erase(std::remove_if(intervals.begin(), intervals.end(),
                                 [](const TimeInterval& interval) {
                                   return interval.end <= interval.start;
                                 }),
                  intervals.end());

  if (intervals.isEmpty()) return 0;

  std::sort(intervals.begin(), intervals.end(),
            [](const TimeInterval& lhs, const TimeInterval& rhs) {
              if (lhs.start == rhs.start) return lhs.end < rhs.end;
              return lhs.start < rhs.start;
            });

  qint64 totalSeconds = 0;
  qint64 currentStart = intervals.first().start;
  qint64 currentEnd = intervals.first().end;

  for (int i = 1; i < intervals.size(); ++i) {
    const TimeInterval& interval = intervals.at(i);
    if (interval.start <= currentEnd) {
      currentEnd = std::max(currentEnd, interval.end);
      continue;
    }

    totalSeconds += currentEnd - currentStart;
    currentStart = interval.start;
    currentEnd = interval.end;
  }

  totalSeconds += currentEnd - currentStart;
  return static_cast<int>(
      std::min<qint64>(totalSeconds, std::numeric_limits<int>::max()));
}

QString StatsService::formatDuration(int seconds) const {
  const int safeSeconds = std::max(0, seconds);
  if (safeSeconds < 60) {
    return QStringLiteral("%1s").arg(safeSeconds);
  }

  const int minutes = safeSeconds / 60;
  if (minutes < 60) {
    return QStringLiteral("%1m").arg(minutes);
  }

  const int hours = minutes / 60;
  const int remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) {
    return QStringLiteral("%1h").arg(hours);
  }

  return QStringLiteral("%1h %2m").arg(hours).arg(remainingMinutes);
}
