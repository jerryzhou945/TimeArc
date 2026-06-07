# Session 20260607-2301 · Track B · settings-page-impl

## Metadata
- Agent: Claude Code (Opus 4.8, ultracode). Track **B**. Date 2026-06-07 → 06-08.
- Branch: feat/settings-page-dark-glass (staged on worktree branch settings-impl-wt,
  delivered via fast-forward push to feat/settings-page-dark-glass / PR #28).
- Baseline: f08e540 (docs-only; 3 design specs already landed).

## Goal
Implement v88「设置」page: 1:1 dark-glass reskin of `DesktopProfilePage.qml` (in place,
A-NAME) + read-only read-glue + honest placeholders, per docs/settings-{implementation-
issues,functional-replication,render-pipeline-replication}.md. Three phases (issues §8).

## Two-sided design (Track B)
- Service: UNCHANGED. No IPC/socket/shm; no write/delete of append-only journal (I1/I2/D1);
  usage jsonl/db read-only.
- UI: settings persisted as UI-private KV via `SettingsRepository` (off the disk contract).
  Read-glue (later phases) only extends existing NON-FROZEN .cpp/.h; never a new C++ source
  (would touch frozen src/CMakeLists.txt).

## Constraints honored (red lines)
G6 no-faking (pomodoro/notify/perm/true-delete → hidden/placeholder, no fake values);
A-DEFAULT keep-day, A-NAME extend-in-place, A-CLEAR UI-cache-only, A-PERM perm「就绪」,
A-POMODORO hide card, A-TRACKPAUSE UI-approx + honest label. No frozen edits (pass2 clean).
G1 tokens (no scattered hex); Qt6 font.pixelSize int. No new C++ source this phase.

## What happened
- Preflight clean. Understanding workflow (9 parallel readers: 3 docs + current page + shell
  routing + style tokens + settings-repo + backend gaps + v88 prototype) → impl map.
- bg-isolation guard → HEAD-based worktree under .claude/worktrees/.
- Phase 1 built: 5 dark-glass controls + tokens + 3 shell routing edits + full page reskin.
- Adversarial review workflow (3 lenses + verify): 1 confirmed major — day/night toast
  inverted (Shell synchronously writes back nightMode before toast reads it). False-positives
  (Column zero-height; ComboBox native-skin leak) disproven. Fixes applied: toast
  target-before-emit; GlassSlider controlled (no self-write of value); slider handle border;
  restoreVisualDefaults also resets show_welcome; tokenized danger-text + swatch border;
  switchOff .14→.12.
- L2 combo advisory: scan flagged 24 reports = ONE "style does not support customization"
  ×3 ComboBox elements ×runs (restyled native Controls.ComboBox). App-wide Style=Basic
  rejected (cross-page regression risk). FIX: rewrote GlassComboBox as pure Item +
  Controls.Popup (Popup bg customization always supported → no advisory) + fixed controlled
  currentIndex. Re-verified scan clean. 24 transient dup reports cleaned (git checkout
  INDEX.md/errors.jsonl + deleted orphans); recorded here (no recurring defect).

## Verification (PrintWindow-by-PID, own worktree build)
build.py clean each cycle (qmlcachegen AOT-compiled all 6 new/changed QML, no warnings).
Captured day+night × 1280×720 (responsive-collapsed: nav hidden / compact tabs / 1-col, per
spec ≤1100) + maximized 1920×1080 (full 238 nav + 2-col). Tabs general/tracking/export:
accent swatches, theme-switch ☾/☀, GlassSwitch/Slider/ComboBox, placeholders, perm「就绪」,
data-overview real 今日使用 + honest「—」. scan_qt_log clean (zero warnings). harness_check 0.

## Outcome — Phase 1: DONE (committed)
- Files: shell routing (3) + MemoryLakeStyle tokens (protoAmber/switchOff/switchKnob/
  dangerText) + 5 Glass* controls + qml/CMakeLists.txt + DesktopProfilePage.qml reskin +
  README settings entry. Frozen files touched: NONE.
- Acceptance C0/C1/C2/C3/C4/C5/C12/C13/C14 met for Phase-1 scope; general tab fully wired;
  backend-dependent items honest placeholders for Phase 2/3 (G6).
- NEXT Phase 2 (read-glue: usage_stat_manager/settings_repository — G-HIDEAPP, G-HIDETITLE/
  G-ANON, G-STORAGE, data-overview real + switch-count derived, G-EXPORT/G-IMPORT). Phase 3
  (restricted: G-TRACK/IDLE/CLEAR/PERM/NOTIFY/POMODORO/ACCENT/I18N per A-*).

## Notes for next agent
- Worktree build: cmake configure (Ninja, C:\Qt\6.11.1\mingw_64) then build.py; PATH needs
  Qt bin+mingw+ninja+cmake. Kill TimeArc.exe before each rebuild (exe lock).
- Verify full-bleed via PrintWindow-by-PID on own build/TimeArc.exe ($CLAUDE_JOB_DIR/tmp/
  shoot.ps1); temp-default Shell selectedIndex/nightMode + page currentTab to reach a state,
  then REVERT before commit.
- Do NOT restyle native Controls directly (per-instance "style does not support customization"
  advisory under Windows style) — use pure QtQuick + Controls.Popup, or app-wide Style=Basic
  (rejected here as cross-page regression risk).
