#ifndef APPICONIMAGEPROVIDER_H
#define APPICONIMAGEPROVIDER_H

#include <QPixmap>
#include <QQuickImageProvider>

// QML 的 image://appicon/... 图片提供器。
//
// UI 传入可执行文件路径，本类用系统图标提供器取出原生 app 图标。
// 网站类活动（例如 B 站）会直接走资源 SVG，不经过这里。
class AppIconImageProvider final : public QQuickImageProvider {
 public:
  AppIconImageProvider();

  QPixmap requestPixmap(const QString& id, QSize* size,
                        const QSize& requestedSize) override;

 private:
  QPixmap transparentPixmap(int side) const;
};

#endif
