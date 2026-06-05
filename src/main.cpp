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

void startUsageService() {
#if defined(Q_OS_WIN)
  const QString appDir = QCoreApplication::applicationDirPath();
  const QString servicePath = QDir(appDir).filePath("time-arc-service.exe");
  if (!QFileInfo::exists(servicePath)) return;

  QProcess::startDetached(servicePath, QStringList(), appDir);
#endif
}

}  // namespace

int main(int argc, char* argv[]) {
  const bool mobilePreview =
      hasMobilePreviewArg(argc, argv) ||
      qEnvironmentVariableIsSet("TIMEARC_MOBILE_PREVIEW");

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
  ManualProjectRepository manualProjectRepository;
  if (!settingsRepository.migrateLegacyQSettings(&manualProjectRepository)) {
    qWarning() << "Legacy QSettings migration did not complete.";
  }

  CalendarManager calendarManager(&settingsRepository);
  MediaSessionRepository mediaRepository;
  StatsService statsService(&frontmostRepository, &mediaRepository,
                            &manualProjectRepository);
  DailyCardService dailyCardService(&statsService, &frontmostRepository);
  TagRepository tagRepository;
  TimerManager timerManager;
  ProjectManager projectManager(&manualProjectRepository);
  UsageStatManager usageStatManager;

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

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  engine.load(QUrl(QStringLiteral("qrc:/qt/qml/time_arc/qml/main.qml")));

  if (engine.rootObjects().isEmpty()) return -1;

#if defined(Q_OS_WIN)
  applyWin11RoundedCorners(
      qobject_cast<QWindow*>(engine.rootObjects().constFirst()));
#endif

  return app.exec();
}
