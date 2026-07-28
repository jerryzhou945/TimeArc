// SPDX-License-Identifier: GPL-3.0-or-later

#include "macos_status_bar_icon.h"

#include <QAction>
#include <QIcon>
#include <QMenu>
#include <QMetaObject>
#include <QPainter>
#include <QPixmap>
#include <QPointer>
#include <QSvgRenderer>
#include <QSystemTrayIcon>
#include <array>
#include <utility>

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

}  // namespace

class MacStatusBarIcon::Impl {
 public:
  Impl() : icon(makeInputSourceTIcon()) {
    showAction = menu.addAction(QStringLiteral("打开 TimeArc"));
    QAction* collectorAction =
        menu.addAction(QStringLiteral("后台采集继续运行"));
    collectorAction->setEnabled(false);
    menu.addSeparator();
    quitAction = menu.addAction(QStringLiteral("退出 TimeArc"));

    icon.setToolTip(QStringLiteral("TimeArc"));
    icon.setContextMenu(&menu);
  }

  QMenu menu;
  QSystemTrayIcon icon;
  QAction* showAction = nullptr;
  QAction* quitAction = nullptr;
};

MacStatusBarIcon::MacStatusBarIcon() : impl_(std::make_unique<Impl>()) {}

MacStatusBarIcon::~MacStatusBarIcon() = default;

QObject* MacStatusBarIcon::qmlObject() const { return &impl_->icon; }

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
  QObject::connect(&impl_->icon, &QSystemTrayIcon::activated, &impl_->icon,
                   [invokeRoot](QSystemTrayIcon::ActivationReason reason) {
                     if (reason == QSystemTrayIcon::Trigger ||
                         reason == QSystemTrayIcon::DoubleClick) {
                       invokeRoot("restoreFromTray");
                     }
                   });
}
