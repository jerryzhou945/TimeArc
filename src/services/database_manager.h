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
  QSqlDatabase database() const;
  Q_INVOKABLE QString getDatabasePath() const;

  // A1 S3: one-shot JSONL->SQLite backfill of the enable-before tail (records
  // older than the earliest row the service ever wrote to SQLite). Idempotent
  // via the settings flag usage_jsonl_backfill_v1_done. Writes a
  // usage_records.jsonl.bak first, imports inside a transaction with
  // INSERT OR IGNORE, then reconciles by unique-key existence (NOT row count)
  // before committing; on any missing record it rolls back, keeps JSONL intact
  // and leaves the flag unset so the next launch retries. Returns false only on
  // a real failure (reconcile mismatch / SQL error); true when done or skipped.
  bool backfillUsageFromJsonl();

  // D1 S1: whole-DB consistent backup via VACUUM INTO (not QFile::copy, which
  // would miss un-checkpointed -wal data). destPath empty -> auto target in the
  // Download->Documents->AppData cascade, named timearc-backup-<ts>.db. Read-only
  // on the live DB; returns the written path, or an empty string on any failure
  // (G6 honest failure).
  Q_INVOKABLE QString backupDatabase(const QString& destPath = QString());

  // D1 S2: read-only validation of a candidate backup .db. Opens it on a unique
  // throwaway read-only connection, runs PRAGMA integrity_check, asserts the
  // three contract tables exist, and reports row counts + start_unix_sec range.
  // Never mutates the candidate. Keys: ok, integrity, frontmostRows, mediaRows,
  // appRows, minUnixSec, maxUnixSec, sizeBytes, error.
  Q_INVOKABLE QVariantMap inspectBackup(const QString& path) const;

  // D1 S2: replace the live DB with a validated backup. inspectBackup must pass
  // first; backs up the current DB to <db>.pre-restore.bak, closes the UI
  // connection, swaps the file, clears stale -wal/-shm, reopens, and emits
  // databaseRestored(). On a locked/failed swap (e.g. the background collection
  // service still holds the file) it rolls back to the pre-restore copy and
  // returns false -- never a fake success (G6).
  Q_INVOKABLE bool restoreDatabase(const QString& sourcePath);

  // D2 S2: relocate the live DB to a user-chosen directory. Validates the
  // target (writable + free space), VACUUM INTOs a consistent snapshot at
  // <dir>/timearc.db, inspectBackup-validates it, then (only after the old DB is
  // confirmed unlocked) atomically switches the cross-process usage_config.json
  // db_path pointer, reopens, and drops the old DB. Any failure rolls back to
  // the old pointer + old DB -- never split-brain, never fake success (G6).
  // Returns {ok, error, newPath}. The user must stop background collection
  // first (B1 has no in-process stop); a locked old DB fails honestly. Restart
  // both processes after success so the service re-reads the pointer.
  Q_INVOKABLE QVariantMap relocateDatabaseTo(const QString& targetDirOrUrl);

  // D2 S2: move the DB back to the default AppData location and clear the
  // db_path pointer (so both processes fall back to the default). Same atomic
  // sequence + rollback as relocateDatabaseTo.
  Q_INVOKABLE QVariantMap restoreDefaultDatabaseLocation();

  // H5 S2: write the background collector's idle-timeout (ms) + tracking on/off
  // flag into usage_config.json so the service applies them at startup. Same
  // atomic RMW + key-preservation as the D2 db_path writer (they share one
  // helper), so neither clobbers the other's keys. idleMs <= 0 omits the key
  // (service keeps its compile-time default). Restart the collector
  // (SettingsRepository) for immediate effect. Returns false on a write failure.
  Q_INVOKABLE bool writeServiceConfig(int idleMs, bool trackEnabled);

  // D2: the directory the live DB currently resides in (for the settings UI).
  Q_INVOKABLE QString currentDatabaseLocationDir() const;
  // D2: true when a db_path redirect is active (DB is not at the default path).
  Q_INVOKABLE bool isUsingCustomDatabaseLocation() const;

 signals:
  void databaseRestored();

 private:
  bool setBackfillDone();  // mark usage_jsonl_backfill_v1_done = true (S3)
  QString databasePath() const;
  QString defaultDatabasePath() const;  // D2: AppData default, ignoring db_path
  // D2: atomic read-modify-write of usage_config.json db_path (empty clears the
  // key). Preserves every other key (H5 idle/track share this file).
  bool writeDbPathPointer(const QString& dbPathOrEmpty);
  // D2: shared body of relocateDatabaseTo / restoreDefaultDatabaseLocation.
  QVariantMap relocateDatabaseImpl(const QString& targetDirOrUrl,
                                   bool clearPointer);
  bool openDatabase();
  bool configureDatabase();
  bool createTables();
  bool insertDefaultTags();
  bool insertDefaultSettings();
  bool createIndexes();
  bool executeQuery(const QString& sql);
};

#endif
