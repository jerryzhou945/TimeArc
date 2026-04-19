#ifndef USAGESTATMANAGER_H
#define USAGESTATMANAGER_H

#include <QList>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class QJsonObject;

class UsageStatManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString usageRecordsPath READ usageRecordsPath CONSTANT)
  Q_PROPERTY(int todaySoftwareMinutes READ todaySoftwareMinutes NOTIFY usageStatsChanged)
  Q_PROPERTY(int monthSoftwareMinutes READ monthSoftwareMinutes NOTIFY usageStatsChanged)
  Q_PROPERTY(int yearSoftwareMinutes READ yearSoftwareMinutes NOTIFY usageStatsChanged)
  Q_PROPERTY(int allSoftwareMinutes READ allSoftwareMinutes NOTIFY usageStatsChanged)

 public:
  explicit UsageStatManager(QObject* parent = nullptr);

  QString usageRecordsPath() const;
  int todaySoftwareMinutes() const;
  int monthSoftwareMinutes() const;
  int yearSoftwareMinutes() const;
  int allSoftwareMinutes() const;

  Q_INVOKABLE void refresh();
  Q_INVOKABLE QVariantList softwareForRange(const QString& range) const;
  Q_INVOKABLE QVariantList activeSoftwareForRange(const QString& range) const;
  Q_INVOKABLE QVariantList foregroundSoftwareForRange(const QString& range) const;
  Q_INVOKABLE QVariantList audioForRange(const QString& range) const;
  Q_INVOKABLE int softwareSecondsForRange(const QString& range) const;
  Q_INVOKABLE int activeSoftwareSecondsForRange(const QString& range) const;
  Q_INVOKABLE int foregroundSoftwareSecondsForRange(const QString& range) const;
  Q_INVOKABLE int audioSecondsForRange(const QString& range) const;
  Q_INVOKABLE QVariantMap currentSoftware() const;

signals:
  void usageStatsChanged();

 private:
  struct UsageRecord {
    QString appId;
    QString source;
    QString appName;
    QString windowTitle;
    QString path;
    qint64 startUnixSec = 0;
    quint64 durationSec = 0;
    qint64 updatedUnixSec = 0;
    bool live = false;
  };

  QList<UsageRecord> m_records;
  UsageRecord m_currentRecord;
  bool m_hasCurrentRecord = false;

  QString recordsFilePath() const;
  QString currentFilePath() const;
  UsageRecord parseRecordObject(const QJsonObject& object, bool live) const;
  QVariantMap recordToVariantMap(const UsageRecord& record) const;
  QVariantList aggregateSoftwareForRange(const QString& range,
                                         const QString& sourceFilter) const;
  int aggregateSoftwareSecondsForRange(const QString& range,
                                       const QString& sourceFilter) const;
  bool matchesRange(const UsageRecord& record, const QString& range) const;
  bool matchesSource(const UsageRecord& record,
                     const QString& sourceFilter) const;
  QString secondsToTimeText(quint64 totalSeconds) const;
};

#endif
