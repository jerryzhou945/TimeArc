# Session Log - app-list-icons-highres

## Metadata

- Agent / Author: Codex
- Track: **B (Feature)**
- Date: 2026-06-14 11:20 -> in progress (local)
- Branch: codex/app-list-icons-highres
- Baseline commit: f583ad5

## Goal

Improve mainstream site icon quality, show all app-management entries with
predictable frequency/name sorting, and make app/site icons fall back reliably
across settings, stats, and Memory Lake report surfaces.

## Service Side

No service writer, schema, or disk-contract changes. The service continues to
emit raw app identifiers, paths, titles, and durations into SQLite/JSONL.

## UI Side

The UI read layer will surface all aggregated apps in app management, attach
stable icon fallback metadata, and use higher-resolution local website icons
when official metadata exposes them. QML icon components should gracefully fall
back to label tiles when image loading fails.

## Expected Files

- `src/services/usage_stat_manager.cpp`, `src/services/site_catalog.h`
- `qml/desktop/components/AppVisual.js`, relevant icon delegates/pages
- `resources/icons/sites/*`, `resources/CMakeLists.txt`
- `docs/site-icon-assets.md`, `docs/implementation-backlog.md`
- `tests/db_smoke.cpp`
