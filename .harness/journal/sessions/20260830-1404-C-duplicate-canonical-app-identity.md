# Session — canonical application identity

Goal: Make persisted variants of one canonical desktop application render as one entry with the primary executable's native icon.

Related error report(s): `.harness/journal/errors/20260830-190925-C-duplicate-canonical-app-identity.md`. Expected changes are limited to categorization identity resolution and its existing C++ regression test; do not touch the service database contract, frozen files, or unrelated statistics-clock work.

Progress: [x] add the failing canonical-ref identity test; [x] implement the minimal resolver fix; [x] run focused tests, harness build, runtime log scan, and process verification.

Outcome: `build.py` passed; the canonical-ref regression failed before the fix and passed after it; all 6 CTest tests, the stats ViewModel test, and desktop UI static checks passed. The rebuilt TimeArc and its service are running from this project's build directory. Qt log scanning found only the pre-existing calendar binding-loop warning; automated navigation to the statistics page was stopped because concurrent user input repeatedly invalidated the window action.

## Completion report

- Completed: Persisted executable variants retain their concrete editable rule id; an explicit WeChat alias policy shares its identity without collapsing unrelated applications from broad defaults.
- Incomplete: None.
- Verification: Expected RED and GREEN database smoke test, wrapped build, 6/6 CTests, stats JS test, desktop static test, runtime process check, Qt log scan, and harness check succeeded.
- Next: Merge through the normal PR path and package the merged release.
- Risks: Existing databases are not rewritten; rows converge at read time, which is intentional and avoids a data migration.
