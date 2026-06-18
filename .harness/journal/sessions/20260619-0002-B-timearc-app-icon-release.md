# B timearc app icon release

Goal: make TimeArc show its own T icon in app rankings and produce an alpha.2
Windows test release package.

Service side: no service behavior or disk contract changes. The background
sampler keeps emitting the same app id, app name, path, and session rows.

UI side: register TimeArc in the desktop app adapter registry so the existing
usage aggregation maps TimeArc activity to `app:timearc` and exposes the
existing `resources/icons/app_icon.svg` qrc source to ranking cards.

Rules touched: `rules/01-architecture.md`, `rules/04-ui-conventions.md`,
`rules/05-build-system.md`, and `rules/06-licensing.md` were checked. No frozen
files, schema, CMake, data bridge, new dependency, or license inventory changes
are expected.

Outcome: added the TimeArc desktop app adapter, verified the adapter wiring,
built successfully, fixed an over-broad match caught by `timearc_db_smoke`, and
produced `dist/TimeArc-0.1.0-alpha.2-win64.zip`.
