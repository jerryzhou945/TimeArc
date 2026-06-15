# B global runtime i18n

Goal: add runtime language switching for the UI, prioritizing complete English coverage while keeping Chinese source strings as fallback.

Service side: no service, schema, data path, or sampling changes. The background service continues to emit the same SQLite/jsonl/live files; language only changes presentation in the UI.

UI side: add a shared QML i18n helper, route Shell/page/component strings through it, keep existing `language_mode` settings storage, and preserve layout with eliding/wrapping on longer English labels.

Expected files touched: QML desktop shell/pages/memorylake/mobile basics, new desktop component i18n JS, README, UI convention rule, session/spec/plan docs.

Files intentionally avoided: frozen service bridge/schema/path files, top-level CMake files, database contracts, service implementation.

Rule update: `.harness/rules/04-ui-conventions.md` language section should allow runtime translation helpers while keeping Chinese source fallback.

Manual smoke path: launch TimeArc, open settings, switch language to English, navigate Home/Stats/Calendar/Memory Lake/Settings, confirm labels change and no obvious overflow.
