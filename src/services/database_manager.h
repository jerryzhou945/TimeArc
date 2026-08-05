#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QVariantMap>

class DatabaseManager : public QObject {
  Q_OBJECT

 public:
  explicit DatabaseManager(QObject* parent = nullptr);

  bool initialize();
  // GUI-owned SQLite connection (`timearc.db`). Service history uses the
  // separate read-only `timearc_service` connection.
  QSqlDatabase database() const;
  QSqlDatabase serviceDatabase() const;
  // GUI database path (`timearc.db`).
  Q_INVOKABLE QString getDatabasePath() const;
  // Service history database path (`timearc_service.db`), resolved from
  // service_config.json database.dir (legacy usage_config.json db_dir as a
  // fallback) or the platform service-data default.
  Q_INVOKABLE QString getServiceDatabasePath() const;

  // GUI DB backup via VACUUM INTO. destPath empty -> auto target in the
  // Download->Documents->AppData cascade, named timearc-backup-<ts>.db. Read-only
  // on the live GUI DB; returns the written path or an empty string on failure.
  Q_INVOKABLE QString backupDatabase(const QString& destPath = QString());

  // Read-only validation of a candidate GUI DB backup. Never mutates the
  // candidate. Keys include ok, integrity, sizeBytes, error.
  Q_INVOKABLE QVariantMap inspectBackup(const QString& path) const;

  // Replace the GUI DB with a validated GUI backup and reopen the GUI
  // connection. The service DB is never modified here.
  Q_INVOKABLE bool restoreDatabase(const QString& sourcePath);

  // Update the service DB directory pointer only. The GUI never moves or writes
  // `timearc_service.db`; the service creates/writes it on its next startup.
  // Returns {ok, error, newPath}.
  Q_INVOKABLE QVariantMap relocateDatabaseTo(const QString& targetDirOrUrl);

  // Clear database.dir so the service DB falls back to the platform default.
  Q_INVOKABLE QVariantMap restoreDefaultDatabaseLocation();

  // Write the background collector's idle timeout (**seconds** -- v1 changed
  // the unit) + tracking on/off into service_config.json so the service applies
  // them at startup. Same atomic RMW + key-preservation as the database.dir
  // writer (they share one helper), so neither clobbers the other's keys.
  // idleSec < 0 omits the key (service keeps its compile-time default); 0 is a
  // real value meaning "never idle". Restart the collector (SettingsRepository)
  // for immediate effect. Returns false on a write failure.
  Q_INVOKABLE bool writeServiceConfig(int idleSec, bool trackEnabled);

  // Service history DB directory shown in the settings UI.
  Q_INVOKABLE QString currentDatabaseLocationDir() const;
  // True when a service database.dir redirect is active.
  Q_INVOKABLE bool isUsingCustomDatabaseLocation() const;

 signals:
  void databaseRestored();

 private:
  QString guiDatabasePath() const;
  QString defaultGuiDatabasePath() const;
  QString serviceDatabasePath() const;
  QString defaultServiceDatabasePath() const;
  // Atomic read-modify-write of service_config.json database.dir (empty clears
  // the leaf). Preserves every other key (tracking.* shares this file).
  bool writeDbDirPointer(const QString& dbDirOrEmpty);
  bool openGuiDatabase();
  bool openServiceDatabaseReadOnly();
  bool configureGuiDatabase();
  bool createTables();
  bool insertDefaultTags();
  bool insertDefaultSettings();
  bool createIndexes();
  bool executeQuery(const QString& sql);
};

#endif
