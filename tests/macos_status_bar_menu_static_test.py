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
    i18n_js = (
        ROOT / "qml/desktop/components/I18n.js"
    ).read_text(encoding="utf-8")

    # The four menu blocks: open, timers, autostart placeholder, quit.
    require(icon_h, "void attach(TimerManager* timerManager,",
            "timer/settings wiring entry point")
    require(main_cpp, "macStatusBarIcon.attach(&timerManager, &settingsRepository)",
            "status item attached to the UI services")
    require(icon_cpp, "autostartAction->setEnabled(false)",
            "autostart row stays a placeholder")
    require(icon_cpp, "invokeRoot(\"quitFromTray\")", "quit row")

    # Timer rows drive TimerManager directly, not through QML.
    for call in ("pauseTimer()", "resumeTimer()", "stopAndCommit()"):
        require(icon_cpp, f"impl->timerManager->{call}", f"timer row calls {call}")
    require(icon_cpp, "bool hasTimerSession() const",
            "stop/resume gated on an existing manual timer")

    # Every row is localized in all three UI languages, relabelled on open.
    require(icon_cpp, "&QMenu::aboutToShow",
            "rows relabelled when the menu opens")
    require(icon_cpp, 'settings->getValue(QStringLiteral("language_mode")',
            "language read from the UI setting")
    for table in ("kZh{", "kEn{", "kJa{"):
        require(icon_cpp, table, f"string table {table}")
    # langFromMode must mirror I18n.js langKey(): zh | en | ja, else zh.
    require(i18n_js, 'lang === "en" || lang === "ja" ? lang : "zh"',
            "I18n.js language fallback this table mirrors")
    require(icon_cpp, 'if (mode == QLatin1String("en")) return kEn;',
            "English branch")
    require(icon_cpp, 'if (mode == QLatin1String("ja")) return kJa;',
            "Japanese branch")
    require(icon_cpp, "return kZh;", "Chinese fallback")
    forbid(icon_cpp, 'menu.addAction(QStringLiteral("',
           "hardcoded single-language menu label")

    # No service control from the menu — that would need a disk-contract
    # change proposal (CHARTER §2 forbids IPC between the two processes).
    for banned in ("QProcess", "startBackgroundCollection",
                   "stopBackgroundCollection"):
        forbid(icon_cpp, banned, "service control from the status menu")


if __name__ == "__main__":
    main()
