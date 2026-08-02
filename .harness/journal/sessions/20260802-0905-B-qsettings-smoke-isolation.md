# QSettings smoke test isolation

Goal: make the Windows DB smoke migration fixture use the configured test QSettings format and location. Service side: no service behavior or disk contract changes. UI side: production legacy migration keeps NativeFormat by default; tests explicitly select IniFormat.

Completed: named legacy QSettings constructors now use `defaultFormat()` and `UserScope`; the smoke seed mirrors that boundary. Incomplete: None. Verification: RED reproduced at legacy-project idempotency; GREEN target build and focused CTest passed.

Next: run the full CTest suite and publish this isolated prerequisite PR before the Windows parity PR. Risks: low; rollback is the PR merge revert and no data migration is required.
