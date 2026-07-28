from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main():
    main_qml = (ROOT / "qml/main.qml").read_text(encoding="utf-8")
    controller_h = (
        ROOT / "src/services/macos/macos_traffic_lights.h"
    ).read_text(encoding="utf-8")
    controller_mm = (
        ROOT / "src/services/macos/macos_traffic_lights.mm"
    ).read_text(encoding="utf-8")

    require(main_qml, "if (macSidebarChrome && macTrafficLightsController)",
            "macOS-only close-to-tray gate")
    require(main_qml, "macTrafficLightsController.hideToTray()",
            "native macOS close-to-tray handoff")
    require(main_qml, "if (!macSidebarChrome",
            "macOS close-notification suppression")
    require(controller_h, "Q_INVOKABLE void hideToTray()",
            "QML-callable native lifecycle method")
    require(controller_mm, "NSWindowStyleMaskFullScreen",
            "native full-screen state detection")
    require(controller_mm, "NSWindowDidExitFullScreenNotification",
            "full-screen exit completion observer")
    require(controller_mm, "[nativeWindow toggleFullScreen:nil]",
            "native full-screen exit request")
    require(controller_mm, "if (qtWindow) qtWindow->hide()",
            "deferred hide after exit completion")


if __name__ == "__main__":
    main()
