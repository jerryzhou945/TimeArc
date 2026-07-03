#ifndef MOBILEUSAGEREPOSITORY_H
#define MOBILEUSAGEREPOSITORY_H

#include <QObject>
#include <QString>
#include <QVariantList>

class MobileUsageRepository : public QObject {
  Q_OBJECT

 public:
  explicit MobileUsageRepository(QObject* parent = nullptr);

  static QString androidAppIdentifierForPackage(const QString& packageName);
  static QString androidPackageForIdentifier(const QString& appIdentifier);

  Q_INVOKABLE bool upsertDailyUsageSummary(
      const QString& deviceId,
      const QString& packageName,
      const QString& appName,
      const QString& displayName,
      const QString& dateLocal,
      qint64 rangeStartUnixSec,
      qint64 rangeEndUnixSec,
      int foregroundSec,
      const QString& source,
      const QString& appIconPath = QString());

  Q_INVOKABLE QVariantList getUsageByDateRange(const QString& startDateLocal,
                                               const QString& endDateLocal,
                                               const QString& platform);

  Q_INVOKABLE int getTotalForegroundSecondsByDateRange(
      const QString& startDateLocal,
      const QString& endDateLocal,
      const QString& platform);

  Q_INVOKABLE bool addUsageSession(const QString& deviceId,
                                   const QString& packageName,
                                   const QString& appName,
                                   const QString& displayName,
                                   qint64 sessionStartUnixSec,
                                   qint64 sessionEndUnixSec,
                                   const QString& source,
                                   const QString& confidence = QString(),
                                   const QString& appIconPath = QString());

  Q_INVOKABLE QVariantList getSessionsByRange(qint64 startUnixSec,
                                              qint64 endUnixSec,
                                              const QString& platform);
};

#endif
