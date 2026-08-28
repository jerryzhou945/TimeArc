from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def forbid(text, needle, label):
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


def main():
    icon_h = (
        ROOT / "src/services/macos/macos_status_bar_icon.h"
    ).read_text(encoding="utf-8")
    icon_cpp = (
        ROOT / "src/services/macos/macos_status_bar_icon.cpp"
    ).read_text(encoding="utf-8")
    main_cpp = (ROOT / "src/main.cpp").read_text(encoding="utf-8")
    main_qml = (ROOT / "qml/main.qml").read_text(encoding="utf-8")
    shell_qml = (
        ROOT / "qml/desktop/DesktopAppShell.qml"
    ).read_text(encoding="utf-8")
    i18n_js = (
        ROOT / "qml/shared/I18n.js"
    ).read_text(encoding="utf-8")

    # Menu rows: open, the pomodoro trio, the two service rows, quit.
    require(icon_h,
            "void attach(SettingsRepository* settings, PomodoroManager* pomodoro)",
            "settings + pomodoro wiring entry point")
    require(main_cpp,
            "macStatusBarIcon.attach(&settingsRepository, &pomodoroManager)",
            "status item attached to the settings repository and the engine")
    require(icon_cpp, "invokeRoot(\"restoreFromTray\")", "open row")
    require(icon_cpp, "invokeRoot(\"quitFromTray\")", "quit row")

    # Two separate concerns, two rows: collecting right now, and starting at
    # login. Folding them into one control would make "stop tracking" look like
    # it also cancels autostart.
    require(icon_cpp, "autostartAction->setCheckable(true)",
            "autostart row is a checkable toggle, not a placeholder")
    forbid(icon_cpp, "autostartAction->setEnabled(false)",
           "autostart row hardwired off; it now follows the service")
    require(icon_cpp, "settings->setAutostartEnabled(enabled)",
            "autostart row writes the launchd registration")
    require(icon_cpp, "settings->startTrackingNow()", "tracking row start command")
    require(icon_cpp, "settings->stopBackgroundCollection()",
            "tracking row stop command")
    for field in ("s.startTracking", "s.stopTracking"):
        require(icon_cpp, field, f"tracking row label {field}")

    # State comes from the service on every open, never from a UI-side copy, and
    # both rows share one query so opening the menu spawns one helper at most.
    require(icon_cpp, "settings->serviceState()", "rows read live service state")
    require(icon_cpp, "autostartAction->setChecked(reachable && autostart)",
            "no checkmark is claimed when the service cannot be reached")
    require(icon_cpp, "trackingAction->setEnabled(reachable)",
            "tracking row disabled when the service cannot be reached")

    # The readout row carries mm:ss and is clickable in all three states.
    require(icon_cpp, "pomodoro->timeText()", "readout row shows mm:ss")
    require(icon_cpp, "invokeRoot(\"showPomodoroFromTray\")",
            "readout row opens the widget")
    # Opening the widget must bring the window back first: the layer lives in
    # the window's QML tree, so marking it shown while the window is closed
    # displays nothing.
    require(main_qml, "function showPomodoroFromTray()",
            "root forwarder for the readout row")
    require(main_qml, "restoreFromTray()", "forwarder restores the window")
    require(main_qml, "shellLoader.item.menuShowPomodoro()",
            "forwarder reaches the shell")
    require(shell_qml, "function menuShowPomodoro()", "shell entry point")
    require(shell_qml, "pomodoroLayer.show()",
            "readout row shows rather than toggles the layer")

    # One row, three faces: idle -> start, paused -> resume, running -> pause.
    require(icon_cpp, "pomodoroPaused()",
            "paused is distinguished from idle, not folded into it")
    require(icon_cpp, "pomodoro->remain() != pomodoro->total()",
            "paused test")
    for field in ("s.startTimer", "s.resumeTimer", "s.pauseTimer"):
        require(icon_cpp, field, f"primary row label {field}")
    require(icon_cpp, "impl->pomodoro->pauseTimer()", "pause command")
    require(icon_cpp, "impl->pomodoro->startTimer()",
            "start command, which also resumes a paused session")
    require(icon_cpp, "impl->pomodoro->resetTimer()", "reset command")

    # Every row is localized in all three UI languages, relabelled on open.
    require(icon_cpp, "&QMenu::aboutToShow",
            "rows relabelled when the menu opens")
    require(icon_cpp, "settings->languageMode()",
            "language read through the one resolver, not a literal default")
    for table in ("kZh{", "kEn{", "kJa{"):
        require(icon_cpp, table, f"string table {table}")
    # langFromMode must mirror I18n.js langKey(): zh | en | ja, else zh.
    require(i18n_js, 'lang === "zh" || lang === "ja" ? lang : "en"',
            "I18n.js language fallback this table mirrors")
    require(icon_cpp, 'if (mode == QLatin1String("zh")) return kZh;',
            "Chinese branch")
    require(icon_cpp, 'if (mode == QLatin1String("ja")) return kJa;',
            "Japanese branch")
    require(icon_cpp, "return kEn;", "English fallback")
    forbid(icon_cpp, 'menu.addAction(QStringLiteral("',
           "hardcoded single-language menu label")


if __name__ == "__main__":
    main()
