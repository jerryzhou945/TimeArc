#ifndef PROJECTMANAGER_H
#define PROJECTMANAGER_H

#include <QDate>
#include <QObject>
#include <QSettings>
#include <QVariantList>

class ProjectManager : public QObject {
  Q_OBJECT

  Q_PROPERTY(QVariantList projects READ projects NOTIFY projectsChanged)
  Q_PROPERTY(
      QVariantList projectsModel READ projectsModel NOTIFY projectsChanged)

  Q_PROPERTY(int studyMinutes READ studyMinutes NOTIFY projectsChanged)
  Q_PROPERTY(int sportMinutes READ sportMinutes NOTIFY projectsChanged)
  Q_PROPERTY(int gameMinutes READ gameMinutes NOTIFY projectsChanged)
  Q_PROPERTY(
      int totalProjectMinutes READ totalProjectMinutes NOTIFY projectsChanged)

  Q_PROPERTY(
      int todayProjectMinutes READ todayProjectMinutes NOTIFY projectsChanged)
  Q_PROPERTY(
      int monthProjectMinutes READ monthProjectMinutes NOTIFY projectsChanged)
  Q_PROPERTY(
      int yearProjectMinutes READ yearProjectMinutes NOTIFY projectsChanged)
  Q_PROPERTY(
      int allProjectMinutes READ allProjectMinutes NOTIFY projectsChanged)

 public:
  explicit ProjectManager(QObject* parent = nullptr);

  QVariantList projects() const;
  QVariantList projectsModel() const;

  int studyMinutes() const;
  int sportMinutes() const;
  int gameMinutes() const;
  int totalProjectMinutes() const;

  int todayProjectMinutes() const;
  int monthProjectMinutes() const;
  int yearProjectMinutes() const;
  int allProjectMinutes() const;

  Q_INVOKABLE void addProject(const QString& name, const QString& tag);
  Q_INVOKABLE void ensureProject(const QString& name, const QString& tag);
  Q_INVOKABLE void addElapsedTime(const QString& projectName,
                                  int elapsedSeconds);
  Q_INVOKABLE void addElapsedTimeForTag(const QString& projectName,
                                        const QString& tag, int elapsedSeconds);
  Q_INVOKABLE void addElapsedTimeForTagOnDate(const QString& projectName,
                                              const QString& tag,
                                              int elapsedSeconds,
                                              const QString& dateText);
  Q_INVOKABLE void addTodoElapsedTimeOnDate(const QString& todoText,
                                            const QString& tag,
                                            const QString& linkedProjectName,
                                            int elapsedSeconds,
                                            const QString& dateText);
  Q_INVOKABLE void recordTimeEntryOnDate(const QString& title,
                                         const QString& tag,
                                         int elapsedSeconds,
                                         const QString& dateText,
                                         const QString& source,
                                         const QString& linkedProjectName);
  Q_INVOKABLE void removeProject(const QString& projectName);

  Q_INVOKABLE QVariantList projectsForRange(const QString& range) const;
  Q_INVOKABLE QVariantList projectsForDate(const QString& dateText) const;
  Q_INVOKABLE QVariantList timeEntriesForDate(const QString& dateText) const;
  Q_INVOKABLE QVariantList projectsForTag(const QString& tagName,
                                          const QString& range) const;
  Q_INVOKABLE QVariantList tagSummariesForRange(const QString& range) const;
  Q_INVOKABLE int tagMinutesFor(const QString& tagName,
                                const QString& range) const;

 signals:
  void projectsChanged();

 private:
  QVariantList m_projects;
  QVariantList m_sessions;

  void loadProjects();
  void saveProjects();

  void loadSessions();
  void saveSessions();

  int findProjectIndex(const QString& projectName) const;
  int findProjectIndex(const QString& projectName, const QString& tag) const;
  int tagMinutes(const QString& tagName) const;

  int tagMinutesForRange(const QString& tagName, const QString& range) const;
  int totalMinutesForRange(const QString& range) const;
  bool sessionMatchesRange(const QVariantMap& session,
                           const QString& range) const;
  bool sessionMatchesDate(const QVariantMap& session,
                          const QDate& date) const;
  bool sessionCountsForProject(const QVariantMap& session) const;
  void appendSession(const QString& title, const QString& tag,
                     int elapsedSeconds, const QDate& sessionDate,
                     const QString& source,
                     const QString& linkedProjectName);

  QString secondsToTimeText(int totalSeconds) const;
};

#endif
