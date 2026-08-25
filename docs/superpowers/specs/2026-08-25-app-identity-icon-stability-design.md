# App Identity and Icon Stability Design

## Goal

Keep desktop statistics icons stable across ranges and refreshes, always use
the installed WeChat main executable's default system icon, and let users map
an application to a custom identity without rewriting collected history.

## Decisions

- Do not add custom icon upload or bundled third-party brand artwork.
- WeChat uses the system icon extracted from `Weixin.exe` or `WeChat.exe`.
  `WeChatAppEx.exe`, updater, browser, and plugin executables are never icon
  representatives for the merged `app:wechat` identity.
- Other apps retain their system icons. The read layer only replaces a missing
  or obsolete executable path with the newest valid path for the same group.
- Custom IDs are UI-private aliases. The service database and raw `app_id`
  values remain unchanged and the service remains their sole writer.
- Two source identities mapped to the same custom ID are intentionally merged
  in every historical statistics range. Removing the alias restores the raw
  grouping immediately.

## Alternatives Considered

1. **Read-layer alias map (selected).** Safe, reversible, applies to history,
   and preserves the two-process/on-disk contract.
2. **Rewrite service database IDs.** Rejected because the UI is read-only and
   rewriting foreign identities risks splitting or losing history.
3. **Visual-only ID label.** Rejected because it would not repair grouping,
   adapter metadata, or historical totals.

## Architecture

### Service side

The collector continues emitting raw executable-path identities and does not
read UI preferences. No service schema, database writer, or sampler changes.

### UI side

`SettingsRepository` stores one JSON object from source group key to custom ID.
`UsageStatManager` receives this mapping separately from existing visibility
filters and applies it before aggregation. Adapter metadata, name, category,
icon identity, all-period totals, and segment grouping use the effective ID.
Raw IDs remain available in the application-management editor for recovery.

The manager also derives one canonical executable path per effective group from
all retained records. Candidates must exist on disk; the newest valid path wins,
except `app:wechat`, where the basename must be `Weixin.exe` or `WeChat.exe`.
If no valid candidate exists, the existing letter fallback remains visible.

## Application Management UI

Each application row keeps its existing visibility switch and gains a compact
edit action. Expanding a row shows:

- Original ID (read-only)
- Custom ID field
- Save and Restore Default actions

IDs are normalized to lowercase `app:<slug>` values. Empty values, whitespace,
path separators, and unsupported prefixes are rejected inline. When the target
ID already exists, the UI warns that historical statistics will merge and asks
for explicit confirmation. Saving refreshes settings and statistics without an
application restart.

## Error Handling

- Invalid ID: keep the editor open and show a field-level explanation.
- Settings write failure: retain the previous mapping and show a toast.
- Missing executable: show the existing deterministic letter fallback; never
  render a blank icon slot.
- Alias cycle is impossible because mappings are resolved once from raw source
  keys to normalized targets; targets are not recursively remapped.

## Testing

- WeChat helper appears before the main process: main WeChat icon path wins.
- Old version path is missing and a newer valid path exists: valid path wins.
- No valid path exists: deterministic fallback remains non-empty.
- Alias changes historical day/week/month/year aggregation and can be restored.
- Two sources targeting the same ID merge interval unions without double count.
- Invalid IDs and merge confirmation follow the specified UI states.
- Existing hidden-app filtering and unmodified IDs retain current behavior.

## Manual Acceptance

Open Statistics and Application Management, verify the same WeChat default icon
appears in ranking, clock, and all-app rows. Change one test application's ID to
an existing adapter ID, confirm the merge warning, verify historical totals and
icon metadata update, then restore the default ID and verify the split returns.
