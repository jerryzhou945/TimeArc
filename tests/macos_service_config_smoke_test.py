# SPDX-License-Identifier: GPL-3.0-or-later

"""Drive the built macOS service against real control files.

HOME is redirected to a temporary directory, so both the Swift config reader and
the shared C database resolver stay inside the sandbox and never touch the real
user profile. Skips when the service has not been built.

Pass --long to include the max_session_sec case, which needs the foreground app
to stay put for a couple of minutes and so is not part of the default run.
"""

import json
import os
import signal
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "build" / "src" / "service" / "time-arc-service"

EXIT_SUCCESS = 0
EXIT_CONFIGURATION = 4
EXIT_ALREADY_RUNNING = 6


def config_path(home: Path) -> Path:
    return home / "Library" / "Application Support" / "TimeArc" / "config" / "service_config.json"


def database_path(home: Path) -> Path:
    return (
        home
        / "Library"
        / "Application Support"
        / "TimeArc"
        / "service"
        / "timearc_service.db"
    )


def write_config(home: Path, config) -> None:
    path = config_path(home)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        config if isinstance(config, str) else json.dumps(config), encoding="utf-8"
    )


def environment(home: Path) -> dict:
    env = dict(os.environ)
    env["HOME"] = str(home)
    return env


def run_until_exit(home: Path, timeout: float = 20.0):
    """Run the service expecting it to exit on its own."""
    return subprocess.run(
        [str(BINARY), "run"],
        env=environment(home),
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def run_then_terminate(home: Path, seconds: float = 2.5):
    """Run the service, let it sample, then ask it to flush and exit."""
    process = subprocess.Popen(
        [str(BINARY), "run"],
        env=environment(home),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    time.sleep(seconds)
    if process.poll() is not None:
        stdout, stderr = process.communicate()
        raise AssertionError(f"service exited early with {process.returncode}: {stderr}")
    process.send_signal(signal.SIGTERM)
    stdout, stderr = process.communicate(timeout=15)
    return process.returncode, stdout, stderr


def case_tracking_disabled(home: Path) -> None:
    write_config(home, {"schema_version": 1, "tracking": {"enabled": False}})
    result = run_until_exit(home)
    if result.returncode != EXIT_SUCCESS:
        raise AssertionError(f"disabled tracking must exit 0, got {result.returncode}")
    if database_path(home).exists():
        raise AssertionError("disabled tracking must not create the database")


def case_both_sub_switches_off(home: Path) -> None:
    write_config(
        home,
        {
            "schema_version": 1,
            "tracking": {
                "enabled": True,
                "frontmost": {"enabled": False},
                "media": {"enabled": False},
            },
        },
    )
    result = run_until_exit(home)
    if result.returncode != EXIT_SUCCESS:
        raise AssertionError(f"no enabled tracker must exit 0, got {result.returncode}")
    if database_path(home).exists():
        raise AssertionError("no enabled tracker must not create the database")


def case_newer_schema(home: Path) -> None:
    write_config(home, {"schema_version": 2, "tracking": {"enabled": True}})
    result = run_until_exit(home)
    if result.returncode != EXIT_CONFIGURATION:
        raise AssertionError(
            f"a newer schema must exit {EXIT_CONFIGURATION}, got {result.returncode}"
        )
    if "schema_version 2" not in result.stderr:
        raise AssertionError(f"the refusal must name the version: {result.stderr!r}")


def case_malformed_config(home: Path) -> None:
    write_config(home, "{ this is not json")
    code, _, stderr = run_then_terminate(home)
    if code != EXIT_SUCCESS:
        raise AssertionError(f"a malformed config must fall back and run, got {code}")
    if "not a JSON object" not in stderr:
        raise AssertionError(f"a malformed config must warn: {stderr!r}")


def case_out_of_range(home: Path) -> None:
    write_config(
        home,
        {
            "schema_version": 1,
            "tracking": {"enabled": True, "sampling": {"poll_period_sec": 999}},
        },
    )
    code, _, stderr = run_then_terminate(home)
    if code != EXIT_SUCCESS:
        raise AssertionError(f"an out-of-range value must fall back and run, got {code}")
    if "poll_period_sec" not in stderr or "outside" not in stderr:
        raise AssertionError(f"an out-of-range value must warn by name: {stderr!r}")


def case_single_instance(home: Path) -> None:
    write_config(home, {"schema_version": 1, "tracking": {"enabled": True}})
    first = subprocess.Popen(
        [str(BINARY), "run"],
        env=environment(home),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        time.sleep(2.0)
        if first.poll() is not None:
            raise AssertionError("the first instance exited before the second started")
        second = run_until_exit(home)
        if second.returncode != EXIT_ALREADY_RUNNING:
            raise AssertionError(
                f"a second instance must exit {EXIT_ALREADY_RUNNING}, got {second.returncode}"
            )
        if first.poll() is not None:
            raise AssertionError("the first instance must keep collecting")
    finally:
        first.send_signal(signal.SIGTERM)
        first.communicate(timeout=15)


def case_max_session(home: Path) -> None:
    """A long foreground session is written as contiguous rows."""
    write_config(
        home,
        {
            "schema_version": 1,
            "tracking": {
                "enabled": True,
                "sampling": {"poll_period_sec": 1, "max_session_sec": 60},
                "media": {"enabled": False},
            },
        },
    )
    run_then_terminate(home, seconds=130)

    connection = sqlite3.connect(database_path(home))
    try:
        rows = connection.execute(
            "select app_id, start_unix_sec, end_unix_sec from frontmost_sessions "
            "order by start_unix_sec"
        ).fetchall()
    finally:
        connection.close()

    capped = [row for row in rows if row[2] - row[1] >= 60]
    if not capped:
        raise AssertionError(f"no record reached the 60s cap: {rows}")
    for app_id, _, end in capped:
        following = [row for row in rows if row[0] == app_id and row[1] == end]
        if not following:
            raise AssertionError(f"record for {app_id} ending {end} has no contiguous successor")


def main() -> None:
    if not BINARY.exists():
        print(f"macOS service not built, skipping: {BINARY}")
        return

    cases = [
        case_tracking_disabled,
        case_both_sub_switches_off,
        case_newer_schema,
        case_malformed_config,
        case_out_of_range,
        case_single_instance,
    ]
    if "--long" in sys.argv:
        cases.append(case_max_session)

    for case in cases:
        with tempfile.TemporaryDirectory() as home:
            case(Path(home))
        print(f"  ok {case.__name__}")

    print("macOS service configuration smoke passed")


if __name__ == "__main__":
    main()
