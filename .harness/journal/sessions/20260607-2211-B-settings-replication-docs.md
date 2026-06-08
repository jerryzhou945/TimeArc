# Session Log — settings-replication-docs

## Metadata

- Agent / Author: Claude (Opus 4.8, ultracode workflow)
- Track: **B (Feature)** — planning/product-docs for the v88 Settings page replication.
- Date: 2026-06-07 22:11 → (local)
- Branch: feat/stats-page-dark-glass
- Baseline commit: 068084f

## Goal

Research the v88 设置 (Settings) page (art + function) vs the existing QML/backend and write the
replication playbook + an implementation issues "问题文档" — **no code touched, docs only**.
User requirement: full study of the HTML settings page first, then engineering docs split into
美术 (art) + 技术 (technical) parts, plus a gaps/decisions issue doc.

## Plan

- Read v88 settings CSS/markup/JS firsthand from `TimeArcDesign_v88.html`.
- Fan-out research workflow (SettingsRepository API / Shell full-bleed routing / reusable QML
  component inventory / per-control backend-capability audit = gaps / existing settings surfaces /
  doc-style template).
- Read firsthand the linchpin files (DesktopAppShell routing+nightMode, DesktopProfilePage,
  settings_repository.h, MemoryLakeStyle, GlassPanel/GridTexture/GlowCircle/RoundedFrame, CHARTER
  frozen list, qml/CMakeLists.txt registration).
- Produce three paired docs mirroring the stats/calendar/memo precedent.

## What actually happened

- 22:11 — preflight --track B → clean (exit 0).
- 22:15 — extracted settings page: DOM 13897–14165, CSS 8194–8830 (+ shared classes
  prototype-status 11608, workflow-map 11689, theme-switch/chip 12313–12418), JS 17824–18008 +
  day-mode 18678–18740, light overrides 12420–13500. v88 settings JS is ~100% front-end state
  (toggle class + toast; accent = CSS var; blur slider = backdrop-filter; import/export = localStorage).
- 22:30 — key firsthand findings:
  - **"settings" route already exists** (`DesktopAppShell.qml:135`), maps to `DesktopProfilePage.qml`
    (`:171`), with `nightModeToggled` signal + nightMode injection already wired (`:822–830`) — but it
    is NOT in `fullBleedPage` (`:61–62`) nor the grid gate (`:296`). So it renders as a normal inset
    cream page today, not full-bleed dark glass.
  - `SettingsRepository` = SQLite `settings` KV table; API only getValue/setValue/getBool/setBool
    (no getInt/getAll, no signals); UI-private, off the JSONL service contract (though physically in
    the same timearc.db). Existing keys incl. night_mode, language_mode.
  - `MemoryLakeStyle` already carries calendar tokens (calPageTop/Bottom, calSunkBg, calInputBorder,
    calGhostBg/Hover, calToastBg, calBtnInk, calDangerWash) that map ~1:1 onto the near-identical
    settings CSS → heavy reuse, near-zero new tokens.
  - Reusable render primitives confirmed: GlassPanel/FrostCard/RoundedFrame/GridTexture/GlowCircle/
    SilkyFlickable + calToast + stats range-Tab. MISSING (must build): GlassSwitch / GlassComboBox /
    GlassSlider / GlassTextField (no switch/dropdown/slider/input components exist in dark glass).
  - Frozen boundary: settings_repository.* and usage_stat_manager.* are NON-frozen (add methods,
    no proposal); the 3 CMakeLists are frozen. QML file list is in `qml/CMakeLists.txt` (NON-frozen,
    explicit list) → new .qml needs a non-frozen edit, but extending DesktopProfilePage in place
    avoids it entirely → **D-EXTEND-IN-PLACE**.
- 22:40 — ran fan-out workflow `settings-impl-research` (6 agents, ~420k tokens, ~5min); the R4
  capability audit produced the gap taxonomy (wired/ui-only/partial/service-change/none).
- 23:00 — wrote the three docs.

## Outcome

**done** (research/planning deliverable).

- Commits landed: none (docs only; user has not asked to commit).
- Files touched (new, non-frozen):
  - `docs/settings-functional-replication.md` (行为/状态/持久化/复刻规则·标准·步骤 + 验收 C 表 + 批次)
  - `docs/settings-render-pipeline-replication.md` (渲染管线 / CSS→QML / 控件配方 / 昼夜映射 / 抓图验证)
  - `docs/settings-implementation-issues.md` (后端缺口 G-* + 产品决策 A-* + 三阶段 + 实测登记 = 问题文档)
  - `.harness/journal/sessions/20260607-2211-B-settings-replication-docs.md` (this log)
- Frozen files touched: **n**.
- Follow-ups: implementation staged in `settings-implementation-issues.md` §8 (阶段一纯 UI 偏好零后端;
  阶段二只读层胶水扩 non-frozen .cpp; 阶段三受限/新能力需 A-* 决策 + 可能服务改提案).

## Notes for the next agent

- Biggest decisions before coding (§0 of issues doc): A-DEFAULT (keep day default), A-NAME (extend
  Profile in place), A-CLEAR (clear only UI-private caches, not append-only usage), A-PERM (Windows
  permission = always "ready"), A-POMODORO (hide pomodoro card — no engine exists), A-TRACKPAUSE
  (UI-approximate track toggle, can't control service capture).
- The "TRACKING" tab is a trap: game-mode/auto-classify/merge-windows are already UI read-layer logic
  (glue, not service); only total-track-toggle + idle-timeout truly touch the service (no IPC, idle is a
  compile-time #define in usage_tracker.h:7) → honest "limited" labeling, never fake.
- No pomodoro/notification/permission backend exists at all (timer_manager counts UP, not down) — these
  are new capabilities, not "bind existing backend"; G6 不造假 forbids faking them.
- Shell edits for full-bleed: add "settings" at DesktopAppShell.qml :61–62 (fullBleedPage), :296 (grid),
  :810 (requestNavigate). All non-frozen .qml body edits.
- One backend helper worth adding once (non-frozen): SettingsRepository::getAllSettings() for export.
