# Error Report - open-folder-unix-file-url

## Metadata

- Level: **L2**
- Track: **C**
- Topic: open-folder-unix-file-url
- Recorded: 2026-07-29T07:23:53Z
- Session: 20260729-0715-C-open-folder-unix-file-url
- Platform: macOS and Linux (Windows unaffected)
- Tooling: Qt 6 (/opt/homebrew/opt/qt) `qml` runtime probe, static test

## 1. What happened

`_folderUrlOf` prefixed `file:///` unconditionally, which is correct only for
Windows drive paths. On macOS/Linux the directory already starts with a slash,
producing `file:////Users/...` — Qt parses that as an empty authority plus a
non-local `//Users/...` path, so `Qt.openUrlExternally` returned false and the
"Open Folder" button did nothing, silently, because the return value was
discarded.

## 2. Evidence

Reported by the user: the button label translated correctly but clicking it
never opened Finder. Reproduced with the exact string the button builds, run
through the real call in Qt's `qml` runtime:

```
before (4 slashes): Qt.openUrlExternally("file:////Users/jz2025/Downloads") -> false
after  (3 slashes): Qt.openUrlExternally("file:///Users/jz2025/Downloads")  -> true
```

The `false` return was never inspected, so nothing surfaced: the confirm card
closed on click and no toast, log line or system error followed.

## 3. Root cause

- Immediate cause: `return "file:///" + dir`. A Windows drive path (`C:/…`)
  carries no leading slash and needs all three; a Unix absolute path supplies
  its own, so the third slash is one too many.
- Underlying cause: the helper was written against Windows path shape and
  never revisited when macOS support landed. Nothing about the code reads as
  platform-specific, so it does not invite a second look — the platform
  assumption is encoded in a slash count.
- Secondary defects found in the same function: no `encodeURI`, so any space
  or non-ASCII character breaks the URL independently. Not hypothetical — the
  default service directory is `~/Library/Application Support/TimeArc/service`.
  Also `i > 0` treated a file at the Unix root (`/foo.db`, `lastIndexOf` is 0)
  as its own parent directory.
- Why the harness/checklists did not prevent it: no test covered URL
  construction, and `rules/02-platform-boundaries.md` treats platform
  divergence as a `src/service/` concern — this is platform-specific logic
  living in shared QML, which no rule addresses.

## 4. Fix

- Files changed:
  - `qml/desktop/pages/DesktopProfilePage.qml` — choose the prefix from the
    path shape (`dir.charAt(0) === "/" ? "file://" : "file:///"`), add
    `encodeURI(dir)`, handle the root-level-file case, and check the
    `openUrlExternally` return value with a failure toast.
  - `qml/desktop/components/I18n.js` — `en`/`ja` entries for that toast.
  - `tests/file_url_static_test.py` — new.
- Short description: build local-file URLs from the path shape instead of
  assuming Windows, and stop discarding the failure signal.
- Commit: (uncommitted at time of writing)

## 5. Prevention

`tests/file_url_static_test.py` fails on a bare `"file:///" + …` return in
`_folderUrlOf`, and asserts the conditional prefix, `encodeURI`, the
root-level-file branch, and the checked return value. It also pins the two
sites that were already correct (`MacMenuBar.qml`, `MobileAppIcon.qml`) so the
idiom cannot drift back.

Verified across every path shape through the real function body in Qt's JS
engine: macOS, macOS with a space, macOS non-ASCII, Linux, Unix root-level
file, Windows drive, Windows backslashes.
