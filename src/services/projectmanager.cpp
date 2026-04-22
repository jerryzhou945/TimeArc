#include "projectmanager.h"

#include <QMap>
#include <QStringList>
#include <QVariantMap>
#include <algorithm>

namespace {
// 固定标签顺序和 QML 中的标签筛选保持一致。当前文件里的中文显示受历史编码
// 影响看起来像乱码，但值需要保持不变以兼容已有 QSettings 数据。
const QStringList kFixedTags = {"学习", "工作", "运动", "娱乐",
                                "阅读", "社交", "生活", "其他"};
}  // namespace

ProjectManager::ProjectManager(QObject* parent) : QObject(parent) {
  loadProjects();
  loadSessions();
}

QVariantList ProjectManager::projects() const { return m_projects; }

QVariantList ProjectManager::projectsModel() const { return m_projects; }

int ProjectManager::tagMinutes(const QString& tagName) const {
  return tagMinutesForRange(tagName, "all");
}

int ProjectManager::studyMinutes() const { return tagMinutes("学习"); }

int ProjectManager::sportMinutes() const { return tagMinutes("运动"); }

int ProjectManager::gameMinutes() const { return tagMinutes("游戏"); }

int ProjectManager::totalProjectMinutes() const { return allProjectMinutes(); }

int ProjectManager::todayProjectMinutes() const {
  return totalMinutesForRange("day");
}

int ProjectManager::monthProjectMinutes() const {
  return totalMinutesForRange("month");
}

int ProjectManager::yearProjectMinutes() const {
  return totalMinutesForRange("year");
}

int ProjectManager::allProjectMinutes() const {
  return totalMinutesForRange("all");
}

void ProjectManager::addProject(const QString& name, const QString& tag) {
  if (name.trimmed().isEmpty()) return;
  QString normalizedTag = tag.trimmed().isEmpty() ? kFixedTags.last() : tag;
  if (findProjectIndex(name, normalizedTag) >= 0) return;

  QVariantMap project;
  project["name"] = name;
  project["tag"] = normalizedTag;
  project["seconds"] = 0;
  project["time"] = "0h 0m";

  m_projects.append(project);
  saveProjects();
  emit projectsChanged();
}

void ProjectManager::ensureProject(const QString& name, const QString& tag) {
  if (name.trimmed().isEmpty()) return;
  QString normalizedTag = tag.trimmed().isEmpty() ? kFixedTags.last() : tag;
  if (findProjectIndex(name, normalizedTag) >= 0) return;
  addProject(name, tag);
}

void ProjectManager::addElapsedTime(const QString& projectName,
                                    int elapsedSeconds) {
  // 旧入口只按项目名找项目，适合首页手动计时。带 tag 的入口用于日历/分类页。
  if (elapsedSeconds <= 0) return;

  int index = findProjectIndex(projectName);
  if (index < 0) return;

  QVariantMap project = m_projects[index].toMap();

  QString tag = project.value("tag").toString();
  int oldSeconds = project.value("seconds", 0).toInt();
  int newSeconds = oldSeconds + elapsedSeconds;

  project["seconds"] = newSeconds;
  project["time"] = secondsToTimeText(newSeconds);
  m_projects[index] = project;

  appendSession(projectName, tag, elapsedSeconds, QDate::currentDate(),
                "manual_project", projectName);

  saveProjects();
  saveSessions();
  emit projectsChanged();
}

void ProjectManager::addElapsedTimeForTag(const QString& projectName,
                                          const QString& tag,
                                          int elapsedSeconds) {
  addElapsedTimeForTagOnDate(projectName, tag, elapsedSeconds,
                             QDate::currentDate().toString("yyyy-MM-dd"));
}

void ProjectManager::addElapsedTimeForTagOnDate(const QString& projectName,
                                                const QString& tag,
                                                int elapsedSeconds,
                                                const QString& dateText) {
  if (elapsedSeconds <= 0) return;

  QString normalizedTag = tag.trimmed().isEmpty() ? kFixedTags.last() : tag;
  if (findProjectIndex(projectName, normalizedTag) < 0)
    addProject(projectName, normalizedTag);

  int index = findProjectIndex(projectName, normalizedTag);
  if (index < 0) return;

  QVariantMap project = m_projects[index].toMap();
  int oldSeconds = project.value("seconds", 0).toInt();
  int newSeconds = oldSeconds + elapsedSeconds;

  project["seconds"] = newSeconds;
  project["time"] = secondsToTimeText(newSeconds);
  m_projects[index] = project;

  QDate sessionDate = QDate::fromString(dateText, "yyyy-MM-dd");
  if (!sessionDate.isValid()) sessionDate = QDate::currentDate();

  appendSession(projectName, normalizedTag, elapsedSeconds, sessionDate,
                "manual_project", projectName);

  saveProjects();
  saveSessions();
  emit projectsChanged();
}

void ProjectManager::addTodoElapsedTimeOnDate(const QString& todoText,
                                              const QString& tag,
                                              const QString& linkedProjectName,
                                              int elapsedSeconds,
                                              const QString& dateText) {
  // 日历待办可以只作为一条时间明细存在，也可以绑定到项目。绑定项目时，
  // 项目累计时长和明细流水都会增加。
  if (elapsedSeconds <= 0) return;

  const QString trimmedLinkedProject = linkedProjectName.trimmed();
  if (trimmedLinkedProject.isEmpty()) {
    recordTimeEntryOnDate(todoText, tag, elapsedSeconds, dateText,
                          "calendar_todo", "");
    return;
  }

  QString normalizedTag = tag.trimmed().isEmpty() ? kFixedTags.last() : tag;
  if (findProjectIndex(trimmedLinkedProject, normalizedTag) < 0)
    addProject(trimmedLinkedProject, normalizedTag);

  int index = findProjectIndex(trimmedLinkedProject, normalizedTag);
  if (index < 0) return;

  QVariantMap project = m_projects[index].toMap();
  int oldSeconds = project.value("seconds", 0).toInt();
  int newSeconds = oldSeconds + elapsedSeconds;

  project["seconds"] = newSeconds;
  project["time"] = secondsToTimeText(newSeconds);
  m_projects[index] = project;

  QDate sessionDate = QDate::fromString(dateText, "yyyy-MM-dd");
  if (!sessionDate.isValid()) sessionDate = QDate::currentDate();

  appendSession(todoText, normalizedTag, elapsedSeconds, sessionDate,
                "calendar_todo", trimmedLinkedProject);

  saveProjects();
  saveSessions();
  emit projectsChanged();
}

void ProjectManager::recordTimeEntryOnDate(const QString& title,
                                           const QString& tag,
                                           int elapsedSeconds,
                                           const QString& dateText,
                                           const QString& source,
                                           const QString& linkedProjectName) {
  if (title.trimmed().isEmpty() || elapsedSeconds <= 0) return;

  QString normalizedTag = tag.trimmed().isEmpty() ? kFixedTags.last() : tag;
  QDate sessionDate = QDate::fromString(dateText, "yyyy-MM-dd");
  if (!sessionDate.isValid()) sessionDate = QDate::currentDate();

  appendSession(title, normalizedTag, elapsedSeconds, sessionDate, source,
                linkedProjectName.trimmed());

  saveSessions();
  emit projectsChanged();
}

void ProjectManager::removeProject(const QString& projectName) {
  // 删除项目时，普通手动项目流水一起删除；日历待办如果曾绑定该项目，则解绑
  // 回到独立待办明细，避免用户的日历记录被误删。
  int index = findProjectIndex(projectName);
  if (index >= 0) {
    m_projects.removeAt(index);
  }

  for (int i = m_sessions.size() - 1; i >= 0; --i) {
    QVariantMap session = m_sessions[i].toMap();
    if (session.value("projectName").toString() == projectName) {
      if (session.value("source").toString() == "calendar_todo") {
        session["projectName"] =
            session.value("displayName", projectName).toString();
        session["linkedProjectName"] = "";
        session["linkedProject"] = false;
        m_sessions[i] = session;
      } else {
        m_sessions.removeAt(i);
      }
    }
  }

  saveProjects();
  saveSessions();
  emit projectsChanged();
}

void ProjectManager::loadProjects() {
  QSettings settings("TimeArc", "ProjectManagerData");
  m_projects = settings.value("projects").toList();
}

void ProjectManager::saveProjects() {
  QSettings settings("TimeArc", "ProjectManagerData");
  settings.setValue("projects", m_projects);
}

void ProjectManager::loadSessions() {
  QSettings settings("TimeArc", "ProjectManagerData");
  m_sessions = settings.value("sessions").toList();
}

void ProjectManager::saveSessions() {
  QSettings settings("TimeArc", "ProjectManagerData");
  settings.setValue("sessions", m_sessions);
}

void ProjectManager::appendSession(const QString& title, const QString& tag,
                                   int elapsedSeconds, const QDate& sessionDate,
                                   const QString& source,
                                   const QString& linkedProjectName) {
  // session
  // 是事实流水：视图层按日期/标签/来源重新聚合，项目主表只保存快速显示值。
  const QString trimmedTitle = title.trimmed();
  const QString trimmedLinkedProject = linkedProjectName.trimmed();

  QVariantMap session;
  session["projectName"] =
      trimmedLinkedProject.isEmpty() ? trimmedTitle : trimmedLinkedProject;
  session["displayName"] = trimmedTitle;
  session["tag"] = tag;
  session["seconds"] = elapsedSeconds;
  session["date"] = sessionDate.toString("yyyy-MM-dd");
  session["year"] = sessionDate.year();
  session["month"] = sessionDate.month();
  session["day"] = sessionDate.day();
  session["source"] = source.trimmed().isEmpty() ? "manual_project" : source;
  session["linkedProjectName"] = trimmedLinkedProject;
  session["linkedProject"] = !trimmedLinkedProject.isEmpty();

  m_sessions.append(session);
}

int ProjectManager::findProjectIndex(const QString& projectName) const {
  for (int i = 0; i < m_projects.size(); ++i) {
    QVariantMap project = m_projects[i].toMap();
    if (project.value("name").toString() == projectName) return i;
  }
  return -1;
}

int ProjectManager::findProjectIndex(const QString& projectName,
                                     const QString& tag) const {
  for (int i = 0; i < m_projects.size(); ++i) {
    QVariantMap project = m_projects[i].toMap();
    if (project.value("name").toString() == projectName &&
        project.value("tag").toString() == tag) {
      return i;
    }
  }
  return -1;
}

bool ProjectManager::sessionMatchesRange(const QVariantMap& session,
                                         const QString& range) const {
  if (range == "all") return true;

  QDate today = QDate::currentDate();

  int year = session.value("year").toInt();
  int month = session.value("month").toInt();
  int day = session.value("day").toInt();

  if (range == "day") {
    return year == today.year() && month == today.month() && day == today.day();
  }

  if (range == "month") {
    return year == today.year() && month == today.month();
  }

  if (range == "year") {
    return year == today.year();
  }

  return false;
}

bool ProjectManager::sessionMatchesDate(const QVariantMap& session,
                                        const QDate& date) const {
  return session.value("year").toInt() == date.year() &&
         session.value("month").toInt() == date.month() &&
         session.value("day").toInt() == date.day();
}

bool ProjectManager::sessionCountsForProject(const QVariantMap& session) const {
  // 日历待办默认不计入项目列表，除非它明确绑定到了某个项目。
  const QString source = session.value("source").toString();
  if (source.isEmpty() || source == "manual_project") return true;
  return session.value("linkedProject", false).toBool() ||
         !session.value("linkedProjectName").toString().trimmed().isEmpty();
}

int ProjectManager::tagMinutesForRange(const QString& tagName,
                                       const QString& range) const {
  int totalSeconds = 0;

  for (const QVariant& item : m_sessions) {
    QVariantMap session = item.toMap();
    if (session.value("tag").toString() == tagName &&
        sessionMatchesRange(session, range)) {
      totalSeconds += session.value("seconds", 0).toInt();
    }
  }

  return totalSeconds / 60;
}

int ProjectManager::totalMinutesForRange(const QString& range) const {
  int totalSeconds = 0;

  for (const QVariant& item : m_sessions) {
    QVariantMap session = item.toMap();
    if (sessionMatchesRange(session, range)) {
      totalSeconds += session.value("seconds", 0).toInt();
    }
  }

  return totalSeconds / 60;
}

QString ProjectManager::secondsToTimeText(int totalSeconds) const {
  int totalMinutes = totalSeconds / 60;
  int h = totalMinutes / 60;
  int m = totalMinutes % 60;
  return QString::number(h) + "h " + QString::number(m) + "m";
}

QVariantList ProjectManager::projectsForRange(const QString& range) const {
  QVariantList result;

  for (const QVariant& item : m_projects) {
    QVariantMap project = item.toMap();

    QString name = project.value("name").toString();
    QString tag = project.value("tag").toString();

    int totalSeconds = 0;
    for (const QVariant& s : m_sessions) {
      QVariantMap session = s.toMap();
      if (session.value("projectName").toString() == name &&
          session.value("tag").toString() == tag &&
          sessionCountsForProject(session) &&
          sessionMatchesRange(session, range)) {
        totalSeconds += session.value("seconds", 0).toInt();
      }
    }

    QVariantMap newProject;
    newProject["name"] = name;
    newProject["tag"] = tag;
    newProject["seconds"] = totalSeconds;
    newProject["time"] = secondsToTimeText(totalSeconds);

    result.append(newProject);
  }

  return result;
}

QVariantList ProjectManager::projectsForDate(const QString& dateText) const {
  QVariantList result;
  const QDate targetDate = QDate::fromString(dateText, "yyyy-MM-dd");
  if (!targetDate.isValid()) return result;

  for (const QVariant& item : m_projects) {
    QVariantMap project = item.toMap();

    QString name = project.value("name").toString();
    QString tag = project.value("tag").toString();

    int totalSeconds = 0;
    for (const QVariant& s : m_sessions) {
      QVariantMap session = s.toMap();
      if (session.value("projectName").toString() != name) continue;
      if (session.value("tag").toString() != tag) continue;
      if (!sessionCountsForProject(session)) continue;

      const int year = session.value("year").toInt();
      const int month = session.value("month").toInt();
      const int day = session.value("day").toInt();
      if (year == targetDate.year() && month == targetDate.month() &&
          day == targetDate.day()) {
        totalSeconds += session.value("seconds", 0).toInt();
      }
    }

    QVariantMap newProject;
    newProject["name"] = name;
    newProject["tag"] = tag;
    newProject["seconds"] = totalSeconds;
    newProject["time"] = secondsToTimeText(totalSeconds);

    result.append(newProject);
  }

  return result;
}

QVariantList ProjectManager::timeEntriesForDate(const QString& dateText) const {
  // 同一天同名/同标签/同来源/同绑定项目的流水合并显示，避免 UI 被很多碎片占满。
  QVariantList result;
  const QDate targetDate = QDate::fromString(dateText, "yyyy-MM-dd");
  if (!targetDate.isValid()) return result;

  QMap<QString, QVariantMap> grouped;

  for (const QVariant& item : m_sessions) {
    QVariantMap session = item.toMap();
    if (!sessionMatchesDate(session, targetDate)) continue;

    const QString name =
        session.value("displayName", session.value("projectName").toString())
            .toString();
    const QString tag = session.value("tag").toString();
    const QString source = session.value("source").toString();
    const QString linkedProjectName =
        session.value("linkedProjectName").toString();
    const QString key =
        name + "\x1F" + tag + "\x1F" + source + "\x1F" + linkedProjectName;

    QVariantMap entry = grouped.value(key);
    const int seconds =
        entry.value("seconds", 0).toInt() + session.value("seconds", 0).toInt();

    entry["name"] = name;
    entry["tag"] = tag;
    entry["source"] = source.isEmpty() ? "manual_project" : source;
    entry["linkedProjectName"] = linkedProjectName;
    entry["linkedProject"] = session.value("linkedProject", false).toBool() ||
                             !linkedProjectName.trimmed().isEmpty();
    entry["seconds"] = seconds;
    entry["minutes"] = seconds / 60;
    entry["time"] = secondsToTimeText(seconds);
    grouped[key] = entry;
  }

  for (const QVariantMap& entry : grouped) result.append(entry);

  std::sort(result.begin(), result.end(),
            [](const QVariant& left, const QVariant& right) {
              return left.toMap().value("seconds", 0).toInt() >
                     right.toMap().value("seconds", 0).toInt();
            });

  return result;
}

QVariantList ProjectManager::projectsForTag(const QString& tagName,
                                            const QString& range) const {
  QVariantList result;

  for (const QVariant& item : projectsForRange(range)) {
    QVariantMap project = item.toMap();
    if (project.value("tag").toString() == tagName) result.append(project);
  }

  return result;
}

QVariantList ProjectManager::tagSummariesForRange(const QString& range) const {
  QVariantList result;

  for (const QString& tag : kFixedTags) {
    int seconds = 0;
    int projectCount = 0;

    for (const QVariant& item : m_projects) {
      QVariantMap project = item.toMap();
      if (project.value("tag").toString() == tag) ++projectCount;
    }

    for (const QVariant& item : m_sessions) {
      QVariantMap session = item.toMap();
      if (session.value("tag").toString() == tag &&
          sessionMatchesRange(session, range)) {
        seconds += session.value("seconds", 0).toInt();
      }
    }

    QVariantMap summary;
    summary["tag"] = tag;
    summary["seconds"] = seconds;
    summary["minutes"] = seconds / 60;
    summary["time"] = secondsToTimeText(seconds);
    summary["projectCount"] = projectCount;
    result.append(summary);
  }

  return result;
}

int ProjectManager::tagMinutesFor(const QString& tagName,
                                  const QString& range) const {
  return tagMinutesForRange(tagName, range);
}
