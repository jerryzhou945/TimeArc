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

    # Three menu rows: open, autostart placeholder, quit.
    require(icon_h, "void attach(SettingsRepository* settings)",
            "language wiring entry point")
    require(main_cpp, "macStatusBarIcon.attach(&settingsRepository)",
            "status item attached to the settings repository")
    require(icon_cpp, "invokeRoot(\"restoreFromTray\")", "open row")
    require(icon_cpp, "autostartAction->setEnabled(false)",
            "autostart row stays a placeholder")
    require(icon_cpp, "invokeRoot(\"quitFromTray\")", "quit row")

    # No timer control from the status item — the window owns the timer.
    for banned in ("TimerManager", "pauseTimer", "resumeTimer",
                   "stopAndCommit", "startProject"):
        forbid(icon_cpp, banned, "timer control in the status menu")
        forbid(icon_h, banned, "timer control in the status menu")

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

    # No service control from the menu — that would need a disk-contract
    # change proposal (CHARTER §2 forbids IPC between the two processes).
    for banned in ("QProcess", "startBackgroundCollection",
                   "stopBackgroundCollection"):
        forbid(icon_cpp, banned, "service control from the status menu")


if __name__ == "__main__":
    main()
