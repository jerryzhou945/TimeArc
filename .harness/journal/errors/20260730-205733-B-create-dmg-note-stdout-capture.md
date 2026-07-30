# Error Report - create-dmg-note-stdout-capture

## Metadata

- Level: **L3**
- Track: **B**
- Topic: create-dmg-note-stdout-capture
- Recorded: 2026-07-30T20:57:33Z
- Session: 20260731-0450-B-macos-create-dmg
- Platform: macos
- Tooling: (fill in)

## 1. What happened

select_dmg_tool returns its choice on stdout but also called note(), which writes to stdout; under dmg_tool=$(select_dmg_tool) the progress line was captured into the variable instead of shown. Caught in diff review, not by a test. Fixed by redirecting those notes to stderr.

## 2. Evidence

```

  local architecture
  architecture="$(architecture_label "$app_bundle/Contents/MacOS/TimeArc")"
  local package_name="TimeArc-$version-macos-$architecture"
  local package_dir="$DIST_DIR/$package_name"
  local dmg_path="$DIST_DIR/$package_name.dmg"
  safe_remove "$package_dir"
  rm -f -- "$dmg_path"
  mkdir -p "$package_dir" "$dmg_root"
  ditto "$app_bundle" "$package_dir/TimeArc.app"
  ditto "$app_bundle" "$dmg_root/TimeArc.app"

  if [[ "$dmg_tool" == "create-dmg" ]]; then
    create_dmg_package "$dmg_path" "$dmg_root"
  else
    hdiutil_package "$dmg_path" "$dmg_root"
  fi
  if [[ -n "${TIMEARC_CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --timestamp \
      --sign "$TIMEARC_CODESIGN_IDENTITY" "$dmg_path"
    codesign --verify --verbose=2 "$dmg_path"
  fi
  hdiutil verify "$dmg_path"

  if [[ -n "${TIMEARC_NOTARY_PROFILE:-}" ]]; then
    [[ -n "${TIMEARC_CODESIGN_IDENTITY:-}" ]] ||
      die "notarization requires TIMEARC_CODESIGN_IDENTITY"
    note "submitting DMG for notarization"
    xcrun notarytool submit "$dmg_path" \
      --keychain-profile "$TIMEARC_NOTARY_PROFILE" \
      --wait
    xcrun stapler staple "$dmg_path"
    xcrun stapler validate "$dmg_path"
  else
    note "notarization skipped; set TIMEARC_NOTARY_PROFILE to enable it"
  fi

  safe_remove "$stage"
  safe_remove "$dmg_root"
  note "app -> $package_dir/TimeArc.app"
  note "dmg -> $dmg_path"
}

configure
build_release

case "$ACTION" in
  build) ;;
  test) run_tests ;;
  package) package_release ;;
  release)
    run_tests
    package_release
    ;;
esac
```

## 3. Root cause

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
