#include "app_icon_image_provider.h"

#include <QFileIconProvider>
#include <QFileInfo>
#include <QIcon>
#include <QSize>
#include <QUrl>
#include <QtGlobal>

AppIconImageProvider::AppIconImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

QPixmap AppIconImageProvider::requestPixmap(const QString& id, QSize* size,
                                            const QSize& requestedSize) {
  // QML 传入的 id 是 percent-encoded 路径。这里解码后交给 QFileIconProvider，
  // 由系统决定 exe/快捷方式/文件的最佳图标。
  const int requestedSide =
      qMax(requestedSize.width(), requestedSize.height());
  const int side = qBound(16, requestedSide > 0 ? requestedSide : 64, 256);
  const QString path = QUrl::fromPercentEncoding(id.toUtf8()).trimmed();

  QPixmap pixmap;
  if (!path.isEmpty()) {
    const QFileInfo fileInfo(path);
    if (fileInfo.exists()) {
      QFileIconProvider iconProvider;
      const QIcon icon = iconProvider.icon(fileInfo);
      pixmap = icon.pixmap(side, side);
    }
  }

  // 返回透明图而不是 null pixmap，可以让 QML 布局尺寸保持稳定。
  if (pixmap.isNull()) pixmap = transparentPixmap(side);

  if (requestedSize.isValid() && !requestedSize.isEmpty()) {
    pixmap = pixmap.scaled(requestedSize, Qt::KeepAspectRatio,
                           Qt::SmoothTransformation);
  }

  if (size) *size = pixmap.size();
  return pixmap;
}

QPixmap AppIconImageProvider::transparentPixmap(int side) const {
  QPixmap pixmap(side, side);
  pixmap.fill(Qt::transparent);
  return pixmap;
}
