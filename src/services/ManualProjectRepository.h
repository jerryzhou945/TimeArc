#ifndef MANUALPROJECTREPOSITORY_H
#define MANUALPROJECTREPOSITORY_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class ManualProjectRepository : public QObject {
  Q_OBJECT

 public:
  explicit ManualProjectRepository(QObject* parent = nullptr);

  Q_INVOKABLE bool createProject(const QString& name,
                                 const QString& description = QString(),
                                 int tagId = -1,
                                 const QString& color = QString());

  Q_INVOKABLE int ensureProject(const QString& name,
                                const QString& tagName,
                                const QString& color = QString());

  Q_INVOKABLE QVariantList getActiveProjects();

  Q_INVOKABLE QVariantMap getProjectById(int projectId);

  Q_INVOKABLE QVariantMap getActiveProjectByName(const QString& name);

  Q_INVOKABLE bool archiveProject(int projectId);

  Q_INVOKABLE bool addManualSession(int projectId,
                                    qint64 startUnixSec,
                                    qint64 endUnixSec,
                                    int durationSec,
                                    const QString& note = QString());

  Q_INVOKABLE bool addManualSessionEntry(
      int projectId,
      qint64 startUnixSec,
      qint64 endUnixSec,
      int durationSec,
      const QString& displayName,
      const QString& source = QString(),
      const QString& linkedProjectName = QString());

  Q_INVOKABLE QVariantList getSessionsByProject(int projectId);

  Q_INVOKABLE QVariantList getSessionsByRange(qint64 startUnixSec,
                                              qint64 endUnixSec);

  Q_INVOKABLE QVariantList getProjectRankingByRange(qint64 startUnixSec,
                                                    qint64 endUnixSec);

  int getTotalManualSecondsByRange(qint64 startUnixSec, qint64 endUnixSec);

  Q_INVOKABLE QVariantList getTodayProjectRanking();
};

#endif
