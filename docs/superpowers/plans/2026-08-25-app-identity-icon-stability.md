# App Identity and Icon Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep statistics icons stable, force WeChat to use its main executable icon, and support reversible custom application IDs that regroup historical statistics.

**Architecture:** The collector and service database remain unchanged. A header-only UI policy validates aliases and ranks executable paths; `UsageStatManager` applies aliases and canonical paths while reading history, while the settings page persists the alias map in the GUI settings database.

**Tech Stack:** Qt 6/C++17, QML/JavaScript, SQLite read models, Python static regression checks, CTest.

**Spec:** `docs/superpowers/specs/2026-08-25-app-identity-icon-stability-design.md`

## Global Constraints

- Never write or migrate `timearc_service.db`; the UI remains read-only.
- Do not add bundled WeChat or other third-party app artwork.
- WeChat icons come only from installed `Weixin.exe` or `WeChat.exe`.
- Custom IDs normalize to lowercase `app:<slug>` and remain reversible.
- No worktree, new dependency, schema change, C ABI change, or frozen-file edit.

---

### Task 1: Identity and representative-path policy

**Files:**
- Create: `src/services/app_identity_policy.h`
- Modify: `tests/db_smoke.cpp`

**Interfaces:**
- Produces: `TimeArcAppIdentity::normalizeCustomId(QString) -> QString`
- Produces: `TimeArcAppIdentity::isValidCustomId(QString) -> bool`
- Produces: `TimeArcAppIdentity::effectiveId(QString, QHash<QString, QString>) -> QString`
- Produces: `TimeArcAppIdentity::shouldReplaceRepresentativePath(...) -> bool`

- [ ] **Step 1: Write failing policy tests in `tests/db_smoke.cpp`**

```cpp
if (TimeArcAppIdentity::normalizeCustomId("  APP:WeChat  ") != "app:wechat" ||
    TimeArcAppIdentity::isValidCustomId("site:wechat") ||
    TimeArcAppIdentity::effectiveId("app:legacy", {{"app:legacy", "app:wechat"}})
        != "app:wechat") {
  return fail("Application identity policy failed.");
}
if (!TimeArcAppIdentity::shouldReplaceRepresentativePath(
        "app:wechat", "C:/Plugin/WeChatAppEx.exe", true, 200,
        "D:/Weixin/Weixin.exe", true, 100)) {
  return fail("WeChat main executable did not outrank its helper.");
}
if (!TimeArcAppIdentity::shouldReplaceRepresentativePath(
        "app:codex", "D:/WindowsApps/old/ChatGPT.exe", false, 200,
        "D:/WindowsApps/current/ChatGPT.exe", true, 100)) {
  return fail("A valid executable did not outrank an obsolete path.");
}
```

- [ ] **Step 2: Build and run the test to confirm it fails**

Run: `.local-python\Python312\python.exe .harness/tools/build.py --track B --topic app-identity-policy-red --session .harness/journal/sessions/20260825-0953-B-app-identity-management.md -- --target timearc_db_smoke`

Run: `build\timearc_db_smoke.exe`

Expected: compilation fails because `app_identity_policy.h` and its functions do not exist.

- [ ] **Step 3: Add the minimum header-only policy**

```cpp
namespace TimeArcAppIdentity {
inline QString normalizeCustomId(const QString& value);
inline bool isValidCustomId(const QString& value);
inline QString effectiveId(const QString& raw,
                           const QHash<QString, QString>& overrides);
inline bool shouldReplaceRepresentativePath(
    const QString& groupKey, const QString& currentPath, bool currentExists,
    qint64 currentSeen, const QString& candidatePath, bool candidateExists,
    qint64 candidateSeen);
}
```

The path rank is: valid WeChat main executable, valid normal executable,
missing normal executable, WeChat helper/updater. Equal ranks use the newest
record, then a case-insensitive lexical tie-break for deterministic output.

- [ ] **Step 4: Rebuild and run the focused test**

Expected: `timearc_db_smoke` builds and prints its existing success message.

- [ ] **Step 5: Commit the policy and test**

```powershell
git add src/services/app_identity_policy.h tests/db_smoke.cpp
git commit -m "Add application identity policy"
```

### Task 2: Apply aliases and stable paths in `UsageStatManager`

**Files:**
- Modify: `src/services/usage_stat_manager.h`
- Modify: `src/services/usage_stat_manager.cpp`
- Modify: `tests/desktop_ux_static_test.py`

**Interfaces:**
- Consumes: policy functions from Task 1.
- Produces: `setAppIdentityOverrides(const QVariantMap&)`
- Produces: `validateCustomAppId(const QString&) -> QVariantMap`
- Produces in `allApps()`: `originalGroupKey`, `effectiveGroupKey`, and `customAppId`.

- [ ] **Step 1: Add failing integration assertions**

```python
require(usage_h, "setAppIdentityOverrides", "custom identity setter")
require(usage_h, "validateCustomAppId", "custom identity validator")
require(usage_cpp, "rebuildRepresentativePaths", "stable icon path cache")
require(all_apps_cpp, 'item["originalGroupKey"]', "recoverable raw identity")
require(all_apps_cpp, 'item["customAppId"]', "custom identity exposure")
```

- [ ] **Step 2: Run the static test and confirm it fails**

Run: `.local-python\Python312\python.exe tests/desktop_ux_static_test.py`

Expected: failure naming the first missing identity API.

- [ ] **Step 3: Implement the read-layer mapping**

Add `QHash<QString, QString> m_identityOverrides`, a representative-path cache
keyed by effective group ID, and these invokables:

```cpp
Q_INVOKABLE void setAppIdentityOverrides(const QVariantMap& overrides);
Q_INVOKABLE QVariantMap validateCustomAppId(const QString& value) const;
```

`effectiveGroupKey()` first derives the raw group, rejects hidden raw/effective
keys, applies one non-recursive override, then falls back to the existing
merge-similar behavior. Changing overrides increments `m_recordsGeneration`,
invalidates canonical paths, and emits `usageStatsChanged()`.

`rebuildRepresentativePaths()` scans retained records once per generation,
uses `QFileInfo::exists()`, and applies Task 1's deterministic ranking.
Aggregates and `allApps()` consume the canonical path instead of the first
record path. `allApps()` remains one row per original group so every alias can
always be restored even after multiple groups merge in statistics.

- [ ] **Step 4: Run focused and existing model tests**

Run: `.local-python\Python312\python.exe tests/desktop_ux_static_test.py`

Run: `node tests/stats_view_model_test.js`

Expected: both pass; existing interval-union and clock behavior remain green.

- [ ] **Step 5: Commit manager integration**

```powershell
git add src/services/usage_stat_manager.h src/services/usage_stat_manager.cpp tests/desktop_ux_static_test.py
git commit -m "Support read-only application identity aliases"
```

### Task 3: Add the inline custom-ID editor

**Files:**
- Modify: `qml/desktop/pages/DesktopProfilePage.qml`
- Modify: `qml/desktop/components/I18n.js`
- Modify: `tests/desktop_ux_static_test.py`

**Interfaces:**
- Consumes: `validateCustomAppId`, `setAppIdentityOverrides`, and enriched `allApps()` rows from Task 2.
- Persists: `app_identity_overrides` JSON through `SettingsRepository::setValue`.

- [ ] **Step 1: Add failing QML contract assertions**

```python
require(settings_qml, '"app_identity_overrides"', "identity override setting")
require(settings_qml, "editingAppKey", "single expanded application editor")
require(settings_qml, "确认合并", "inline merge confirmation")
require(settings_qml, "恢复默认 ID", "identity reset action")
require(settings_qml, "setAppIdentityOverrides", "live statistics refresh")
```

- [ ] **Step 2: Run the static test and confirm it fails**

Run: `.local-python\Python312\python.exe tests/desktop_ux_static_test.py`

Expected: failure on the missing settings key.

- [ ] **Step 3: Implement persistence and editor state**

Add QML state `appIdentityOverrides`, `editingAppKey`, `appIdDraft`,
`appIdError`, and `pendingMergeKey`. Load the JSON beside `hidden_apps`, push
it into `UsageStatManager`, and only replace local state after
`SettingsRepository::setValue` returns true.

Keep the existing two-column application layout. An `ID` action expands one
row inline to show original ID, a filled `GlassTextField`, Save, and Restore.
The first save to an occupied effective ID shows an inline warning; the same
save action becomes `确认合并`. No modal is introduced. Successful save or
restore refreshes the application list and statistics immediately.

- [ ] **Step 4: Add Chinese/English/Japanese strings and run checks**

Run: `.local-python\Python312\python.exe tests/i18n_duplicate_keys_static_test.py`

Run: `.local-python\Python312\python.exe tests/desktop_ux_static_test.py`

Expected: both pass, with no duplicate translation keys.

- [ ] **Step 5: Commit the settings UI**

```powershell
git add qml/desktop/pages/DesktopProfilePage.qml qml/desktop/components/I18n.js tests/desktop_ux_static_test.py
git commit -m "Add custom application ID editor"
```

### Task 4: Build and runtime acceptance

**Files:**
- Modify: `.harness/journal/sessions/20260825-0953-B-app-identity-management.md`
- Create: `docs/app-identity-icon-stability-report-2026-08-25.md`
- Modify: `docs/implementation-backlog.md`
- Modify: `.harness/state/open-issues.md`

**Interfaces:**
- Consumes: all deliverables from Tasks 1–3.
- Produces: verified Windows desktop behavior and a rollback report.

- [ ] **Step 1: Run the full wrapped build and tests**

Run: `.local-python\Python312\python.exe .harness/tools/build.py --track B --topic app-identity-build --session .harness/journal/sessions/20260825-0953-B-app-identity-management.md`

Run: `ctest --test-dir build --output-on-failure`

Run: `.local-python\Python312\python.exe tests/desktop_ux_static_test.py`

Run: `node tests/stats_view_model_test.js`

Expected: build and every test pass.

- [ ] **Step 2: Launch the desktop app and inspect the changed surfaces**

Run: `.\launch.cmd`

Verify: WeChat uses the same default icon in ranking, clock, all-app table,
and application management; custom ID save, collision confirmation, merge,
and restore work without restart or blank icons.

- [ ] **Step 3: Scan Qt logs**

Run: `.local-python\Python312\python.exe .harness/tools/scan_qt_log.py`

Expected: no new QML warning or image-provider error.

- [ ] **Step 4: Write completion records and run the harness audit**

The Chinese report records goal, changed files, verification, known gaps, and
rollback commits. Update backlog/open issues and the session's Completed,
Incomplete, Verification, Next, and Risks fields.

Run: `.local-python\Python312\python.exe .harness/tools/harness_check.py`

Expected: all seven harness passes are clean.

- [ ] **Step 5: Commit verification and documentation**

```powershell
git add .harness/journal/sessions/20260825-0953-B-app-identity-management.md docs/app-identity-icon-stability-report-2026-08-25.md docs/implementation-backlog.md .harness/state/open-issues.md
git commit -m "Document application identity verification"
```
