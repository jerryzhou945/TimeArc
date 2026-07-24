# Mobile Report Release, Avatar Refresh, and APK Design

## Goal

Make avatar selection visibly refresh, publish monthly reports only after their
release time, notify users about unseen report releases, remove simulated phone
status chrome, and produce a testable Android APK after integration.

## Avatar refresh

The imported avatar file and settings path are already valid. The Profile page
will own an `avatarSource` URL, initialize it from `MobileUiService.avatarUrl`,
and explicitly clear then reassign it on `avatarChanged`. This forces the
asynchronous image and rounded composition layer to rebuild. The page displays
“头像已更新” or `lastError` after selection instead of silently doing nothing.

## Report release policy

All release calculations use device-local date and time.

- A month report is released at 08:00 on the first day of the following month.
- At or after that instant, the previous calendar month is the latest released
  report.
- Before 08:00 on the first day, the latest released report remains two months
  behind the current month.
- Example: June 2026 is visible from July 1, 2026 at 08:00. July 2026 is
  visible from August 1, 2026 at 08:00.
- An annual release key advances at 08:00 on January 1 for the previous year.

`MobileUsageService` exposes the latest released month/year keys and a combined
release token. Memory Lake loads the released month with exact calendar start
and end dates; it never substitutes the current partial month.

## Unread report notification

The mobile shell compares the current release token with
`mobile_seen_report_release_token` in `SettingsRepository`. A red dot appears
on the Memory Lake tab whenever either the monthly or annual key changes. The
token is marked seen when the user opens Memory Lake, mirroring a familiar
message-tab notification without displaying an invented count.

The annual key is notification-ready and may appear in the archive label; this
change does not invent a full annual-story reader.

## Status chrome

`MobileStatusBar` remains as a zero-height compatibility component so existing
pages do not need structural changes. It renders no hard-coded time, battery,
or signal UI. Android uses the real platform status area.

## APK and integration

After desktop/mobile verification:

1. push the feature branch and open a non-draft PR;
2. merge the PR into `dev`;
3. delete the remote and local feature branch;
4. build the Android APK from the merged `dev` state;
5. report the exact APK path and whether it is debug/release signed.

No production signing key is assumed. If release credentials are unavailable,
the deliverable is an installable debug APK for device testing.

## Verification

- Static checks assert avatar refresh bindings, zero fake status chrome,
  release API, 08:00 boundary markers, released-month Memory Lake, and badge.
- Release policy cases cover July 1 before/after 08:00 and August 1 at 08:00.
- Build through the project harness and run the mobile preview.
- Build the Android target from merged `dev`.

