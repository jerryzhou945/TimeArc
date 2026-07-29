// SPDX-License-Identifier: GPL-3.0-or-later

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QResource>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStringList>
#include <QUrl>
#include <QWindow>

#if defined(Q_OS_WIN)
#include <windows.h>
#endif

#include "services/app_repository.h"
#include "services/daily_card_service.h"
#include "services/database_manager.h"
#include "services/frontmost_session_repository.h"
#include "services/manual_project_repository.h"
#include "services/media_session_repository.h"
#include "services/mobile/mobile_usage_repository.h"
#include "services/mobile/mobile_usage_service.h"
#include "services/mobile/mobile_ui_service.h"
#include "services/settings_repository.h"
#include "services/stats_service.h"
#include "services/tag_repository.h"
#include "services/app_icon_image_provider.h"
#include "services/calendar_manager.h"
#include "services/harness_logger.h"
#include "services/project_manager.h"
#include "services/timer_manager.h"
#include "services/usage_stat_manager.h"

#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
#include <QApplication>

#include "services/macos/macos_app_lifecycle.h"
#include "services/macos/macos_launch_agent.h"
#include "services/macos/macos_menu_localizer.h"
#include "services/macos/macos_status_bar_icon.h"
#include "services/macos/macos_traffic_lights.h"
#endif

namespace {

#if defined(Q_OS_WIN)
const wchar_t* kTimeArcUiMutexName = L"Local\\TimeArcUiSingleInstance";

struct ExistingWindowSearch {
  DWORD current_pid = 0;
  HWND hwnd = nullptr;
};

BOOL CALLBACK findTimeArcWindowProc(HWND hwnd, LPARAM lparam) {
  auto* search = reinterpret_cast<ExistingWindowSearch*>(lparam);
  if (!search) return TRUE;

  wchar_t title[256] = {};
  GetWindowTextW(hwnd, title,
                 static_cast<int>(sizeof(title) / sizeof(title[0])));
  if (wcscmp(title, L"TimeArc") != 0) return TRUE;

  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0 || pid == search->current_pid) return TRUE;

  search->hwnd = hwnd;
  return FALSE;
}

void activateExistingTimeArcWindow() {
  ExistingWindowSearch search;
  search.current_pid = GetCurrentProcessId();
  EnumWindows(findTimeArcWindowProc, reinterpret_cast<LPARAM>(&search));
  if (!search.hwnd) return;

  if (IsIconic(search.hwnd)) {
    ShowWindow(search.hwnd, SW_RESTORE);
  } else {
    ShowWindow(search.hwnd, SW_SHOW);
  }
  SetForegroundWindow(search.hwnd);
}
#endif

bool hasMobilePreviewArg(int argc, char* argv[]) {
  for (int i = 1; i < argc; ++i) {
    const QString arg = QString::fromLocal8Bit(argv[i]);
    if (arg == QStringLiteral("--mobile") ||
        arg == QStringLiteral("--mobile-preview")) {
      return true;
    }
  }
  return false;
}

bool hasStartInTrayArg(int argc, char* argv[]) {
  for (int i = 1; i < argc; ++i) {
    const QString arg = QString::fromLocal8Bit(argv[i]);
    if (arg == QStringLiteral("--start-in-tray") ||
        arg == QStringLiteral("--tray")) {
      return true;
    }
  }
  return false;
}

#if !defined(Q_OS_ANDROID)
QString bundledGuiResourceDirectory() {
  const QString appDir = QCoreApplication::applicationDirPath();
#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
  return QDir(appDir).filePath(QStringLiteral("../Resources/assets"));
#else
  return QDir(appDir).filePath(QStringLiteral("assets"));
#endif
}

bool registerBundledGuiResources() {
  const QDir resourceDirectory(bundledGuiResourceDirectory());
  const QStringList resourceFiles = {
      QStringLiteral("timearc-backgrounds.rcc"),
      QStringLiteral("timearc-site-icons.rcc"),
      QStringLiteral("timearc-monthly-recap.rcc"),
  };
  for (const QString& resourceFile : resourceFiles) {
    const QString resourcePath =
        QFileInfo(resourceDirectory.filePath(resourceFile)).absoluteFilePath();
    if (!QFileInfo::exists(resourcePath)) {
      qCritical() << "Required GUI resource pack is missing:" << resourcePath;
      return false;
    }
    if (!QResource::registerResource(resourcePath)) {
      qCritical() << "Failed to register GUI resource pack:" << resourcePath;
      return false;
    }
  }
  return true;
}
#endif

#if defined(Q_OS_WIN)
// Use native Win11 DWM corners and shadows for the frameless window.
// Load dwmapi at runtime to avoid changing the frozen CMakeLists.
// The call safely fails on pre-Win11 systems, leaving square corners.
void applyWin11RoundedCorners(QWindow* window) {
  if (!window) return;
  const HWND hwnd = reinterpret_cast<HWND>(window->winId());
  if (!hwnd) return;
  HMODULE dwm = LoadLibraryW(L"dwmapi.dll");
  if (!dwm) return;
  using SetAttrFn = HRESULT(WINAPI*)(HWND, DWORD, LPCVOID, DWORD);
  auto setAttr =
      reinterpret_cast<SetAttrFn>(GetProcAddress(dwm, "DwmSetWindowAttribute"));
  if (setAttr) {
    const DWORD DWMWA_WINDOW_CORNER_PREFERENCE = 33;
    const DWORD DWMWCP_ROUND = 2;  // Standard corners; Windows removes them when maximized.
    DWORD pref = DWMWCP_ROUND;
    setAttr(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &pref, sizeof(pref));
  }
  FreeLibrary(dwm);
}
#endif

}  // namespace

int main(int argc, char* argv[]) {
#if defined(Q_OS_WIN)
  HANDLE uiInstanceMutex =
      CreateMutexW(nullptr, TRUE, kTimeArcUiMutexName);
  if (uiInstanceMutex && GetLastError() == ERROR_ALREADY_EXISTS) {
    activateExistingTimeArcWindow();
    CloseHandle(uiInstanceMutex);
    return 0;
  }
#endif

  const bool mobilePreview =
      hasMobilePreviewArg(argc, argv) ||
      qEnvironmentVariableIsSet("TIMEARC_MOBILE_PREVIEW");
  const bool startInTray = hasStartInTrayArg(argc, argv) && !mobilePreview;

#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
  // The native status-item menu is QMenu-backed and therefore requires
  // QApplication. Other platforms retain the lighter QGuiApplication path.
  QApplication app(argc, argv);
  // macOS convention: closing the window leaves the app running in the Dock
  // and menu bar. Quitting is ⌘Q or the status-item menu, not the red button.
  QGuiApplication::setQuitOnLastWindowClosed(false);
#else
  QGuiApplication app(argc, argv);
#endif
  QCoreApplication::setOrganizationName("TimeArc");
  QCoreApplication::setApplicationName("TimeArc");

#if !defined(Q_OS_ANDROID)
  if (!registerBundledGuiResources()) return 1;
#endif

  // macOS gets its application and Dock icon from CFBundleIconFile. Setting
  // the QRC SVG there would override the native multi-resolution .icns.
#if !defined(Q_OS_MACOS)
  QGuiApplication::setWindowIcon(
      QIcon(QStringLiteral(":/qt/qml/time_arc/resources/app/TimeArc.svg")));
#endif

  // Tee Qt Warning/Critical/Fatal into the harness log. See
  // .harness/tools/scan_qt_log.py for the consumer that converts log
  // lines into L2 error reports.
  installHarnessLogger();

#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
  const MacLaunchAgentRegistration launchAgent =
      registerMacLaunchAgent();
  if (!launchAgent.registered) {
    qWarning() << "Could not register the macOS LaunchAgent:"
               << launchAgent.errorMessage;
  } else if (launchAgent.requiresApproval) {
    qWarning() << "The macOS LaunchAgent requires approval in System Settings.";
  }
#endif

  QQmlApplicationEngine engine;

#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
  MacStatusBarIcon macStatusBarIcon;
  QObject* macStatusBarControllerContext = macStatusBarIcon.qmlObject();
  MacMenuLocalizer macMenuLocalizer;
  MacTrafficLightsController macTrafficLightsController;
  QObject* macTrafficLightsControllerContext = &macTrafficLightsController;
  MacAppLifecycle macAppLifecycle;
  QObject* macAppLifecycleContext = &macAppLifecycle;
#else
  QObject* macStatusBarControllerContext = nullptr;
  QObject* macTrafficLightsControllerContext = nullptr;
  QObject* macAppLifecycleContext = nullptr;
#endif

  DatabaseManager databaseManager;
  if (!databaseManager.initialize()) {
    qWarning() << "Database initialization failed.";
  }

  AppRepository appRepository;
  SettingsRepository settingsRepository;
  FrontmostSessionRepository frontmostRepository;
  MobileUsageRepository mobileUsageRepository;
  ManualProjectRepository manualProjectRepository;
  if (!settingsRepository.migrateLegacyQSettings(&manualProjectRepository)) {
    qWarning() << "Legacy QSettings migration did not complete.";
  }
#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
  macMenuLocalizer.setLanguage(settingsRepository.getValue(
      QStringLiteral("language_mode"), QStringLiteral("zh")));
#endif

  CalendarManager calendarManager(&settingsRepository);
  MediaSessionRepository mediaRepository;
  StatsService statsService(&frontmostRepository, &mediaRepository,
                            &manualProjectRepository);
  MobileUsageService mobileUsageService(&mobileUsageRepository);
  MobileUiService mobileUiService(&settingsRepository);
  DailyCardService dailyCardService(&statsService, &frontmostRepository);
  TagRepository tagRepository;
  TimerManager timerManager;
  ProjectManager projectManager(&manualProjectRepository);
  UsageStatManager usageStatManager;

#if defined(Q_OS_ANDROID)
  QObject::connect(&app, &QGuiApplication::applicationStateChanged,
                   &mobileUsageService, [&](Qt::ApplicationState state) {
                     if (state == Qt::ApplicationActive) {
                       mobileUsageService.requestImmediateSync();
                     }
                   });
#endif

  engine.addImageProvider(QStringLiteral("appicon"), new AppIconImageProvider);

  engine.rootContext()->setContextProperty("databaseManager",
                                           &databaseManager);
  engine.rootContext()->setContextProperty("appRepository", &appRepository);
  engine.rootContext()->setContextProperty("calendarManager", &calendarManager);
  engine.rootContext()->setContextProperty("frontmostRepository",
                                           &frontmostRepository);
  engine.rootContext()->setContextProperty("manualProjectRepository",
                                           &manualProjectRepository);
  engine.rootContext()->setContextProperty("mediaRepository",
                                           &mediaRepository);
  engine.rootContext()->setContextProperty("mobileUsageService",
                                           &mobileUsageService);
  engine.rootContext()->setContextProperty("mobileUiService",
                                           &mobileUiService);
  engine.rootContext()->setContextProperty("settingsRepository",
                                           &settingsRepository);
  engine.rootContext()->setContextProperty("statsService", &statsService);
  engine.rootContext()->setContextProperty("dailyCardService",
                                           &dailyCardService);
  engine.rootContext()->setContextProperty("tagRepository", &tagRepository);
  engine.rootContext()->setContextProperty("timerManager", &timerManager);
  engine.rootContext()->setContextProperty("projectManager", &projectManager);
  engine.rootContext()->setContextProperty("usageStatManager",
                                           &usageStatManager);
  engine.rootContext()->setContextProperty("mobilePreview", mobilePreview);
  engine.rootContext()->setContextProperty("startInTray", startInTray);
  engine.rootContext()->setContextProperty("macStatusBarController",
                                           macStatusBarControllerContext);
#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
  engine.rootContext()->setContextProperty("macMenuLocalizer",
                                           &macMenuLocalizer);
#endif
  engine.rootContext()->setContextProperty("macTrafficLightsController",
                                           macTrafficLightsControllerContext);
  engine.rootContext()->setContextProperty("macAppLifecycle",
                                           macAppLifecycleContext);

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  engine.load(QUrl(QStringLiteral("qrc:/qt/qml/time_arc/qml/main.qml")));

  if (engine.rootObjects().isEmpty()) return -1;

#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
  QWindow* const macRootWindow =
      qobject_cast<QWindow*>(engine.rootObjects().constFirst());
  macTrafficLightsController.attach(macRootWindow);
  macAppLifecycle.attach(macRootWindow);
  macStatusBarIcon.attach(&settingsRepository);
  macStatusBarIcon.connectToRoot(engine.rootObjects().constFirst());
#endif

#if defined(Q_OS_WIN)
  applyWin11RoundedCorners(
      qobject_cast<QWindow*>(engine.rootObjects().constFirst()));
#endif

  const int rc = app.exec();

#if defined(Q_OS_WIN)
  if (uiInstanceMutex) {
    ReleaseMutex(uiInstanceMutex);
    CloseHandle(uiInstanceMutex);
  }
#endif

  return rc;
}
