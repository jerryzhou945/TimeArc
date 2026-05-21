#ifndef STATSSERVICE_H
#define STATSSERVICE_H

#include <QList>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class FrontmostSessionRepository;
class ManualProjectRepository;
class MediaSessionRepository;

class StatsService : public QObject {
  Q_OBJECT

 public:
  explicit StatsService(FrontmostSessionRepository* frontmostRepository,
                        MediaSessionRepository* mediaRepository,
                        ManualProjectRepository* manualProjectRepository,
                        QObject* parent = nullptr);

  Q_INVOKABLE int getTodayFrontmostActiveSeconds();
  Q_INVOKABLE QString getTodayFrontmostActiveText();

  Q_INVOKABLE int getTodayMediaPlaybackSeconds();
  Q_INVOKABLE QString getTodayMediaPlaybackText();

  Q_INVOKABLE int getTodayManualProjectSeconds();
  Q_INVOKABLE QString getTodayManualProjectText();

  Q_INVOKABLE int getTodayRecordedCoverageSeconds();
  Q_INVOKABLE QString getTodayRecordedCoverageText();

  Q_INVOKABLE QVariantList getTodayAppRanking();
  Q_INVOKABLE QVariantList getTodayMediaRanking();
  Q_INVOKABLE QVariantList getTodayProjectRanking();

  Q_INVOKABLE QVariantMap getHomeSummary();

 private:
  struct TimeInterval {
    qint64 start;
    qint64 end;
  };

  qint64 todayStartUnix() const;
  qint64 nowUnix() const;

  int calculateUnionDuration(QList<TimeInterval> intervals) const;
  QString formatDuration(int seconds) const;

  FrontmostSessionRepository* m_frontmostRepository;
  MediaSessionRepository* m_mediaRepository;
  ManualProjectRepository* m_manualProjectRepository;
};

#endif
