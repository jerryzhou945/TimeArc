# Goal

Unify the desktop MVP pages around the existing repository/storage layer so projects, todos, timer sessions, stats, settings, and local memo chat persist through one data path.

# Service side

The native service continues to emit foreground and audio usage through the existing disk contract. This session must not change sampling, path detection, media detection, frozen shared headers, or the service JSONL/live snapshot contract.

# UI side

Desktop QML should stop relying on page-local mock arrays for core MVP data and should consume QObject managers backed by the repository/database layer. Writes from projects, todos, timer, settings, and memo chat should persist and emit refresh signals for related pages.

# Rules

Touches `qml/` and `src/services/`, so `rules/01-architecture.md`, `rules/03-data-contract.md`, and `rules/04-ui-conventions.md` apply. Avoid frozen files unless an existing change already requires separate owner review.

# Outcome

Project/timer writes now go through `ManualProjectRepository`; project deletion archives instead of deleting history. Calendar todos and local memo chat persist through SQLite settings, night mode reads/writes the same settings repository, and the desktop data path is shown read-only. The obsolete "导入想查看时间的软件" entry was removed. Harness build could not run because Python is unavailable in this session; see the L3 error report.

P1.1 follow-up added an idempotent legacy QSettings migration for projects/sessions, calendar todos, local memo chat, and night mode. Smoke coverage was extended for migration and repeat-run behavior, but harness build/test execution remains blocked by the same missing Python runtime.
