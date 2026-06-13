#include "app_icon_image_provider.h"

#include <QFileIconProvider>
#include <QFileInfo>
#include <QIcon>
#include <QImage>
#include <QPainter>
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
      pixmap = normalizePixmap(icon.pixmap(side, side), side);
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

QPixmap AppIconImageProvider::normalizePixmap(const QPixmap& source,
                                              int side) const {
  if (source.isNull()) return source;

  const QImage image = source.toImage().convertToFormat(QImage::Format_ARGB32);
  int left = image.width();
  int top = image.height();
  int right = -1;
  int bottom = -1;

  for (int y = 0; y < image.height(); ++y) {
    for (int x = 0; x < image.width(); ++x) {
      if (qAlpha(image.pixel(x, y)) <= 8) continue;
      left = qMin(left, x);
      top = qMin(top, y);
      right = qMax(right, x);
      bottom = qMax(bottom, y);
    }
  }

  if (right < left || bottom < top) return transparentPixmap(side);

  const QRect bounds(left, top, right - left + 1, bottom - top + 1);
  const QImage cropped = image.copy(bounds);
  const int targetSide = qMax(1, side - 4);
  const QImage scaled =
      cropped.scaled(targetSide, targetSide, Qt::KeepAspectRatio,
                     Qt::SmoothTransformation);

  QImage normalized(side, side, QImage::Format_ARGB32);
  normalized.fill(Qt::transparent);
  QPainter painter(&normalized);
  painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
  painter.drawImage((side - scaled.width()) / 2, (side - scaled.height()) / 2,
                    scaled);
  painter.end();
  return QPixmap::fromImage(normalized);
}

QPixmap AppIconImageProvider::transparentPixmap(int side) const {
  QPixmap pixmap(side, side);
  pixmap.fill(Qt::transparent);
  return pixmap;
}
