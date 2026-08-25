# Session Log — English-first i18n inversion

## Metadata

- Agent / Author: Claude Code
- Track: **B (Feature)**
- Date: 2026-08-25 21:30 → 2026-08-26 00:40
- Branch: `feature/ui-statistics`
- Baseline commit: `0adb8a6`

## Goal

Invert the UI language architecture: English becomes the source for every
user-visible string, with Chinese and Japanese as translation tables. Scope
agreed with the user: visible text only (comments untouched), full Japanese, and
the C++ prose/regex bridge replaced by structured fields.

## Why

`I18n.js` keyed on Chinese source strings, so English mode needed a dictionary
hit for every string and a missing key rendered raw Chinese. 38 shipped that way;
the journal carries two incidents (`i18n-residual-chinese-copy`,
`i18n-confirm-dialog`). Japanese covered 232 of 579 keys, and `qml/mobile/` had
no language plumbing at all. English-first makes `t()` an identity for English:
a missing key can now only surface an untranslated string, never a wrong-language
one. `src/services/categorization/` already worked this way (`rule.h:120`
requires an `"en"` label), so this extends a house pattern rather than inventing
one.

## Shape of the change

1,144 distinct Chinese literals over ~1,567 sites; the old `en` table inverted
for free into English→Chinese, and 626 English strings were authored.

- `I18n.js` rebuilt English-keyed, moved to `qml/shared/` for mobile.
- `smartText()` deleted — it recovered fields from finished prose with regexes.
  `daily_card_service` now emits a template key plus fields; QML composes.
- Weekday/month/date helpers replace eight per-language ternaries that had been
  giving Japanese the Chinese labels.
- `tests/i18n_source_coverage_static_test.py` added.

## Data contract

`tags.name` held the eight shipped tags as data, but `manual_projects` refers to
them by integer `tag_id`, so `renameLegacyChineseTags()` renames the rows in
place before `insertDefaultTags()` and every project keeps its tag. Guarded on
the English name not already existing, so a user-made "Other" is left alone
rather than hitting the UNIQUE constraint. `schema_migrations` exists but has no
runner, so this is an idempotent guarded statement at the existing insertion
point, not a new framework. No service, schema-shape or jsonl change.

## Errors filed

- L1 `build-failure` — a scripted edit left `title`/`titleParams` undefined.
- L3 `i18n-js-blind-spot` — rewrite and new test both walked only `.qml`, so
  `TagPalette.js` kept matching Chinese and every tag rendered grey.
- L2 `i18n-category-label-locale` — `categoryName()` hardcoded `"zh"`, correct
  until the downstream re-translator was removed.

## Completion

No Chinese string literals remain in `qml/` or `src/` outside three allowlisted
files, each with its reason in the coverage test: `macos_status_bar_icon.cpp`
(own zh column; QCocoa cannot reach I18n.js), `AppVisual.js` (needles matching
OS-reported app names), and `I18n.js`. `zh`/`ja` are symmetric at 1126 keys,
with 107 sentence templates in all three languages.

Last round closed `MobileMonthProfiles.js` (36), `StatsViewModel.js` (19, now
emitting template keys so it stays free of I18n) and `mobile_usage_service.cpp`
(8 `M月d日` patterns, now numeric parts formatted per language).

## Verification

- `build.py` success; `harness_check.py` clean; 33/33 Python tests pass.
- `stats_view_model_test.js` was rewritten for the new shapes but needs Node,
  which is absent. Its logic ran instead under Qt's own JS engine via a
  scratchpad QML harness: 21 assertions covering the view-model output and the
  rendered sentences in en/zh/ja, all passing.
- `windows_executable_icon_test.py` now skips when `build/TimeArc.exe` is
  absent instead of raising: meaningful on Windows, inert elsewhere.
- Two README assertions went stale when 0adb8a6 rewrote README.md. Both
  behaviours are real, so the docs were restored and the needles updated.

**Language names.** Settled by the owner: language rows are endonyms everywhere — 简体中文 / English
/ 日本語. The macOS menu bar had listed them by English name, contradicting its
own comment that names stay in their own language;
`macos_menu_bar_static_test.py` now pins the endonyms and forbids `tr()` on
them. The dead `"Chinese"`/`"Japanese"` table entries were removed.

## Runtime verification

The app was launched against the finished tree. The clean run produced **no Qt
warnings at all** — the message-handler log stayed empty, so no TypeError or
ReferenceError on Memory Lake, the landing page whose Today Conclusion card had
shown the mixed-language headline. `scan_qt_log.py` consumed the accumulated
log: its `smartText` TypeErrors are from this session's broken intermediate and
are fixed; its `ReferenceError: root` in `DesktopProfilePage.qml` predates the
session (12:46Z vs 13:30Z start).

Still unverified: no page beyond the landing page was navigated to.
