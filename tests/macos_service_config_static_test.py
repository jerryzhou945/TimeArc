# SPDX-License-Identifier: GPL-3.0-or-later

"""Cross-check the macOS configuration reader against the documented contract.

The control-file schema lives in src/service/README.md and the config path is
owned by src/service/shared/database_path.c. This test fails when the Swift
reader drifts from either one.
"""

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
README = ROOT / "src" / "service" / "README.md"
CONFIG = ROOT / "src" / "service" / "macos" / "Configuration"
PORTS = CONFIG / "ConfigurationPorts.swift"
STORE = CONFIG / "FileConfigurationStore.swift"
PATH = CONFIG / "ServiceConfigurationPath.swift"
TRACKING_PORTS = ROOT / "src" / "service" / "macos" / "Tracking" / "TrackingPorts.swift"
DATABASE_PATH_C = ROOT / "src" / "service" / "shared" / "database_path.c"
SERVICE_CMAKE = ROOT / "src" / "service" / "CMakeLists.txt"

# Keys the service reader deliberately ignores: the schema gate is handled
# separately, and the database directory is resolved by the shared C resolver.
IGNORED_KEYS = {"schema_version", "database.dir"}


def key_description_section(readme: str) -> str:
    """The Key Descriptions table, which other tables in the README mimic."""
    match = re.search(
        r"### Key Descriptions\n(.*?)\n### File Location", readme, flags=re.DOTALL
    )
    if match is None:
        raise AssertionError("README Key Descriptions section not found")
    return match.group(1)


def documented_keys(readme: str) -> dict[str, str]:
    """Key path -> documented range, from the README key table."""
    rows = re.findall(
        r"^\|\s*\*\*`([a-z_.]+)`\*\*\s*\|\s*`[^`]+`[^|]*\|([^|]*)\|",
        key_description_section(readme),
        flags=re.MULTILINE,
    )
    if not rows:
        raise AssertionError("README key table not found")
    return {key: value.strip() for key, value in rows}


def documented_defaults(readme: str) -> dict:
    """The default configuration object from the README format block."""
    match = re.search(r"```json\n(\{.*?\n\})\n```", readme, flags=re.DOTALL)
    if match is None:
        raise AssertionError("README default configuration block not found")
    return json.loads(match.group(1))


def flatten(obj: dict, prefix: str = "") -> dict:
    flat = {}
    for key, value in obj.items():
        path = f"{prefix}{key}"
        if isinstance(value, dict):
            flat.update(flatten(value, f"{path}."))
        else:
            flat[path] = value
    return flat


def check_keys_read(keys: dict[str, str], store: str) -> None:
    """Every documented key is read by the store."""
    for key in keys:
        if key in IGNORED_KEYS:
            continue
        if f'"{key}"' not in store:
            raise AssertionError(f"configuration store does not read: {key}")
    if '"schema_version"' not in store:
        raise AssertionError("configuration store must gate on schema_version")


def check_ranges(keys: dict[str, str], store: str) -> None:
    """Every documented numeric range appears as a Swift range literal."""
    for key, documented in keys.items():
        if key in IGNORED_KEYS:
            continue
        bounds = re.fullmatch(r"(\d+)-(\d+)", documented)
        exception = re.fullmatch(r"(\d+) or (\d+)-(\d+)", documented)
        if bounds:
            literal = f"{bounds.group(1)}...{bounds.group(2)}"
        elif exception:
            literal = f"{exception.group(2)}...{exception.group(3)}"
            if f"allowing: {exception.group(1)}" not in store:
                raise AssertionError(
                    f"{key} documents '{documented}' but the store does not allow "
                    f"{exception.group(1)}"
                )
        else:
            continue
        if literal not in store:
            raise AssertionError(f"{key} documents range {documented}, missing {literal}")


def swift_default(source: str, name: str, struct: str | None = None) -> str:
    """The default value of an initializer parameter, optionally within a struct."""
    scope = source
    if struct is not None:
        match = re.search(rf"struct {struct}[^{{]*\{{(.*?)\n\}}", source, flags=re.DOTALL)
        if match is None:
            raise AssertionError(f"struct not found: {struct}")
        scope = match.group(1)
    match = re.search(rf"\b{name}: \w+ = ([\w.]+)", scope)
    if match is None:
        raise AssertionError(f"no default for {name} in {struct or 'file'}")
    return match.group(1)


def check_defaults(readme: str, ports: str, tracking_ports: str) -> None:
    """Swift defaults match the README default configuration block."""
    defaults = flatten(documented_defaults(readme))
    expected = {
        "tracking.enabled": ("enabled", "TrackingConfiguration"),
        "tracking.sampling.poll_period_sec": ("pollPeriodSec", "SamplingConfiguration"),
        "tracking.sampling.min_session_sec": ("minSessionSec", "SamplingConfiguration"),
        "tracking.sampling.max_session_sec": ("maxSessionSec", "SamplingConfiguration"),
        "tracking.frontmost.enabled": ("enabled", "FrontmostConfiguration"),
        "tracking.frontmost.idle_threshold_sec": (
            "idleThresholdSec",
            "FrontmostConfiguration",
        ),
        "tracking.frontmost.video_overrides_idle": (
            "videoOverridesIdle",
            "FrontmostConfiguration",
        ),
        "tracking.media.enabled": ("enabled", "MediaConfiguration"),
    }
    for key, (name, struct) in expected.items():
        if key not in defaults:
            raise AssertionError(f"README default block lost the key: {key}")
        documented = str(defaults[key]).replace("True", "true").replace("False", "false")
        actual = swift_default(ports, name, struct)
        if actual != documented:
            raise AssertionError(f"{key} default is {actual}, README says {documented}")

    # The tracking policy carries the same defaults, so a coordinator built
    # without a control file behaves like a documented one.
    for name, key in (
        ("idleThresholdSec", "tracking.frontmost.idle_threshold_sec"),
        ("videoOverridesIdle", "tracking.frontmost.video_overrides_idle"),
        ("minSessionSec", "tracking.sampling.min_session_sec"),
        ("maxSessionSec", "tracking.sampling.max_session_sec"),
    ):
        documented = str(defaults[key]).replace("True", "true").replace("False", "false")
        actual = swift_default(tracking_ports, name, "TrackingPolicy")
        if actual != documented:
            raise AssertionError(f"TrackingPolicy.{name} is {actual}, README says {documented}")


def check_config_path(readme: str, path_source: str, database_path_c: str) -> None:
    """The Swift path components match the C resolver and the README table."""
    filename = re.search(
        r'#define TIMEARC_CONFIG_FILENAME "([^"]+)"', database_path_c
    )
    if filename is None:
        raise AssertionError("TIMEARC_CONFIG_FILENAME not found in database_path.c")
    for component in (filename.group(1), "TimeArc", "config"):
        if f'"{component}"' not in path_source:
            raise AssertionError(f"Swift config path is missing the C component: {component}")
    if 'environment["HOME"]' not in path_source:
        raise AssertionError("Swift config path must read HOME as the C resolver does")
    if '"Application Support"' not in path_source:
        raise AssertionError("Swift config path must use the documented macOS base")
    documented = f"~/Library/Application Support/TimeArc/config/{filename.group(1)}"
    if documented not in readme:
        raise AssertionError(f"README no longer documents the macOS path: {documented}")
    if "TIMEARC_SERVICE_CONFIG" not in path_source:
        raise AssertionError("the config path must honor the TIMEARC_SERVICE_CONFIG redirect")


def check_sources_built(service_cmake: str) -> None:
    for source in (
        "Configuration/ConfigurationPorts.swift",
        "Configuration/ServiceConfigurationPath.swift",
        "Configuration/FileConfigurationStore.swift",
        "Runtime/RuntimePorts.swift",
        "Runtime/ServiceRuntime.swift",
        "Runtime/FileInstanceLock.swift",
    ):
        if source not in service_cmake:
            raise AssertionError(f"service CMakeLists does not build: {source}")


def main() -> None:
    readme = README.read_text(encoding="utf-8")
    store = STORE.read_text(encoding="utf-8")
    ports = PORTS.read_text(encoding="utf-8")
    keys = documented_keys(readme)

    check_keys_read(keys, store)
    check_ranges(keys, store)
    check_defaults(readme, ports, TRACKING_PORTS.read_text(encoding="utf-8"))
    check_config_path(
        readme,
        PATH.read_text(encoding="utf-8"),
        DATABASE_PATH_C.read_text(encoding="utf-8"),
    )
    check_sources_built(SERVICE_CMAKE.read_text(encoding="utf-8"))

    print("macOS service configuration checks passed")


if __name__ == "__main__":
    main()
