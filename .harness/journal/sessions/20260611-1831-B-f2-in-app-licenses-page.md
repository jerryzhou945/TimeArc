# Session — F2 in-app third-party licenses page

- Track: B (Feature)
- Date: 2026-06-11 18:31 (local)
- Branch: `feat/f2-in-app-licenses-page` (based on `docs/f1-f2-licensing-kickoff` @87a331d, kickoffs present).
- Kickoff: `docs/f2-in-app-licenses-page-kickoff.md` (Route A); sibling `docs/f1-release-dynamic-link-qt-kickoff.md` §S2.
- Change proposal: **none** (no frozen file touched; no new C++ file).

## Scope decision (F1 had not landed)
F2 depends on F1-S2's `resources/licenses/*.txt`. F1 has not landed (no `resources/licenses/`,
only the docs branch). Per the kickoff, I **produced F1-S2's full vendored license-text set**
as the single source of truth (F1 owns it on landing — no second copy), then built the F2 page on it.
I deliberately did **not** do F1-S1 (linkage objdump assertion) or F1-S3 (packaging), so I left the
README Qt linkage wording ("dynamic (planned for release)") to F1-S1 and only surfaced F2's deliverable.

## What I did
1. **License texts (F1-S2 artifact)** → `resources/licenses/`: `qt-lgpl-3.0.txt` (verbatim
   `C:/Qt/Licenses/LICENSE` = Qt preamble + GPLv3 + LGPLv3), `qt-gpl-3.0.txt` (GPLv3 block, lines
   26–701 of that file), `parson-mit.txt` (parson.c:4–23, MIT), `sqlite-public-domain.txt`
   (sqlite3.h blessing + explicit "public domain, no license text" deviation note),
   `timearc-gpl-3.0.txt` (= repo `LICENSE`), `mingw-runtime-exception.txt` (`COPYING.RUNTIME`).
   Registered all six in `resources/CMakeLists.txt` (qrc-embedded). Added discovery `LICENSE`
   files under `thirdparty/{parson,sqlite3}/`.
2. **F2-S1 page** → `DesktopProfilePage.qml` export tab: `SettingsCard「关于与开源许可」` after the
   恢复与重置 card. App row (TimeArc v0.1, MVP constant — `appVersion`) + `Repeater` over
   `licenseComponents` (Qt 6.11.1 / SQLite 3.51.3 / Parson 1.5.3 / TimeArc, each name+version+
   license+linkage + 「查看全文」). Full-text viewer = glass scrim + `SilkyFlickable` (mirrors the
   confirm-modal pattern). Reused `SettingsCard`/`GhostBtn`/`GlassPanel`/`ThinRule`/`PlaceholderNote`.
3. **F2-S2 docs** → `.harness/rules/06-licensing.md §4` (marked shipped + location + §4(1) public-domain
   deviation + sync recipe; kept §4(1)/(2)/(3) numbering other docs cite; file 92 lines), `README.md`
   (line 585 `[x]` + post-table offline/sync note), `.harness/state/open-issues.md` (entry → shipped,
   in place, file held at 100).

## Loader blocker + correction (filed L3 `…-f2-qrc-xhr-blocked-use-readtextfile.md`)
The kickoff's **recommended** loader (pure-QML `XMLHttpRequest` GET on `qrc:`) is **blocked** by Qt's
default (`XMLHttpRequest: Using GET on a local file is disabled by default … QML_XHR_ALLOW_FILE_READ`).
Switched to the kickoff's option 2: normalize `qrc:/…` → `:/…` and call `settingsRepository.readTextFile()`
(`QFile` reads the `:/` resource prefix). Zero C++, no security env-var.

## Verify (kickoff §6 — all green)
- **Loader non-empty for every component** (temp scaffold, reverted): readTextFile lengths —
  qt-lgpl=44699, qt-gpl=35149, sqlite=1335, parson=1209, timearc=35149. No XHR-disabled, no QML errors.
- **Embedded/offline**: strings present in `build/TimeArc.exe` (SQLite blessing, Parson copyright, LGPL);
  loader reads `:/` qrc resource — no network → offline by construction.
- **PrintWindow-by-PID** (own instance): card at 1280×720 (4 rows + buttons, versions/linkage correct,
  v0.1 honest); GPL full-text viewer scrolling at 1280×720 and maximized 1920×1080 — no glass artifacts.
- **Builds green** via `build.py` (`20260611-190834-build.log`, final clean after temp scaffold removed).
- **scan_qt_log clean** (stale XHR warnings were from the fixed intermediate loader → rotated aside,
  learning captured as L3, not a phantom L2). **harness_check exit 0.**

## Adversarial review (4 dimensions + verify, 8 agents) — findings addressed
- **[HIGH] rules/06 §4 loader prose was wrong** — said "XMLHttpRequest GET on qrc:" (written before the
  loader pivot); the shipped code uses `readTextFile` with qrc:/→:/. **Fixed** to match code + cite the L3.
- **[MED] `mingw-runtime-exception.txt` was qrc-embedded but surfaced nowhere** (dangling resource / I6).
  **Fixed**: un-registered it from `resources/CMakeLists.txt` (kept on disk as the F1-S2 artifact F1-S3
  distributes via NOTICE). Not added as a page row on purpose — full MinGW-runtime attribution includes
  libwinpthread (not GCC-exception), which is F1's NOTICE job, not a single page row.
- **[MED] stale "经 XHR 读 qrc" comment** in the viewer header — **fixed** to "readTextFile 读 :/ qrc".
- **[LOW] Esc while a modal open navigated home** — **fixed**: root `Keys.onEscapePressed` now closes the
  license viewer / confirm card first, navigates only if neither is open.
- **[LOW, deferred to F1] Qt linkage de-stale** (README:620 "dynamic (planned for release)", rules/06 §1):
  outside this prompt's scope (named rules/06 **§4** only) and overlaps F1-S1's explicit targets. I verified
  the fact for F1: `objdump -p build/TimeArc.exe` → imports Qt6Core/Gui/Qml/Quick/Sql/Widgets DLLs, no static
  Qt. Left the wording for F1-S1 (which also owns the release-time assertion + packaging).
- Re-verified after fixes: build green, 5 texts still qrc-embedded (mingw no longer), harness_check exit 0.
