#ifndef MEDIASESSIONREPOSITORY_H
#define MEDIASESSIONREPOSITORY_H

#include <QObject>
#include <QString>
#include <QVariantList>

class MediaSessionRepository : public QObject {
  Q_OBJECT

 public:
  explicit MediaSessionRepository(QObject* parent = nullptr);

  Q_INVOKABLE bool addMediaSession(const QString& appIdentifier,
                                   const QString& mediaType,
                                   const QString& mediaTitle,
                                   qint64 startUnixSec,
                                   qint64 endUnixSec,
                                   int playbackSec);

  Q_INVOKABLE QVariantList getSessionsByRange(qint64 startUnixSec,
                                              qint64 endUnixSec);

  QVariantList getIntervalsByRange(qint64 startUnixSec, qint64 endUnixSec);

  int getTotalPlaybackSecondsByRange(qint64 startUnixSec, qint64 endUnixSec);

  Q_INVOKABLE QVariantList getTodayMediaRanking();
};

#endif
