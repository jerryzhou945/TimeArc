// SPDX-License-Identifier: GPL-3.0-or-later

#include "macos_status_bar_icon.h"

#include <QAction>
#include <QDebug>
#include <QIcon>
#include <QMenu>
#include <QMetaObject>
#include <QPainter>
#include <QPixmap>
#include <QPointer>
#include <QString>
#include <QSvgRenderer>
#include <QSystemTrayIcon>
#include <QVariantMap>
#include <array>
#include <utility>

#include "services/pomodoro_manager.h"
#include "services/settings_repository.h"

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
  const char* pomodoro;   // 前缀，后接 mm:ss
  const char* startTimer;
  const char* resumeTimer;
  const char* pauseTimer;
  const char* resetTimer;
  const char* autostart;
  const char* startTracking;
  const char* stopTracking;
  const char* quit;
};

constexpr MenuStrings kZh{"打开 TimeArc", "番茄钟",   "开始计时",
                          "继续计时",     "暂停计时", "重置计时",
                          "开机自启",     "开始采集", "停止采集",
                          "退出 TimeArc"};
constexpr MenuStrings kEn{"Open TimeArc",  "Pomodoro",    "Start Timer",
                          "Resume Timer",  "Pause Timer", "Reset Timer",
                          "Launch at Login", "Start Tracking", "Stop Tracking",
                          "Quit TimeArc"};
constexpr MenuStrings kJa{"TimeArc を開く",   "ポモドーロ",       "計測を開始",
                          "計測を再開",       "計測を一時停止",   "計測をリセット",
                          "ログイン時に起動", "記録を開始",       "記録を停止",
                          "TimeArc を終了"};

// Mirrors I18n.js langKey(): anything unrecognized falls back to English.
const MenuStrings& stringsForMode(const QString& mode) {
  if (mode == QLatin1String("zh")) return kZh;
  if (mode == QLatin1String("ja")) return kJa;
  return kEn;
}

}  // namespace

class MacStatusBarIcon::Impl {
 public:
  Impl() : icon(makeInputSourceTIcon()) {
    showAction = menu.addAction(QString());
    menu.addSeparator();
    // 番茄钟三行：读数（可点，打开浮窗）+ 主命令（开始/继续/暂停）+ 重置。
    pomodoroAction = menu.addAction(QString());
    pomodoroPrimaryAction = menu.addAction(QString());
    pomodoroResetAction = menu.addAction(QString());
    menu.addSeparator();
    // 采集开关（临时）+ 开机自启（持久）。两件不同的事，故两行：前者只管此刻有没有
    // 在采集，后者只管登录时要不要自动起来。状态每次开菜单向服务问一次，UI 不留副本。
    trackingAction = menu.addAction(QString());
    QObject::connect(trackingAction, &QAction::triggered, &icon,
                     [this]() { toggleTracking(); });

    autostartAction = menu.addAction(QString());
    autostartAction->setCheckable(true);
    QObject::connect(autostartAction, &QAction::triggered, &icon,
                     [this](bool checked) { toggleAutostart(checked); });
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

  // 暂停态 = 停表但走过一段（remain 已被扣过）。空闲态 remain 与 total 相等。
  bool pomodoroPaused() const {
    return pomodoro && !pomodoro->running() &&
           pomodoro->remain() != pomodoro->total();
  }

  void sync() {
    const QString mode =
        settings ? settings->languageMode() : QStringLiteral("en");
    const MenuStrings& s = stringsForMode(mode);

    showAction->setText(QString::fromUtf8(s.open));
    quitAction->setText(QString::fromUtf8(s.quit));

    syncService(s);
    syncPomodoro(s);
  }

  // 服务两行：问一次 status，两行共用同一次结果（一次开菜单只 spawn 一个子进程）。
  void syncService(const MenuStrings& s) {
    const QVariantMap state =
        settings ? settings->serviceState() : QVariantMap{};
    const bool reachable = state.value(QStringLiteral("ok")).toBool();
    const bool running =
        state.value(QStringLiteral("trackingRunning")).toBool();
    const bool autostart =
        state.value(QStringLiteral("autostartEnabled")).toBool();

    // 采集行按当前是否在跑改写：在跑给「停止」，没跑给「开始」。
    trackingAction->setText(QString::fromUtf8(running ? s.stopTracking
                                                      : s.startTracking));
    trackingAction->setEnabled(reachable);

    // 服务问不到时不画勾：没勾是一个断言，问不出来就别断言。
    autostartAction->setText(QString::fromUtf8(s.autostart));
    autostartAction->setChecked(reachable && autostart);
    autostartAction->setEnabled(reachable);
  }

  // 采集开关：停用 `stop`，开用 `start`（有注册拉注册的，没注册起临时的）。
  void toggleTracking() {
    if (!settings) return;
    const bool running = settings->serviceState()
                             .value(QStringLiteral("trackingRunning"))
                             .toBool();
    const bool ok = running ? settings->stopBackgroundCollection()
                            : settings->startTrackingNow();
    if (!ok) {
      qWarning() << "TimeArc: could not"
                 << (running ? "stop" : "start") << "background tracking";
    }
  }

  // 自启开关：写的是 launchd 注册，不是本地设置。失败就把勾回退到真值，免得菜单
  // 显示一个并没有发生的状态。
  void toggleAutostart(bool enabled) {
    if (!settings) {
      autostartAction->setChecked(false);
      return;
    }
    if (!settings->setAutostartEnabled(enabled)) {
      qWarning() << "TimeArc: could not"
                 << (enabled ? "enable" : "disable") << "launch at login";
    }
    autostartAction->setChecked(settings->autostartEnabled());
  }

  void syncPomodoro(const MenuStrings& s) {
    // 读数只在菜单打开的那一刻取一次：菜单一经点击即关闭（AppKit 先撤下菜单再派发
    // 动作），停留期间没人盯着秒数走，故不需要边开边刷。引擎按墙钟锚点算，睡眠醒来
    // 后这一次取值照样是准的。
    const QString timeText =
        pomodoro ? pomodoro->timeText() : QStringLiteral("00:00");
    pomodoroAction->setText(QString::fromUtf8(s.pomodoro) + QLatin1Char(' ') +
                            timeText);
    pomodoroAction->setEnabled(pomodoro != nullptr);

    const bool running = pomodoro && pomodoro->running();
    if (running) {
      pomodoroPrimaryAction->setText(QString::fromUtf8(s.pauseTimer));
    } else if (pomodoroPaused()) {
      pomodoroPrimaryAction->setText(QString::fromUtf8(s.resumeTimer));
    } else {
      pomodoroPrimaryAction->setText(QString::fromUtf8(s.startTimer));
    }
    // 0 分 0 秒时 startTimer() 会拒绝开始，那一行便不该是可点的。
    pomodoroPrimaryAction->setEnabled(pomodoro &&
                                      (running || pomodoro->total() > 0));

    pomodoroResetAction->setText(QString::fromUtf8(s.resetTimer));
    pomodoroResetAction->setEnabled(pomodoro != nullptr);
  }

  QMenu menu;
  QSystemTrayIcon icon;
  QAction* showAction = nullptr;
  QAction* pomodoroAction = nullptr;
  QAction* pomodoroPrimaryAction = nullptr;
  QAction* pomodoroResetAction = nullptr;
  QAction* trackingAction = nullptr;
  QAction* autostartAction = nullptr;
  QAction* quitAction = nullptr;
  SettingsRepository* settings = nullptr;
  PomodoroManager* pomodoro = nullptr;
};

MacStatusBarIcon::MacStatusBarIcon() : impl_(std::make_unique<Impl>()) {}

MacStatusBarIcon::~MacStatusBarIcon() = default;

QObject* MacStatusBarIcon::qmlObject() const { return &impl_->icon; }

void MacStatusBarIcon::attach(SettingsRepository* settings,
                              PomodoroManager* pomodoro) {
  impl_->settings = settings;
  impl_->pomodoro = pomodoro;
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
  // 读数行：浮窗长在窗口里，光把它标为可见没用，得先把窗口叫回来。
  QObject::connect(impl_->pomodoroAction, &QAction::triggered, &impl_->icon,
                   [invokeRoot]() { invokeRoot("showPomodoroFromTray"); });
  // 三态一行：开始 / 继续 / 暂停。startTimer() 只在 remain 归零时重填，因此暂停态
  // 调它就是原地继续。菜单开着的这几秒里状态若变了（比如刚好走完），这些调用都是
  // 安全的空操作——引擎各自在入口处挡掉了不合时宜的那一次。
  QObject::connect(impl_->pomodoroPrimaryAction, &QAction::triggered,
                   &impl_->icon, [impl]() {
                     if (!impl->pomodoro) return;
                     if (impl->pomodoro->running()) {
                       impl->pomodoro->pauseTimer();
                     } else {
                       impl->pomodoro->startTimer();
                     }
                   });
  QObject::connect(impl_->pomodoroResetAction, &QAction::triggered,
                   &impl_->icon, [impl]() {
                     if (impl->pomodoro) impl->pomodoro->resetTimer();
                   });

  // Deliberately no QSystemTrayIcon::activated handler. macOS status items
  // open their menu on click; restoring the window is 打开 TimeArc in that
  // menu, not a side effect of the click itself. The Qt.labs tray used on
  // Windows/Linux keeps its click-to-restore behavior.
}
