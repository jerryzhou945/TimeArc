// SPDX-License-Identifier: GPL-3.0-or-later

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QProcess>
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
#include "services/settings_repository.h"
#include "services/stats_service.h"
#include "services/tag_repository.h"
#include "services/app_icon_image_provider.h"
#include "services/calendar_manager.h"
#include "services/harness_logger.h"
#include "services/project_manager.h"
#include "services/timer_manager.h"
#include "services/usage_stat_manager.h"

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

#if defined(Q_OS_WIN)
// 无边框窗口的圆角：用 Win11 DWM 原生圆角（DWMWA_WINDOW_CORNER_PREFERENCE），
// 系统级平滑抗锯齿圆角并补回原生投影。运行时动态加载 dwmapi，避免改动冻结的 CMakeLists。
// Win11 (build >= 22000) 才支持；旧系统调用无害失败，窗口仍为直角。
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
    const DWORD DWMWCP_ROUND = 2;  // 标准圆角（最大化时系统自动取消）
    DWORD pref = DWMWCP_ROUND;
    setAttr(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &pref, sizeof(pref));
  }
  FreeLibrary(dwm);
}
#endif

#if defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
QString findMacUsageServicePath(const QString& appDir) {
  const QString exe = QStringLiteral("time-arc-service");
  const QStringList candidates = {
      QDir(appDir).filePath(exe),
      QDir(appDir).filePath(QStringLiteral("../Helpers/") + exe),
      QDir(appDir).filePath(QStringLiteral("../../../bin/") + exe),
      QDir(appDir).filePath(QStringLiteral("../../../") + exe),
      QDir(appDir).filePath(QStringLiteral("src/service/") + exe),
      QDir(appDir).filePath(QStringLiteral("../src/service/") + exe),
  };

  for (const QString& candidate : candidates) {
    const QFileInfo info(candidate);
    if (info.exists() && info.isFile() && info.isExecutable()) {
      return info.absoluteFilePath();
    }
  }
  return {};
}
#endif

void startUsageService() {
#if defined(Q_OS_WIN)
  const QString appDir = QCoreApplication::applicationDirPath();
  const QString servicePath = QDir(appDir).filePath("time-arc-service.exe");
  if (!QFileInfo::exists(servicePath)) return;

  QProcess::startDetached(servicePath, QStringList(), appDir);
#elif defined(Q_OS_MACOS) || defined(Q_OS_DARWIN)
  const QString appDir = QCoreApplication::applicationDirPath();
  const QString servicePath = findMacUsageServicePath(appDir);
  if (servicePath.isEmpty()) return;

  QProcess::startDetached(servicePath, QStringList(),
                          QFileInfo(servicePath).absolutePath());
#endif
}

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

  QGuiApplication app(argc, argv);
  QCoreApplication::setOrganizationName("TimeArc");
  QCoreApplication::setApplicationName("TimeArc");

  // 无边框窗口的标题栏图标 + 任务栏图标共用同一品牌 SVG（资源随 QML 模块打包）。
  QGuiApplication::setWindowIcon(
      QIcon(QStringLiteral(":/qt/qml/time_arc/resources/icons/app_icon.svg")));

  // Tee Qt Warning/Critical/Fatal into the harness log. See
  // .harness/tools/scan_qt_log.py for the consumer that converts log
  // lines into L2 error reports.
  installHarnessLogger();

  startUsageService();

  QQmlApplicationEngine engine;

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

  CalendarManager calendarManager(&settingsRepository);
  MediaSessionRepository mediaRepository;
  StatsService statsService(&frontmostRepository, &mediaRepository,
                            &manualProjectRepository);
  MobileUsageService mobileUsageService(&mobileUsageRepository);
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

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  engine.load(QUrl(QStringLiteral("qrc:/qt/qml/time_arc/qml/main.qml")));

  if (engine.rootObjects().isEmpty()) return -1;

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
