# SPDX-License-Identifier: GPL-3.0-or-later

"""Pins `status` to the contract in src/service/README.md.

The GUI parses this output at every launch to decide whether to repair the
service registration, so the field names and the exit-code table are a contract
between two processes, not just console text.
"""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
README = ROOT / "src" / "service" / "README.md"
DIAGNOSTICS = ROOT / "src" / "service" / "macos" / "Diagnostics"
PORTS = DIAGNOSTICS / "DiagnosticsPorts.swift"
RENDERER = DIAGNOSTICS / "StatusRenderer.swift"
COMMAND = DIAGNOSTICS / "StatusCommand.swift"
EXIT_CODES = ROOT / "src" / "service" / "macos" / "CommandLine" / "ServiceExitCode.swift"
SETTINGS = ROOT / "src" / "services" / "settings_repository.cpp"

# The state fields the README documents for `status`.
DOCUMENTED_FIELDS = (
    "platform",
    "tracking.running",
    "tracking.enabled",
    "tracking.frontmost.enabled",
    "tracking.media.enabled",
    "autostart.enabled",
    "autostart.backend",
)


def check_json_fields() -> None:
    """Every documented field is emitted by the JSON renderer."""
    renderer = RENDERER.read_text(encoding="utf-8")
    for field in DOCUMENTED_FIELDS:
        leaf = field.split(".")[-1]
        if f'"{leaf}"' not in renderer:
            raise AssertionError(f"status JSON is missing the documented field: {field}")
    for required in ('"schema_version"', '"command"', '"status"'):
        if required not in renderer:
            raise AssertionError(f"status JSON envelope is missing: {required}")


def check_exit_code_table() -> None:
    """The state-to-exit-code mapping matches the README table."""
    readme = README.read_text(encoding="utf-8")
    for code, phrase in (
        (11, "running but not enabled"),
        (12, "not running but enabled"),
        (13, "not running and not enabled"),
        (10, "could not be queried reliably"),
    ):
        if phrase not in readme:
            raise AssertionError(f"README no longer documents exit {code}: {phrase}")

    codes = EXIT_CODES.read_text(encoding="utf-8")
    for name, value in (
        ("statusUnavailable", 10),
        ("statusRunningNotEnabled", 11),
        ("statusNotRunningEnabled", 12),
        ("statusNotRunningNotEnabled", 13),
    ):
        if not re.search(rf"case {name} = {value}\b", codes):
            raise AssertionError(f"exit code {name} must stay {value}")

    ports = PORTS.read_text(encoding="utf-8")
    for name in (
        "statusRunningNotEnabled",
        "statusNotRunningEnabled",
        "statusNotRunningNotEnabled",
    ):
        if name not in ports:
            raise AssertionError(f"the status report must map a state to {name}")
    if "statusUnavailable" not in COMMAND.read_text(encoding="utf-8"):
        raise AssertionError("an unreadable configuration must report exit 10")


def check_status_reads_locally() -> None:
    """`status` must answer without needing a healthy control channel.

    A caller reaches for `status` precisely when the service may be wedged, so
    it is built from the config file, the instance lock, and the autostart
    backend -- never from a request to the running instance.
    """
    command = COMMAND.read_text(encoding="utf-8")
    if "FileInstanceLock.isHeld" not in command:
        raise AssertionError("status must read liveness from the instance lock")
    if "ControlClient" in command:
        raise AssertionError("status must not depend on the control channel")


def check_views_cannot_go_stale() -> None:
    """Every view re-reads; none of them caches a value with no invalidation.

    The Settings switch is a QML-side snapshot of launchd state. Two ways it can
    fall behind: a change made elsewhere in the app (the status-bar rows), and a
    change made outside it (System Settings). The first needs a signal from the
    one class both paths call; the second can only be caught when the app is
    activated again, since nothing notifies us at all.
    """
    header = (ROOT / "src" / "services" / "settings_repository.h").read_text(encoding="utf-8")
    if "void serviceStateChanged();" not in header:
        raise AssertionError("SettingsRepository must announce service-state changes")

    settings = SETTINGS.read_text(encoding="utf-8")
    if settings.count("emit serviceStateChanged();") < 4:
        raise AssertionError("every path that changes service state must announce it")

    page = (ROOT / "qml" / "desktop" / "pages" / "DesktopProfilePage.qml").read_text(
        encoding="utf-8"
    )
    if "function onServiceStateChanged()" not in page:
        raise AssertionError("the settings page must listen for in-app changes")
    if "Qt.ApplicationActive" not in page:
        raise AssertionError("the settings page must re-read when the app is activated")


def check_gui_consumes_json() -> None:
    """The GUI reads autostart state from the service and mirrors none of it.

    launchd is the single source of truth. A copy in the UI database could
    disagree with the registration, and then neither value would be trustworthy,
    so the UI queries `status` every time instead of remembering an answer.
    """
    settings = SETTINGS.read_text(encoding="utf-8")
    if 'QStringLiteral("status")' not in settings or '"--json"' not in settings:
        raise AssertionError("the GUI must query `status --json`")
    if "verifyBackgroundCollection" not in settings:
        raise AssertionError("the GUI must have a startup self-check")
    if "macos_autostart_enabled" in settings:
        raise AssertionError("the UI must not mirror the autostart state it does not own")
    if 'state.value(QStringLiteral("autostart.enabled"))' not in settings:
        raise AssertionError("the self-check must gate on the registration the service reports")


def main() -> None:
    check_views_cannot_go_stale()
    check_json_fields()
    check_exit_code_table()
    check_status_reads_locally()
    check_gui_consumes_json()
    print("macOS service status checks passed")


if __name__ == "__main__":
    main()
