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

 signals:
  void databaseRestored();

 private:
  bool setBackfillDone();  // mark usage_jsonl_backfill_v1_done = true (S3)
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
