# Open Issues

Known-broken or incomplete; keep entries short and move fixed items to a session log.
> Actionable backlog: [`implementation-backlog.md`](../../docs/implementation-backlog.md).

## Platform

- **Linux service is empty.** `src/service/linux/main.c` is a 0-byte file. Needed: X11 + Wayland
  foreground/idle/audio/single-instance support; see [`rules/02`](../rules/02-platform-boundaries.md) §3.
- **macOS validation/packaging still open.** Helper now has tracking, full v1 config,
  CLI lifecycle/status and a single-instance guard. `tools/build-macos.sh` automates
  packaging; remaining work is credentialed signing/notarization, runtime/Accessibility
  smoke, launchd/login verification, and clean-machine QA.
- **Windows background startup restored (2026-08-20).** UI start, v1 enabled/idle and JSON
  status work. Codex counts changing related-worker CPU/I/O, never mere process presence;
  advanced leaves and SCM Session-0 remain deferred.
- ~~**Windows Codex audio counted sleep as playback.**~~ **Fixed (2026-08-31):** `OpenAI.Codex_` closes long gaps; other media and SQLite stay unchanged.
- **Bilibili marker-free video attribution fixed (2026-08-25).** Recent explicit browser-site identity now survives title-only navigation; direct deep links without any marker remain limited.
## Storage

- **SQLite usage migration (A1) — DONE** (`CHARTER` v0.9); UI read-only.
- **Whole-DB backup/restore (D1) — DONE (S1+S2, PR #40).** S3 retention deferred.
- **Cross-device sync E1-E9 is not implemented.** Approved design and live
  checklist: `docs/superpowers/specs/2026-07-24-cross-device-sync-design.md`
  and `docs/cross-device-sync-progress.md`.

## UI

- ~~**Memory Lake placeholder page.**~~ **Replaced** by a 1:1 prototype port
  (`qml/desktop/memorylake/`).
- **Memory Lake real-data wiring (phase E).** Desktop **done** (Phase 1 daily view +
  Phase 2 monthly recap): `MemoryLakeMock.js` replaced by read-only `UsageStatManager`
  data + `DailyCardService::memoryLake{Day,Recap}` local templates; C++ aggregation added
  (no schema change): per-day month series, last-month compare, category share, time-of-day
  peak, per-app sessions; cross-app focus-block task summary; window-title-aware category
  classifier (`系统` bucket); icon-dominant-color blended background + covers. 2026-06-13
  alpha + 2026-06-14 C passes covered process naming/grouping, icon fallback, and
  monthly heatmap fixes. **Mobile equivalent is implemented** (real usage, four
  ranges, Memory Lake, wallpaper, sharing).
  Adaptive/round/legacy launcher icons and the native-to-QML launch experience are also implemented. The Qt default theme remains, while a lifecycle Activity reapplies edge-to-edge and immediate sync. Real app icons now use a GPU rounded mask; UsageStats are replaced per local day and notify QML only after persistence. Pura 90 Pro visual/data QA and Android/HarmonyOS multi-ROM validation remain. **Still open:** broader classifier long-tail keyword
  coverage (`A4` — uncommon apps can still fall to 其他). Implementation issues + resolutions (A1–A7, B1–B11):
  `docs/memory-lake-integration-issues.md`; per-surface plan:
  `docs/memory-lake-backend-integration-plan.md` (also `…-implementation-plan.md` §4).
- **Third-party license page — shipped (F2).** Settings → 导入导出 →「关于与开源许可」
  surfaces each component's name / version / full text offline (`resources/licenses/`,
  qrc-embedded); see [`../rules/06-licensing.md`](../rules/06-licensing.md) §4.
- **Frameless window — native snap-layouts fly-out deferred (Step 2).** PR #18
  shipped pure-QML frameless chrome (`qml/desktop/components/WindowChrome.qml`)
  + Win11 DWM rounded corners/shadow (`main.cpp::applyWin11RoundedCorners`);
  macOS now uses a borderless full-height sidebar with embedded traffic lights. The
  Win11 hover-maximize **snap-layouts fly-out** and maximize-over-taskbar
  precision need a native `WM_NCCALCSIZE`/`WM_NCHITTEST` pass in `main.cpp`; not
  done. See agent memory `timearc-frameless-window`.
- **Memory Lake memo blackboard overlay (备忘) — implemented (merged PR #14).**
  Modal overlay (entry-as-action + flip-guard) replicating v88 `#memoOverlay`: freehand
  pen/eraser ink; sticky notes (due date/time picker + done checkbox) + resizable text
  layers; multi-page archive folder (per-page ink+objects, **max 10**); marquee **select
  tool** (ink + objects → copy/delete/move/scale, clipboard **Ctrl+C/V cross-page**, **Ctrl+Z
  undo**); pomodoro + completion overlay; **Dynamic-Island** auto-hide chrome. Content drawn
  in a fixed **1920×1080 logical board scaled-to-fit (16:9)**, persisted UI-private via
  `SettingsRepository` (`memoryLakeMemoDoc`, no new C++; off the disk contract). Canvas
  pitfalls + patterns recorded in agent memory `timearc-qml-canvas-memo`. **Pending:** manual
  in-app QA (draw / drag / marquee / hover-reveal / fullscreen-scale / pomodoro). PR #18
  (2026-06-05/06) added: toolbar hover fix (topZone hover-block), page rename, and the 7
  functional-gap features — pen color palette, pen/eraser width, clear-canvas (+confirm),
  page drag-reorder, page thumbnails, sticky-note signature, pomodoro persistence (functional
  doc §A #1–#10 now all done). Still deferred (§A #11–#14): pomodoro sound + work-rest cycle +
  progress-ring, keyboard tool-switch, conic-aura shader. Specs `docs/memory-lake-memo-*`.

- ~~**Stats double-counts audio under another foreground app.**~~ **Fixed:** stats is frontmost-only; the cross-app sum still stands for the `active*` pages.
- ~~**Wall-clock counting; hiding and renames stopped applying.**~~ **Fixed:** desktop counts `active_sec`; both persisted key maps match by alias and canonicalize.
- ~~**Canonical app variants appeared as duplicate rows with helper icons.**~~ **Fixed:** persisted variants retain their editable rule id; an explicit alias policy groups approved helpers without collapsing broad defaults.
- **Mobile has no per-app hiding.** Track B: needs a settings surface + a
  package-name key scheme. `active_sec` has no mobile analogue (Android's
  `totalTimeInForeground` carries no idle part).
- **`rules/04` lacks three read-layer invariants**: clip by intersection (day <=
  24h), name declares caliber, persisted derived keys need migration.

## Build / distribution

- **Qt dynamic link + release packaging — shipped (F1).** Windows has `build-windows.ps1`.
- **Windows public distribution remains unsigned.** Portable ZIP is suitable for a disclosed
  small beta. The test installer's PowerShell launch chain and the native EXE icon resource are
  fixed; signing, registered uninstall/update, clean-machine QA and build/test CI remain open.
- **Service config v1 partially shipped** (`CHARTER` v0.13). UI and macOS full reader
  are implemented; Windows reads tracking enabled + idle, while Windows advanced leaves
  and the Linux reader remain open. `usage_config.json` is retired.

## Harness itself

- ~~Windows DB smoke named QSettings escaped the test IniFormat path.~~ **Fixed:** `defaultFormat()` + isolated UserScope fixture.
- ~~`record_error.py` / `harness_check.py` stubs.~~ **Implemented.** Reports +
  JSONL + INDEX.md atomically; 7 check passes, `--bootstrap` seeds hashes.
- `preflight.py` — **new.** Session-start one-stop; wraps `--fast` audit.
- ~~`HarnessHooks.cmake` stub.~~ **Implemented.** `timearc_harness_enable` +
  `harness-check`; L1 capture via `tools/build.py`.
- ~~No runtime L2 capture.~~ **Wired.** `harnesslogger.cpp` tees Qt
  Warning/Critical/Fatal to `logs/harness-qt.log`; `scan_qt_log.py` drains it
  into L2 reports. Still needs a Qt build to smoke-test.
- ~~No track enforcement in slugs.~~ **Done.** Pass 6 enforces `YYYYMMDD-HHMM(SS)-[ABC]-kebab.md`.
