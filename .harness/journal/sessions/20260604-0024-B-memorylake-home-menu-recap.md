# 20260604-0024 · Track B · Memory Lake → 首页 + menu rework + Monthly Recap page

Design ref: `MemoryLakeDesign/TimeArcDesign_v88.html` (Memory Lake Draggable Desktop
Prototype V5). Reproduce its menu + page split onto the desktop QML app.

## Goal (3 user instructions)
1. **Menu order/text → v88**: 首页/Dashboard · 日历/Calendar · 统计/Stats · 设置/Settings ·
   备忘/Notes · then **记忆湖/Memory Recap pinned at the bottom (separated)**.
   - Memory Lake dashboard becomes 首页 (index 0). 我的(Profile) relabel → 设置(Settings).
   - Old project/timer home (`DesktopHomePage`) drops out of nav (user chose full v88 align).
2. **Monthly Recap → own page** at the bottom menu item. Extract `RecapOverlay` host into a
   new full page; remove the recap CTA + overlay from the Memory Lake page.
3. **Three v88 panels onto the (new home) Memory Lake page**:
   - **A** Today Conclusion **replaces** the left-panel Monthly-Recap CTA slot.
   - **B** middle card carousel **untouched**.
   - **C** Daily Usage Share (饼图) + Calendar Sync (今日事项) on the right panel; per the
     user's choice the **DetailPanel is removed** so right = [pie · 使用时间图 · 今日事项].

## Approach (backend assembles, QML renders — rule 07 §3)
- `DailyCardService::memoryLakeDay` (additive only, no .h change): add `usageShare` (top-4 +
  其他 slices w/ percent) and `todayConclusion` ({kicker,title,desc,total,chips}); peak-hour
  window computed from passed-in `segments`. Todo-count chip is added in QML from
  `calendarManager` (DCS must not link USM/calendar symbols — see [[timearc-data-path]]).
- Shell nav becomes page-keyed (`page:` field), order-independent: `currentPageSource` +
  `onMemoryLake` + signal wiring all keyed off `page`, not magic index. Bottom item pinned
  via fillHeight spacer. English subtitles added under labels to match v88.
- New full page `DesktopMonthlyRecapPage` builds the recap model (moved from Memory Lake page)
  and hosts `RecapOverlay` opened=true; `RecapOverlay` gets a `exitRequested()` signal →
  page emits `requestNavigate("memorylake")` → shell switches nav.

## Files expected to change
- `src/services/daily_card_service.cpp` (additive map keys; file-local peak-hour helper)
- `qml/desktop/DesktopAppShell.qml` (menu rework, page-keyed routing, full-bleed for recap)
- `qml/desktop/pages/DesktopMemoryLakePage.qml` (left Today Conclusion, right pie+今日事项,
  remove DetailPanel/recap overlay/buildRecap)
- `qml/desktop/memorylake/RecapOverlay.qml` (add `exitRequested()` signal)
- NEW `qml/desktop/pages/DesktopMonthlyRecapPage.qml`
- NEW `qml/desktop/memorylake/{TodayConclusionCard,DailyUsageShare,CalendarSyncList}.qml`
- NEW `resources/icons/{settings,recap}.svg`
- Register new QML in `qml/CMakeLists.txt`; new SVG in `resources/CMakeLists.txt` (non-frozen)
Frozen files: NONE. `src/service/`: UNTOUCHED. Disk contract: UNTOUCHED.

## Smoke path
Build via `python .harness/tools/build.py`. Launch → lands on 首页 = Memory Lake (cards +
left Today Conclusion + right pie/时间图/今日事项, all real data, empty-state when none).
Menu reads 首页·日历·统计·设置·备忘 then 记忆湖 at bottom; 记忆湖 opens full Monthly Recap
page; 返回湖面/Esc returns to 首页. `scan_qt_log.py`; `harness_check.py` before commit.

## Errors / mismatches
Any implement-time mismatch → `record_error.py` (L1 build / L2 runtime-QML / L3 premise).
No fake data; missing data → empty state.
