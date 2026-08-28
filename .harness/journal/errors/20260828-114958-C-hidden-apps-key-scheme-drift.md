# Error Report - hidden-apps-key-scheme-drift

## Metadata

- Level: **L2** | Track: **C** | Platform: macos
- Topic: hidden-apps-key-scheme-drift | Recorded: 2026-08-28T11:49:58Z
- Session: `20260828-1747-C-stats-day-window-clip`
- Tooling: Claude Code (Opus 5); sqlite3 + throwaway harness on the real read layer

## 1. What happened

Per-app hiding silently stopped working. hidden_apps stores the group key that was current when the user hid the app; the rule table since changed loginwindow's identity from the legacy exe:loginwindow to app:macos-shell, so the stored key matched nothing and the app kept being counted everywhere.

## 2. Evidence

Reported as "I disabled loginwindow and it is still there". The GUI settings DB
holds exactly what the user checked:

```
hidden_apps = ["exe:usernotificationcenter","exe:loginwindow"]
```

Driving the real read layer with that stored value, nothing was hidden and the
app was counted in full:

```
groupKey            name           lifetime   hidden?
app:macos-shell     macOS Shell     74.93h    (blank)
```

`app:macos-shell` is what `com.apple.loginwindow` resolves to today, via the
rule in `default_rules.h`. `exe:loginwindow` is what
`Categorization::fallbackIdentity()` produces when **no** rule matches —
`normalize(display_name)` of "loginwindow". The stored key is therefore a
fossil from before that rule existed, and matched nothing.

## 3. Root cause

- Immediate cause: hidden-ness was tested with a single equality —
  `m_hiddenKeys.contains(key)` in `effectiveGroupKey()`, the three trend loops,
  the focus loop, and `allApps()`'s `hidden` flag — against whichever key the
  current rule table produces. A stored key from an older scheme matches none
  of them.
- Underlying cause: `hidden_apps` persists a *derived* identifier. Group keys
  are an output of the rule table, and the rule table is edited by users and
  shipped with updates, so the key for a given app is not stable over time.
  Nothing owned the job of keeping stored keys in step, and the failure is
  silent in the worst direction: the app quietly returns to every total.
  `fallbackIdentity()`'s own comment says stored keys "survive the upgrade",
  which is true only while no rule ever starts matching an app.
- Why the harness did not prevent it: no rule says a persisted identity must be
  migrated when its derivation changes, and no test hides an app under a legacy
  key and asserts it stays hidden.

## 4. Fix

- Files: `src/services/usage_stat_manager.{h,cpp}`,
  `qml/desktop/DesktopAppShell.qml`,
  `qml/desktop/pages/DesktopProfilePage.qml`,
  `tests/stats_day_window_clip_static_test.py`.
- Short description: two halves, because either alone is not enough.
  **Read side** — `activityAliases()` enumerates every key one app can resolve to
  (rule key with title, app-level key without it, the legacy `fallbackIdentity`,
  and the `exe:` key `mergeSimilar = false` produces); `isHiddenActivity()`
  matches the hidden set against all of them, and every former single-key test
  now calls it, including `allApps()`'s `hidden` flag so the settings checkbox
  reflects reality. The app-level alias means hiding a browser also hides its
  `site:*` children — what "disable this app" should mean. **Settings side** — `canonicalHiddenKeys()` rewrites stored
  legacy `exe:` / `path:` keys to the current identity, and the shell and the
  settings page write the canonical list back once at startup. Without this the
  read side would hide correctly but *unhiding* could not: the UI removes the
  current key and the fossil would keep matching forever. `app:` / `site:` keys
  are left alone — a site key means a site, and must not widen to its host app.
- Verification (real read layer + real DB, using the user's actual stored value):
  ```
  canonicalHiddenKeys(exe:usernotificationcenter, exe:loginwindow)
                   -> (exe:usernotificationcenter, app:macos-shell)
  app:macos-shell  9.11h  HIDDEN
  2026-08-03  4.59h -> 3.04h   (SQL, excluding the shell group: 3.042h)
  ```
  `exe:usernotificationcenter` is preserved rather than dropped: no record in
  this DB resolves it, so there is nothing to map it to, and discarding an
  unrecognised key would silently unhide an app the user hid on another machine.
- Commit: pending commit

## 5. Prevention

`tests/stats_day_window_clip_static_test.py` section 4: `activityAliases()` must
include `fallbackIdentity`, no read path may test the hidden set with a single
key again (three `m_hiddenKeys.contains(...)` shapes rejected), and both QML
settings surfaces must call `canonicalHiddenKeys`. Confirmed to fail when
`isHiddenActivity()` is reduced to one key.

The general lesson, worth a rule: **a persisted key derived from editable data
needs a migration path at the point of derivation.** `app_display_name_overrides`
keys the same way and holds `{"app:terminal":…, "exe:goodnotes":…}` on this
machine. It still works only because no rule matches GoodNotes yet — the day one
ships, that override dies the same silent death. Latent, not broken; not fixed
here (out of scope). Filed to `state/open-issues.md`.
