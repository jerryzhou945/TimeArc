# App Identity and Icon Stability Design

## Goal

Keep desktop statistics icons stable across ranges and refreshes, always use
the installed WeChat main executable's default system icon, and let users set
a custom display name without changing application identity or history.

## Decisions

- Do not add custom icon upload or bundled third-party brand artwork.
- WeChat uses the system icon extracted from `Weixin.exe` or `WeChat.exe`.
  `WeChatAppEx.exe`, updater, browser, and plugin executables are never icon
  representatives for the merged `app:wechat` identity.
- Other apps retain their system icons. The read layer only replaces a missing
  or obsolete executable path with the newest valid path for the same group.
- Custom display names are UI-private labels. The service database, raw
  `app_id`, group key, historical totals, and collector behavior stay unchanged.
- Restoring the default removes only the label override; it never merges or
  splits history.

## Alternatives Considered

1. **Read-layer display-name map (selected).** Safe, reversible, and preserves
   the two-process/on-disk contract.
2. **Rewrite service database IDs.** Rejected because the UI is read-only and
   rewriting foreign identities risks splitting or losing history.
3. **Editable application ID.** Rejected because the requested value is a
   presentation label, and changing identity would unexpectedly regroup data.

## Architecture

### Service side

The collector continues emitting raw executable-path identities and does not
read UI preferences. No service schema, database writer, or sampler changes.

### UI side

`SettingsRepository` stores one JSON object from source group key to custom
display name. `UsageStatManager` receives the mapping separately from existing
visibility filters and adds the label after aggregation. Raw IDs, adapter
identity, category, icon identity, totals, and segment grouping are unchanged.

The manager also derives one canonical executable path per effective group from
all retained records. Candidates must exist on disk; the newest valid path wins,
except `app:wechat`, where the basename must be `Weixin.exe` or `WeChat.exe`.
If no valid candidate exists, the existing letter fallback remains visible.

## Application Management UI

Each application row keeps its existing visibility switch and gains a compact
edit action. Expanding a row shows:

- Original ID (read-only)
- Custom display-name field
- Save and Restore Default Name actions

Names are trimmed, limited to 80 characters, and may contain Chinese. Empty
values are rejected inline. Saving refreshes settings and statistics without
an application restart; no collision or merge flow exists because identity is
never changed.

## Error Handling

- Empty display name: keep the editor open and show a field-level explanation.
- Settings write failure: retain the previous mapping and show a toast.
- Missing executable: show the existing deterministic letter fallback; never
  render a blank icon slot.

## Testing

- WeChat helper appears before the main process: main WeChat icon path wins.
- Old version path is missing and a newer valid path exists: valid path wins.
- No valid path exists: deterministic fallback remains non-empty.
- A custom Chinese name appears consistently in home, statistics, and settings.
- Setting or restoring a name never changes the source group key or totals.
- Empty names are rejected and restore removes the override.
- Existing hidden-app filtering and application IDs retain current behavior.

## Manual Acceptance

Open Statistics and Application Management, verify the same WeChat default icon
appears in ranking, clock, and all-app rows. Change one test application's
display name to Chinese, verify the name updates everywhere while totals and ID
stay fixed, then restore the default name.
