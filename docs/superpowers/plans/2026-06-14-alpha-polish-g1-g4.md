# Alpha Polish G1/G4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the agreed alpha polish slice: settings import/export UI cleanup, app identity/ranking polish, Bilibili icon source cleanup, and TimeRiver label de-overlap.

**Architecture:** Keep service and disk contracts unchanged. Put identity/category/mainstream filtering in `UsageStatManager` and `DailyCardService`, put display sorting/icon fallback in QML helpers, and keep static site icons inside resources.

**Tech Stack:** Qt 6 / QML, C++ QVariant models, existing harness build/check scripts.

---

### Task 1: Commit Harness Setup Records

**Files:**
- Modify: `.harness/journal/INDEX.md`
- Modify: `.harness/journal/errors.jsonl`
- Create: `.harness/journal/errors/20260613-200641-C-cmake-not-in-path.md`
- Create: `.harness/journal/errors/20260613-200750-C-shell-path-not-reloaded.md`
- Create: `.harness/journal/errors/20260613-200855-C-powershell-python-heredoc.md`
- Create: `.harness/journal/errors/20260613-204041-B-tdd-before-design-approval.md`
- Create: `.harness/journal/sessions/20260614-0403-C-cmake-d-drive-path.md`

- [ ] Stage and commit harness-only records with `git commit -m "Add CMake path repair journal"`.

### Task 2: Settings UI + G1 Backlog

**Files:**
- Modify: `qml/desktop/pages/DesktopProfilePage.qml`
- Modify: `docs/implementation-backlog.md`

- [ ] Remove the visible “导出设置 JSON” control while keeping `doExport()` available.
- [ ] Retitle/copy the card around import/summary so the layout still feels intentional.
- [ ] Update G1 to state alpha does not need a Parson-backed human JSON config file.
- [ ] Build, run harness check, commit.

### Task 3: App Identity and Mainstream Ranking

**Files:**
- Modify: `src/services/usage_stat_manager.cpp`
- Modify: `src/services/daily_card_service.cpp`
- Modify: `docs/implementation-backlog.md`

- [ ] Extend common app names/categories and group keys for noisy Windows/QQ screenshot helpers.
- [ ] Mark low-signal helper/system apps so Memory Lake home ranking excludes them, while full settings app management remains complete.
- [ ] Build, run harness check, commit.

### Task 4: App Management Icons and Sort

**Files:**
- Modify: `qml/desktop/pages/DesktopProfilePage.qml`
- Modify: `qml/desktop/components/AppVisual.js`

- [ ] Add helper functions to detect icon availability and sort apps with icon-first then display name.
- [ ] Replace letter-only app management tiles with icon image plus first-letter fallback.
- [ ] Build, run harness check, commit.

### Task 5: Bilibili Site Icon and TimeRiver Labels

**Files:**
- Modify: `src/services/site_catalog.h`
- Modify: `src/services/adapters/websites/bilibili_adapter.h`
- Modify: `qml/desktop/components/AppVisual.js`
- Modify: `qml/desktop/memorylake/TimeRiver.qml`
- Modify: `resources/CMakeLists.txt`
- Delete: `resources/icons/bilibili.svg`
- Add: `resources/icons/sites/bilibili.ico`

- [ ] Move Bilibili to the same `resources/icons/sites/*.ico` site-icon path as other video sites.
- [ ] Remove the old root `bilibili.svg` resource entry.
- [ ] Add TimeRiver label lane/skip logic so dense labels do not overlap.
- [ ] Build, run harness check, commit.
