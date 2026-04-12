#include "projectmanager.h"

#include <QVariantMap>

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

  QVariantMap project;
  project["name"] = name;
  project["tag"] = tag;
  project["seconds"] = 0;
  project["time"] = "0h 0m";

  m_projects.append(project);
  saveProjects();
  emit projectsChanged();
}

void ProjectManager::addElapsedTime(const QString& projectName,
                                    int elapsedSeconds) {
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

  QDate today = QDate::currentDate();

  QVariantMap session;
  session["projectName"] = projectName;
  session["tag"] = tag;
  session["seconds"] = elapsedSeconds;
  session["date"] = today.toString("yyyy-MM-dd");
  session["year"] = today.year();
  session["month"] = today.month();
  session["day"] = today.day();

  m_sessions.append(session);

  saveProjects();
  saveSessions();
  emit projectsChanged();
}

void ProjectManager::removeProject(const QString& projectName) {
  int index = findProjectIndex(projectName);
  if (index >= 0) {
    m_projects.removeAt(index);
  }

  for (int i = m_sessions.size() - 1; i >= 0; --i) {
    QVariantMap session = m_sessions[i].toMap();
    if (session.value("projectName").toString() == projectName) {
      m_sessions.removeAt(i);
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

int ProjectManager::findProjectIndex(const QString& projectName) const {
  for (int i = 0; i < m_projects.size(); ++i) {
    QVariantMap project = m_projects[i].toMap();
    if (project.value("name").toString() == projectName) return i;
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

int ProjectManager::tagMinutesFor(const QString& tagName,
                                  const QString& range) const {
  return tagMinutesForRange(tagName, range);
}
