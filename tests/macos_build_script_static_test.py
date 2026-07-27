# SPDX-License-Identifier: GPL-3.0-or-later

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "build-macos.sh"


def require(source: str, fragment: str, purpose: str) -> None:
    if fragment not in source:
        raise AssertionError(f"missing {purpose}: {fragment}")


def main() -> None:
    source = SCRIPT.read_text(encoding="utf-8")

    require(source, 'ACTION="release"', "no-argument release default")
    for option in ("--release", "--build", "--test", "--package"):
        require(source, option, f"{option} option")

    require(
        source,
        '"$REPO_ROOT/.harness/tools/build.py"',
        "harness-wrapped compilation",
    )
    if "cmake --build" in source:
        raise AssertionError("script must not bypass the harness build wrapper")

    require(source, "ctest --test-dir", "test execution")
    require(source, "select_swift_generator", "Swift-capable generator selection")
    require(source, 'generator="Ninja"', "Ninja default")
    require(source, 'generator="Xcode"', "Xcode fallback")
    require(
        source,
        "reset_incompatible_cmake_state",
        "incompatible cached-generator recovery",
    )
    require(source, "CMAKE_GENERATOR:INTERNAL", "cached generator inspection")
    require(source, "cmake --install", "project-owned install staging")
    require(source, "macdeployqt", "Qt framework deployment")
    require(
        source,
        '"QtQuick/Controls/Fusion/qmldir"',
        "macOS style Fusion dependency validation",
    )
    require(
        source,
        '"libqtquickcontrols2fusionstyleplugin.dylib"',
        "Fusion style plug-in validation",
    )
    if "set(unused_styles Fusion " in source:
        raise AssertionError("macOS packaging must retain the Fusion fallback")
    require(source, 'Contents/MacOS/TimeArc', "app binary layout")
    require(source, 'Contents/MacOS/time-arc-service', "service binary layout")
    require(
        source,
        "Contents/Library/LaunchAgents/com.timearc.service.plist",
        "production LaunchAgent template",
    )
    for pack in ("backgrounds", "site-icons", "monthly-recap"):
        require(source, f"timearc-$pack.rcc", f"{pack} resource pack")

    require(source, "verify_portable_linkage", "portable linkage gate")
    require(source, "codesign --verify", "signature verification")
    require(source, "hdiutil create", "DMG creation")
    require(source, "notarytool submit", "optional notarization")
    require(source, "stapler validate", "notarization ticket validation")
    require(source, '"$REPO_ROOT/LICENSE"', "project license")
    require(source, '"$REPO_ROOT/resources/licenses"', "third-party licenses")

    print("macOS build script static checks passed")


if __name__ == "__main__":
    main()
