# Error Report - display-name-override-key-drift

## Metadata

- Level: **L2** | Track: **C** | Platform: macos
- Topic: display-name-override-key-drift | Recorded: 2026-08-28T12:57:49Z
- Session: `20260828-1747-C-stats-day-window-clip`
- Tooling: Claude Code (Opus 5); sqlite3 + throwaway harness on the real read layer

## 1. What happened

app_display_name_overrides has the same key-drift exposure as hidden_apps (stored group keys stop matching when the rule table changes an app's identity), and the map was only pushed into UsageStatManager by the settings page, which pageLoader instantiates on demand, so custom names did not apply until the user opened settings once per session.

## 2. Evidence

Spun out of [`hidden-apps-key-scheme-drift`](20260828-114958-C-hidden-apps-key-scheme-drift.md)
§5, which predicted this map had the same exposure. It does. On this machine:

```
app_display_name_overrides = {"app:terminal":"Terminal","exe:goodnotes":"Goodnotes"}
```

`exe:goodnotes` is a legacy fallback key. It still works only because no rule
matches GoodNotes yet — nothing in `default_rules.h` does. Reproduced with an
app that *does* have a rule now, which is the state GoodNotes reaches the day
one ships:

```
stored {"app:terminal":"Terminal", "exe:loginwindow":"Lock Screen"}
before: app:macos-shell shows "macOS Shell"   <- override silently ignored
after : app:macos-shell shows "Lock Screen"   custom="Lock Screen"
canonicalDisplayNameKeys -> {"app:macos-shell":"Lock Screen","app:terminal":"Terminal"}
```

Second, separate defect found while wiring it: `setAppDisplayNameOverrides()`
was called from exactly one place — `DesktopProfilePage.onCompleted`. The shell
builds one page at a time through `pageLoader`, so in any session where the user
never opened Settings, every renamed app showed its default name on Home, Stats
and Memory Lake.

## 3. Root cause

- Immediate cause: the override map was looked up by a single key
  (`m_displayNameOverrides.value(aggregate.groupKey)` and two siblings), and it
  was pushed into the manager only by the settings page's `onCompleted`.
- Underlying cause: the same one as `hidden_apps` — a *derived* identifier is
  persisted, and group keys are an output of an editable rule table. This map
  fails more quietly than hiding did: a rename that stops applying looks like
  the user never made it, so there is nothing to notice.
- Why the harness did not prevent it: the previous report named this exposure
  and filed it; nothing enforced it. Also, no rule says UI-private read-layer
  state must be pushed from a surface that always exists (the shell), not from
  a page the router may never instantiate.

## 4. Fix

- Files: `src/services/usage_stat_manager.{h,cpp}`,
  `qml/desktop/DesktopAppShell.qml`,
  `qml/desktop/pages/DesktopProfilePage.qml`,
  `tests/stats_day_window_clip_static_test.py`.
- Short description: `displayNameOverrideFor()` looks the map up through
  `activityAliases()` (current key first, legacy last, so a stale key never
  shadows a fresh one), replacing all three single-key lookups.
  `canonicalDisplayNameKeys()` rewrites stored legacy keys to current identities,
  dropping a legacy entry when the current key is already present — the current
  one is the more recent rename. The `legacyKeyMap()` helper is now shared with
  `canonicalHiddenKeys()`. The shell gained
  `applyDisplayNameOverridesFromSettings()`, called beside the read filters at
  startup, which both canonicalizes-and-writes-back and pushes the map, so
  renames apply without visiting Settings.
- Verification: legacy-key override resolves onto the current identity, and the
  rendered result is byte-identical before and after canonicalization (the read
  side and the write side agree, so canonicalizing is safe and idempotent).
  Full sweep: 31/31 static, `ctest` 3/3, `build.py` clean.
- Commit: pending commit

## 5. Prevention

`tests/stats_day_window_clip_static_test.py` section 5: the alias-aware lookup
and `canonicalDisplayNameKeys` must exist, the three single-key lookups are
rejected by name, and the shell must both push and canonicalize. Confirmed to
fail when one lookup is reverted.

Both persisted-key maps are now covered. The rule worth writing in
`rules/04-ui-conventions.md` is the generalisation this session earned twice:
**a persisted key derived from editable data needs a migration path at the point
of derivation, and UI-private read-layer state is pushed from the shell, not
from a routed page.** Filed to `state/open-issues.md`.
