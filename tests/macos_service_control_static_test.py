# SPDX-License-Identifier: GPL-3.0-or-later

"""Pins the service control channel to what CHARTER v0.14 permits.

The channel is allowed only between `time-arc-service` instances. That is
enforced at runtime by three checks in the server; this test makes sure none of
them can be dropped silently, and that the wire format stays versioned so a
future `status`/`doctor` request cannot break an older peer.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTROL = ROOT / "src" / "service" / "macos" / "Control"
SERVER = CONTROL / "ControlServer.swift"
PORTS = CONTROL / "ControlPorts.swift"
CHARTER = ROOT / ".harness" / "CHARTER.md"
PATHS = ROOT / "src" / "service" / "macos" / "Configuration" / "ServiceConfigurationPath.swift"


def check_peer_defenses() -> None:
    """All three layers that keep the UI off this channel."""
    server = SERVER.read_text(encoding="utf-8")
    for required, why in (
        ("chmod(path, S_IRUSR | S_IWUSR)", "socket must be owner-only"),
        ("getpeereid", "peer uid must be checked"),
        ("LOCAL_PEERPID", "peer pid must be resolved"),
        ("ProcessIdentity.executablePath", "peer executable must be compared"),
    ):
        if required not in server:
            raise AssertionError(f"control server dropped a peer defense ({why}): {required}")


def check_versioned_wire() -> None:
    """Requests and responses carry a schema version, and unknown commands answer."""
    ports = PORTS.read_text(encoding="utf-8")
    for required in ('"schema_version"', "schemaVersion", "unsupported_command"):
        if required not in ports:
            raise AssertionError(f"control wire format is missing: {required}")
    if "maximumMessageBytes" not in ports:
        raise AssertionError("control reads must stay bounded")


def check_socket_location() -> None:
    """The socket sits in the fixed config dir, not under the redirectable DB dir."""
    paths = PATHS.read_text(encoding="utf-8")
    if "controlSocket" not in paths or ".sock" not in paths:
        raise AssertionError("the control socket path must be resolved with the other runtime paths")
    socket_helper = (CONTROL / "ControlSocket.swift").read_text(encoding="utf-8")
    if "socketPathTooLong" not in socket_helper:
        raise AssertionError("sun_path is 104 bytes; the bind path must be length-checked")


def check_enable_starts_the_collector() -> None:
    """`enable` must start a collector that is registered but not running.

    RunAtLoad only fires when launchd loads the job, so re-registering an agent
    that is already registered starts nothing. That is the state `enable` is in
    every time the UI uses it to resume collection rather than to set it up, and
    it silently left the user with autostart on and nothing collecting.
    """
    command = (ROOT / "src" / "service" / "macos" / "Autostart" / "EnableCommand.swift").read_text(
        encoding="utf-8"
    )
    if "LaunchAgentControl.kickstart" not in command:
        raise AssertionError("enable must ask launchd to run an already-registered job")
    if "FileInstanceLock.isHeld" not in command:
        raise AssertionError("enable must skip the kickstart when a collector already holds the lock")
    if "isCollecting" not in command:
        raise AssertionError("enable must not wait on a collector that configuration will stop")


def check_charter_permits_it() -> None:
    charter = CHARTER.read_text(encoding="utf-8")
    if "v0.14" not in charter:
        raise AssertionError("CHARTER must record the amendment permitting this channel")
    if "instances" not in charter:
        raise AssertionError("CHARTER must scope IPC to service instances")


def main() -> None:
    check_peer_defenses()
    check_versioned_wire()
    check_socket_location()
    check_enable_starts_the_collector()
    check_charter_permits_it()
    print("macOS service control channel checks passed")


if __name__ == "__main__":
    main()
