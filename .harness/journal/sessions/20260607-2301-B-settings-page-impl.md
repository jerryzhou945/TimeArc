# Session 20260607-2301 · Track B · settings-page-impl

## Metadata
- Agent: Claude Code (Opus 4.8, ultracode). Track **B**. Date 2026-06-07 → 06-08.
- Branch: feat/settings-page-dark-glass (staged on worktree settings-impl-wt,
  delivered via fast-forward push to feat/settings-page-dark-glass / PR #28).
- Baseline: f08e540 (docs-only; 3 design specs already landed).

## Goal
Implement v88「设置」page per docs/settings-{implementation-issues,functional-
replication,render-pipeline-replication}.md: dark-glass reskin of
DesktopProfilePage.qml (in place, A-NAME) + read-only/read-layer glue + honest
placeholders. Phases §8: 1, 2(2A–2G), 3(3A–3E). 3E (global accent + i18n) deferred
by product owner to a separate change.

## Two-sided design (Track B)
- Service: UNCHANGED. No IPC/socket/shm; no write/delete of append-only journal
  (I1/I2/D1); usage jsonl/db read-only.
- UI: settings persisted as UI-private KV via SettingsRepository (off disk contract).
  Read-layer filters only extend existing NON-FROZEN .cpp/.h; never a new C++ source.

## Constraints honored (red lines)
G6 no-faking (pomodoro/notify/true-delete/anon-share → hidden/placeholder/honest
label, no fake values); A-* decisions (keep-day, extend-in-place, UI-cache-only
clear, perm就绪, hide pomodoro, track UI-approx). No frozen edits (pass2 clean).
G1 tokens; Qt6 font.pixelSize int. No new C++ source (qml/CMakeLists.txt unchanged).

## Phase 1 (4a588a3) — DONE/pushed
Shell routing (3) + MemoryLakeStyle tokens + 5 Glass* controls + qml/CMakeLists.txt
+ full DesktopProfilePage reskin + README. general tab → KV; rest visual + honest
placeholders. Day/night toast fix; GlassComboBox = pure Item+Popup (native-skin
advisory); GlassSlider controlled. Frozen: NONE.

## Phase 2a (e4599a2) — DONE/pushed
usage_stat_manager +fileSizeBytes/+recordCount (G-STORAGE); settings_repository
+getAllSettings (G-EXPORT)/+readTextFile (G-IMPORT). Storage card real, data
overview real + QML-derived switch count, export/import.

## Phase 2b/2c/2G + Phase 3 (this round, 06-08) — DONE
- 2A/2B/2C/3A read layer (usage_stat_manager.{h,cpp}, non-frozen, no new file):
  flags autoClassify/gameClassify/mergeSimilar/hideTitles/trackingActive + m_hiddenKeys;
  effectiveGroupKey() (merge-off→exe key, hidden→excluded); Q_INVOKABLE setReadFilters()
  + allApps(). Hooks: aggregateSoftware (group key + category vote gate),
  foregroundSegmentsImpl (group key), recordToVariantMap (title→category mask),
  currentSoftware (soft-pause). Defaults all-on = byte-identical to pre-change.
- 2A/2B/2E QML (DesktopProfilePage): pushReadFilters() on game/classify/merge/title/
  track toggles + onCompleted; 应用管理 = real allApps() picker (per-app GlassSwitch →
  hidden_apps JSON + push). Shell Component.onCompleted pushes persisted filters at
  startup (home/stats reflect before settings opened).
- 2G: G-LANDING (Shell onCompleted reads landing_page → selectedIndex / memo overlay);
  G-WIN (main.qml save geometry onClosing[Windowed only] + restore onCompleted, gated
  restore_window); G-MEMO N hotkey (Shell Shortcut, ShortcutOverride-safe, pref read
  fresh) + memo_autosave gate (MemoOverlay.scheduleSave; close-save kept → no data loss).
- 3A track_running real soft-pause (live record excluded) + honest idle label; 3B
  confirm dialog + clearUiCache (window geometry only, no history) + honest delete-info;
  3C perm就绪 + notify honest (already); 3D pomodoro hidden (already).
- G-ANON: persisted + honest label; render-pipeline anonymize deferred with 3E
  (faithful target = recap share-image; stats-export half-wiring would leak names via
  free-text insight → dishonest, so not shipped).

## Verification (this round, PrintWindow-by-PID, own build)
build.py clean ×4. Home baseline (default): ranking + category「开发为主」+ live card
= read path intact at defaults (no regression). Settings/tracking/night: app picker
populated from allApps (real apps), confirm dialog instantiates clean. Stats/night:
metrics/switch-count 47/category/ranking intact (no regression). FUNCTIONAL: forced
hidden=[app:terminal]+autoClassify=false → Home drops Terminal everywhere + theme→
「今日无明显主线」 = filters genuinely propagate. scan_qt_log clean (1 env clipboard
one-off, cleaned). harness_check 0. Temp-verify edits all reverted (grep clean).

## Refinements (06-08, post phase-3) — DONE
User 微调 3 项（PrintWindow 复核 tracking+memo tab 夜态、build/scan/harness 全清、对抗复核 24→4 全 low 已修关键项）：
- #1 应用管理重设计：单列长清单（几十应用撑高右栏、栅格失衡）→ 整宽卡 + 搜索 + 2 列紧凑芯片
  (字母头像+名+开关) + 计数 + 软折叠（默认 appCap=14，"显示全部"展开）；追踪范围去 wide 与分类规则并排上行。
- #2 番茄钟接真引擎：番茄 = 备忘黑板 PomodoroWidget（纯 QML 倒计时、自带 KV memoryLakeMemoPomodoro，
  **非** count-up timer_manager）。设置卡（默认时长/标题/结束庆祝）写 pomodoro_duration/title/celebrate；
  PomodoroWidget _load(无存档)+resetTimer 读默认时长+标题；MemoOverlay 完成庆祝按 pomodoro_celebrate 门控。
- #3 快捷键自定义：KeyCaptureChip（受控、单字母 A–Z、Keys.onShortcutOverride 捕获时吃全局键避免误触）；
  写 memo_hotkey_key/pomodoro_hotkey_key + setHotkey 冲突校验 + hotkeysChanged 信号；Shell
  memoHotkeyKey/pomodoroHotkeyKey 响应式 → Shortcut.sequences 即时重绑 + 新番茄 Shortcut→togglePomodoro。

## Notes for next agent
- Worktree build: PATH = Qt 6.11.1 mingw_64 bin + mingw1310 + CMake_64 + Ninja, then
  build.py. Kill TimeArc.exe before each rebuild (exe lock).
- Verify pages via temp-force Shell landing var lp + nightMode + page currentTab,
  rebuild, PrintWindow shoot.ps1; REVERT before commit (grep TEMP-VERIFY).
- Read-layer filters default all-on = no behavior change; toggling pushes via
  setReadFilters (bumps recordsGeneration + emits usageStatsChanged → pages recompute).
- DEFERRED (separate change, per owner): 3E global accent injection + i18n; G-ANON
  share-image render anonymize.
