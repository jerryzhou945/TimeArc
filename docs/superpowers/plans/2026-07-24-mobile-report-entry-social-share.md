# Mobile Report Entry and Direct Social Share Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mismatched Memory Lake report cover and deliver gallery-first Android sharing with explicit WeChat Moments, QQ Zone, and system targets that degrade honestly before platform authorization.

**Architecture:** QML owns poster generation, presentation, and the four-action share bar. `MobileUiService` owns configuration and a stable channel API; `MobileUiBridge` owns MediaStore and system sharing, while channel-specific Java adapters isolate optional official SDK calls and report configuration/client state without inventing success.

**Tech Stack:** Qt 6 Quick/QML and C++17, Android Java, MediaStore, FileProvider, WeChat OpenSDK adapter contract, QQ Connect adapter contract, SQLite-backed `SettingsRepository`, Python static tests.

## Global Constraints

- Work directly in `D:\TimeArc\time-arc`; do not create a worktree.
- Every channel action saves the PNG to `Pictures/TimeArc` before social handoff.
- Empty AppIDs show `等待平台授权`; no placeholder AppID enters a release.
- A launched target app is not reported as a successful post.
- Posters never receive package names, window titles, contacts, or device IDs.
- The seasonal cover uses bundled local month art and honors reduced motion.
- Build only through `.local-python\Python312\python.exe .harness/tools/build.py`.
- Run `scan_qt_log.py` after each QML preview and `harness_check.py` before commits.

---

### Task 1: Seasonal Glass Monthly Entry

**Files:**
- Modify: `qml/mobile/pages/MobileHistoryPage.qml`
- Modify: `qml/mobile/components/MobileMonthlyStory.qml`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Consumes: `report.profile`, `MobileMonthProfiles.forMonth(month)`, existing `theme.reducedMotion`.
- Produces: a local seasonal image cover and neutral `6 / 6` final progress label.

- [ ] **Step 1: Write failing static assertions**

Add assertions that `MobileHistoryPage.qml` imports `MobileMonthProfiles.js`,
uses `Image.PreserveAspectCrop`, contains `report.profile.sceneSource`, and no
longer contains the old report-cover `Canvas`. Assert the story contains
`"6 / 6"` and does not contain `? "完成"`.

- [ ] **Step 2: Run and verify RED**

Run:

```powershell
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
```

Expected: failure for the existing Canvas cover and “完成” label.

- [ ] **Step 3: Implement the seasonal glass cover**

Derive a cover profile from `report.profile` with a
`MobileMonthProfiles.forMonth()` fallback. Put the scene image behind one
vertical contrast veil. Use a border-only glass layer, 20 px internal spacing,
white primary text, month accent eyebrow, and the existing compact action.
Do not add a nested opaque card.

- [ ] **Step 4: Replace final-page completion copy**

Change the bottom-right story label to:

```qml
text: (root.currentPage + 1) + " / " + root.pageCount
font.pixelSize: 11
color: "#AFFFFFFF"
```

- [ ] **Step 5: Verify and commit**

Run the static test and harness desktop build, then commit:

```powershell
git add qml/mobile/pages/MobileHistoryPage.qml qml/mobile/components/MobileMonthlyStory.qml tests/mobile_ui_static_test.py
git commit -m "feat: align monthly entry with seasonal stories"
```

---

### Task 2: Gallery-First Android Media Export

**Files:**
- Modify: `android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java`
- Modify: `src/services/mobile/mobile_ui_service.h`
- Modify: `src/services/mobile/mobile_ui_service.cpp`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Produces: `Q_INVOKABLE bool saveImageToGallery(const QUrl&, const QString&)`.
- Java produces: `saveImageToGallery(Context, String, String) -> String`,
  returning the created `content://` URI or an empty string.

- [ ] **Step 1: Add failing MediaStore checks**

Assert Java contains `MediaStore.Images.Media.EXTERNAL_CONTENT_URI`,
`MediaStore.MediaColumns.RELATIVE_PATH`, `Pictures/TimeArc`,
`IS_PENDING`, and `saveImageToGallery`. Assert the C++ header exposes the
QML invokable.

- [ ] **Step 2: Run and verify RED**

Run:

```powershell
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
```

Expected: failure because gallery export does not exist.

- [ ] **Step 3: Implement Android 10+ insertion**

Insert `DISPLAY_NAME`, `MIME_TYPE=image/png`, `RELATIVE_PATH`, and
`IS_PENDING=1`; copy the source PNG to the resolver output stream, clear
`IS_PENDING`, and return the media URI. Delete the incomplete row on failure.

- [ ] **Step 4: Implement Android 9 fallback**

Copy to the public Pictures/TimeArc directory and call
`MediaScannerConnection.scanFile`. Keep the implementation isolated behind
the same Java method and return a `file://` URI on success.

- [ ] **Step 5: Bridge status to QML**

`MobileUiService` stores the gallery URI in `lastSavedImagePath`, emits the
existing notification, and sets a specific Chinese error on failure.

- [ ] **Step 6: Verify and commit**

Run mobile and Android static checks plus the harness build, then commit:

```powershell
git add android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java src/services/mobile/mobile_ui_service.h src/services/mobile/mobile_ui_service.cpp tests/mobile_ui_static_test.py
git commit -m "feat: save mobile share images to gallery"
```

---

### Task 3: Stable Social Channel Adapter Contracts

**Files:**
- Create: `android/src/main/java/com/timearc/mobile/ui/WeChatMomentsAdapter.java`
- Create: `android/src/main/java/com/timearc/mobile/ui/QqZoneAdapter.java`
- Modify: `android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java`
- Modify: `src/services/mobile/mobile_ui_service.h`
- Modify: `src/services/mobile/mobile_ui_service.cpp`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- QML: `shareImageToChannel(source, channel, title) -> bool`.
- QML: `socialShareStatus(channel) -> QVariantMap`.
- Java: `shareImageToChannel(Context, path, channel, title, appId) -> String`.
- Status codes: `ready`, `waiting_authorization`, `client_missing`,
  `sdk_missing`, `launch_failed`, `saved`.

- [ ] **Step 1: Add failing channel-contract tests**

Assert all methods and status codes exist. Assert channel validation accepts
only `gallery`, `moments`, `qzone`, and `system`.

- [ ] **Step 2: Run and verify RED**

Run the mobile static test. Expected: missing adapters and invokables.

- [ ] **Step 3: Implement WeChat adapter boundary**

The adapter checks AppID, WeChat installation, and OpenSDK class availability.
When available it builds an image message and sends it with timeline scene;
when unavailable it returns the exact status code. It must not report publish
success from `sendReq` alone.

- [ ] **Step 4: Implement QQ Zone adapter boundary**

The adapter checks AppID, QQ/Qzone client installation, and QQ Connect class
availability. It invokes the Qzone image-publish contract when available and
returns the exact status code otherwise.

- [ ] **Step 5: Enforce save-before-handoff**

`shareImageToChannel` first calls gallery export. Only after success may it
call either adapter or the existing Sharesheet. Its final message combines
the saved result and adapter state.

- [ ] **Step 6: Verify and commit**

Run static checks and build, then commit:

```powershell
git add android/src/main/java/com/timearc/mobile/ui/WeChatMomentsAdapter.java android/src/main/java/com/timearc/mobile/ui/QqZoneAdapter.java android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java src/services/mobile/mobile_ui_service.h src/services/mobile/mobile_ui_service.cpp tests/mobile_ui_static_test.py
git commit -m "feat: add direct social share adapters"
```

---

### Task 4: AppID Configuration and Authorization State

**Files:**
- Modify: `qml/mobile/pages/MobileSettingsPage.qml`
- Modify: `src/services/mobile/mobile_ui_service.h`
- Modify: `src/services/mobile/mobile_ui_service.cpp`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Properties: `wechatAppId`, `qqAppId`.
- Invokable: `setSocialAppId(channel, value) -> bool`.
- Settings keys: `mobile_share_wechat_app_id`, `mobile_share_qq_app_id`.

- [ ] **Step 1: Add failing persistence and UI checks**

Assert both settings keys and properties exist, and Settings contains
“社交平台授权”, “微信 AppID”, “QQ AppID”, and “等待平台授权”.

- [ ] **Step 2: Run and verify RED**

Run mobile static checks. Expected: missing properties and section.

- [ ] **Step 3: Implement local settings storage**

Trim values, accept empty strings for clearing, reject whitespace or values
over 128 characters, persist through `SettingsRepository`, emit property
notifications, and never log values.

- [ ] **Step 4: Add settings UI**

Reuse existing transparent setting rows and text-field vocabulary. Show one
field per platform, a status label from `socialShareStatus`, and one sentence
explaining package/signature registration. Password masking is not used
because AppIDs are public identifiers.

- [ ] **Step 5: Verify and commit**

Run static checks, build, harness check, and commit:

```powershell
git add qml/mobile/pages/MobileSettingsPage.qml src/services/mobile/mobile_ui_service.h src/services/mobile/mobile_ui_service.cpp tests/mobile_ui_static_test.py
git commit -m "feat: configure mobile social authorization"
```

---

### Task 5: Unified Four-Action Share Bar

**Files:**
- Create: `qml/mobile/components/MobileShareActionBar.qml`
- Modify: `qml/mobile/components/MobileShareOverlay.qml`
- Modify: `qml/mobile/components/MobileRankingShareOverlay.qml`
- Modify: `qml/mobile/components/MobileMonthlyStory.qml`
- Modify: `qml/CMakeLists.txt`
- Modify: `tests/mobile_ui_static_test.py`

**Interfaces:**
- Consumes: `imageSource`, `exportImage(callback)`, channel statuses.
- Emits: `channelRequested(string channel)`.
- Shows: gallery, moments, qzone, system in that order.

- [ ] **Step 1: Add failing share-bar tests**

Assert the new component is registered and all three share surfaces use it.
Assert the four channel keys occur in the component and social feedback
contains `已保存到图库` plus authorization state.

- [ ] **Step 2: Run and verify RED**

Run mobile static checks. Expected: missing action bar.

- [ ] **Step 3: Build the transparent action row**

Use four equal 56 px touch targets with recognizable monochrome glyphs,
11 px labels, active press feedback, and no style chooser. Disabled social
targets remain tappable so they can save locally and explain authorization.

- [ ] **Step 4: Connect each poster surface**

Each surface grabs its existing poster tree once, writes the temporary PNG,
and passes the chosen channel to `shareImageToChannel`. Gallery success closes
neither preview nor report. A social failure keeps the preview open and shows
the combined saved/authorization message.

- [ ] **Step 5: Verify and commit**

Run static checks and build, then commit:

```powershell
git add qml/mobile/components/MobileShareActionBar.qml qml/mobile/components/MobileShareOverlay.qml qml/mobile/components/MobileRankingShareOverlay.qml qml/mobile/components/MobileMonthlyStory.qml qml/CMakeLists.txt tests/mobile_ui_static_test.py
git commit -m "feat: add mobile social share action bar"
```

---

### Task 6: Runtime Verification and Handoff

**Files:**
- Modify: `.harness/journal/sessions/20260724-0721-B-mobile-social-share.md`
- Modify: `README.md`

- [ ] **Step 1: Run all tests**

```powershell
.local-python\Python312\python.exe tests/mobile_ui_static_test.py
.local-python\Python312\python.exe tests/android_usage_static_test.py
.local-python\Python312\python.exe .harness/tools/build.py
ctest --test-dir build --output-on-failure
```

Expected: every command exits zero.

- [ ] **Step 2: Run mobile preview**

Inspect the seasonal entry, `6 / 6`, all four share actions, unconfigured
authorization messages, dark/light wallpaper readability, and reduced motion.

- [ ] **Step 3: Scan QML logs**

```powershell
.local-python\Python312\python.exe .harness/tools/scan_qt_log.py --track B
```

Expected: zero new QML warnings.

- [ ] **Step 4: Document the signed-device boundary**

Record that MediaStore and unconfigured states are implemented locally while
direct publication requires official SDK binaries, registered AppIDs, package
name, release signature, installed clients, and real-device callbacks.

- [ ] **Step 5: Final harness check and commit**

```powershell
.local-python\Python312\python.exe .harness/tools/harness_check.py
git add README.md .harness/journal/sessions/20260724-0721-B-mobile-social-share.md
git commit -m "docs: record mobile social share verification"
```
