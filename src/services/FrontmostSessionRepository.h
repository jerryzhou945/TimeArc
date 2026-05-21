#ifndef FRONTMOSTSESSIONREPOSITORY_H
#define FRONTMOSTSESSIONREPOSITORY_H

#include <QObject>
#include <QString>
#include <QVariantList>

class FrontmostSessionRepository : public QObject {
  Q_OBJECT

 public:
  explicit FrontmostSessionRepository(QObject* parent = nullptr);

  Q_INVOKABLE bool addFrontmostSession(const QString& appIdentifier,
                                       const QString& windowTitle,
                                       qint64 startUnixSec,
                                       qint64 endUnixSec,
                                       int durationSec,
                                       int activeSec,
                                       int idleSec);

  Q_INVOKABLE QVariantList getSessionsByRange(qint64 startUnixSec,
                                              qint64 endUnixSec);

  QVariantList getIntervalsByRange(qint64 startUnixSec, qint64 endUnixSec);

  int getTotalActiveSecondsByRange(qint64 startUnixSec, qint64 endUnixSec);

  Q_INVOKABLE QVariantList getTodayFrontmostRanking();
};

#endif
