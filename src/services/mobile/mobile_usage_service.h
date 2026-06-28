#ifndef MOBILEUSAGESERVICE_H
#define MOBILEUSAGESERVICE_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class MobileUsageRepository;

class MobileUsageService : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool usageAccessGranted READ usageAccessGranted NOTIFY statusChanged)
  Q_PROPERTY(QString syncStatus READ syncStatus NOTIFY statusChanged)
  Q_PROPERTY(QString syncStatusText READ syncStatusText NOTIFY statusChanged)

 public:
  explicit MobileUsageService(MobileUsageRepository* repository,
                              QObject* parent = nullptr);

  bool usageAccessGranted() const;
  QString syncStatus() const;
  QString syncStatusText() const;

  Q_INVOKABLE QVariantMap getUsageDashboard(const QString& startDateLocal,
                                            const QString& endDateLocal);
  Q_INVOKABLE QVariantMap getDashboardForRange(const QString& range);
  Q_INVOKABLE bool refreshUsageAccessState();
  Q_INVOKABLE bool openUsageAccessSettings();
  Q_INVOKABLE bool requestImmediateSync();

 signals:
  void statusChanged();
  void dataChanged();

 private:
  static QString formatDuration(int seconds);
  static QString initialForName(const QString& displayName);
  static QString startDateForRange(const QString& range,
                                   const QDate& today);
  void setStatus(bool accessGranted,
                 const QString& status,
                 const QString& text);

  MobileUsageRepository* repository_ = nullptr;
  bool usageAccessGranted_ = false;
  QString syncStatus_ = QStringLiteral("idle");
  QString syncStatusText_ = QStringLiteral("Ready");
};

#endif
