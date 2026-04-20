#ifndef APPICONIMAGEPROVIDER_H
#define APPICONIMAGEPROVIDER_H

#include <QPixmap>
#include <QQuickImageProvider>

class AppIconImageProvider final : public QQuickImageProvider {
 public:
  AppIconImageProvider();

  QPixmap requestPixmap(const QString& id, QSize* size,
                        const QSize& requestedSize) override;

 private:
  QPixmap transparentPixmap(int side) const;
};

#endif
