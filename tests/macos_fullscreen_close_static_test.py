from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def forbid(text, needle, label):
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


def main():
    main_qml = (ROOT / "qml/main.qml").read_text(encoding="utf-8")
    main_cpp = (ROOT / "src/main.cpp").read_text(encoding="utf-8")
    lifecycle_h = (
        ROOT / "src/services/macos/macos_app_lifecycle.h"
    ).read_text(encoding="utf-8")
    lifecycle_mm = (
        ROOT / "src/services/macos/macos_app_lifecycle.mm"
    ).read_text(encoding="utf-8")
    traffic_lights_mm = (
        ROOT / "src/services/macos/macos_traffic_lights.mm"
    ).read_text(encoding="utf-8")
    cmake = (ROOT / "src/CMakeLists.txt").read_text(encoding="utf-8")

    # macOS closes the window instead of hiding it to the status item.
    require(main_qml, "|| macSidebarChrome)",
            "macOS excluded from close-to-tray")
    require(main_qml, "close.accepted = macAppLifecycle.beginWindowClose()",
            "native macOS close handoff")
    require(main_qml, "macAppLifecycle.restoreWindow()",
            "native macOS restore handoff")
    forbid(main_qml, "macTrafficLightsController.hideToTray",
           "removed close-to-tray call")

    # The process outlives its window only on macOS.
    require(main_cpp, "QGuiApplication::setQuitOnLastWindowClosed(false)",
            "macOS keeps running without a window")
    require(main_cpp, "macAppLifecycle.attach(macRootWindow)",
            "lifecycle adapter attached to the root window")

    # Dock reopen + full-screen exit sequencing live in the new adapter.
    require(lifecycle_h, "Q_INVOKABLE bool beginWindowClose()",
            "QML-callable deferred-close decision")
    require(lifecycle_h, "Q_INVOKABLE void restoreWindow()",
            "QML-callable window restore")
    require(lifecycle_mm, "applicationShouldHandleReopen:",
            "Dock reopen handler")
    require(lifecycle_mm, "forwardingTargetForSelector:",
            "delegate proxy forwards to Qt's delegate")
    require(lifecycle_mm, "NSWindowStyleMaskFullScreen",
            "native full-screen state detection")
    require(lifecycle_mm, "NSWindowDidExitFullScreenNotification",
            "full-screen exit completion observer")
    require(lifecycle_mm, "[nativeWindow toggleFullScreen:nil]",
            "native full-screen exit request")
    require(lifecycle_mm, "if (qtWindow) qtWindow->close()",
            "deferred close after exit completion")

    # Traffic lights survive the platform window being destroyed and rebuilt.
    require(traffic_lights_mm, "&QWindow::visibleChanged",
            "native buttons follow the platform window lifetime")
    forbid(traffic_lights_mm, "hideToTray",
           "close-to-tray path in the traffic-light controller")

    require(cmake, "services/macos/macos_app_lifecycle.mm",
            "lifecycle adapter compiled on APPLE")

    # Clicking the macOS status item opens its menu; it does not restore the
    # window. Windows/Linux keep click-to-restore in NotifierTray.qml.
    status_bar = (
        ROOT / "src/services/macos/macos_status_bar_icon.cpp"
    ).read_text(encoding="utf-8")
    forbid(status_bar, "&QSystemTrayIcon::activated",
           "click-to-restore handler on the macOS status item")
    require(status_bar, "invokeRoot(\"restoreFromTray\")",
            "menu item restores the window")
    notifier_qml = (
        ROOT / "qml/desktop/memorylake/NotifierTray.qml"
    ).read_text(encoding="utf-8")
    require(notifier_qml, "Platform.SystemTrayIcon.Trigger",
            "non-macOS tray keeps click-to-restore")


if __name__ == "__main__":
    main()
