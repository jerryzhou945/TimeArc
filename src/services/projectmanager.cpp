#include "projectmanager.h"

#include <QVariantMap>

ProjectManager::ProjectManager(QObject* parent) : QObject(parent) {
  loadProjects();
}

QVariantList ProjectManager::projects() const { return m_projects; }

QVariantList ProjectManager::projectsModel() const { return m_projects; }

int ProjectManager::tagMinutes(const QString& tagName) const {
  int total = 0;

  for (const QVariant& item : m_projects) {
    QVariantMap project = item.toMap();
    if (project.value("tag").toString() == tagName) {
      int seconds = project.value("seconds", 0).toInt();
      total += seconds / 60;
    }
  }

  return total;
}

int ProjectManager::studyMinutes() const { return tagMinutes("学习"); }

int ProjectManager::sportMinutes() const { return tagMinutes("运动"); }

int ProjectManager::gameMinutes() const { return tagMinutes("游戏"); }

int ProjectManager::totalProjectMinutes() const {
  return studyMinutes() + sportMinutes() + gameMinutes();
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
  int index = findProjectIndex(projectName);
  if (index < 0) return;

  QVariantMap project = m_projects[index].toMap();
  int oldSeconds = project.value("seconds", 0).toInt();
  int newSeconds = oldSeconds + elapsedSeconds;

  project["seconds"] = newSeconds;

  int totalMinutes = newSeconds / 60;
  int h = totalMinutes / 60;
  int m = totalMinutes % 60;
  project["time"] = QString::number(h) + "h " + QString::number(m) + "m";

  m_projects[index] = project;

  saveProjects();
  emit projectsChanged();
}

void ProjectManager::loadProjects() {
  QSettings settings("TimeArc", "DesktopHomePageData");
  m_projects = settings.value("projects").toList();
}

void ProjectManager::saveProjects() {
  QSettings settings("TimeArc", "DesktopHomePageData");
  settings.setValue("projects", m_projects);
}

int ProjectManager::findProjectIndex(const QString& projectName) const {
  for (int i = 0; i < m_projects.size(); ++i) {
    QVariantMap project = m_projects[i].toMap();
    if (project.value("name").toString() == projectName) return i;
  }
  return -1;
}
