# SPDX-License-Identifier: GPL-3.0-or-later

"""Guards the UI/service lifecycle boundary.

This test used to assert that the UI registered the LaunchAgent. CHARTER v0.14
moved that ownership to the service, so the assertions are inverted: the UI must
not register anything or launch the collector itself, and the service must be the
side holding SMAppService. The CMake bundling checks are unchanged -- the helper
and the agent template still ship inside the app.
"""

import plistlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "src" / "main.cpp"
SETTINGS = ROOT / "src" / "services" / "settings_repository.cpp"
SERVICE_AUTOSTART = ROOT / "src" / "service" / "macos" / "Autostart"
CMAKE = ROOT / "CMakeLists.txt"
PLIST = ROOT / "resources/bundle/macos/com.timearc.service.plist"


def check_ui_does_not_own_lifecycle() -> None:
    """The UI may not start the collector or register its agent."""
    source = MAIN.read_text(encoding="utf-8")
    for forbidden in (
        "startUsageService",
        "findMacUsageServicePath",
        "QProcess::startDetached",
        "registerMacLaunchAgent",
        "macos_launch_agent",
    ):
        if forbidden in source:
            raise AssertionError(f"UI must not own the service lifecycle: {forbidden}")

    if (ROOT / "src" / "services" / "macos" / "macos_launch_agent.mm").exists():
        raise AssertionError("the UI LaunchAgent adapter should be gone; the service owns this")

    cmake = CMAKE.read_text(encoding="utf-8")
    if "macos_launch_agent" in cmake:
        raise AssertionError("CMake still builds the retired UI LaunchAgent adapter")


def check_ui_drives_the_cli() -> None:
    """The UI reaches the service only through its CLI verbs."""
    settings = SETTINGS.read_text(encoding="utf-8")
    if "time-arc-service" not in settings:
        raise AssertionError("the UI must locate the service binary to invoke it")
    for verb in ('QStringLiteral("enable")', 'QStringLiteral("disable")', 'QStringLiteral("stop")'):
        if verb not in settings:
            raise AssertionError(f"the macOS UI branch must invoke {verb}")

    # The UI must never spawn a collector launchd does not supervise. Starting
    # collection goes through `enable`, whose RunAtLoad gets it running under the
    # supervisor. Matches the bare verb only, so Windows's `--start` is untouched.
    if 'QStringLiteral("start")' in settings:
        raise AssertionError("the UI must never invoke the service `start` verb")


def check_service_owns_registration() -> None:
    """SMAppService lives in the service, not the UI."""
    autostart = (SERVICE_AUTOSTART / "LaunchAgentAutostart.swift").read_text(encoding="utf-8")
    for required in ("SMAppService", "agent(plistName:", "register()", "unregister()"):
        if required not in autostart:
            raise AssertionError(f"service autostart is missing: {required}")
    # The bundled backend cannot register an ad-hoc signed build, so the
    # user-level fallback is what actually works before notarization.
    if "userAgentURL" not in autostart or "LaunchAgents" not in autostart:
        raise AssertionError("service autostart must keep the user-level fallback backend")


def check_packaging() -> None:
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


def check_restart_policy() -> None:
    """KeepAlive must restart only after a failure.

    A bare `true` would restart the helper after the clean exit that `stop`
    performs, which is what made `stop` indistinguishable from `disable`.
    """
    with PLIST.open("rb") as stream:
        launch_agent = plistlib.load(stream)
    if launch_agent["Label"] != "com.timearc.service":
        raise AssertionError("production LaunchAgent label is incorrect")
    if launch_agent["BundleProgram"] != "Contents/MacOS/time-arc-service":
        raise AssertionError("LaunchAgent BundleProgram is incorrect")
    if "ProgramArguments" in launch_agent:
        raise AssertionError("embedded LaunchAgent must use BundleProgram")
    if not launch_agent["RunAtLoad"]:
        raise AssertionError("LaunchAgent must run at load")

    keep_alive = launch_agent["KeepAlive"]
    if not isinstance(keep_alive, dict) or keep_alive.get("SuccessfulExit") is not False:
        raise AssertionError(
            "KeepAlive must be {SuccessfulExit: false}; a clean exit is how `stop` works"
        )


def main() -> None:
    check_ui_does_not_own_lifecycle()
    check_ui_drives_the_cli()
    check_service_owns_registration()
    check_packaging()
    check_restart_policy()
    print("service lifecycle ownership checks passed")


if __name__ == "__main__":
    main()
