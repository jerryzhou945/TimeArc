# Categorization Redesign

## Goal

Replace four overlapping, hand-maintained categorization sources with one
English-first rule table that ships as a hardcoded default, is fully editable
by the user, works identically on every platform and in every UI language, and
derives its colors from icons the app already renders.

## Why replace the current system

Categorization today is spread across four places that must be edited together
and can silently disagree:

| Source | Shape | Problem |
|---|---|---|
| `src/services/adapters/` (19 headers, 3 registries) | C++ literals | adding one app touches 2–4 files |
| `src/services/site_catalog.h` | C++ literals, 28 sites | duplicates adapter entries with different display names |
| `classifyActivityImpl` keyword ladder | C++ if-chain | Windows `.exe`-centric; unreachable on macOS bundle ids |
| `DailyCardService::classifyApp` | C++ if-chain | crude fallback; `has("game")` is the false-positive class the ladder was rewritten to avoid |

Consequences visible today: browser site attribution never fires on macOS
because every browser test spells `chrome.exe`; categories are raw Chinese
string literals used as map keys, so the site-catalog-only ones have no English
label at all; and ~47 brand colors are hand-maintained next to icons that
already carry the same information.

## Decisions

- **D1.** One rule table. Identity, category, label and icon come from the same
  record. `adapters/`, `site_catalog.h`, the ladder, and `classifyApp` are
  deleted.
- **D2.** Identity text is `display_name` ∪ `app_id`. `app_id` is included
  because it is the only field that is never localized on either platform.
- **D3.** English-first. `label.en` is required, other locales optional and
  fall back to English. Machine ids stay ASCII.
- **D4.** Defaults are hardcoded in C++ and seeded into the database **eagerly
  on first run**, filtered to the apps the service has actually recorded and
  bound to the names it recorded them under.
- **D5.** The stored set is the only source; there is no delta layer and no
  builtin-versus-user precedence. `Reset to defaults` re-derives from current
  tracking data instead of restoring a fixed table, and is always available.
- **D6.** The stored form is simpler than the built-in form: no icon, no color,
  no locale map. `name` exists only when the user typed one.
- **D7.** Colors are inferred from icons, not stored. User-picked colors win.
- **D8.** Classification stays single-valued. Multi-membership belongs to
  tags/projects, which already exist.
- **D9.** No service change. This is entirely a UI read-layer feature.
- **D10.** Rule ids keep the legacy `app:` / `site:` colon separator. Stored
  `hidden_apps` and `app_display_names` are keyed by group key, so a new
  separator would silently orphan every existing user preference.

## Alternatives Considered

1. **Delta storage — store only overrides, disables and pins (rejected).**
   Needs four override mechanisms, two layers, and layer-aware tie-breaking.
   Full materialization collapses all of it into one editable list.
2. **Category-oriented storage — each category owns its members (rejected).**
   Isomorphic to a flat rule list with a category reference, but worse to edit
   (moving a rule is a splice across two arrays) and it invites per-category
   priority, which is too coarse to express "YouTube in a browser beats Chrome".
   Adopted as a *view* instead; see UI.
3. **Regex needles (deferred).** Contains/exact/word covers the shipped table.
   Regex invites unreadable rules and pathological backtracking on every record.
4. **Keeping window titles out of matching entirely (rejected).** Titles are the
   only signal that separates YouTube from Chrome. They are made safe by
   scoping instead; see Resolution.

## Model

### Input

Two fields from the service database, plus one for identity stability:

| Field | Windows | macOS |
|---|---|---|
| `app_id` | full executable path | bundle id (`com.google.Chrome`) |
| `display_name` | executable basename (`chrome.exe`) | `localizedName`, varies by system language |
| `window_title` | window title | AX title; media title on `media_sessions` rows |

`identity = norm(display_name) ⧺ norm(app_id)`, `title = norm(window_title)`.

### Normalization

`norm()` is the whole cross-language story and is roughly fifteen lines:

1. NFKC — unifies full-width/half-width and CJK compatibility forms.
2. `toCaseFolded()` — not `toLower()`; handles Turkish dotless i, German ß,
   Greek final sigma.
3. Fold diacritics (NFD, drop combining marks) — `café` ≡ `cafe`.
4. Strip trailing `.exe` / `.app`.
5. Normalize dash variants and collapse whitespace.

Substring `contains` is the default primitive precisely because CJK and Thai
have no word boundaries. Needle syntax is three-valued:

- `foo` — contains
- `=foo` — equals one whole component (`display_name` **or** `app_id`, never
  the joined identity text)
- `word:foo` — Latin word boundary

Identity is one haystack for `contains` and two components for `=`. A `contains`
needle may hit either half, which is what lets a single flat array hold a bundle
id, an executable name and a localized name at once; an `=` needle must equal a
component outright, so it can express "this exact app and nothing else".

### Rule — built-in form

Hardcoded in `src/services/categorization/default_rules.h`, read-only, shipped.

```cpp
{ .id="app:wechat", .category="social",
  .app={"com.tencent.xinwechat","wechat","weixin","wechat.exe","微信"},
  .label={{"en","WeChat"},{"zh","微信"}},
  .icon="apps/wechat.png" }

{ .id="site:youtube.chrome", .category="video",
  .app={"com.google.chrome","google chrome","chrome.exe"},
  .title={"youtube","youtu.be"},
  .label={{"en","YouTube"}},
  .icon="sites/youtube.png" }
```

`label` and `app` are different kinds of data. `label` is presentation and is
English-first with optional locales. `app` is match data and is *polyglot by
necessity* — it must contain whatever the OS reports, including localized
macOS display names. It is a flat array with no locale keys.

### Rule — stored form

One entry in the materialized set.

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | `app:wechat` from a default, `user.<ts>` when created |
| `ref` | string | no | id of the default it came from; absent for user-created |
| `name` | string | no | **only when the user renamed it**; otherwise resolved from `ref` |
| `category` | string | yes | category id |
| `app` | string[] | no | needles matched against identity text |
| `title` | string[] | no | needles matched against title text |
| `enabled` | bool | yes | false keeps the rule but stops applying it |
| `order` | int | yes | tie-break only, never the primary mechanism |

`name` being optional is what keeps the stored form simple without losing
localization: an untouched materialized rule resolves its label from `ref`
against the hardcoded table, so it still renders as `微信` or `WeChat` per UI
language. Once the user renames it, their word wins and localization stops for
that rule — which is correct, because it is now their word.

### Categories

Built-in: `{ id, label{en required, …}, traits[] }`. Stored:
`{ id, ref?, name?, color?, traits[], enabled }` — same `ref` rule as above.

Traits replace four hardcoded sets currently scattered across C++ and QML:

| Trait | Replaces |
|---|---|
| `focus` | the `{开发, 办公, 笔记}` literal in `focusStatsForWindow` |
| `entertainment` | `DailyCardService::isEntertainment` |
| `deprioritize` | the `系统` special cases in home rank, task-block naming, headline category |

Default set, English-first:

| id | en | zh | traits |
|---|---|---|---|
| `dev` | Development | 开发 | focus |
| `office` | Office | 办公 | focus |
| `notes` | Notes | 笔记 | focus |
| `create` | Creation | 创作 | — |
| `social` | Social | 社交 | — |
| `video` | Video | 视频 | entertainment |
| `music` | Music | 音乐 | — |
| `game` | Games | 游戏 | entertainment |
| `browse` | Browsing | 浏览 | — |
| `read` | Reading | 阅读 | — |
| `shop` | Shopping | 购物 | — |
| `system` | System | 系统 | deprioritize |
| `other` | Other | 其他 | — |

### Colors

No color is stored in the built-in form. The machinery already exists:
`iconDominantColors()` (`src/services/usage_stat_manager.cpp:592`) extracts up
to three dominant colors from an icon, skipping transparent, near-grey and
near-black/white pixels, cached by path; `ambientTone()` / `coverTone()`
(`qml/desktop/components/AppVisual.js:92`) tune them into the design language;
`hashedColor()` (`:50`) is the stable per-identity fallback.

Rule color:

```
dominant(rule icon) → ambientTone   ??   hashedColor(rule.id)
```

Reading the *rule's* icon rather than the record's path also fixes a bug
currently worked around by blanking `iconColors` for every `site:*` group
(`usage_stat_manager.cpp:978`), where Bilibili picked up the host browser's
colors. A site rule owns its own icon, so the special case disappears.

Category color needs one more step, because a legend must be *distinguishable*,
not merely faithful:

1. representative = highest all-time-seconds member of the category
2. hue = dominant(representative icon).hue
3. snap to the nearest free slot on a fixed 12-hue ring (≥30° apart)
4. apply the tone curve
5. cache by category id; recompute only on materially changed membership
6. a stored `color` always wins

`other` and `system` stay neutral grey. `iconDominantColors` needs an on-disk
path and `QFileIconProvider`, so it is unavailable headless — the resolver must
stay total, with `hashedColor(id)` covering both that case and missing icons.
This deletes `categoryHeatBase()` from QML and ~47 hex literals from C++.

### Resolution

Single layer, two phases.

```
PHASE 1 — identity
  best     = highest-scoring enabled rule
  score    = 100 × conditions matched          // app-or-scope gate, title
           + 50  if the winning needle is `=`  // exactness bonus
           + len(longest matched needle)       // specificity within a tier
  ties     → lower `order` → id
  identity = best.id ?? fallback key derived from app_id

PHASE 2 — category
  cat = best.category ?? "other"
  if categories[cat].enabled == false          → "other"
  if auto_classify == false and !userTouched   → "other"
```

Counting conditions is what makes a title refinement beat a bare app match:
`site:youtube` (gate + title = 207) outranks `app:chrome` (gate only = 113), so
YouTube in a browser is Video and everything else in that browser is Browsing.
Longest-needle scoring is what makes `visual studio code` beat `code`, and the
exactness bonus is what lets a user's `=google chrome` rule outrank a broad
multi-browser rule without outranking title refinements. None of it depends on
ordering discipline in the table.

**A title needle may never match outside a scope.** This is the structural form
of the rule the current code discovered the hard way: a Chrome window titled
`"…game…"` cannot become Games, because no rule can match a bare title.

Two switch semantics change:

- `auto_classify: off` stops *inference* but leaves rules the user created or
  edited in force. Today it blanket-assigns `其他`. The new reading matches the
  switch's own label and makes it useful rather than destructive.
- `game_mode: off` becomes `categories.game.enabled = false`. The existing
  switch stays in the UI as a shortcut writing that flag; every category gains
  the same capability for free.

## Storage

### Seeded from tracking data

> Superseded. This section originally described a FOLLOWING/OWNED state machine
> where the row appeared on the user's first edit. Seeding is now eager and
> derived: the row is written on first run and holds one app-level rule per app
> the service has recorded, bound to the name it recorded. See
> [`categorization-system.md`](categorization-system.md) for the current model.

### The stored document

One row in the existing `settings` table (`database_manager.cpp:508`), key
`categorization`, value JSON. Atomic writes, matches how `hidden_apps` and
`app_display_names` already work, and the matcher reads the whole set into
memory anyway. If rule counts ever grow past a few hundred, promote `rules` to
its own table; the shape does not change.

```json
{
  "schema": 1,
  "fromDefaults": 7,
  "categories": [
    { "id": "social", "ref": "social", "traits": [], "enabled": true },
    { "id": "study", "name": "Study", "color": "#76B7F2",
      "traits": ["focus"], "enabled": true }
  ],
  "rules": [
    { "id": "app:vscode", "ref": "app:vscode", "category": "dev",
      "app": ["com.microsoft.vscode","visual studio code","code.exe","=code"],
      "enabled": true, "order": 120 },

    { "id": "site:youtube", "ref": "site:youtube", "category": "video",
      "scope": "@browser", "title": ["youtube","youtu.be"],
      "enabled": true, "order": 310 },

    { "id": "user.1756089600", "name": "arXiv", "category": "study",
      "scope": "@browser", "title": ["arxiv.org","arxiv"],
      "enabled": true, "order": 320 }
  ]
}
```

### New defaults after an upgrade

Full materialization means an Owned user stops receiving new default rules.
`fromDefaults` records the default-table version at snapshot time. When the
shipped version is newer, the Categorization card shows a non-blocking line —
`12 new default rules are available. [Review]` — and Review appends only
defaults whose `ref` id is absent, each with a checkbox. Never merge silently;
never withhold silently either.

## A single rule, end to end

### In the database

```json
{ "id": "app:vscode", "ref": "app:vscode", "category": "dev",
  "app": ["com.microsoft.vscode","visual studio code","code.exe","=code"],
  "enabled": true, "order": 120 }
```

### In the UI

Collapsed row:

```
┌────────────────────────────────────────────────────────────────────────┐
│ ●  VS Code                          [ Development ▾ ]  12 apps  ⦿  ⋯  │
│ ▏  app: visual studio code, code.exe, +2                               │
└────────────────────────────────────────────────────────────────────────┘
  │   │                                 │            │       │    └ Edit · Duplicate · Restore · Delete
  │   │                                 │            │       └ enable toggle → `enabled`
  │   │                                 │            └ live match count from the user's own records
  │   │                                 └ inline category dropdown → `category`
  │   └ `name` ?? localized(`ref`) ?? first app needle
  └ color dot: category color
```

Field-to-display mapping:

| Field | Rendered as |
|---|---|
| `name` / `ref` | row title |
| `category` | inline dropdown + color dot |
| `app` | `app: a, b, +n` |
| `title` | `title: a, b` |
| `scope` | `in browsers ·` prefix |
| `enabled` | toggle; disabled rows render at 45% opacity |
| `ref` present + fields differ from default | "modified" marker, `Restore` enabled |
| `ref` absent | `Restore` hidden, `Delete` only |

Summary line by rule shape:

| Shape | Summary |
|---|---|
| `app` only | `app: wechat, weixin, +2` |
| `app` + `title` | `app: chrome · title: youtube` |
| `scope` + `title` | `in browsers · title: arxiv.org` |

Edit form — four controls, one per model field:

| Control | Writes | Notes |
|---|---|---|
| Name | `name` | placeholder shows the inherited localized name; untouched leaves `name` absent |
| Category | `category` | picker over existing categories, plus inline `+ New category` |
| App matches | `app` | chip input, autocompleted from the user's own recorded values |
| Title matches | `title` | chip input |
| Applies in | `scope` | Anywhere / Browsers / Media players / Specific apps… |

**Save is disabled when Title is filled and Applies-in is Anywhere.** The
false-positive class is unreachable through the UI, not merely linted.

Below the form, a live preview lists which of the user's actually-recorded apps
and titles the rule would match, with counts and total time, and warns about
anything it would take from another rule. The data is already in memory
(`allApps()` + `m_records`), so it is a filter over a few thousand rows. It is
what makes the scoring model visible instead of mysterious.

## UI

### App Management card — inline assignment

The existing card keeps its search, chips and hide toggles, and each row gains
a category dropdown. It writes into the same rule list; there is no separate
pin concept.

1. Materialize if still Following.
2. Find the rule that currently matches this app.
3. **Matches only this app** → set that rule's `category`. One write.
4. **Matches several of the user's apps** → confirm:
   `The "Browsers" rule covers 4 apps. [Change all 4] [Only Google Chrome]`.
   "Only" creates a narrow rule with an exact needle on that app's identity,
   which outscores the broad one by specificity.
5. **No rule matched** → create `user.<ts>` with `app: ["=<display_name>"]`,
   `name` = the app's display name, category = the picked one.

The card also gains an `Uncategorized` filter: apps resolving to `other`,
sorted by recorded time. It is the fastest path from "the defaults don't know
my app" to a working rule, and the signal for what the shipped table is missing.

### Categorization card — grouped by category

Default view groups rules under their category; a flat/search view is the
toggle. Grouping is better for the three questions users actually have:
coverage ("what counts as Focus for me?"), placement of title and scope rules
(`arXiv (in browsers)` is not an app but is an unremarkable member of Study),
and categories as editable objects with their month's hours next to them.

```
▾ Development · 4 rules · 38h this month                    [ ⋯ ]
    ● VS Code          app: visual studio code, +3        12 apps  ⦿
    ● Terminal         app: windowsterminal, +4            3 apps  ⦿
    ● arXiv            in browsers · title: arxiv.org      1 app   ⦿
    + Add rule to Development
▸ Video · 7 rules · 11h this month
▸ Uncategorized · 12 apps with recorded time                 [ Review ]
```

Card-level actions: `Restore all defaults` (deletes the row, returns to
Following) and, when applicable, the new-defaults Review line. Import and
export are deliberately **not** here; they are separate functionality.

### Why this category?

Every category badge in the app gets a popover:

```
Development
  matched    app.vscode  ·  "visual studio code"  ·  score 312
  runner-up  app.terminal (score 205)
  [ change to… ]   [ edit rule ]
```

Rule systems feel arbitrary when opaque. This is what makes the model
inspectable, and `change to…` is a second entry point to inline assignment.

## Boundaries

### Category versus tag and project

Classification stays single-valued. Multi-membership would double-count every
sum in the app — pie percentages, focus totals, the heat map. The second axis
already exists as `tag_repository`, `manual_project_repository` and
`project_manager`.

| | Category | Tag / Project |
|---|---|---|
| Cardinality | exactly one per activity | many per activity |
| Assigned by | rules, automatically | the user, deliberately |
| Answers | "what kind of software was this?" | "what was I working on?" |
| Safe to sum | yes | no — overlaps by design |

### Privacy

Suggestions in the Uncategorized queue are **app-level only**. The app must
never mine observed window titles into proposed rules, because accepting one
would persist a fragment of the user's own titles. Title authoring stays in the
rule editor, where the user is looking at local data and types the needle
themselves. Titles remain classification-only: never displayed, never persisted
into a card, never sent to AI.

### Two-process contract

No service change, no schema change, no new sampling source. The collector keeps
emitting the same identity fields; the UI keeps reading them read-only.

## Validation and failure

- Row absent or empty → seed from records and write. Row present → parse,
  lint, use; re-seed automatically only when the set has never been user-edited
  and either it was seeded before any data existed or `seedVersion` advanced.
- Parse or lint failure → **fall back to hardcoded defaults and show a
  persistent banner** naming the error, with `Restore all defaults` beside it.
  Silent fallback is the one unacceptable outcome: the user's customization
  would appear to have evaporated.
- Lint on every write and on load: unknown `category`, duplicate `id`, `title`
  without `scope`, Latin needle under 3 characters without `=`, more than 32
  needles per rule, more than 500 rules, unknown `schema`.
- Stale `ref` (a default removed in a later release) is kept in storage and
  shown as "default rule removed" with a dismiss action. Dropping it silently
  loses user intent across an upgrade.

## Invalidation and retroactivity

Any write bumps `rulesGeneration` → clears the classify memo → bumps
`m_recordsGeneration` → emits `usageStatsChanged`. This is the path
`setReadFilters()` already uses.

Because categories are computed at read time and never stored on records, every
edit is **retroactive across all history, instantly**. This is worth stating in
the UI; users trained by other trackers will assume the opposite.

## Migration

Mechanical, one-time generation of the default table from the three existing
sources, then deletion of all four.

| Old category | New id |
|---|---|
| 短视频, 直播 | `video` |
| 知识 | `read` |
| 搜索, 网站 | `browse` |
| 购物 | `shop` |
| 生活, 支付, 应用 | `other` |
| everything else | direct 1:1 |

Windows-only ladder entries keyed on `.exe` names become `app` needles with the
suffix stripped, which then match on every platform. Entries that relied on the
executable path (Wuthering Waves ships as a generic `Client-Win64-Shipping.exe`)
are recovered for free: on Windows `app_id` *is* the full path, and `app_id` is
in the identity union.

Existing `hidden_apps` and `app_display_names` are untouched and keep working.

## Testing

- Golden fixture: `(app_id, display_name, window_title) → expected category`,
  one line per case, extended alongside each shipped rule. Must reproduce
  today's categories before any of the four sources is deleted.
- Customization fixture: `(stored document, input) → expected category`,
  covering materialization, rename, disable, delete, add, restore, disabled
  categories, and the `auto_classify` + user-touched interaction.
- Round-trip: a stored set serialized and reloaded resolves identically over
  the whole golden fixture, with labels rehydrated through `ref`.
- Linter unit tests, including unscoped-title rejection.
- Normalization tests: NFKC width folding, case folding for tr/de/el,
  diacritics, `.exe`/`.app` stripping.

## Rollout — status

1. **Done.** Loader, matcher, hardcoded English-first table (137 rules,
   13 categories), fixture in `tests/db_smoke.cpp`.
2. **Done.** `CategorizationManager`, materialization into the `settings` row,
   inline assignment in App Management, `explain()` for "why this category?".
   The four previous sources are deleted.
3. **Done.** Categorization card: grouped view, rule CRUD, per-rule and global
   restore, category enable, new-defaults review, `game_mode` kept as a shim.
4. **Done.** Icon-inferred rule and category colors replacing
   `categoryHeatBase()` and ~47 hand-maintained hex literals.

### Revisions after the first UI pass

- **A rule names one app — including in the defaults.** The editor offers a
  name, one app chosen from the recorded list, title matches, and a category.
  `scope` is gone from the model, not just the UI: nothing binds to an abstract
  group like "all browsers", because a binding the user cannot point at is a
  binding they cannot reason about. Shipped site rules are generated once per
  browser (`site:youtube.chrome`, `site:youtube.edge`, …), taking the table from
  137 to 239 rules. The cost is near-duplicate rows under a category; the
  benefit is that every rule is editable from the app it belongs to.
- **One row per application** in App Management. Identity there resolves with
  the window title ignored, so a browser is one row and its title rules are
  listed inside its edit panel.
- **One Edit control per app row**, covering name, category and title rules.
- **One reset**, for the whole table. Per-rule "restore"/"modified" markers are
  gone; a rule is edited, disabled or deleted instead.
- **Categories are creatable and deletable** in the rules card. Deleting one
  re-homes its rules to `other` rather than dropping them; `other` cannot go.
- The old two-toggle "分类规则" card is removed; `auto_classify` and
  `merge_windows` keep their stored values and read-layer behavior.

Not built: import/export of rule packs (separate functionality), the
Uncategorized review queue, and the rule editor's live match preview — the
card validates the draft with `lintDraft()` but does not preview matches.

## Open decisions

- **`ref` + optional `name`.** One extra field, and the only thing standing
  between "user edits one rule" and "all category names freeze into whatever
  language they were running". Recommended, slightly more than the minimum.
- **Custom categories in step 3 or later.** "Add a rule" naturally wants a
  category that does not exist yet. Assumed here as a lightweight
  `+ New category` (name + color, no traits) inside the picker.
- **`auto_classify` semantics.** The change described in Resolution is a
  behavior change from today's blanket reassignment.
