#include "app_icon_image_provider.h"

#include <QFileIconProvider>
#include <QFileInfo>
#include <QFont>
#include <QIcon>
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
      pixmap = icon.pixmap(side, side);
    }
  }

  if (pixmap.isNull()) pixmap = fallbackPixmap(path, side);

  if (requestedSize.isValid() && !requestedSize.isEmpty()) {
    pixmap = pixmap.scaled(requestedSize, Qt::KeepAspectRatio,
                           Qt::SmoothTransformation);
  }

  if (size) *size = pixmap.size();
  return pixmap;
}

QPixmap AppIconImageProvider::fallbackPixmap(const QString& identity,
                                             int side) const {
  const QString base = QFileInfo(identity).completeBaseName().trimmed();
  const QString labelSource = base.isEmpty() ? identity.trimmed() : base;
  const QString label =
      labelSource.isEmpty() ? QStringLiteral("?") : labelSource.left(1).toUpper();

  uint hash = 2166136261u;
  const QString key = labelSource.toLower();
  for (const QChar ch : key) {
    hash ^= static_cast<uint>(ch.unicode());
    hash *= 16777619u;
  }

  const QColor palette[] = {QColor("#CFE8D8"), QColor("#D9D0F2"),
                            QColor("#EFDCC3"), QColor("#EBC9CF"),
                            QColor("#BFD7EA"), QColor("#DDF1E5")};
  const QColor bg = palette[hash % (sizeof(palette) / sizeof(palette[0]))];

  QPixmap pixmap(side, side);
  pixmap.fill(Qt::transparent);

  QPainter painter(&pixmap);
  painter.setRenderHint(QPainter::Antialiasing, true);
  painter.setPen(Qt::NoPen);
  painter.setBrush(bg);
  painter.drawRoundedRect(QRectF(0, 0, side, side), side * 0.22, side * 0.22);

  QFont font = painter.font();
  font.setBold(true);
  font.setPixelSize(qMax(10, static_cast<int>(side * 0.46)));
  painter.setFont(font);
  painter.setPen(QColor("#2D2724"));
  painter.drawText(QRect(0, 0, side, side), Qt::AlignCenter, label);
  return pixmap;
}
