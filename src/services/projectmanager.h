#ifndef PROJECTMANAGER_H
#define PROJECTMANAGER_H

#include <QDate>
#include <QDateTime>
#include <QObject>
#include <QSettings>
#include <QVariantList>

class ManualProjectRepository;

// 手动项目和日历待办时间的聚合服务。
//
// m_projects 保存项目列表和累计显示字段；m_sessions 保存每次计时的明细。
// UI 的“今日/本月/全年/全部”视图都从 m_sessions 重新聚合，避免历史明细丢失。
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
  explicit ProjectManager(ManualProjectRepository* repository = nullptr,
                          QObject* parent = nullptr);

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
  // 给已存在项目追加“今天”的手动计时时长。
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
  // 写一条不一定绑定项目的时间明细，主要给日历待办和批量写入场景使用。
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
  QVariantList m_projects;  // 项目主表：name/tag/seconds/time。
  QVariantList m_sessions;  // 时间流水：date/source/displayName/seconds 等。
  ManualProjectRepository* m_repository;

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
  QVariantList sessionsForRange(const QString& range) const;
  qint64 rangeStartUnix(const QString& range) const;
  qint64 rangeEndUnix(const QString& range) const;
  QDateTime sessionEndForDate(const QDate& sessionDate,
                              int elapsedSeconds) const;

  QString secondsToTimeText(int totalSeconds) const;
};

#endif
