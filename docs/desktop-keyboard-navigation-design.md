# Desktop Keyboard Navigation — Design

Keyboard-first navigation for the **desktop shell** (`qml/desktop/`) on Windows
and macOS. Companion to `docs/macos-menu-bar-design.md`, which covers the same
commands as *menu rows*; this document covers them as *keys*, adds the focus
model the menu bar cannot provide, and gives Windows the parity it never had.

Mobile (`qml/mobile/`) is out of scope — touch shells have no focus ring and no
key chain (rule 04 §1 is about pages, and this adds no page).

## 1. What the keyboard can do today

Everything the desktop shell currently accepts, exhaustively:

| Key | Effect | Where | Platform |
|---|---|---|---|
| `N` / `P` (rebindable letters) | 备忘黑板 / 番茄钟 toggle | `DesktopAppShell.qml:389,400` | all |
| ⌘1 ⌘2 ⌘3 ⌘4 | 首页 / 日历 / 统计 / 记忆湖 | `MacMenuBar.qml:236-271` | **macOS only** |
| ⌘, · ⇧⌘N · ⇧⌘P · ⇧⌘D · ⇧⌘E · ⌘W · ⌘M · ⌘Q | 设置 / 备忘 / 番茄 / 夜间 / 导出统计 / 窗口命令 | `MacMenuBar.qml` | **macOS only** |
| ⌃⌘F | full screen | `main.qml:159-169` | macOS only |
| ⌘Z ⌘X ⌘C ⌘V ⌘A | forwarded to `activeFocusItem` | `MacMenuBar.qml:80-88,186-229` | macOS only |
| `Esc` | 回首页 | `DesktopStatsPage.qml:612`, `DesktopProfilePage.qml:632` | all (2 pages) |
| `Esc` `Del` `Ctrl+Z/Y/C/V` | 备忘黑板 internals | `MemoOverlay.qml:619` | all |
| `Esc` `Space` `Enter` `←↑→↓` | 月度回顾 story | `RecapOverlay.qml:65` | all |
| `A`–`Z`, `Esc` | hotkey capture chip | `DesktopProfilePage.qml:2117` | all |
| `Enter` / `Esc` | commit / cancel in three text fields | calendar, memo folder | all |

Four gaps follow from that table:

1. **Windows and Linux have no navigation keys at all.** Every page key ships as
   a `Platform.MenuItem.shortcut` inside the macOS-gated `Loader`
   (`main.qml:142`), so on Windows the entire ⌘1–⌘4 / ⇧⌘N / ⇧⌘D / ⇧⌘E set does
   not exist. The letter hotkeys and `Esc` are the whole Windows keyboard.
2. **Nothing is focusable.** 132 `MouseArea`s across `qml/desktop/`, zero
   `FocusScope`, zero `KeyNavigation`, zero `activeFocusOnTab`, and no visual
   that reacts to `activeFocus`. Tab does nothing outside the six text fields.
3. **Focus has no owner.** Two pages grab it themselves
   (`DesktopStatsPage.qml:618`, `DesktopProfilePage.qml:348`); 记忆湖/日历 never
   do, so their `Esc` would not arrive even if they had one. `MemoOverlay` takes
   focus on open (`:604`) and returns it to nobody on close, so after one 备忘
   round trip even the two self-focusing pages stop hearing keys.
4. **No in-page keyboard reach.** Card selection, rank rows, calendar cells,
   range tabs, period stepping, settings tabs and cards are mouse/wheel only —
   although every one of them is already driven by a single QML state property
   (§5), which is what makes this cheap.

## 2. Platform constraints the design must respect

**Qt swaps Ctrl/Meta on macOS.** `"Ctrl+1"` renders ⌘1 on macOS and Ctrl+1 on
Windows, so one platform-neutral string serves both. `"Meta+…"` means ⌃ on
macOS and the Windows key on Windows and is therefore never usable for a shared
binding.

**macOS gates Tab to text controls.** Qt Quick's focus chain consults
`QStyleHints::tabFocusBehavior()` (verified: `QtQuick` framework imports
`QStyleHints::tabFocusBehavior() const`), and the cocoa plugin derives it from
the system's *Keyboard navigation* setting. Probed on this machine
(`AppleKeyboardUIMode = 2`, i.e. the setting on): `tabFocusBehavior = 255`
(`Qt.TabFocusAllControls`). With the macOS default — the setting **off** — Qt
reports text-controls-only and Tab will not reach a nav item no matter what the
QML declares. **A Tab-only design would therefore be broken for most macOS
users.** Every region reachable by Tab must also have a modifier key (§4).

**Bare letters cannot be menu key equivalents.** Already learned and recorded in
`macos-menu-bar-design.md` §2.4: a menu swallows the letter before a focused
text field sees it, which is what `Keys.onShortcutOverride` exists to prevent.
This design adds **no new bare-letter shortcut**.

**A native menu equivalent and a QML `Shortcut` for the same sequence must not
both exist.** On macOS the menu row owns its key; the shared table must
therefore instantiate the QML `Shortcut` under `active: !macSidebarChrome` for
commands that have a row. Phase 0 verifies whether an ungated duplicate
double-fires or merely warns — until then, gate.

**AltGr.** On Windows, `Ctrl+Alt` *is* AltGr on layouts that have one. The
region keys below use `Ctrl+Alt+digit`, which is safe for the shipped zh/en/ja
audiences but would collide on e.g. a German layout. The Windows-only `F6`
alias (§4) is the escape hatch, and a European layout is the trigger to revisit.

**`Ctrl+Shift+digit` is unusable on macOS**: ⇧⌘3/4/5 are system screenshots.

## 3. The model: three layers

| Layer | Owns | Lives in |
|---|---|---|
| **Commands** | global sequences → shell functions | `KeyMap.js` + `DesktopShortcuts.qml`, read by `MacMenuBar` too |
| **Regions** | which pane has focus; the Tab/modifier ring | `DesktopAppShell` + one `KeyRegion.qml` per pane |
| **Cursors** | movement *inside* a pane, drawn as a focus ring | existing page state + `FocusRing.qml` |

The layers are strictly ordered: a command fires regardless of focus; a region
key fires unless a capture/edit mode claims it; a cursor key fires only in the
focused region. `Esc` walks back down the same ladder (§6).

## 4. Key map

### 4.1 Global commands — one table, both platforms

`qml/desktop/components/KeyMap.js` (`.pragma library`, next to `I18n.js`)
becomes the single source of truth: `{ id, seq, macMenuRow, scope, gate }`.
`MacMenuBar` reads `seq` for its rows instead of hardcoding them; a
`Repeater`-of-`Shortcut` in `DesktopShortcuts.qml` binds the same table on every
desktop platform. Today's assignments are kept exactly — ⌘1–⌘4 numbering
follows `macos-menu-bar-design.md` §2.4, *not* the `navItems` index, and 记忆湖
stays ⌘4 while 设置 keeps ⌘, .

| 命令 | Sequence | Gate | Status |
|---|---|---|---|
| 首页 / 日历 / 统计 / 记忆湖 | `Ctrl+1..4` | `canNavigate` | **new on Windows** |
| 设置 | `Ctrl+,` | `canNavigate` | **new on Windows** |
| 备忘黑板 | `Ctrl+Shift+N` + letter | `!memoLocked` | letter exists; combo new on Windows |
| 番茄钟 | `Ctrl+Shift+P` + letter | `!memoLocked` | as above |
| 夜间模式 | `Ctrl+Shift+D` | — | **new on Windows** |
| 导出统计报告 | `Ctrl+Shift+E` | `selectedPage === "stats"` | **new on Windows** |
| 收起 / 展开侧栏 | `Ctrl+B` | — | **new** |
| 快捷键速查 | `Ctrl+/` | — | **new** |
| 上一期 / 下一期 | `Ctrl+[` / `Ctrl+]` | stats, calendar | **new** |
| 回到今天 | `Ctrl+T` | calendar | **new** |
| 搜索 | `Ctrl+F` | settings | **new** |
| 全屏 | ⌃⌘F (macOS) · `F11` (Windows) | — | macOS ships; Windows deferred to phase 3 |

### 4.2 Region and cursor keys

| Key | Meaning |
|---|---|
| `Tab` / `Shift+Tab` | next / previous region (ergonomic path; gated by the macOS setting) |
| `Ctrl+Alt+1` | focus 侧栏 — always region 1 |
| `Ctrl+Alt+2..4` | focus the page's declared regions, in declaration order |
| `F6` / `Shift+F6` | Windows-only region ring alias (real F-keys; macOS defaults F6 to a system function) |
| `←` `↑` `→` `↓` | move the cursor inside the focused region |
| `Home` / `End` | first / last item in region |
| `PgUp` / `PgDn` | region-defined page step (calendar month, long lists) |
| `Enter` / `Space` | activate the cursor item — the same code path as its `onClicked` |
| `Esc` | walk back one rung (§6) |
| `Del` | region-defined destructive action, only where a click already offers one |

No bare letters. No `Ctrl+Tab` (that is ⌘Tab — the macOS app switcher).

### 4.3 Per-page regions

Each page declares its regions; the shell never hardcodes a page's shape.
Cursors reuse the state property the mouse already mutates, so keyboard and
mouse cannot disagree.

| Page | Regions (⌃⌥2, 3, 4) | Cursor state | Keys |
|---|---|---|---|
| 记忆湖首页 | 排行 · 卡牌区 · 今日事项 | `selectedIndex` (`DesktopMemoryLakePage.qml:38`) | 卡牌: `←→` `selectCard(±1)` (`:188`), `Enter` `toggleFlip` (`:193`); 排行: `↑↓` same `selectedIndex` via `onRequestSelect` (`:328`); 事项: `↑↓`, `Space` 勾选, `Enter` 打开日历 |
| 日历 | 视图 Tab · 日格栅 · 侧面板 | `activeView` (`:80`), `selectedDateKey` (`:69`) | 视图: `←→`; 格栅: `←→` ±1d, `↑↓` ±7d via `selectCellDate` (`:863`), `PgUp/PgDn` = `previousMonth/nextMonth` (`:844,849`), `Ctrl+T` 今天, `Enter` `openCreate()` (`:624`); 侧面板: `↑↓`, `Enter` primary, `Del` 删除 |
| 统计 | 期次工具条 · 明细列表 | `range` (`:46`), `periodOffset` (`:47`) | 工具条: `←→` over `rangeModel` (`:645`), `Ctrl+[/]` = `periodOffset ∓1` keeping the `atCurrentPeriod` guard and its 已是最新一期 toast (`:892`) |
| 设置 | 分区 Tab 列 · 卡片区 · 搜索 | `currentTab` (`:51`), `searchQuery` (`:52`) | Tab 列: `↑↓` over `tabModel` (`:394`); 卡片: `↑↓` cursor, `Enter` → the card's optional `keyActivate()`, cards without one are skipped; `Ctrl+F` → the 搜索 field (`:874`) |
| 月度回顾 | story overlay owns its keys (`RecapOverlay.qml:65`) | — | unchanged, but now listed in the cheat sheet |
| 备忘黑板 | modal; region layer suspended | — | unchanged (`MemoOverlay.qml:619`) |
| 计时页 | 项目列表 · 主按钮 | — | phase 3. `Esc` must **not** stop a running timer |

## 5. Why cursors ride existing state

Retrofitting focus onto 132 `MouseArea`s is the obvious approach and the wrong
one. Every list-like surface in this app already keeps its selection in one QML
property, and clicking merely writes it. So a region needs **no per-item focus
item**: it is one `FocusScope` whose arrow keys write that same property, and
the ring draws on the delegate whose index matches. Consequences:

- keyboard and mouse cannot drift apart — one state, one code path;
- the Tab chain stays ~4 stops per page instead of ~40;
- the flip lock (`locked`/`memoLocked`) keeps working for free, because
  `selectCard()` already early-returns while a card is flipped
  (`DesktopMemoryLakePage.qml:189`) and `canNavigate` already gates the menu;
- delegates gain one binding (`ring.shown: index === region.cursor`) and no
  behavior.

Non-list surfaces (toolbar ghost buttons, settings cards) get a cursor over a
declared action array in the same `KeyRegion`, with `Enter` calling the action —
which is why `SoftButton`/`StatsGhostButton` need no focus plumbing either.

## 6. Focus ownership and the `Esc` ladder

**One owner: the shell.** `applyKeyContextToLoadedPage()` runs beside
`applyThemeToLoadedPage()` from `pageLoader.onLoaded` (`DesktopAppShell.qml:1197`),
reads the page's duck-typed keyboard contract, and calls `forceActiveFocus()`.
The self-focus calls in `DesktopStatsPage.qml:618` and
`DesktopProfilePage.qml:348` and their `focus: true` (`:17`, `:20`) come out —
two owners fighting over focus is how the current 备忘-round-trip bug happens.

**Overlays push and pop.** `MemoOverlay` / `RecapOverlay` opening pushes the
current region onto a shell-side stack; closing pops it and restores focus.
Nothing else may call `forceActiveFocus()` on a page.

**The page contract** (optional properties/functions, duck-typed exactly like
the theme contract in rule 04 §2 — a page that declares none simply has no
in-page keyboard, and standalone preview still works):

```qml
readonly property var keyRegions: [{ id: "cards", title: "卡牌区" }]
function focusKeyRegion(id)        // → bool, false = no such region
readonly property bool keyCaptureActive   // true while a text/capture mode owns keys
```

**`Esc`, one rung per press**, innermost first: open popup (许可全文 /
二次确认 / 创建浮层 / 时间选择) → active selection or capture mode → modal overlay →
leave the region, focus returns to 侧栏 → 回首页. This makes today's
"`Esc` = 回首页" from stats/settings a **second** press rather than the first;
that is a deliberate behavior change, listed as a phase-1 acceptance check, and
it is what stops `Esc` from throwing away a page while the user is only trying
to dismiss a picker.

While `keyCaptureActive` is true — the hotkey capture chip
(`DesktopProfilePage.qml:2117`), a focused text field, memo ink — the region and
cursor layers are off entirely. Only the command layer stays live, which is safe
because §4 adds no bare letters.

## 7. Focus visuals

Focus must be distinguishable from selection, which already carries three
signals on nav items (fill, border, the aqua glow dot — NAV2,
`DesktopAppShell.qml:856`). A fourth competing signal there would be noise, so:

- **selection** keeps `accentSoft` fill + `accentSoftBorder`;
- **focus** is a 2px ring *outside* the item plus a soft halo, from new
  `MemoryLakeStyle` tokens `focusRing` / `focusRingSoft` / `focusRingWidth`,
  derived from `glowCyan` with a day-mode ink-cyan variant — modelled on the
  existing `selectedRing` (`MemoryLakeStyle.qml:225`). No inline hex anywhere
  (rule 04 §4, §8).
- one new component, `qml/desktop/memorylake/FocusRing.qml`, taking
  `style: MemoryLakeStyle` the way `KbdChip.qml` does.

**The ring only appears in keyboard mode.** A shell-level `keyboardMode` flag
turns true on any region/cursor key and false on any mouse press, so clicking
never leaves a ring behind — the web's `:focus-visible` rule, and a hard
requirement here because the app's whole look is mouse-first.

## 8. Discoverability

- `Ctrl+/` opens a 快捷键速查 sheet (`ShortcutSheet.qml`, a `GlassPanel` of
  `KbdChip` rows generated from `KeyMap.js`) — a keyboard layer nobody can find
  is not shipped.
- The settings 快捷键 card (`DesktopProfilePage.qml:1470-1534`) today hardcodes
  three display-only rows (`Del` / `Esc` / `Wheel`) — the 🟡 at
  `docs/settings-remaining-work.md:104`. It becomes the same generated table,
  closing that gap.
- Strings go through `I18n.js` (zh source + en/ja) like every other UI string;
  `KeyMap.js` holds sequences only, never display text.
- Phase 3 adds `Accessible.role`/`name` on regions and nav items — cheap once
  regions exist, and the only path to screen-reader legibility.

## 9. Rejected alternatives

| Alternative | Why not |
|---|---|
| `activeFocusOnTab` on all 132 `MouseArea`s | ~40 tab stops per page; needs a focus visual on each; and macOS ignores it at default settings (§2) |
| Migrate to Qt Quick Controls (`Button`, `ItemDelegate`) for free focus | The v88 replication docs pin pixel output; the native style already fights this skin (rule 04 §8, SpinBox) |
| Vim keys (`h/j/k/l`, `g g`) | Bare letters collide with the rebindable `N`/`P` and every text field; `ShortcutOverride` does not scale to a dozen letters |
| A C++ `QAction`/`QShortcut` command layer | Commands target QML state; rule 04 §6 keeps that seam in QML, and `MacMenuBar` exists in QML for the same reason |
| System-wide global hotkeys | Different feature, different permissions; `N`/`P` are deliberately window-scoped |
| Leave Windows menu-less and key-less | That is today's state, and gap 1 is the reason this document exists |
| `F6` as the shared region ring | Modern Macs default F6 to a system function; it stays a Windows-only alias |
| `Ctrl+Shift+1..3` for regions | ⇧⌘3/4/5 are macOS screenshot keys |
| Renumber ⌘1–⌘4 to include 设置 | Breaks shipped muscle memory and `macos-menu-bar-design.md` §2.4 |

## 10. Phases

Smallest runnable slice first; each phase ships alone.

**Phase 0 — two probes** (out-of-tree, `scratchpad`; the ⌃⌘F session's pattern):
`tabFocusBehavior` on Windows and on a macOS account with keyboard navigation
**off**; and whether a `Platform.MenuItem.shortcut` plus an identical QML
`Shortcut` double-fires on macOS. Both answers are load-bearing for §2.

**Phase 1 — commands + focus ownership.** `KeyMap.js`,
`DesktopShortcuts.qml`, `MacMenuBar` reading the table, `Ctrl+B`, `Ctrl+/`,
shell focus ownership, the `Esc` ladder, `keyboardMode`, ring on 侧栏 only.
Windows gains the whole command set. Accept when: on Windows `Ctrl+1..4`,
`Ctrl+,`, `Ctrl+Shift+N/P/D`, `Ctrl+Shift+E` (stats only) work and match the
macOS rows; `N`/`P` and every gate (`memoLocked`, `canNavigate`,
window-less macOS) behave exactly as before; a 备忘 open/close round trip leaves
`Esc` working; first `Esc` on stats/settings dismisses a popup, second returns
home; no duplicate-shortcut warning in `scan_qt_log.py`.

**Phase 2 — regions and cursors.** `KeyRegion.qml`, `FocusRing.qml`, the new
style tokens, `Ctrl+Alt+1..4`, then the four pages in this order: 记忆湖首页
(cards + 排行), 统计 (toolbar), 设置 (tabs + search), 日历 (views + grid).
Accept per page when: every cursor move maps to an existing click path; the
mouse still wins the last word; the flip lock blocks keys exactly as it blocks
clicks; no ring after a click.

**Phase 3 — polish.** 设置 card `keyActivate()` coverage, 计时页, 侧面板 and
议程 rows, `Accessible` attributes, Windows `F11`, and — only if asked — user
rebinding of the region keys through the existing `KeyCaptureChip` path.

## 11. Non-goals

No service side: nothing is sampled, no `usage_config.json` key, no schema
touch, no IPC — `time-arc-service` is not rebuilt. No mouse behavior change. No
mobile shell change. No new C++ manager (all UI-private state; if rebinding
lands in phase 3 it reuses `settingsRepository`, never `localStorage` —
rule 04 §4). No AI, no page added, no new third-party dependency.

## 12. Harness notes

- Track **B**. No frozen file is involved: `qml/CMakeLists.txt` (which must
  list every new QML file, rule 05) is not in `state/frozen-files.json`.
- Rule 04 gains a **§9 keyboard/focus contract**: new desktop pages declare
  `keyRegions` / `focusKeyRegion()` / `keyCaptureActive`; only the shell calls
  `forceActiveFocus()`; focus visuals come from `MemoryLakeStyle` tokens; no new
  bare-letter shortcut. Lands in the same commit as phase 1.
- `docs/macos-menu-bar-design.md` §2.4 gets a pointer noting the key column is
  generated from `KeyMap.js`; `docs/settings-remaining-work.md:104` flips to ✅
  when phase 3's generated card lands.
- `CLAUDE.md` product-context list gets a line for this document.
- `README.md` gets a user-visible note when phase 1 ships (track B exit).
