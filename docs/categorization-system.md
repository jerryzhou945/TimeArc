# TimeArc Categorization System

One rule table decides three things at once: which app an activity belongs to,
what it is called, and which category it counts toward. It replaces the adapter
registries, the site catalog, the keyword ladder, and the legacy card
classifier. The design and its rationale are in
[`categorization-redesign.md`](categorization-redesign.md).

## Where it lives

```
src/services/categorization/
  normalize.h        NFKC + case fold + diacritics + .exe/.app strip
  rule.h             needles, scoring, Rule / CategoryDef / RuleSet
  default_rules.h    GENERATED shipped table (do not hand-edit)
  matcher.h          compile + resolve
  rule_set_json.h    stored form, rehydrate-by-ref, lint
src/services/categorization_manager.{h,cpp}   ownership, persistence, QML API
tools/gen_default_rules.py                    readable source of the table
```

Header-only except the manager, because `src/CMakeLists.txt` is frozen; the
manager's entry was added under an approved change proposal.

## Inputs

Two observed fields, plus one for stability:

| Field | Windows | macOS |
|---|---|---|
| `app_id` | full executable path | bundle id (`com.google.Chrome`) |
| `display_name` | executable basename | `localizedName`, **varies by system language** |
| `window_title` | window title | AX title; media title on `media_sessions` rows |

`app` needles are tested against `display_name` ∪ `app_id`; `title` needles
against `window_title`. `app_id` is in the union because it is the only field
that is never localized, which is what makes the table work on a non-English
macOS.

## Matching

Needles and observed text pass through the same `normalize()`, so a needle
spelled `chrome.exe` matches a macOS bundle id and a Windows basename alike.

- `foo` — contains
- `=foo` — equals one whole component (never the joined identity text)
- `word:foo` — Latin word boundary

```
score = 100 × conditions matched      (app gate, title)
      +  50 when the winning needle is exact
      +  length of the longest matched needle
```

Counting conditions is what makes a title refinement outrank a bare app match,
so `site:youtube` beats `app:chrome` and YouTube in a browser is Video.

**Every rule names an app, and a title needle never fires without one.** There
is no abstract grouping like "all browsers": a rule's binding is always a
concrete app the user has, which is what makes it inspectable and editable from
that app's row. Shipped site rules are therefore generated once per browser —
`site:youtube.chrome`, `site:youtube.edge`, and so on — rather than sharing one
scoped rule. `lint()` rejects a title match with no app, and the invariant is
asserted over the whole shipped table in `tests/db_smoke.cpp`.

## Categories

ASCII ids with English-first labels (`en` required, other locales optional and
falling back to it) and traits that replace four previously hardcoded sets:

| Trait | Effect |
|---|---|
| `focus` | counts toward focus statistics |
| `entertainment` | counts as leisure in Memory Lake cards |
| `deprioritize` | excluded from home rank, task naming, headline category |

Colors are **not** in the table. Rule color comes from the rule's icon, and
category color from its busiest member's icon snapped to a 12-hue ring so
legend swatches stay distinguishable (`components/AppVisual.js`).

## Storage

One `settings` row, key `categorization`, written **eagerly on first run** — the
row always exists.

What gets written is not the shipped table. The manager walks the apps the
service has actually recorded and writes **one app-level rule per app**, bound
to the name the service reported — the same shape the UI produces when you pick
an app from the menu:

```
shipped default:  app:chrome   app = ["com.google.chrome", "google chrome", "chrome.exe"]
recorded:         com.google.Chrome / "Google Chrome.app"
written rule:     app:chrome   app = ["=Google Chrome.app"]     ref = app:chrome
```

An app the shipped table has never heard of is written too, with category
`other` and the recorded name, under the same `exe:` identity the read layer
already uses for unknown apps. So the rules table is a complete inventory of
what this machine runs, spelled the way this machine spells it, and every row in
App Management has a rule you can open.

Deriving per app also stops one rule from speaking for several: matching picks
the **best-scoring** default per app rather than letting the first loose needle
claim it. Real cases this fixed — `code.exe` normalizes to the substring `code`
and was swallowing `com.openai.codex`; `com.tencent.qq` is a prefix of
`com.tencent.QQMusicMac` and was filing QQ Music under Social. Where two
recorded apps genuinely map to the same default (a PDF reader and its updater),
the busiest keeps the plain id and the rest get an `@<name>` suffix.

Three consequences, all intended:

- **A brand-new install has no rules**, because it has recorded nothing yet.
  The category palette is still written, so the pickers work. Once tracking has
  seen something, the next launch seeds for real — the manager only re-seeds
  automatically while the set has never been user-edited.
- **`Reset to defaults` is always available**, and re-derives from *current*
  tracking data rather than restoring a fixed table. Run it after installing new
  software and it picks that software up.
- **The seeding algorithm is versioned** (`seedVersion`). When it changes, a set
  the user has never edited re-derives itself on the next launch, so nobody has
  to know to press Reset. A set the user *has* edited is never touched — if they
  deleted every rule, it stays deleted.
- **New default rules** are counted against what you record, so the upgrade
  prompt only offers rules for apps you actually have.

The stored form is deliberately thinner than the built-in one: no icon, no
color, no locale map. `name` appears only when the user renamed something, so
untouched entries still resolve their localized label through `ref`.

A stored document that fails to parse or lint falls back to the shipped
defaults **and reports the error**; silent fallback would look like the user's
customization had vanished.

## What a rule is, in the UI

A rule is **a name, one app, and any number of title matches, in one category**.
Because a rule always names an app, a title match only ever applies inside that
app — there is no "anywhere / browsers / players" control to get wrong, and no
rule whose target the user cannot point at.

Site coverage is generated per browser (Chrome, Edge, Firefox, Safari). A
browser outside that set classifies as Browsing until the user adds a title rule
under it, which is two clicks in App Management.

The settings page has two cards:

- **App Management** — one row per application (identity is resolved with the
  window title ignored, so a browser is never split into several rows). One
  `Edit` control opens a panel that edits the name, the category, and the
  window-title rules that can fire for that app. Changing the category of an app
  whose rule also covers other apps narrows automatically to a rule for that app
  alone, so editing one row never moves another.
- **Category Rules** — categories with their rules, each category creatable and
  deletable (rules in a deleted category move to `other`; `other` itself stays).
  One `Reset to defaults` for the whole table; individual rules are edited,
  disabled or deleted rather than individually reverted. Deleting a rule or a
  category and resetting the table all go through the page's confirm sheet.

The app for a rule is chosen from a **menu overlay**, not typed and not an
inline list: the settings page scrolls, so an inline expansion is clipped and
hard to hit. Row actions are icon buttons with hover hints and a hit area
larger than the glyph.

Two QML traps this UI hit, both worth remembering:

> **Assign a new object, never mutate and reassign.** `var d = obj; d.k = v;
> obj = d` puts the same reference back, so QML detects no change, emits no
> signal, and every binding goes stale. Use `withField()`. This is what made the
> category chips and app selection look dead.

> **`GlassTextField.text` is an alias to an internal `TextInput`.** The first
> keystroke destroys any declarative binding the parent put on it, permanently.
> Prefill must therefore be *assigned* when the form opens (`_syncRuleFields()`,
> or `onVisibleChanged` for fields inside a delegate), never bound. This is what
> made "Edit rule" stop filling the name and title fields once the user had
> typed in the new-rule form.

## Adding support for an app or site

1. Edit the readable table in `tools/gen_default_rules.py`.
2. Run `python3 tools/gen_default_rules.py` from the repository root.
3. Add a case to the categorization fixture in `tests/db_smoke.cpp`.
4. Build and run the tests.

One entry, one file. An app rule:

```python
app("app:example", "dev", "Example", ["com.example.app", "example.exe"])
```

A site rule (expanded to one rule per browser automatically):

```python
site("site:example", "read", "Example", ["example.com", "example"])
```

`site()` expands into one rule per entry in `BROWSER_TARGETS`, each bound to
that browser's own needles.

Rule ids keep the legacy colon format because `hidden_apps` and
`app_display_names` are keyed by group key; changing the separator would orphan
every existing user preference.

Needles are normalized, so `qq.exe` becomes the two-character substring `qq`
and would match QQMusic and QQBrowser. Use `=` for short names — `lint()`
rejects short Latin substrings, and it caught exactly this in the shipped table.

## Privacy

Window titles are matched locally and never displayed, never persisted into a
card, never sent to AI. Suggestions in the Uncategorized queue are app-level
only: the app must not mine observed titles into proposed rules. Rule metadata
never stores a full URL.
