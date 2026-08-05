# SPDX-License-Identifier: GPL-3.0-or-later

"""Cross-check the macOS service CLI sources against the documented contract.

The CLI contract lives in src/service/README.md. This test fails when the Swift
sources and that document drift apart, and when the entry point grows behavior
that belongs in a command type.
"""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
README = ROOT / "src" / "service" / "README.md"
MACOS = ROOT / "src" / "service" / "macos"
MAIN = MACOS / "TimeArcService.swift"
PARSER = MACOS / "CommandLine" / "ServiceCommandParser.swift"
COMMAND = MACOS / "CommandLine" / "ServiceCommand.swift"
EXIT_CODE = MACOS / "CommandLine" / "ServiceExitCode.swift"
USAGE = MACOS / "CommandLine" / "ServiceUsage.swift"
SERVICE_CMAKE = ROOT / "src" / "service" / "CMakeLists.txt"
ROOT_CMAKE = ROOT / "CMakeLists.txt"

VERBS = (
    "run",
    "enable",
    "disable",
    "start",
    "stop",
    "restart",
    "status",
    "doctor",
    "help",
    "version",
)
ALIASES = ("-h", "--help", "-v", "--version")
OPTIONS = ("--text", "--json", "--verbose")


def check_verbs(parser: str, command: str) -> None:
    """Every documented verb is parsed and modelled."""
    for verb in VERBS:
        if f'"{verb}"' not in parser:
            raise AssertionError(f"parser does not accept the verb: {verb}")
        if f"case {verb}" not in command:
            raise AssertionError(f"ServiceCommand does not model: {verb}")
    for alias in ALIASES + OPTIONS:
        if f'"{alias}"' not in parser:
            raise AssertionError(f"parser does not accept: {alias}")


def check_readme_usage(readme: str, usage: str) -> None:
    """The help text repeats the usage block documented in the README."""
    for verb in VERBS:
        line = f"time-arc-service {verb}"
        if line not in readme and f"time-arc-service [{verb}]" not in readme:
            raise AssertionError(f"README usage block lost the verb: {verb}")
    if "time-arc-service [run]" not in usage:
        raise AssertionError("help text must document the default run command")
    for option in OPTIONS:
        if option not in usage:
            raise AssertionError(f"help text does not document: {option}")


def check_exit_codes(readme: str, exit_code: str) -> None:
    """Every exit code in the README table exists with the same number."""
    documented = {
        int(value)
        for value in re.findall(r"^\|\s*`(\d+)`\s*\|", readme, flags=re.MULTILINE)
    }
    if not documented:
        raise AssertionError("README exit-code table not found")
    implemented = {
        int(value) for value in re.findall(r"^\s*case \w+ = (\d+)$", exit_code, flags=re.MULTILINE)
    }
    missing = sorted(documented - implemented)
    if missing:
        raise AssertionError(f"ServiceExitCode is missing documented codes: {missing}")
    invented = sorted(implemented - documented)
    if invented:
        raise AssertionError(f"ServiceExitCode invents undocumented codes: {invented}")


def check_version(usage: str, root_cmake: str) -> None:
    """The advertised version tracks the CMake project version."""
    match = re.search(r'static let version = "([\d.]+)"', usage)
    if match is None:
        raise AssertionError("ServiceUsage does not declare a version constant")
    project = re.search(r"project\(time-arc VERSION ([\d.]+)", root_cmake)
    if project is None:
        raise AssertionError("root CMakeLists does not declare a project version")
    if not match.group(1).startswith(project.group(1)):
        raise AssertionError(
            f"service version {match.group(1)} does not match "
            f"CMake project version {project.group(1)}"
        )


def check_entry_point(main: str, service_cmake: str) -> None:
    """The entry point stays a composition root and every source is built."""
    for forbidden in ("TrackingCoordinator", "CFRunLoopRun", "Timer("):
        if forbidden in main:
            raise AssertionError(
                f"TimeArcService.swift must delegate the tracking loop: {forbidden}"
            )
    if "ServiceCommandParser.parse" not in main:
        raise AssertionError("entry point must parse the command line")
    for source in (
        "CommandLine/ServiceCommand.swift",
        "CommandLine/ServiceCommandParser.swift",
        "CommandLine/ServiceExitCode.swift",
        "CommandLine/ServiceUsage.swift",
        "Runtime/RunCommand.swift",
    ):
        if source not in service_cmake:
            raise AssertionError(f"service CMakeLists does not build: {source}")


def main() -> None:
    readme = README.read_text(encoding="utf-8")
    parser = PARSER.read_text(encoding="utf-8")
    command = COMMAND.read_text(encoding="utf-8")
    usage = USAGE.read_text(encoding="utf-8")
    exit_code = EXIT_CODE.read_text(encoding="utf-8")

    check_verbs(parser, command)
    check_readme_usage(readme, usage)
    check_exit_codes(readme, exit_code)
    check_version(usage, ROOT_CMAKE.read_text(encoding="utf-8"))
    check_entry_point(
        MAIN.read_text(encoding="utf-8"),
        SERVICE_CMAKE.read_text(encoding="utf-8"),
    )

    print("macOS service CLI checks passed")


if __name__ == "__main__":
    main()
