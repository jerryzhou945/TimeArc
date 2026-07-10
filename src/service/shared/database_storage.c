// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang
// Copyright (C) 2026 Jerry Zhou

#include "database_storage.h"

#include <stdio.h>
#include <string.h>
#include <time.h>

#include "database_path.h"
#include "sqlite3.h"
#include "util.h"

// One service process owns one writable connection. UI readers use their own
// read-only connections and never include this service-side module.
static sqlite3* g_db = NULL;
static int g_schema_ready = 0;

static int has_text(const char* value) {
  return value != NULL && value[0] != '\0';
}

static const char* text_or_empty(const char* value) {
  return value != NULL ? value : "";
}

static int64_t timestamp_or_now(int64_t value) {
  return value > 0 ? value : (int64_t)time(NULL);
}

static int require_text(const char* value, const char* field_name) {
  if (has_text(value)) {
    return 0;
  }

  fprintf(stderr, "TimeArc service database missing required field: %s\n",
          field_name);
  return -1;
}

static int is_valid_platform(const char* platform) {
  return strcmp(platform, "windows") == 0 || strcmp(platform, "macos") == 0 ||
         strcmp(platform, "linux") == 0;
}

static int is_valid_media_type(const char* media_type) {
  return strcmp(media_type, "audio") == 0 || strcmp(media_type, "video") == 0 ||
         strcmp(media_type, "unknown") == 0;
}

static int exec_on_db(const char* sql) {
  char* error = NULL;
  if (g_db == NULL || sql == NULL) {
    return -1;
  }

  if (sqlite3_exec(g_db, sql, NULL, NULL, &error) != SQLITE_OK) {
    fprintf(stderr, "TimeArc service database SQL failed: %s\nSQL: %s\n",
            error != NULL ? error : sqlite3_errmsg(g_db), sql);
    sqlite3_free(error);
    return -1;
  }

  return 0;
}

static const char* database_error(void) {
  return g_db != NULL ? sqlite3_errmsg(g_db) : "database is not open";
}

static int open_connection(void) {
  if (g_db != NULL) {
    return 0;
  }

  char db_path[TA_MAX_PATH_BYTES];
  if (get_database_path(db_path, sizeof(db_path)) != 0) {
    fprintf(stderr, "TimeArc service database path resolution failed.\n");
    return -1;
  }

  sqlite3* db = NULL;
  if (sqlite3_open(db_path, &db) != SQLITE_OK) {
    fprintf(stderr, "TimeArc service database open failed: %s (%s)\n", db_path,
            db != NULL ? sqlite3_errmsg(db) : "unknown");
    if (db != NULL) {
      sqlite3_close(db);
    }
    return -1;
  }

  g_db = db;
  sqlite3_busy_timeout(g_db, 5000);

  if (exec_on_db("PRAGMA foreign_keys = ON;") != 0 ||
      exec_on_db("PRAGMA journal_mode = WAL;") != 0) {
    database_storage_close();
    return -1;
  }

  return 0;
}

static int create_schema(void) {
  // All service-table DDL lives here so bridge code never manages SQLite.
  if (exec_on_db("CREATE TABLE IF NOT EXISTS apps ("
                 "app_id TEXT NOT NULL PRIMARY KEY,"
                 "platform TEXT NOT NULL CHECK(platform IN "
                 "('windows','macos','linux')),"
                 "display_name TEXT NOT NULL DEFAULT '',"
                 "icon_path TEXT NOT NULL DEFAULT '',"
                 "executable_path TEXT NOT NULL DEFAULT '',"
                 "created_at INTEGER NOT NULL,"
                 "updated_at INTEGER NOT NULL"
                 ");") != 0 ||
      exec_on_db("CREATE TABLE IF NOT EXISTS frontmost_sessions ("
                 "app_id TEXT NOT NULL,"
                 "window_title TEXT NOT NULL DEFAULT '',"
                 "start_unix_sec INTEGER NOT NULL,"
                 "end_unix_sec INTEGER NOT NULL,"
                 "duration_sec INTEGER GENERATED ALWAYS AS "
                 "(end_unix_sec - start_unix_sec) STORED,"
                 "active_sec INTEGER NOT NULL,"
                 "idle_sec INTEGER GENERATED ALWAYS AS "
                 "((end_unix_sec - start_unix_sec) - active_sec) STORED,"
                 "CHECK(start_unix_sec >= 0),"
                 "CHECK(end_unix_sec >= start_unix_sec),"
                 "CHECK(active_sec >= 0),"
                 "CHECK(active_sec <= end_unix_sec - start_unix_sec)"
                 ");") != 0 ||
      exec_on_db("CREATE TABLE IF NOT EXISTS media_sessions ("
                 "app_id TEXT NOT NULL,"
                 "media_type TEXT NOT NULL CHECK(media_type IN "
                 "('audio','video','unknown')),"
                 "media_title TEXT NOT NULL DEFAULT '',"
                 "start_unix_sec INTEGER NOT NULL,"
                 "end_unix_sec INTEGER NOT NULL,"
                 "duration_sec INTEGER GENERATED ALWAYS AS "
                 "(end_unix_sec - start_unix_sec) STORED,"
                 "CHECK(start_unix_sec >= 0),"
                 "CHECK(end_unix_sec >= start_unix_sec)"
                 ");") != 0 ||
      exec_on_db("CREATE INDEX IF NOT EXISTS idx_apps_platform "
                 "ON apps(platform);") != 0 ||
      exec_on_db("CREATE INDEX IF NOT EXISTS idx_frontmost_time "
                 "ON frontmost_sessions(start_unix_sec, end_unix_sec);") != 0 ||
      exec_on_db("CREATE INDEX IF NOT EXISTS idx_frontmost_app "
                 "ON frontmost_sessions(app_id);") != 0 ||
      exec_on_db(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_frontmost_unique_session "
          "ON frontmost_sessions(app_id, window_title, start_unix_sec, "
          "end_unix_sec);") != 0 ||
      exec_on_db("CREATE INDEX IF NOT EXISTS idx_media_time "
                 "ON media_sessions(start_unix_sec, end_unix_sec);") != 0 ||
      exec_on_db("CREATE INDEX IF NOT EXISTS idx_media_app "
                 "ON media_sessions(app_id);") != 0 ||
      exec_on_db("CREATE UNIQUE INDEX IF NOT EXISTS idx_media_unique_session "
                 "ON media_sessions(app_id, media_type, media_title, "
                 "start_unix_sec, end_unix_sec);") != 0 ||
      exec_on_db("PRAGMA user_version = 1;") != 0) {
    return -1;
  }

  return 0;
}

static int ensure_schema(void) {
  if (g_schema_ready) {
    return 0;
  }

  if (open_connection() != 0 || create_schema() != 0) {
    return -1;
  }

  g_schema_ready = 1;
  return 0;
}

static int prepare_statement(const char* sql, sqlite3_stmt** out_statement) {
  if (out_statement == NULL) {
    return -1;
  }
  *out_statement = NULL;

  if (sql == NULL || ensure_schema() != 0) {
    return -1;
  }

  if (sqlite3_prepare_v2(g_db, sql, -1, out_statement, NULL) != SQLITE_OK) {
    fprintf(stderr, "TimeArc service database prepare failed: %s\n",
            sqlite3_errmsg(g_db));
    return -1;
  }

  return 0;
}

static int bind_text(sqlite3_stmt* statement, int index, const char* value) {
  return sqlite3_bind_text(statement, index, text_or_empty(value), -1,
                           SQLITE_TRANSIENT) == SQLITE_OK
             ? 0
             : -1;
}

static int bind_int64(sqlite3_stmt* statement, int index, int64_t value) {
  return sqlite3_bind_int64(statement, index, value) == SQLITE_OK ? 0 : -1;
}

static int bind_required_text(sqlite3_stmt* statement, int index,
                              const char* value, const char* field_name) {
  if (require_text(value, field_name) != 0) {
    return -1;
  }
  return bind_text(statement, index, value);
}

static int finish_statement(sqlite3_stmt* statement, const char* action) {
  if (sqlite3_step(statement) != SQLITE_DONE) {
    fprintf(stderr, "TimeArc service database %s failed: %s\n", action,
            database_error());
    sqlite3_finalize(statement);
    return -1;
  }

  sqlite3_finalize(statement);
  return 0;
}

static int fail_statement(sqlite3_stmt* statement, const char* action) {
  fprintf(stderr, "TimeArc service database %s bind failed: %s\n", action,
          database_error());
  sqlite3_finalize(statement);
  return -1;
}

int database_storage_open(void) { return ensure_schema(); }

void database_storage_close(void) {
  if (g_db != NULL) {
    sqlite3_close(g_db);
    g_db = NULL;
  }
  g_schema_ready = 0;
}

int database_storage_begin(void) {
  return database_storage_open() == 0 ? exec_on_db("BEGIN IMMEDIATE;") : -1;
}

int database_storage_commit(void) {
  return g_db != NULL ? exec_on_db("COMMIT;") : -1;
}

void database_storage_rollback(void) {
  if (g_db != NULL) {
    exec_on_db("ROLLBACK;");
  }
}

int database_storage_upsert_app(const DatabaseAppRecord* app) {
  if (app == NULL || require_text(app->app_id, "app_id") != 0 ||
      require_text(app->platform, "platform") != 0) {
    return -1;
  }
  if (!is_valid_platform(app->platform)) {
    fprintf(stderr, "TimeArc service database invalid platform: %s\n",
            app->platform);
    return -1;
  }

  const char* sql =
      "INSERT INTO apps (app_id, platform, display_name, icon_path, "
      "executable_path, created_at, updated_at) "
      "VALUES (?, ?, ?, ?, ?, ?, ?) "
      "ON CONFLICT(app_id) DO UPDATE SET "
      "platform = excluded.platform,"
      "display_name = excluded.display_name,"
      "icon_path = excluded.icon_path,"
      "executable_path = excluded.executable_path,"
      "updated_at = excluded.updated_at;";

  sqlite3_stmt* statement = NULL;
  if (prepare_statement(sql, &statement) != 0) {
    return -1;
  }

  const int64_t now = timestamp_or_now(app->updated_at);
  if (bind_required_text(statement, 1, app->app_id, "app_id") != 0 ||
      bind_required_text(statement, 2, app->platform, "platform") != 0 ||
      bind_text(statement, 3, app->display_name) != 0 ||
      bind_text(statement, 4, app->icon_path) != 0 ||
      bind_text(statement, 5, app->executable_path) != 0 ||
      bind_int64(statement, 6, now) != 0 ||
      bind_int64(statement, 7, now) != 0) {
    return fail_statement(statement, "app upsert");
  }

  return finish_statement(statement, "app upsert");
}

int database_storage_insert_frontmost_session(
    const DatabaseFrontmostSession* session) {
  if (session == NULL || require_text(session->app_id, "app_id") != 0) {
    return -1;
  }

  const int64_t duration_sec = session->end_unix_sec - session->start_unix_sec;
  if (session->start_unix_sec < 0 ||
      session->end_unix_sec < session->start_unix_sec ||
      session->active_sec < 0 || session->active_sec > duration_sec) {
    fprintf(stderr, "TimeArc service database invalid frontmost interval.\n");
    return -1;
  }

  const char* sql =
      "INSERT OR IGNORE INTO frontmost_sessions ("
      "app_id, window_title, start_unix_sec, end_unix_sec, active_sec"
      ") VALUES (?, ?, ?, ?, ?);";

  sqlite3_stmt* statement = NULL;
  if (prepare_statement(sql, &statement) != 0) {
    return -1;
  }

  if (bind_required_text(statement, 1, session->app_id, "app_id") != 0 ||
      bind_text(statement, 2, session->window_title) != 0 ||
      bind_int64(statement, 3, session->start_unix_sec) != 0 ||
      bind_int64(statement, 4, session->end_unix_sec) != 0 ||
      bind_int64(statement, 5, session->active_sec) != 0) {
    return fail_statement(statement, "frontmost insert");
  }

  return finish_statement(statement, "frontmost insert");
}

int database_storage_insert_media_session(const DatabaseMediaSession* session) {
  if (session == NULL || require_text(session->app_id, "app_id") != 0) {
    return -1;
  }

  const char* media_type =
      has_text(session->media_type) ? session->media_type : "unknown";
  if (!is_valid_media_type(media_type)) {
    fprintf(stderr, "TimeArc service database invalid media_type: %s\n",
            media_type);
    return -1;
  }

  if (session->start_unix_sec < 0 ||
      session->end_unix_sec < session->start_unix_sec) {
    fprintf(stderr, "TimeArc service database invalid media interval.\n");
    return -1;
  }

  const char* sql =
      "INSERT OR IGNORE INTO media_sessions ("
      "app_id, media_type, media_title, start_unix_sec, end_unix_sec"
      ") VALUES (?, ?, ?, ?, ?);";

  sqlite3_stmt* statement = NULL;
  if (prepare_statement(sql, &statement) != 0) {
    return -1;
  }

  if (bind_required_text(statement, 1, session->app_id, "app_id") != 0 ||
      bind_text(statement, 2, media_type) != 0 ||
      bind_text(statement, 3, session->media_title) != 0 ||
      bind_int64(statement, 4, session->start_unix_sec) != 0 ||
      bind_int64(statement, 5, session->end_unix_sec) != 0) {
    return fail_statement(statement, "media insert");
  }

  return finish_statement(statement, "media insert");
}
