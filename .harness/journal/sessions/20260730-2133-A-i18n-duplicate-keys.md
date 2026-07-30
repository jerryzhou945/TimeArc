# Session Log — A-i18n-duplicate-keys

## 1. Metadata

- Agent: Claude (Claude Code)
- Track: **A (Stabilize)** — UI strings only, resolved translations unchanged.
- Date: 2026-07-30 21:33 → 21:45 (local)
- Branch: `development/macos-support`
- Baseline commit: `17fb4b0` (+ uncommitted hotkey work already in tree)

## 2. Goal

Collapse the duplicate keys in `qml/desktop/components/I18n.js` so no translation
is dead code, without changing a single string on screen.

## 3. What was wrong

`en` held 608 entries for 523 distinct keys — 84 keys declared twice (one, `记录`,
three times). Two pasted blocks account for most of it: settings-page strings at
L427–469 repeating L357–420, and the stats-card labels at L497–526 repeating
L104–153, plus a memo/timer tail at L574–581. `ja` had two (`取消`, `返回首页`).
A JS object literal keeps the **last** value, so every earlier copy was unreachable
and 15 pairs had drifted — someone edited the first copy and the UI never changed.

## 4. What I did

- Kept the **first** occurrence's position (that is where the file's section
  grouping lives) and gave it the **last** occurrence's value, then deleted the
  later lines. 87 lines removed, 15 first-copy values overwritten.
- Policy for the 15 conflicts: the later value ships today, so it wins unless the
  earlier is clearly better. None was, so all 15 kept the shipping string — this
  makes the diff provably behaviour-neutral. Two are defensible either way and are
  logged as follow-ups rather than silently changed (§7).
- Spot-checked one against its call site: `多个应用` is interpolated into
  `insightMain` mid-sentence (`DesktopStatsPage.qml:473`), so the later lowercase
  "multiple apps" is the correct one, not the earlier "Multiple apps".
- Added `tests/i18n_duplicate_keys_static_test.py`: counts keys per table, fails on
  any repeat, and also asserts every `ja` key exists in `en`. Anything it cannot
  parse (multi-line or single-quoted entry) is a failure rather than a silent skip.
- `tests/i18n_settings_dialog_static_test.py` carried a docstring saying duplicates
  exist "today"; updated to point at the new guard.

## 5. Verification

- `tests/i18n_duplicate_keys_static_test.py` — PASS (en 523, ja 191, sentencesEn 56,
  sentencesJa 40, menuEn 32, menuJa 32; zero duplicates).
- Negative check: the same test on the pre-change file fails with "en declares 84
  duplicated key(s)", so the guard actually bites.
- The rewrite script asserted `resolved(before) == resolved(after)` per table —
  the key → value map JS would build is byte-identical, so no visible string moved.
- `tests/i18n_settings_dialog_static_test.py` — PASS (unchanged behaviour).
- `python3 .harness/tools/build.py` — success, 0 warnings; `qmlcachegen` compiled
  `I18n.js`, which is a real parse of the edited file.

## 6. No-behavior-delta statement

Observable behavior unchanged; the resolved translation table is identical before
and after (asserted programmatically), so no journal or UI output can differ.

## 7. Follow-ups (not done — they would be visible changes)

- `年度总使用` ships as "Year Total" while its siblings are "This Week Total" /
  "This Month Total". The deleted copy said "This Year Total". The year card is
  internally parallel ("Year Total" / "Year Focus"), so both readings are coherent
  — a product call, not a cleanup.
- `纵轴 0–24 时` ships as "Y-axis 0-24h" with an ASCII hyphen; the deleted copy
  used the en dash that matches the Chinese ("0–24h axis").

## 8. Outcome

**Done.** Files touched: `qml/desktop/components/I18n.js`,
`tests/i18n_duplicate_keys_static_test.py` (new),
`tests/i18n_settings_dialog_static_test.py` (comment). No frozen files.
