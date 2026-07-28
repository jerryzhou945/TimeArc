// SPDX-License-Identifier: GPL-3.0-or-later

#include "macos_status_bar_icon.h"

#include <QAction>
#include <QIcon>
#include <QMenu>
#include <QMetaObject>
#include <QPainter>
#include <QPixmap>
#include <QPointer>
#include <QString>
#include <QSvgRenderer>
#include <QSystemTrayIcon>
#include <array>
#include <utility>

#include "services/settings_repository.h"
#include "services/timer_manager.h"

namespace {

QIcon makeInputSourceTIcon() {
  static constexpr qreal logicalWidth = 22.0;
  static constexpr qreal logicalHeight = 18.0;

  static const QByteArray svg = R"SVG(
    <svg xmlns="http://www.w3.org/2000/svg"
         width="22"
         height="18"
         viewBox="0 0 22 18">
      <path fill="#ffffff"
            fill-rule="evenodd"
            d="
              M 3 1
              H 19
              A 3 3 0 0 1 21.5 4
              V 14
              A 3 3 0 0 1 19 17
              H 3
              A 3 3 0 0 1 0.5 14
              V 4
              A 3 3 0 0 1 3 1
              Z

              M 6.8 4.6
              H 15.2
              V 6.2
              H 11.9
              V 13.6
              H 10.1
              V 6.2
              H 6.8
              Z
            "/>
    </svg>
  )SVG";

  QSvgRenderer renderer(svg);
  if (!renderer.isValid()) return {};

  QIcon icon;
  for (const qreal dpr : std::array{1.0, 2.0, 3.0}) {
    const QSize pixelSize(qRound(logicalWidth * dpr),
                          qRound(logicalHeight * dpr));
    QPixmap pixmap(pixelSize);
    pixmap.setDevicePixelRatio(dpr);
    pixmap.fill(Qt::transparent);

    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);
    renderer.render(&painter, QRectF(0.0, 0.0, logicalWidth, logicalHeight));
    painter.end();

    icon.addPixmap(pixmap, QIcon::Normal, QIcon::Off);
  }

  icon.setIsMask(true);
  return icon;
}

// The status menu cannot call qml/desktop/components/I18n.js — that is a QML
// JS library, not something C++ can reach — so the handful of rows carry their
// own table. Columns follow I18n.js langKey(): zh, en, ja.
struct MenuStrings {
  const char* open;
  const char* startTimer;
  const char* pauseTimer;
  const char* resumeTimer;
  const char* stopTimer;
  const char* autostart;
  const char* quit;
};

constexpr MenuStrings kZh{"打开 TimeArc", "开始计时…",  "暂停计时",
                          "继续计时",     "结束并记录", "开机自启",
                          "退出 TimeArc"};
constexpr MenuStrings kEn{"Open TimeArc", "Start Timer…",  "Pause Timer",
                          "Resume Timer", "Stop and Save", "Launch at Login",
                          "Quit TimeArc"};
constexpr MenuStrings kJa{"TimeArc を開く", "計測を開始…",  "計測を一時停止",
                          "計測を再開",     "終了して記録", "ログイン時に起動",
                          "TimeArc を終了"};

// Mirrors I18n.js langKey(): anything unrecognized falls back to Chinese.
const MenuStrings& stringsForMode(const QString& mode) {
  if (mode == QLatin1String("en")) return kEn;
  if (mode == QLatin1String("ja")) return kJa;
  return kZh;
}

}  // namespace

class MacStatusBarIcon::Impl {
 public:
  Impl() : icon(makeInputSourceTIcon()) {
    showAction = menu.addAction(QString());
    menu.addSeparator();
    timerAction = menu.addAction(QString());
    stopTimerAction = menu.addAction(QString());
    menu.addSeparator();
    autostartAction = menu.addAction(QString());
    // Placeholder: SettingsRepository::autostartSupported() is Windows-only and
    // registerMacLaunchAgent() has no query/unregister path yet.
    autostartAction->setEnabled(false);
    menu.addSeparator();
    quitAction = menu.addAction(QString());

    // Rows are relabelled on every open instead of following a language-change
    // signal: the menu is invisible until the moment it opens, so a pull here
    // is both cheaper than a subscription and immune to missing one.
    QObject::connect(&menu, &QMenu::aboutToShow, &icon, [this]() { sync(); });
    sync();

    icon.setToolTip(QStringLiteral("TimeArc"));
    icon.setContextMenu(&menu);
  }

  // True when a manual timer exists — running or paused mid-session.
  bool hasTimerSession() const {
    return timerManager && !timerManager->currentProject().isEmpty();
  }

  void sync() {
    const QString mode =
        settings ? settings->getValue(QStringLiteral("language_mode"),
                                      QStringLiteral("zh"))
                 : QStringLiteral("zh");
    const MenuStrings& s = stringsForMode(mode);

    showAction->setText(QString::fromUtf8(s.open));
    autostartAction->setText(QString::fromUtf8(s.autostart));
    quitAction->setText(QString::fromUtf8(s.quit));

    // One row with three faces, so the menu never offers a no-op: without a
    // project startProject() has no name to use, and the window has to come
    // back for the user to pick one.
    const bool running = timerManager && timerManager->running();
    if (running) {
      timerAction->setText(QString::fromUtf8(s.pauseTimer));
    } else if (hasTimerSession()) {
      timerAction->setText(QString::fromUtf8(s.resumeTimer));
    } else {
      timerAction->setText(QString::fromUtf8(s.startTimer));
    }
    timerAction->setEnabled(timerManager != nullptr);

    stopTimerAction->setText(QString::fromUtf8(s.stopTimer));
    stopTimerAction->setEnabled(hasTimerSession());
  }

  QMenu menu;
  QSystemTrayIcon icon;
  QAction* showAction = nullptr;
  QAction* timerAction = nullptr;
  QAction* stopTimerAction = nullptr;
  QAction* autostartAction = nullptr;
  QAction* quitAction = nullptr;
  TimerManager* timerManager = nullptr;
  SettingsRepository* settings = nullptr;
};

MacStatusBarIcon::MacStatusBarIcon() : impl_(std::make_unique<Impl>()) {}

MacStatusBarIcon::~MacStatusBarIcon() = default;

QObject* MacStatusBarIcon::qmlObject() const { return &impl_->icon; }

void MacStatusBarIcon::attach(TimerManager* timerManager,
                              SettingsRepository* settings) {
  impl_->timerManager = timerManager;
  impl_->settings = settings;
  impl_->sync();
}

void MacStatusBarIcon::connectToRoot(QObject* rootObject) {
  const QPointer<QObject> root(rootObject);
  const auto invokeRoot = [root](const char* method) {
    if (root) {
      QMetaObject::invokeMethod(root, method, Qt::QueuedConnection);
    }
  };

  QObject::connect(impl_->showAction, &QAction::triggered, &impl_->icon,
                   [invokeRoot]() { invokeRoot("restoreFromTray"); });
  QObject::connect(impl_->quitAction, &QAction::triggered, &impl_->icon,
                   [invokeRoot]() { invokeRoot("quitFromTray"); });

  Impl* const impl = impl_.get();
  QObject::connect(impl_->timerAction, &QAction::triggered, &impl_->icon,
                   [impl, invokeRoot]() {
                     if (!impl->timerManager) return;
                     if (impl->timerManager->running()) {
                       impl->timerManager->pauseTimer();
                     } else if (impl->hasTimerSession()) {
                       impl->timerManager->resumeTimer();
                     } else {
                       // No project to resume — the window owns project choice.
                       invokeRoot("restoreFromTray");
                     }
                   });
  QObject::connect(impl_->stopTimerAction, &QAction::triggered, &impl_->icon,
                   [impl]() {
                     // DesktopAppShell's onTimerStopped writes the elapsed time
                     // into project history; that Connections object outlives a
                     // macOS window close, which destroys the platform window
                     // but not the QML tree.
                     if (!impl->hasTimerSession()) return;
                     impl->timerManager->stopAndCommit();
                   });

  // Deliberately no QSystemTrayIcon::activated handler. macOS status items
  // open their menu on click; restoring the window is 打开 TimeArc in that
  // menu, not a side effect of the click itself. The Qt.labs tray used on
  // Windows/Linux keeps its click-to-restore behavior.
}
