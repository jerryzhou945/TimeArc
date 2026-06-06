# Session 20260606-0837 · Track B · Calendar v88 dark-glass reskin

## Track
B (Feature) — reskin `qml/desktop/pages/DesktopCalenderPage.qml` from the legacy
cream/`Soft*` theme to the memory-lake dark-glass neon language. Observable
behaviour change (Monday-start, time/type fields, new panels) → Track B.

## Source of truth / plan
- `docs/calendar-refactor-functional-replication.md` (behaviour/state/data, C0–C14)
- `docs/calendar-refactor-render-pipeline-replication.md` (art/lighting, M-B)
- `MemoryLakeDesign/TimeArcDesign_v88.stripped.html` (calendar CSS 9109–9606)

## Locked decisions
- **D-ROUTE**: keep the routed full-page Loader; opaque dark-glass base replaces
  `backdrop-filter` (no 4th blur).
- **D-KEEP**: preserve anniversaries/countdown, day photos, records-timer tab on
  the v88 3-column layout.

## Isolation
Worked in a dedicated git worktree (`F:/Git Proj/TimeArc-cal`, branch
`feat/calendar-v88-reskin` off `origin/dev`) because the main checkout was being
branch-switched live by the fork-sync workflow. PR #22 → fork `dev`.

## Batches (one commit each)
- **F-B1** ml token migration + dark-glass page base (RoundedFrame r26 + gradient
  + 42px GridTexture + 2 corner GlowCircle). Local `MemoryLakeStyle` bound to the
  injected theme contract. Calendar tokens appended to `MemoryLakeStyle.qml`.
- **F-B2** Monday-start `buildCalendarCells` ((getDay()+6)%7) + hairline ledger
  month view (RoundedFrame, no fill, light states) + translucent GlassPanel topbar.
- **F-B3** cell event chips (cap3 + N more, 3 type colours) + todo time/type
  free-JSON fields + right-panel GlassPanel + segmented mode switch + event-form +
  SilkyFlickable agenda. `buildCalendarCells` hoists maps (42×→1× JSON parse).
- **F-B4** left column: brand FrostCard + 4 view tabs (month real, others honest
  placeholder) + 2×2 stats (今日事项/完成率 real; 专注块/本周任务 占位, A5).
- **F-B5** selected-day card (photo hero, RoundedFrame) + records/anniversaries
  reskin + open animation (easeSnappy) + bottom-centre toast + light-mode pass.

## Boundaries held
- Zero new C++; `calendar_manager.{h,cpp}` API unchanged → no frozen-file proposal.
- `startTodoProject(4-arg)` + `completeTodo(dateKey,text)` signatures preserved (G5).
- `DesktopCalendarAnniversaryData` Settings category byte-stable (G9).
- UI-private persistence only; disk contract (`usage_records.jsonl`) untouched (G4).
- All colour via `ml.*` tokens; only `tagColor()` fixed semantic colours retained (G1).
- Rounded+opaque content uses RoundedFrame FBO mask, never `clip:true` (G7).

## Verification
Each batch: kill exe → `build.py` (exit 0) → launch on calendar (temp
`selectedIndex=1`) → CopyFromScreen capture → log inspect → revert temp shell edit.
Night + day modes both captured. Records/anniversaries/placeholder views captured
via temp side-mode/view defaults. Cell chips verified via throwaway `qml.exe` mock
(no user data touched — DB seed was correctly denied by the sandbox).

## Conformance (C0–C14)
C0 build clean ✓ · C1 dark base+grid+glow, rounded via RoundedFrame ✓ · C2 3-col ✓ ·
C3 Monday 42-cell 4-state ✓ · C4 chips cap3+more 3 colours ✓ · C5 CRUD via
calendarManager ✓ · C6 startTodoProject 4-arg intact ✓ · C7 anniversaries +
category kept ✓ · C8 records + photo hero (RoundedFrame) ✓ · C9 month real, others
placeholder (no fake view) ✓ · C10 ml tokens night/day ✓ · C11 open anim + toast ✓ ·
C12 今日事项/完成率 real, 专注块/本周任务 占位 ✓ · C13 memo→calendar tool = deferred B ·
C14 static-grab walkthrough (Win32 automation unstable) ✓.

## Notes / follow-ups
- **Native-style warnings**: `ComboBox`/`TextField` custom-background emit the Qt
  "current style does not support customization" advisory. Pre-existing app-wide
  class (also on Home/Pomodoro/StickyNote); custom styling visibly applies; dropping
  the per-item `CheckBox` made the calendar's count comparable-or-lower than before.
  Clean app-wide fix = `qtquickcontrols2.conf` `Style=Basic` — out of scope here.
- **CLAUDE.md** registration of the two calendar docs into Product Context is a
  recommended follow-up (the editor blocked it as agent self-config modification).
- `harness_check` pass-5 journal-hygiene drift (115 missing error reports) is
  pre-existing on `origin/dev`, unrelated to this diff. Pass 2/3/4/7 clean.
