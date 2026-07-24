# Mobile Report Entry and Direct Social Share Design

## Goal

Polish the Memory Lake monthly-report entry so it belongs to the seasonal
story system, and add a truthful Android sharing flow that always saves the
generated poster to the gallery before attempting WeChat Moments, QQ Zone, or
the Android Sharesheet.

## Visual Direction

The monthly entry uses the active month profile and the same bundled scene as
the full report. The scene fills the rounded entry with
`Image.PreserveAspectCrop`; a restrained vertical veil protects contrast.
Content sits directly over the scene with one translucent glass information
plane, not a second opaque card. The month eyebrow, report title, short
data-derived summary, and one compact “打开完整月报” action form the hierarchy.

The old generated green Canvas, decorative diagonal rain lines, and unrelated
button styling are removed. Seasonal motion is optional and must respect the
existing reduced-motion setting. The full report’s final-page corner label
changes from “完成” to the neutral progress marker `6 / 6`; the share action
remains the only primary action.

## Share Interaction

Every poster preview exposes one bottom action row:

1. 保存到图库
2. 朋友圈
3. QQ 动态
4. 更多

All actions first save the current PNG to Android shared media through
`MediaStore.Images`. Saving is idempotent for a single generated share action:
the same path is not inserted twice during one attempt. On Android 10 and
newer, no storage permission is requested for app-created media. The gallery
location is `Pictures/TimeArc`.

After a successful gallery save:

- `gallery` stops and reports the saved result.
- `moments` invokes the WeChat OpenSDK timeline scene.
- `qzone` invokes the QQ Connect Qzone publish/share API.
- `system` opens the Android Sharesheet with the existing FileProvider URI.

If a channel cannot continue, the saved gallery copy remains successful and
the UI reports both facts, for example:

> 已保存到图库 · 朋友圈等待平台授权

No button may claim that a social post succeeded merely because the target
application opened.

## Platform Adapters

`MobileUiService` owns the QML-facing contract:

- `saveImageToGallery(source, albumName)`
- `shareImageToChannel(source, channel, title)`
- `socialShareStatus(channel)`
- local WeChat and QQ AppID properties

The Android JNI layer delegates to `MobileUiBridge`. The bridge separates:

- MediaStore insertion and stream copying;
- FileProvider system sharing;
- WeChat Moments adapter;
- QQ Zone adapter;
- installed-client and configuration checks.

Official SDK calls live behind channel-specific Java adapters. Their public
entry points remain stable even while AppIDs are empty. SDK callbacks update
status where the platform provides them; launch success alone is not presented
as publish success.

## Configuration

“我的 → 分享与隐私” gains a “社交平台授权” section containing:

- 微信 AppID field and current state;
- QQ AppID field and current state;
- short guidance that package name and release signature must also be
  registered on the corresponding platform.

AppIDs are identifiers rather than secrets and are stored in the existing
local settings repository. Empty or malformed values keep the related channel
disabled and display “等待平台授权”. No placeholder AppID is compiled into a
release build.

## Privacy and Failure States

Posters continue to contain only aggregate durations, dates, narrative facts,
and explicitly selected app identity. Package names, window titles, contacts,
device identifiers, and SDK credentials never enter poster QML.

The UI distinguishes:

- image generation failure;
- gallery write failure;
- missing AppID;
- signature/package registration mismatch;
- target client not installed;
- SDK rejected or cancelled;
- system share unavailable.

For every social-channel failure after gallery insertion, “更多” remains
available as a fallback.

## Testing

Static tests assert the seasonal entry, removal of the old Canvas and “完成”
label, four share actions, MediaStore implementation, SDK adapter contracts,
configuration fields, and privacy-safe data flow.

C++ smoke tests cover channel validation and local setting persistence where
the existing service test harness permits it. Android tests remain source-level
until a signed build with registered AppIDs is available. Desktop mobile
preview verifies layout, empty authorization states, and system fallback.

## Out of Scope

- Applying for WeChat or QQ platform accounts.
- Registering the release package signature on third-party portals.
- Claiming successful publication without an SDK callback.
- Adding cloud storage or uploading TimeArc poster data to a TimeArc server.
