from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def forbid(text, needle, label):
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


def main():
    bar = (ROOT / "qml/desktop/MacMenuBar.qml").read_text(encoding="utf-8")
    main_qml = (ROOT / "qml/main.qml").read_text(encoding="utf-8")
    shell = (
        ROOT / "qml/desktop/DesktopAppShell.qml"
    ).read_text(encoding="utf-8")
    profile = (
        ROOT / "qml/desktop/pages/DesktopProfilePage.qml"
    ).read_text(encoding="utf-8")
    i18n_js = (
        ROOT / "qml/desktop/components/I18n.js"
    ).read_text(encoding="utf-8")
    main_cpp = (ROOT / "src/main.cpp").read_text(encoding="utf-8")
    localizer = (
        ROOT / "src/services/macos/macos_menu_localizer.cpp"
    ).read_text(encoding="utf-8")
    src_cmake = (ROOT / "src/CMakeLists.txt").read_text(encoding="utf-8")
    build_script = (ROOT / "tools/build-macos.sh").read_text(encoding="utf-8")
    qml_cmake = (ROOT / "qml/CMakeLists.txt").read_text(encoding="utf-8")
    settings_repo = (
        ROOT / "src/services/settings_repository.cpp"
    ).read_text(encoding="utf-8")

    require(qml_cmake, "qml/desktop/MacMenuBar.qml", "menu bar in the QML module")

    # macOS only. Windows/Linux must not instantiate a MenuBar at all: they
    # keep the self-drawn WindowChrome, whose caption would collide with one.
    require(main_qml, "active: appWindow.macSidebarChrome",
            "menu bar gated on the macOS chrome flag")
    require(main_qml, "MacMenuBar {", "menu bar instantiated from the window")
    forbid(shell, "MacMenuBar {", "menu bar instantiated from the shared shell")

    # The injected properties must NOT be named after main.qml's ids. In
    # `MacMenuBar { appWindow: appWindow }` the right-hand side resolves to the
    # object's own property first, so the binding is a self-assignment that
    # stays null — and every command gated on a live window greys out.
    require(main_qml, "hostWindow: appWindow", "window injected under a distinct name")
    require(main_qml, "hostShell: shellLoader.item", "shell injected under a distinct name")
    require(bar, "property var hostWindow: null", "window property")
    require(bar, "property var hostShell: null", "shell property")
    for shadowing in ("property var appWindow", "property var shell:"):
        forbid(bar, shadowing, "property name that shadows a main.qml id")

    # Six menus: the app menu is populated by role merging (see below), the
    # other five are declared here.
    for title in ("文件", "编辑", "显示", "窗口", "帮助"):
        require(bar, f'title: bar.tr("{title}")', f"{title} menu")

    # About, Settings and Quit carry roles so macOS merges them into the app menu.
    # Quit must route through quitFromTray(): the default quit item bypasses
    # forceQuit and hits main.qml's "close keeps the app running" onClosing.
    require(bar, "role: Platform.MenuItem.AboutRole", "about role")
    require(bar, "role: Platform.MenuItem.PreferencesRole", "settings role")
    require(bar, "role: Platform.MenuItem.QuitRole", "quit role")
    require(bar, "enabled: bar.hasShell && !bar.memoOpen && !bar.capturing",
            "About remains available without a visible window")
    require(bar, "if (!bar.hasWindow && bar.hostWindow)",
            "About detects a closed window")
    require(bar, "bar.hostShell.menuOpenAbout()", "about routed to the shell")
    require(bar, "bar.hostWindow.restoreFromTray()", "about restores a closed window")
    require(bar, "bar.hostWindow.quitFromTray()", "quit routed through the window")

    # Commands, each bound to behavior that already exists.
    for command in (
        'shortcut: "Ctrl+,"',            # settings
        'shortcut: "Ctrl+Q"',            # quit
        'shortcut: "Ctrl+Shift+E"',      # export stats report
        'shortcut: "Ctrl+W"',            # close window
        'shortcut: "Ctrl+Z"',            # undo
        'shortcut: "Ctrl+Shift+Z"',      # redo
        'shortcut: "Ctrl+X"',            # cut
        'shortcut: "Ctrl+C"',            # copy
        'shortcut: "Ctrl+V"',            # paste
        'shortcut: "Ctrl+A"',            # select all
        'shortcut: "Ctrl+1"',            # memory lake
        'shortcut: "Ctrl+2"',            # calendar
        'shortcut: "Ctrl+3"',            # stats
        'shortcut: "Ctrl+4"',            # monthly recap
        'shortcut: "Ctrl+Shift+N"',      # memo board
        'shortcut: "Ctrl+Shift+P"',      # pomodoro
        'shortcut: "Ctrl+Shift+D"',      # night mode
        'shortcut: "Ctrl+M"',            # minimize
    ):
        require(bar, command, "menu command")

    # A single letter can never be a menu key equivalent: the menu would eat
    # the keystroke before a focused text field sees it, which is what the
    # shell's Keys.onShortcutOverride exists to prevent. The letter hotkeys
    # (N / P, user-rebindable) stay in the shell, untouched.
    for bare in ('shortcut: "N"', 'shortcut: "P"',
                 "shortcut: root.memoHotkeyKey", "shortcut: bar.host"):
        forbid(bar, bare, "bare single-letter menu shortcut")
    require(shell, "sequences: root.memoHotkeyKey.length > 0",
            "memo letter hotkey still owned by the shell")
    require(shell, "sequences: root.pomodoroHotkeyKey.length > 0",
            "pomodoro letter hotkey still owned by the shell")

    # The menu bar outlives the window (red button closes the window, the
    # process stays). Commands needing a window/shell must grey out instead of
    # silently restoring it; only the Window menu's TimeArc row brings it back.
    require(bar, "readonly property bool hasWindow: hostWindow !== null && hostWindow.visible",
            "no-window state")
    require(bar, "readonly property bool canNavigate: hasWindow && hasShell && !memoOpen",
            "navigation disabled with no window or over the memo board")
    require(bar, "bar.hostWindow.restoreFromTray()", "window restore row")
    require(bar, "enabled: bar.canNavigate && bar.onStatsPage",
            "stats export scoped to the stats page")
    require(bar, "!hostShell.memoLocked", "memo guard shared with the letter hotkey")

    # Check state is pushed on aboutToShow, never bound: Qt.labs.platform
    # writes checked on activation, which would break a binding for good.
    require(bar, "onAboutToShow: bar.syncViewChecks()", "view menu check sync")
    require(bar, "onAboutToShow: bar.syncWindowChecks()", "window menu check sync")
    forbid(bar, "checked: bar.", "bound check state that activation would break")

    # Command targets exist on the objects the menu calls into.
    for fn in ("function menuNavigateTo(", "function menuOpenAbout(",
               "function menuToggleMemo(",
               "function menuTogglePomodoro(", "function menuToggleNightMode(",
               "function menuSetLanguage(", "function menuRunSettingsAction(",
               "function menuExportStatsReport("):
        require(shell, fn, "shell command entry point")
    require(profile, "function openImportDialog()", "settings import entry point")
    require(profile, "function doExport()", "settings export entry point")
    require(profile, "function doBackupDatabase()", "database backup entry point")
    require(shell, 'it.selectTab("about")', "About menu selects the About settings tab")
    require(profile, 'tabKey: "about"', "dedicated About settings tab")

    # All three UI languages, from the same file the window UI uses.
    require(bar, 'import "components/I18n.js" as I18n', "shared i18n source")
    require(bar, "return I18n.menu(lang, source);", "menu strings localized")
    require(i18n_js, "var menuEn = {", "English menu table")
    require(i18n_js, "var menuJa = {", "Japanese menu table")
    require(i18n_js, "function menu(lang, source)", "menu lookup")
    for label in ("文件", "编辑", "显示", "窗口", "帮助", "关于 TimeArc",
                  "备忘黑板", "记忆湖", "夜间模式", "在 Finder 中显示数据文件夹"):
        require(i18n_js, f'"{label}": "', f"{label} translated")
    # Language names stay in their own language, macOS-style — never translated.
    for literal in ('text: "中文"', 'text: "English"', 'text: "日本語"'):
        require(bar, literal, "language row")

    # Merged Preferences/Quit rows are relabelled by QCocoa from Qt's
    # MAC_APPLICATION_MENU catalog, not from their QML text. The translator
    # therefore follows the same languageMode that drives the custom menus.
    require(bar, "macMenuLocalizer.setLanguage(bar.hostShell.languageMode)",
            "language forwarded to the native translator")
    require(main_cpp, "MacMenuLocalizer macMenuLocalizer;",
            "macOS-owned translator lifetime")
    require(main_cpp, 'setContextProperty("macMenuLocalizer"',
            "translator exposed to the macOS menu")
    require(localizer, "QCoreApplication::installTranslator",
            "Qt translator installation")
    require(localizer, 'QStringLiteral("../Resources/translations")',
            "packaged translation lookup")
    require(src_cmake, "services/macos/macos_menu_localizer.cpp",
            "localizer compiled only in the APPLE source branch")
    require(build_script, '"TimeArc.app/Contents/Resources/translations"',
            "native menu catalogs deployed inside the app bundle")
    require(build_script, "qt6_deploy_translations(",
            "targeted Qt translation deployment")

    # AppKit contributes its own rows (自动填充 / 开始听写 / 表情与符号 to 编辑,
    # 进入全屏幕 to 显示, the search field to 帮助) only to menus whose titles
    # match ITS OWN localization. Pinning AppleLanguages to the UI language is
    # what makes it recognise 编辑/显示/帮助 on a system running another
    # language; without it those rows silently never appear.
    require(localizer, "AppleLanguages", "AppKit localization pinned to the UI language")
    require(localizer, "rememberAppKitLanguage(normalized)",
            "override re-asserted on every language change")

    # One writer. The native pin is driven only by the shell's persisted
    # languageMode — never by a view binding, which is how a transient value
    # got pinned and then outlived the session that produced it.
    require(bar, "function onLanguageModeChanged()", "single native-language funnel")
    forbid(bar, "syncNativeLanguage", "view binding driving process-wide state")
    forbid(bar, "macMenuLocalizer.setLanguage(lang)",
           "display fallback reaching the native side")

    # English is the fallback for anything unrecognized, on both sides. A
    # Chinese fallback made Chinese an attractor: any stray value re-pinned it,
    # so en/ja sessions decayed into a Chinese AppKit while zh never did.
    require(localizer,
            'if (mode == QLatin1String("zh") || mode == QLatin1String("ja")) return mode;',
            "English fallback in the native normalizer")
    forbid(localizer, 'return QStringLiteral("zh");', "Chinese fallback")
    require(i18n_js, 'if (lang === "zh")', "explicit Chinese branch in menu lookup")
    require(i18n_js, "return menuEn[source] || source\n}",
            "English fallback for unrecognized menu languages")
    # Same rule for the window UI: explicit zh/ja are untouched, anything
    # unrecognized resolves to English rather than resurrecting Chinese.
    require(i18n_js, 'return lang === "zh" || lang === "ja" ? lang : "en"',
            "English fallback in langKey")

    # The UI language has one resolver. Readers call it instead of carrying a
    # literal default, so a fresh install adopts the system language and every
    # surface — shells, settings page, menu bar, status item — agrees.
    require(settings_repo, "QString SettingsRepository::languageMode()",
            "single language resolver")
    require(settings_repo, '".GlobalPreferences"',
            "system language read from the GLOBAL domain, not our own pin")
    require(settings_repo, 'QLatin1String("hant")',
            "Traditional Chinese is not treated as a match")
    require(settings_repo, 'return QStringLiteral("en");',
            "English is the fallback when nothing matches")
    require(main_cpp, "macMenuLocalizer.setLanguage(settingsRepository.languageMode())",
            "startup pin uses the resolver")
    require(bar, "settingsRepository.languageMode()", "menu bar uses the resolver")
    require(shell, "settingsRepository.languageMode()", "shell uses the resolver")
    for stale in ('getValue("language_mode", "zh")',
                  'getValue(QStringLiteral("language_mode")'):
        forbid(shell, stale, "literal language default in the shell")
        forbid(bar, stale, "literal language default in the menu bar")
        forbid(main_cpp, stale, "literal language default in main")

    # Nothing arriving during teardown is a user choice. On quit the QML engine
    # outlives SettingsRepository, so bindings re-evaluate to their fallbacks
    # and fire change signals; pinning one of those poisoned the NEXT launch.
    require(localizer, "aboutToQuit", "shutdown latch connected")
    require(localizer, "if (shuttingDown_) return true;",
            "language changes ignored once the app is quitting")

    # Written only when it differs, and read back — the pin is the whole
    # mechanism, so a silent failure to store it must not be silent.
    require(localizer, "if (pinned == wanted) return;", "write only on change")
    require(localizer, "did not stick", "read-back verification")
    require(localizer, "until TimeArc is relaunched",
            "divergence reported when AppKit runs another language")

    # The bar is built before shellLoader has an item, so its fallback goes
    # through the resolver too (asserted above). A literal there titled the
    # menus in the wrong language for that window — long enough for AppKit to
    # adopt a mislabelled Edit menu and fill it in the wrong language.
    forbid(bar, 'hasShell ? hostShell.languageMode : "zh"',
           "hardcoded startup language fallback")
    require(build_script, "CATALOGS qtbase", "Qt Base catalog deployment")
    require(build_script, "LOCALES zh_CN ja",
            "the two translated in-app languages")

    # No service control from the menu bar: pausing the sampler means the UI
    # signalling the service, and CHARTER §2 forbids IPC. Same rule the status
    # item follows.
    for banned in ("stopBackgroundCollection", "startBackgroundCollection",
                   "Qt.createQmlObject", "timerManager"):
        forbid(bar, banned, "service or timer control from the menu bar")


if __name__ == "__main__":
    main()
