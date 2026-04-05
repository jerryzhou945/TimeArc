#ifndef PROJECTMANAGER_H
#define PROJECTMANAGER_H

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

 public:
  explicit ProjectManager(QObject* parent = nullptr);

  QVariantList projects() const;
  QVariantList projectsModel() const;

  int studyMinutes() const;
  int sportMinutes() const;
  int gameMinutes() const;
  int totalProjectMinutes() const;

  Q_INVOKABLE void addProject(const QString& name, const QString& tag);
  Q_INVOKABLE void addElapsedTime(const QString& projectName,
                                  int elapsedSeconds);

 signals:
  void projectsChanged();

 private:
  QVariantList m_projects;

  void loadProjects();
  void saveProjects();
  int findProjectIndex(const QString& projectName) const;
  int tagMinutes(const QString& tagName) const;
};

#endif
