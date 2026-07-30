#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
ACTION="release"
ACTION_SET=0

usage() {
  cat <<'EOF'
Usage: tools/build-macos.sh [--release|--build|--test|--package]

  --release  Configure, build, test, deploy Qt, sign, and create a DMG.
             This is the default when no option is supplied.
  --build    Configure and build the Release configuration.
  --test     Configure, build, and run the Release tests.
  --package  Configure, build, deploy Qt, sign, and create a DMG.

The DMG is styled with create-dmg when that tool is in PATH, and is otherwise
a plain hdiutil image with the same contents.

Environment:
  TIMEARC_BUILD_DIR            Build directory (default: build).
  TIMEARC_DIST_DIR             Release output directory (default: dist).
  TIMEARC_QT_PREFIX            Optional Qt installation prefix for CMake.
  TIMEARC_MACDEPLOYQT          Optional explicit macdeployqt executable.
  TIMEARC_CMAKE_GENERATOR      Swift-capable generator (default: Ninja, then Xcode).
  TIMEARC_CODESIGN_IDENTITY    Developer ID Application identity.
  TIMEARC_ENTITLEMENTS         Optional entitlements for TimeArc.app.
  TIMEARC_SERVICE_ENTITLEMENTS Optional entitlements for time-arc-service.
  TIMEARC_NOTARY_PROFILE       notarytool Keychain profile.
  TIMEARC_REQUIRE_SIGNING=1    Reject an ad-hoc local package.
  TIMEARC_DMG_TOOL             DMG backend: auto (default), create-dmg, hdiutil.
                               create-dmg needs a GUI session; use hdiutil when
                               packaging headlessly.
EOF
}

die() {
  echo "build-macos: error: $*" >&2
  exit 1
}

note() {
  echo "build-macos: $*"
}

set_action() {
  if [[ "$ACTION_SET" -eq 1 ]]; then
    die "choose exactly one action"
  fi
  ACTION="$1"
  ACTION_SET=1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --release) set_action "release" ;;
    --build) set_action "build" ;;
    --test) set_action "test" ;;
    --package) set_action "package" ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ "$(uname -s)" == "Darwin" ]] || die "this script requires macOS"

BUILD_DIR="${TIMEARC_BUILD_DIR:-$REPO_ROOT/build}"
DIST_DIR="${TIMEARC_DIST_DIR:-$REPO_ROOT/dist}"
BUILD_DIR="$(mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR" && pwd -P)"
DIST_DIR="$(mkdir -p "$DIST_DIR" && cd "$DIST_DIR" && pwd -P)"

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

safe_remove() {
  local target="$1"
  case "$target" in
    "$DIST_DIR"/*) rm -rf -- "$target" ;;
    *) die "refusing to remove path outside dist: $target" ;;
  esac
}

select_swift_generator() {
  local generator="${TIMEARC_CMAKE_GENERATOR:-}"
  if [[ -z "$generator" ]]; then
    if command -v ninja >/dev/null 2>&1; then
      generator="Ninja"
    elif command -v xcodebuild >/dev/null 2>&1; then
      generator="Xcode"
    else
      die "Swift requires Ninja or Xcode; install Ninja or set TIMEARC_CMAKE_GENERATOR"
    fi
  fi

  case "$generator" in
    Ninja|"Ninja Multi-Config")
      require_command ninja
      ;;
    Xcode)
      require_command xcodebuild
      ;;
    *)
      die "Swift is not supported by CMake generator '$generator'; use Ninja or Xcode"
      ;;
  esac
  printf '%s\n' "$generator"
}

reset_incompatible_cmake_state() {
  [[ "$BUILD_DIR" != "/" && "$BUILD_DIR" != "$REPO_ROOT" ]] ||
    die "refusing to reset generated state in $BUILD_DIR"
  note "resetting generated CMake state after generator change"
  rm -rf -- "$BUILD_DIR/CMakeFiles"
  rm -f -- \
    "$BUILD_DIR/CMakeCache.txt" \
    "$BUILD_DIR/Makefile" \
    "$BUILD_DIR/build.ninja" \
    "$BUILD_DIR/rules.ninja" \
    "$BUILD_DIR/.ninja_deps" \
    "$BUILD_DIR/.ninja_log"
}

configure() {
  require_command cmake
  local generator
  generator="$(select_swift_generator)"
  local cache="$BUILD_DIR/CMakeCache.txt"
  if [[ -f "$cache" ]]; then
    local cached_generator
    cached_generator="$(sed -nE \
      's/^CMAKE_GENERATOR:INTERNAL=(.*)$/\1/p' "$cache" | head -n 1)"
    if [[ -n "$cached_generator" && "$cached_generator" != "$generator" ]]; then
      note "cached generator '$cached_generator' is incompatible with '$generator'"
      reset_incompatible_cmake_state
    fi
  fi

  local args=(
    -S "$REPO_ROOT"
    -B "$BUILD_DIR"
    -G "$generator"
    -DCMAKE_BUILD_TYPE=Release
  )
  if [[ -n "${TIMEARC_QT_PREFIX:-}" ]]; then
    args+=("-DCMAKE_PREFIX_PATH=$TIMEARC_QT_PREFIX")
  fi
  note "configuring Release in $BUILD_DIR"
  cmake "${args[@]}"
}

build_release() {
  note "building Release"
  cmake --build "$BUILD_DIR" --config Release --parallel
}

run_tests() {
  require_command ctest
  note "running Release tests"
  ctest --test-dir "$BUILD_DIR" -C Release --output-on-failure
}

find_macdeployqt() {
  if [[ -n "${TIMEARC_MACDEPLOYQT:-}" ]]; then
    [[ -x "$TIMEARC_MACDEPLOYQT" ]] ||
      die "TIMEARC_MACDEPLOYQT is not executable: $TIMEARC_MACDEPLOYQT"
    printf '%s\n' "$TIMEARC_MACDEPLOYQT"
    return
  fi
  if command -v macdeployqt >/dev/null 2>&1; then
    command -v macdeployqt
    return
  fi
  if command -v qtpaths6 >/dev/null 2>&1; then
    local qt_bins
    qt_bins="$(qtpaths6 --query QT_INSTALL_BINS)"
    if [[ -x "$qt_bins/macdeployqt" ]]; then
      printf '%s\n' "$qt_bins/macdeployqt"
      return
    fi
  fi
  if [[ -n "${TIMEARC_QT_PREFIX:-}" &&
        -x "$TIMEARC_QT_PREFIX/bin/macdeployqt" ]]; then
    printf '%s\n' "$TIMEARC_QT_PREFIX/bin/macdeployqt"
    return
  fi
  die "macdeployqt not found; set TIMEARC_MACDEPLOYQT"
}

project_version() {
  local version
  version="$(sed -nE \
    's/.*project\(time-arc VERSION ([^ )]+).*/\1/p' \
    "$REPO_ROOT/CMakeLists.txt" | head -n 1)"
  [[ -n "$version" ]] || die "could not read project version from CMakeLists.txt"
  printf '%s\n' "$version"
}

architecture_label() {
  local app_binary="$1"
  local architectures
  architectures="$(lipo -archs "$app_binary")"
  if [[ "$architectures" == *"arm64"* &&
        "$architectures" == *"x86_64"* ]]; then
    printf '%s\n' "universal2"
  elif [[ "$architectures" == *"arm64"* ]]; then
    printf '%s\n' "arm64"
  elif [[ "$architectures" == *"x86_64"* ]]; then
    printf '%s\n' "x86_64"
  else
    die "unsupported app architecture: $architectures"
  fi
}

verify_portable_linkage() {
  local app_bundle="$1"
  local candidate
  local dependency
  local dependency_path
  local install_id
  local resolved_path
  local bad=0

  while IFS= read -r -d '' candidate; do
    if ! file "$candidate" | grep -q "Mach-O"; then
      continue
    fi

    install_id="$(otool -D "$candidate" 2>/dev/null | sed -n '2p' || true)"
    while IFS= read -r dependency; do
      read -r dependency_path _ <<<"$dependency"
      [[ -n "$dependency_path" ]] || continue
      [[ "$dependency_path" == "$install_id" ]] && continue

      resolved_path=""
      case "$dependency_path" in
        /System/Library/*|/usr/lib/*)
          continue
          ;;
        @rpath/*)
          dependency_path="${dependency_path#@rpath/}"
          if [[ -e "$app_bundle/Contents/Frameworks/$dependency_path" ||
                -e "$app_bundle/Contents/MacOS/$dependency_path" ]]; then
            continue
          fi
          ;;
        @executable_path/*)
          resolved_path="$app_bundle/Contents/MacOS/${dependency_path#@executable_path/}"
          ;;
        @loader_path/*)
          resolved_path="$(dirname "$candidate")/${dependency_path#@loader_path/}"
          ;;
        /*)
          ;;
        *)
          ;;
      esac

      if [[ -n "$resolved_path" && -e "$resolved_path" ]]; then
        continue
      fi
      echo "build-macos: unresolved dependency in $candidate: $dependency_path" >&2
      bad=1
    done < <(otool -L "$candidate" | sed '1d')
  done < <(find "$app_bundle/Contents" -type f -print0)

  if [[ "$bad" -ne 0 ]]; then
    die "bundle contains unresolved or development-machine library paths"
  fi
}

deploy_qt() {
  local app_bundle="$1"
  local macdeployqt="$2"
  local deploy_sign_option="-codesign=-"
  if [[ -n "${TIMEARC_CODESIGN_IDENTITY:-}" ]]; then
    deploy_sign_option="-sign-for-notarization=$TIMEARC_CODESIGN_IDENTITY"
  fi

  note "deploying the recorded QML imports and private Qt frameworks"
  cmake \
    "-DTIMEARC_BUILD_DIR=$BUILD_DIR" \
    "-DTIMEARC_DEPLOY_PREFIX=$(dirname "$app_bundle")" \
    "-DTIMEARC_DEPLOY_TOOL=$macdeployqt" \
    "-DTIMEARC_DEPLOY_SIGN_OPTION=$deploy_sign_option" \
    -DCMAKE_MESSAGE_LOG_LEVEL=WARNING \
    -P /dev/stdin <<'CMAKE'
set(QT_DEPLOY_PREFIX "${TIMEARC_DEPLOY_PREFIX}")
set(CMAKE_INSTALL_PREFIX "${TIMEARC_DEPLOY_PREFIX}")
include("${TIMEARC_BUILD_DIR}/.qt/QtDeploySupport.cmake")
set(__QT_DEPLOY_TOOL "${TIMEARC_DEPLOY_TOOL}")

qt6_deploy_qml_imports(TARGET time-arc PLUGINS_FOUND plugins_found)

# Homebrew exposes these two optional plugins as relative symlinks. CMake's
# deploy helper preserves the links, which become broken inside an app bundle,
# so materialize the plugin bytes before macdeployqt processes them.
set(qt_qml_root
  "${__QT_DEPLOY_QT_INSTALL_PREFIX}/${__QT_DEPLOY_QT_INSTALL_DATA}/qml")
foreach(plugin_spec IN ITEMS
    "QtQuick/libqtquick2plugin.dylib"
    "QtQml/libqmlplugin.dylib")
  get_filename_component(plugin_name "${plugin_spec}" NAME)
  set(staged_plugin
    "${QT_DEPLOY_PREFIX}/TimeArc.app/Contents/PlugIns/${plugin_name}")
  if(IS_SYMLINK "${staged_plugin}")
    file(REMOVE "${staged_plugin}")
    file(COPY_FILE "${qt_qml_root}/${plugin_spec}" "${staged_plugin}")
  endif()
endforeach()
foreach(module IN ITEMS QtQuick QtQml)
  set(staged_qmldir
    "${QT_DEPLOY_PREFIX}/TimeArc.app/Contents/Resources/qml/${module}/qmldir")
  if(IS_SYMLINK "${staged_qmldir}")
    file(REMOVE "${staged_qmldir}")
    file(COPY_FILE "${qt_qml_root}/${module}/qmldir" "${staged_qmldir}")
  endif()
endforeach()

# A generic QtQuick.Controls import records every optional control style.
# The macOS style imports Fusion, and Fusion imports Basic, so retain both
# transitive fallbacks alongside the native style.
set(unused_styles Imagine Material Universal FluentWinUI3 iOS)
foreach(style IN LISTS unused_styles)
  string(TOLOWER "${style}" style_lower)
  list(FILTER plugins_found EXCLUDE REGEX
    "qtquickcontrols2${style_lower}(style|styleimpl)plugin")
  file(REMOVE_RECURSE
    "${QT_DEPLOY_PREFIX}/TimeArc.app/Contents/Resources/qml/QtQuick/Controls/${style}")
  file(GLOB unused_style_plugins
    "${QT_DEPLOY_PREFIX}/TimeArc.app/Contents/PlugIns/*qtquickcontrols2${style_lower}*")
  if(unused_style_plugins)
    file(REMOVE ${unused_style_plugins})
  endif()
endforeach()

foreach(required_qml_module IN ITEMS
    "QtQuick/Controls/macOS/qmldir"
    "QtQuick/Controls/Fusion/qmldir"
    "QtQuick/Controls/Basic/qmldir")
  if(NOT EXISTS
      "${QT_DEPLOY_PREFIX}/TimeArc.app/Contents/Resources/qml/${required_qml_module}")
    message(FATAL_ERROR
      "Missing required deployed QML module: ${required_qml_module}")
  endif()
endforeach()
foreach(required_qml_plugin IN ITEMS
    "libqtquickcontrols2macosstyleplugin.dylib"
    "libqtquickcontrols2fusionstyleplugin.dylib"
    "libqtquickcontrols2basicstyleplugin.dylib"
    "libqtquickcontrols2macosstyleimplplugin.dylib"
    "libqtquickcontrols2fusionstyleimplplugin.dylib"
    "libqtquickcontrols2basicstyleimplplugin.dylib")
  if(NOT EXISTS
      "${QT_DEPLOY_PREFIX}/TimeArc.app/Contents/PlugIns/${required_qml_plugin}")
    message(FATAL_ERROR
      "Missing required deployed QML plugin: ${required_qml_plugin}")
  endif()
endforeach()

# The Cocoa platform plugin owns standard application-menu strings after role
# merging. Deploy only the Qt Base catalogs matching TimeArc's in-app languages.
set(QT_DEPLOY_TRANSLATIONS_DIR
  "TimeArc.app/Contents/Resources/translations")
qt6_deploy_translations(
  CATALOGS qtbase
  LOCALES zh_CN ja
)

qt6_deploy_runtime_dependencies(
  EXECUTABLE "TimeArc.app"
  ADDITIONAL_MODULES ${plugins_found}
  # Targeted catalogs were deployed above; suppress the broad automatic pass.
  NO_TRANSLATIONS
  DEPLOY_TOOL_OPTIONS "${TIMEARC_DEPLOY_SIGN_OPTION}" "-verbose=1"
)
CMAKE

  if [[ ! -d "$app_bundle/Contents/Frameworks" ]]; then
    die "Qt deployment did not create Contents/Frameworks"
  fi
}

sign_bundle() {
  local app_bundle="$1"
  local helper="$app_bundle/Contents/MacOS/time-arc-service"
  local identity="${TIMEARC_CODESIGN_IDENTITY:-}"

  if [[ -z "$identity" ]]; then
    if [[ "${TIMEARC_REQUIRE_SIGNING:-0}" == "1" ]]; then
      die "TIMEARC_CODESIGN_IDENTITY is required"
    fi
    note "using ad-hoc signing; this is a local package, not a public release"
    codesign --force --sign - "$helper"
    codesign --force --sign - "$app_bundle"
  else
    local service_args=(--force --options runtime --timestamp --sign "$identity")
    local app_args=(--force --options runtime --timestamp --sign "$identity")
    if [[ -n "${TIMEARC_SERVICE_ENTITLEMENTS:-}" ]]; then
      [[ -f "$TIMEARC_SERVICE_ENTITLEMENTS" ]] ||
        die "service entitlements not found: $TIMEARC_SERVICE_ENTITLEMENTS"
      service_args+=(--entitlements "$TIMEARC_SERVICE_ENTITLEMENTS")
    fi
    if [[ -n "${TIMEARC_ENTITLEMENTS:-}" ]]; then
      [[ -f "$TIMEARC_ENTITLEMENTS" ]] ||
        die "app entitlements not found: $TIMEARC_ENTITLEMENTS"
      app_args+=(--entitlements "$TIMEARC_ENTITLEMENTS")
    fi
    codesign "${service_args[@]}" "$helper"
    codesign "${app_args[@]}" "$app_bundle"
  fi

  codesign --verify --deep --strict --verbose=1 "$app_bundle"
}

# Finder layout for the styled DMG. Coordinates are window-relative points.
DMG_VOLUME_NAME="TimeArc"
DMG_WINDOW_POS_X=200
DMG_WINDOW_POS_Y=120
DMG_WINDOW_WIDTH=720
DMG_WINDOW_HEIGHT=420
DMG_ICON_SIZE=112
DMG_TEXT_SIZE=14
DMG_APP_ICON_X=180
DMG_APP_ICON_Y=200
DMG_DROP_LINK_X=540
DMG_DROP_LINK_Y=200
DMG_VOLICON="$REPO_ROOT/resources/bundle/macos/TimeArc.icns"
DMG_BACKGROUND="$REPO_ROOT/resources/bundle/macos/dmg_background.png"

# Callers read the chosen tool from stdout, so progress notes go to stderr.
select_dmg_tool() {
  local requested="${TIMEARC_DMG_TOOL:-auto}"
  case "$requested" in
    hdiutil)
      printf '%s\n' "hdiutil"
      return
      ;;
    create-dmg)
      command -v create-dmg >/dev/null 2>&1 ||
        die "TIMEARC_DMG_TOOL=create-dmg but create-dmg is not in PATH"
      ;;
    auto)
      if ! command -v create-dmg >/dev/null 2>&1; then
        note "create-dmg not found; building a plain DMG with hdiutil" >&2
        printf '%s\n' "hdiutil"
        return
      fi
      ;;
    *)
      die "unknown TIMEARC_DMG_TOOL: $requested"
      ;;
  esac

  # A second, unrelated tool ships under the same name with a different CLI.
  # Only the create-dmg/create-dmg one understands the layout options below.
  if ! create-dmg --help 2>&1 | grep -q -- "--app-drop-link"; then
    [[ "$requested" != "create-dmg" ]] ||
      die "the create-dmg in PATH does not support --app-drop-link"
    note "the create-dmg in PATH is a different tool; building a plain DMG" >&2
    printf '%s\n' "hdiutil"
    return
  fi

  printf '%s\n' "create-dmg"
}

image_dimension() {
  sips -g "$2" "$1" | sed -nE "s/.*$2: ([0-9]+).*/\1/p"
}

stage_dmg_background() {
  local staged="$1"
  local width
  local height
  width="$(image_dimension "$DMG_BACKGROUND" pixelWidth)"
  height="$(image_dimension "$DMG_BACKGROUND" pixelHeight)"
  [[ -n "$width" && -n "$height" ]] ||
    die "could not read DMG background dimensions: $DMG_BACKGROUND"

  # Finder neither scales nor centers the background, so an image that is not
  # exactly the window size leaves the icon coordinates pointing at the wrong
  # part of the artwork.
  if [[ "$width" == "$DMG_WINDOW_WIDTH" && "$height" == "$DMG_WINDOW_HEIGHT" ]]; then
    ditto "$DMG_BACKGROUND" "$staged"
    return
  fi
  note "resizing DMG background ${width}x${height} to ${DMG_WINDOW_WIDTH}x${DMG_WINDOW_HEIGHT}"
  sips -z "$DMG_WINDOW_HEIGHT" "$DMG_WINDOW_WIDTH" "$DMG_BACKGROUND" \
    --out "$staged" >/dev/null
}

create_dmg_package() {
  local dmg_path="$1"
  local source_dir="$2"
  require_command create-dmg
  require_command sips
  [[ -f "$DMG_VOLICON" ]] || die "DMG volume icon not found: $DMG_VOLICON"
  [[ -f "$DMG_BACKGROUND" ]] || die "DMG background not found: $DMG_BACKGROUND"

  # create-dmg copies this file into the volume's .background directory and
  # then addresses it from AppleScript, which cannot name a dotfile. Keep the
  # staged file itself visible and hide the directory holding it instead.
  local asset_dir="$DIST_DIR/.timearc-dmg-assets"
  local background="$asset_dir/dmg-background.png"
  safe_remove "$asset_dir"
  mkdir -p "$asset_dir"
  stage_dmg_background "$background"

  note "creating $dmg_path with create-dmg"
  local status=0
  create-dmg \
    --volname "$DMG_VOLUME_NAME" \
    --volicon "$DMG_VOLICON" \
    --background "$background" \
    --window-pos "$DMG_WINDOW_POS_X" "$DMG_WINDOW_POS_Y" \
    --window-size "$DMG_WINDOW_WIDTH" "$DMG_WINDOW_HEIGHT" \
    --icon-size "$DMG_ICON_SIZE" \
    --text-size "$DMG_TEXT_SIZE" \
    --icon "TimeArc.app" "$DMG_APP_ICON_X" "$DMG_APP_ICON_Y" \
    --hide-extension "TimeArc.app" \
    --app-drop-link "$DMG_DROP_LINK_X" "$DMG_DROP_LINK_Y" \
    --format UDZO \
    --overwrite \
    "$dmg_path" \
    "$source_dir" || status=$?

  safe_remove "$asset_dir"
  # create-dmg leaves its writable intermediate next to the output when it
  # bails out partway through.
  rm -f -- "$DIST_DIR"/rw.*."$(basename "$dmg_path")"
  if [[ "$status" -ne 0 || ! -f "$dmg_path" ]]; then
    die "create-dmg failed (exit $status);" \
      "set TIMEARC_DMG_TOOL=hdiutil to build a plain DMG instead"
  fi
}

hdiutil_package() {
  local dmg_path="$1"
  local source_dir="$2"
  require_command hdiutil
  ln -s /Applications "$source_dir/Applications"

  note "creating $dmg_path"
  hdiutil create \
    -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$source_dir" \
    -format UDZO \
    -ov \
    "$dmg_path"
}

package_release() {
  require_command hdiutil
  require_command codesign
  require_command otool
  require_command file
  require_command find
  require_command lipo
  require_command ditto

  local dmg_tool
  dmg_tool="$(select_dmg_tool)"
  local macdeployqt
  macdeployqt="$(find_macdeployqt)"
  local version
  version="$(project_version)"
  local stage="$DIST_DIR/.timearc-macos-stage"
  local dmg_root="$DIST_DIR/.timearc-macos-dmg"
  safe_remove "$stage"
  safe_remove "$dmg_root"
  mkdir -p "$stage"

  note "installing project-owned bundle content into staging"
  cmake --install "$BUILD_DIR" --prefix "$stage" --config Release

  local app_bundle="$stage/TimeArc.app"
  local helper="$app_bundle/Contents/MacOS/time-arc-service"
  [[ -x "$app_bundle/Contents/MacOS/TimeArc" ]] || die "staged TimeArc is missing"
  [[ -x "$helper" ]] || die "staged time-arc-service is missing"
  [[ -f "$app_bundle/Contents/Library/LaunchAgents/com.timearc.service.plist" ]] ||
    die "staged production LaunchAgent plist is missing"
  local pack
  for pack in backgrounds site-icons monthly-recap; do
    [[ -f "$app_bundle/Contents/Resources/assets/timearc-$pack.rcc" ]] ||
      die "staged GUI resource pack is missing: timearc-$pack.rcc"
  done

  local compliance_dir="$app_bundle/Contents/Resources"
  mkdir -p "$compliance_dir"
  ditto "$REPO_ROOT/LICENSE" "$compliance_dir/LICENSE"
  ditto "$REPO_ROOT/resources/licenses" "$compliance_dir/licenses"

  deploy_qt "$app_bundle" "$macdeployqt"
  verify_portable_linkage "$app_bundle"
  sign_bundle "$app_bundle"

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
