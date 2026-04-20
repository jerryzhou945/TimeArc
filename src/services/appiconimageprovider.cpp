#include "appiconimageprovider.h"

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
