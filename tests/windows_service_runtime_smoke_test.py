# SPDX-License-Identifier: GPL-3.0-or-later

"""Exercise the real Windows UI/service lifecycle in an isolated profile."""

import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UI = Path(os.environ.get("TIMEARC_SMOKE_UI", ROOT / "build" / "TimeArc.exe"))
SERVICE = Path(
    os.environ.get(
        "TIMEARC_SMOKE_SERVICE", ROOT / "build" / "time-arc-service.exe"
    )
)


def isolated_environment(profile: Path) -> dict:
    env = dict(os.environ)
    env["APPDATA"] = str(profile / "Roaming")
    env["LOCALAPPDATA"] = str(profile / "Local")
    env["TIMEARC_TEST_APPDATA"] = str(profile / "GuiData")
    return env


def config_path(profile: Path) -> Path:
    return profile / "Roaming" / "TimeArc" / "config" / "service_config.json"


def service_status(env: dict) -> str:
    result = subprocess.run(
        [str(SERVICE), "--status"],
        env=env,
        capture_output=True,
        text=True,
        timeout=10,
    )
    return result.stdout


def stop_service(env: dict) -> None:
    subprocess.run(
        [str(SERVICE), "--stop"],
        env=env,
        capture_output=True,
        text=True,
        timeout=10,
    )
    deadline = time.time() + 8
    while time.time() < deadline:
        if "running=no" in service_status(env):
            return
        time.sleep(0.2)
    raise AssertionError("Windows collector did not stop during smoke cleanup")


def wait_for_running(env: dict, timeout: float = 10) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if "running=yes" in service_status(env):
            return
        time.sleep(0.2)
    raise AssertionError("opening TimeArc did not start the Windows collector")


def case_ui_launch_starts_collection(profile: Path) -> None:
    env = isolated_environment(profile)
    ui = subprocess.Popen(
        [str(UI), "--start-in-tray"],
        cwd=str(UI.parent),
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        wait_for_running(env)
        if ui.poll() is not None:
            raise AssertionError(f"TimeArc exited before startup completed: {ui.stderr.read()}")
    finally:
        ui.terminate()
        try:
            ui.wait(timeout=8)
        except subprocess.TimeoutExpired:
            ui.kill()
            ui.wait(timeout=5)
        stop_service(env)


def case_current_config_can_disable_collection(profile: Path) -> None:
    env = isolated_environment(profile)
    path = config_path(profile)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({"schema_version": 1, "tracking": {"enabled": False}}),
        encoding="utf-8",
    )

    process = subprocess.Popen(
        [str(SERVICE)],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        code = process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        stop_service(env)
        process.wait(timeout=5)
        raise AssertionError(
            "Windows collector ignored service_config.json tracking.enabled=false"
        )
    if code != 0:
        raise AssertionError(f"disabled collection should exit 0, got {code}")


def case_status_json_reports_current_config(profile: Path) -> None:
    env = isolated_environment(profile)
    path = config_path(profile)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "tracking": {
                    "enabled": False,
                    "frontmost": {"idle_threshold_sec": 0},
                },
            }
        ),
        encoding="utf-8",
    )

    result = subprocess.run(
        [str(SERVICE), "--status", "--json"],
        env=env,
        capture_output=True,
        text=True,
        timeout=10,
    )
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise AssertionError(
            f"Windows status --json did not return JSON: {result.stdout!r}"
        ) from error
    if payload.get("platform") != "windows":
        raise AssertionError(f"status JSON platform mismatch: {payload!r}")
    tracking = payload.get("tracking", {})
    if tracking.get("running") is not False or tracking.get("enabled") is not False:
        raise AssertionError(f"status JSON tracking state mismatch: {payload!r}")
    if tracking.get("frontmost", {}).get("idle_threshold_sec") != 0:
        raise AssertionError(f"status JSON idle threshold mismatch: {payload!r}")


def main() -> None:
    if sys.platform != "win32":
        print("Windows service runtime smoke skipped outside Windows")
        return
    if not UI.exists() or not SERVICE.exists():
        raise AssertionError("build TimeArc.exe and time-arc-service.exe before this smoke")

    with tempfile.TemporaryDirectory(prefix="timearc-windows-runtime-") as tmp:
        profile = Path(tmp)
        stop_service(isolated_environment(profile))
        case_ui_launch_starts_collection(profile)
        case_current_config_can_disable_collection(profile)
        case_status_json_reports_current_config(profile)

    print("Windows service runtime smoke passed")


if __name__ == "__main__":
    main()
