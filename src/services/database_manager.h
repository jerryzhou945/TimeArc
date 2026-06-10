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

  // A1 S3: one-shot JSONL->SQLite backfill of the enable-before tail (records
  // older than the earliest row the service ever wrote to SQLite). Idempotent
  // via the settings flag usage_jsonl_backfill_v1_done. Writes a
  // usage_records.jsonl.bak first, imports inside a transaction with
  // INSERT OR IGNORE, then reconciles by unique-key existence (NOT row count)
  // before committing; on any missing record it rolls back, keeps JSONL intact
  // and leaves the flag unset so the next launch retries. Returns false only on
  // a real failure (reconcile mismatch / SQL error); true when done or skipped.
  bool backfillUsageFromJsonl();

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
