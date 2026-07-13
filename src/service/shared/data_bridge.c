// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

// Public C bridge for service writers. SQLite details stay in database_storage.

#include "data_bridge.h"

#include "database_storage.h"

// update_apps - update the apps table through the storage backend.
int update_apps(const char* app_id, const char* platform,
                const char* display_name, const char* icon_path,
                const char* executable_path, int64_t updated_at) {
  DatabaseAppRecord app = {
      app_id, platform, display_name, icon_path, executable_path, updated_at,
  };
  return database_storage_upsert_app(&app);
}

// update_frontmost - store one completed frontmost app session.
int update_frontmost(const char* app_id, const char* window_title,
                     int64_t start_unix_sec, int64_t end_unix_sec,
                     int64_t active_sec) {
  DatabaseFrontmostSession session = {
      app_id, window_title, start_unix_sec, end_unix_sec, active_sec,
  };
  return database_storage_insert_frontmost_session(&session);
}

// update_media - store one completed media session.
int update_media(const char* app_id, const char* media_type,
                 const char* media_title, int64_t start_unix_sec,
                 int64_t end_unix_sec) {
  DatabaseMediaSession session = {
      app_id, media_type, media_title, start_unix_sec, end_unix_sec,
  };
  return database_storage_insert_media_session(&session);
}
