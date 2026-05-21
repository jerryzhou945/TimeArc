#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QObject>
#include <QSqlDatabase>
#include <QString>

class DatabaseManager : public QObject {
  Q_OBJECT

 public:
  explicit DatabaseManager(QObject* parent = nullptr);

  bool initialize();
  QSqlDatabase database() const;
  Q_INVOKABLE QString getDatabasePath() const;

 private:
  QString databasePath() const;
  bool openDatabase();
  bool configureDatabase();
  bool createTables();
  bool insertDefaultTags();
  bool insertDefaultSettings();
  bool createIndexes();
  bool executeQuery(const QString& sql);
};

#endif
