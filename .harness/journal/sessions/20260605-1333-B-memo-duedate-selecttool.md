# 20260605-1333 · Track B · memo due-date picker + select tool

Branch `feat/memory-lake-memo` (PR #14). Two requested features on the memo
overlay. UI-private QML only under `qml/desktop/memorylake/`; no service /
disk-contract / IPC. dev at `0e637ad`.

## Feature 2 — sticky due date/time (done)
Sticky's bottom date line becomes an **editable due date + 24h time** for
deadline todos (later consumed by the calendar rebuild + home 今日事项).

- New `MemoDatePicker.qml`: self-drawn mini calendar (month nav, Mon-first
  weekday row, 6x7 day grid) + 24h hour:minute steppers + 清除/确定. No
  `Qt.labs` module (avoids availability risk; fully themeable). Centered popup
  with scrim; click-outside dismisses. Order-independent init (open/initialMs).
- Sticky: `due` property + `dueEditRequested()`; date line shows
  "截止 yyyy-MM-dd HH:mm" or "＋ 设置截止时间", click opens picker.
- New model role `odue` (epoch ms, 0=unset) round-trips through save/load and
  undo snapshots. MemoOverlay mounts one picker singleton, writes odue + live
  obj on 确定/清除, schedules save + records undo.
- Registered MemoDatePicker in qml/CMakeLists.txt; rules/04 §8 updated.

## Feature 1 — transform / select tool (in progress)
Marquee-select **ink region + stickies + text**, then delete / copy / move /
scale the selection (no whole-board zoom — chosen scope). See follow-up commits.

## Verify
`build.py` green; date picker checked via qml.exe probe (lands on the right
day + time, weekday alignment correct). Manual in-app QA still the user's pass.
