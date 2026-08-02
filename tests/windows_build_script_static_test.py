# SPDX-License-Identifier: GPL-3.0-or-later

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "build-windows.ps1"


def require(source: str, fragment: str, purpose: str) -> None:
    if fragment not in source:
        raise AssertionError(f"missing {purpose}: {fragment}")


def main() -> None:
    source = SCRIPT.read_text(encoding="utf-8")

    require(source, '$action = "release"', "no-argument release default")
    for option in ("--release", "--build", "--test", "--package"):
        require(source, option, f"{option} option")

    require(
        source,
        '".harness/tools/build.py"',
        "harness-wrapped compilation",
    )
    require(source, "TIMEARC_BUILD_PARALLEL", "bounded build parallelism")
    if "cmake --build" in source:
        raise AssertionError("script must not bypass the harness build wrapper")
    for legacy_script in ("package-release.ps1", "verify-linkage.ps1"):
        if legacy_script in source:
            raise AssertionError(f"script must not invoke legacy {legacy_script}")

    require(source, '"--test-dir"', "test execution")
    require(source, '"--install"', "project-owned install staging")
    require(source, "windeployqt.exe", "Qt runtime deployment")
    require(source, "TimeArc.exe", "GUI executable")
    require(source, "time-arc-service.exe", "service executable")
    for pack in ("backgrounds", "site-icons", "monthly-recap"):
        require(source, f'"{pack}"', f"{pack} resource pack")

    require(source, "Assert-DynamicQtLinkage", "dynamic Qt linkage gate")
    require(source, "Qt6*.dll", "replaceable Qt DLL notice")
    require(source, "libgcc_s_seh-1.dll", "MinGW compiler runtime")
    require(source, "Compress-Archive", "portable ZIP creation")
    require(source, "TIMEARC_SIGN_CERTIFICATE_SHA1", "optional signing")
    require(source, "signtool.exe", "Authenticode tool")
    require(source, '"LICENSE"', "project license")
    require(source, '"resources/licenses"', "third-party licenses")

    print("Windows build script static checks passed")


if __name__ == "__main__":
    main()
