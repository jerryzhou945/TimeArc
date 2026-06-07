# Error Report - memorylake-responsive-minmax

## Metadata

- Level: **L2**
- Track: **C**
- Topic: memorylake-responsive-minmax
- Recorded: 2026-06-06T16:23:09Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Memory Lake page (首页) breaks at window min 1280x720 and max 1920x1080: (1) sidebar top-nav collides with bottom 记忆湖+companion card; (2) TodayConclusionCard desc text overlaps chips (fixed 204h too short); (3) MemoryCard fixed 310x440 overflows small cards-zone; (4) full-width 64% water line streaks across zone at max. Plus StickyNote due-date row too small/gray (visual).

## 2. Evidence

Reproduced via PrintWindow(flag2) capture of a dedicated instance at 1280×720
and maximized 1920×1080 (`.harness/tmp/repro_minmax.py`). Before-fix crops:
sidebar 备忘/记忆湖 text printed on top of each other; 今日结论 gray desc text
overlapping the chip row; selected card (310×440) filling the whole ~298×370
cards-zone; a full-width aqua water-line streaking the empty cards-zone at max
(empty-left band mean 14.3 / max 23 vs background 14).

## 3. Root cause

- Immediate cause: The Memory Lake page is built from fixed pixel sizes
  (panels 300/310, briefing 204, card 310×440, water line = full lane width,
  sidebar two opposed anchored Columns) that were tuned for ~1440 width and do
  not adapt when the window shrinks to the 1280×720 floor or stretches to max.
- Underlying cause: independent top/bottom anchoring (sidebar columns; briefing
  top text vs bottom chips) overlaps once content no longer fits the fixed gap;
  decorative full-width lines streak once the zone is much wider than a card.
- Why the harness/checklists did not prevent it: no min/max responsive check in
  the UI checklist; 1280×720 was assumed "barely works" but never verified.

## 4. Fix

- Files changed: `qml/desktop/DesktopAppShell.qml` (hide companion card when
  sidebar too short), `qml/desktop/memorylake/TodayConclusionCard.qml`
  (adaptive implicitHeight), `qml/desktop/pages/DesktopMemoryLakePage.qml`
  (briefingActualH + briefCollapse factor; centered/clamped 50% line),
  `qml/desktop/memorylake/CardCarousel.qml` (fitScale on track + clamped water
  line + dots positioned below scaled card), `qml/desktop/memorylake/StickyNote.qml`
  (due-date pill: self-drawn clock + stronger ink, tokens from MemoryLakeStyle).
- Short description: make the Memory Lake layout adapt to window min/max and
  constrain full-width decorative lines; redesign the memo due-date row.
- Commit: pending commit.

## 5. Prevention

Add a min-window (1280×720) + maximized screenshot pass to the UI before-commit
checklist for any change to a full-bleed page, captured via the existing
PrintWindow harness. (Noted for `checklists/before-commit.md`.)
