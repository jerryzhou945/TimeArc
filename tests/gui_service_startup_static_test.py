# SPDX-License-Identifier: GPL-3.0-or-later

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "src" / "main.cpp"
ADAPTER = ROOT / "src" / "services" / "macos" / "macos_launch_agent.mm"
CMAKE = ROOT / "CMakeLists.txt"
PLIST = ROOT / "resources/bundle/macos/com.timearc.service.plist"


def main() -> None:
    source = MAIN.read_text(encoding="utf-8")
    for forbidden in (
        "startUsageService",
        "findMacUsageServicePath",
        "QProcess::startDetached",
    ):
        if forbidden in source:
            raise AssertionError(f"GUI must not launch the service: {forbidden}")

    cmake = CMAKE.read_text(encoding="utf-8")
    if "install(TARGETS time_arc_service" not in cmake:
        raise AssertionError("service must remain a packaged standalone target")
    if "com.timearc.service.plist" not in cmake:
        raise AssertionError("LaunchAgent template must be bundled by CMake")
    for required in ("Library/LaunchAgents", "Contents/MacOS/time-arc-service"):
        if required not in cmake:
            raise AssertionError(f"missing embedded service layout: {required}")
    if "Contents/Resources/com.timearc.service.plist" not in cmake:
        raise AssertionError("CMake must remove the legacy plist bundle path")

    adapter = ADAPTER.read_text(encoding="utf-8")
    for required in (
        "SMAppService",
        "agentServiceWithPlistName",
        "registerAndReturnError",
        "case SMAppServiceStatusNotFound:\n"
        "        case SMAppServiceStatusNotRegistered:\n"
        "          break;",
    ):
        if required not in adapter:
            raise AssertionError(f"missing LaunchAgent registration: {required}")

    import plistlib

    with PLIST.open("rb") as stream:
        launch_agent = plistlib.load(stream)
    if launch_agent["Label"] != "com.timearc.service":
        raise AssertionError("production LaunchAgent label is incorrect")
    if launch_agent["BundleProgram"] != "Contents/MacOS/time-arc-service":
        raise AssertionError("LaunchAgent BundleProgram is incorrect")
    if "ProgramArguments" in launch_agent:
        raise AssertionError("embedded LaunchAgent must use BundleProgram")
    if not launch_agent["RunAtLoad"] or not launch_agent["KeepAlive"]:
        raise AssertionError("LaunchAgent must run immediately and stay alive")

    print("GUI LaunchAgent registration checks passed")


if __name__ == "__main__":
    main()
