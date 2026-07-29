from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def forbid(text, needle, label):
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


def main():
    shell_qml = (
        ROOT / "qml/desktop/DesktopAppShell.qml"
    ).read_text(encoding="utf-8")
    traffic_lights_h = (
        ROOT / "src/services/macos/macos_traffic_lights.h"
    ).read_text(encoding="utf-8")
    traffic_lights_mm = (
        ROOT / "src/services/macos/macos_traffic_lights.mm"
    ).read_text(encoding="utf-8")

    require(
        shell_qml,
        "macTrafficLightsController.performTitlebarDoubleClickAction()",
        "QML native double-click handoff",
    )
    forbid(
        shell_qml,
        "window.showMaximized()",
        "hard-coded QML maximize action",
    )
    require(
        traffic_lights_h,
        "Q_INVOKABLE void performTitlebarDoubleClickAction()",
        "QML-callable AppKit action",
    )
    require(
        traffic_lights_mm,
        'stringForKey:@"AppleActionOnDoubleClick"]',
        "macOS double-click preference lookup",
    )
    require(
        traffic_lights_mm,
        '[action caseInsensitiveCompare:@"Minimize"]',
        "Minimize preference branch",
    )
    require(
        traffic_lights_mm,
        "[nativeWindow performMiniaturize:nil]",
        "native minimize action",
    )
    require(
        traffic_lights_mm,
        '[action caseInsensitiveCompare:@"Fill"]',
        "Fill preference branch",
    )
    require(
        traffic_lights_mm,
        "window_->showMaximized()",
        "Fill maximized action",
    )
    require(
        traffic_lights_mm,
        '[action caseInsensitiveCompare:@"Maximize"]',
        "Zoom preference storage value",
    )
    require(
        traffic_lights_mm,
        "[nativeWindow performZoom:nil]",
        "native zoom action",
    )


if __name__ == "__main__":
    main()
