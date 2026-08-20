from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SETTINGS = ROOT / "src/services/settings_repository.cpp"
PROFILE = ROOT / "qml/desktop/pages/DesktopProfilePage.qml"


def extract_function(source: str, signature: str) -> str:
    start = source.find(signature)
    if start < 0:
        raise AssertionError(f"function not found: {signature}")
    end = source.find("\n}", start)
    if end < 0:
        raise AssertionError(f"unterminated function: {signature}")
    return source[start:end]


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main() -> None:
    settings = SETTINGS.read_text(encoding="utf-8")
    profile = PROFILE.read_text(encoding="utf-8")

    # Windows exposes the same live state/start-now surface used by the macOS
    # status UI, while keeping Windows login registration as the autostart truth.
    state = extract_function(settings, "SettingsRepository::serviceState")
    require(state, "defined(Q_OS_WIN)", "Windows service-state branch")
    require(state, "readServiceStatus(&state)", "Windows JSON status query")
    require(state, "autostartEnabled()", "Windows UI autostart truth")

    start = extract_function(settings, "SettingsRepository::startTrackingNow")
    require(start, "defined(Q_OS_WIN)", "Windows start-now branch")
    require(start, "startBackgroundCollection()", "Windows idempotent start path")

    # macOS needs a registered LaunchAgent for apply-and-restart; Windows can
    # launch its user-session collector regardless of login-autostart choice.
    require(
        profile,
        'Qt.platform.os === "windows" || root.autostartEnabled',
        "Windows apply-and-restart availability",
    )

    print("Windows tracking parity static checks passed")


if __name__ == "__main__":
    main()
