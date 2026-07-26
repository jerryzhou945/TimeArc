# Site Icons App List Timeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix Douyin/Xiaohongshu site visibility, upgrade known site icons, clean the settings app list, de-overlap the home TimeRiver, and add a white Memory Lake icon.

**Architecture:** Keep service and disk schemas unchanged. Fix UI-side aggregation in `UsageStatManager`, feed cleaner list metadata into QML, and keep all website icons as local qrc resources.

**Tech Stack:** Qt 6/QML, C++17, SQLite read model, existing harness build/check scripts.

---

### Task 1: Plan And Journal

**Files:**
- Create: `.harness/journal/sessions/20260614-0546-B-site-icons-app-list-timeline.md`
- Create: `docs/superpowers/plans/2026-06-14-site-icons-app-list-timeline.md`
- Modify: `.harness/journal/INDEX.md`
- Modify: `.harness/journal/errors.jsonl`
- Create: `.harness/journal/errors/20260613-214742-B-sqlite-query-inline-python-escape.md`
- Create: `.harness/journal/errors/20260613-214814-B-sqlite-inspection-output-encoding.md`

- [ ] Record service/UI design paragraphs and the observed SQLite evidence.
- [ ] Run `python .harness/tools/harness_check.py`.
- [ ] Commit with `Add site icon app list plan`.

### Task 2: Site Recognition And High Resolution Icons

**Files:**
- Modify: `src/services/usage_stat_manager.cpp`
- Modify: `src/services/site_catalog.h`
- Modify: `tests/db_smoke.cpp`
- Modify: `resources/CMakeLists.txt`
- Modify: `docs/site-icon-assets.md`
- Modify: `docs/mainland-site-tracking.md`
- Modify: `qml/desktop/components/AppVisual.js`
- Add/replace: `resources/app/icons/sites/*`

- [ ] Add/extend smoke coverage for Chrome titles and audio media titles: `douyin.com/...`, `小红书 - ...`, and `...抖音 - 抖音` must resolve to `site:douyin` / `site:xiaohongshu`.
- [ ] Run the smoke target or full harness build to verify the test fails before code/resource updates.
- [ ] Upgrade catalog and QML fallback icon paths to high-resolution local resources for known sites where official metadata provides one.
- [ ] Build, run harness check, commit with `Support high resolution site icons`.

### Task 3: Settings App List Quality

**Files:**
- Modify: `src/services/usage_stat_manager.cpp`
- Modify: `qml/desktop/pages/DesktopProfilePage.qml`
- Modify: `qml/desktop/components/AppVisual.js`
- Modify: `docs/implementation-backlog.md`

- [ ] Add a failing static or smoke check proving app list items expose `settingsVisible` and `seconds`.
- [ ] In `allApps()`, aggregate usage seconds by key, use public display names, hide low-signal pid/dll/helper rows by default, and keep hidden rows searchable.
- [ ] In QML, sort by usage frequency descending, then icon availability, then display name.
- [ ] Build, run harness check, commit with `Support cleaner settings app list`.

### Task 4: Home TimeRiver Label Clarity

**Files:**
- Modify: `qml/desktop/memorylake/TimeRiver.qml`

- [ ] Add a failing static check for the new dense-label summarization helper.
- [ ] Replace dense full labels with limited readable labels and a compact overflow indicator when nearby sessions cluster.
- [ ] Build, run harness check, commit with `Support readable TimeRiver labels`.

### Task 5: White Memory Lake Icon

**Files:**
- Add: `resources/app/icons/navigation/recap_white.svg`
- Modify: `resources/CMakeLists.txt`
- Modify: `qml/desktop/DesktopAppShell.qml`
- Modify: `docs/implementation-backlog.md`

- [ ] Add white Memory Lake icon resource matching the existing `recap.svg` shape.
- [ ] Wire dark/navigation usage to `recap_white.svg`.
- [ ] Build, run harness check, commit with `Add white memory lake icon`.

### Task 6: Report, PR, Merge, Cleanup

**Files:**
- Create: `docs/site-icons-app-list-timeline-report.md`
- Modify: `.harness/journal/sessions/20260614-0546-B-site-icons-app-list-timeline.md`

- [ ] Write the Chinese completion report with verification and rollback notes.
- [ ] Run final build and harness check.
- [ ] Push branch, open PR to `dev`, merge after clean, delete remote and local branch.
