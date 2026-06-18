#include "app_icon_image_provider.h"

#include <QDir>
#include <QFileIconProvider>
#include <QFileInfo>
#include <QFont>
#include <QIcon>
#include <QPainter>
#include <QRegularExpression>
#include <QSettings>
#include <QSize>
#include <QStandardPaths>
#include <QUrl>
#include <QtGlobal>

namespace {

QString existingPathOrEmpty(const QString& path) {
  const QFileInfo info(path);
  if (!info.exists()) return QString();
  return info.absoluteFilePath();
}

QString appPathRegistryValue(const QString& exeName) {
#if defined(Q_OS_WIN)
  // Windows App Paths lets us recover native icons when QML only has an app id.
  const QStringList keys = {
      QStringLiteral("HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows"
                     "\\CurrentVersion\\App Paths\\") +
          exeName,
      QStringLiteral("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows"
                     "\\CurrentVersion\\App Paths\\") +
          exeName,
      QStringLiteral("HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Microsoft"
                     "\\Windows\\CurrentVersion\\App Paths\\") +
          exeName};
  for (const QString& key : keys) {
    QSettings settings(key, QSettings::NativeFormat);
    QString value = settings.value(QStringLiteral(".")).toString().trimmed();
    if (value.isEmpty())
      value = settings.value(QStringLiteral("Default")).toString().trimmed();
    const QString found = existingPathOrEmpty(value);
    if (!found.isEmpty()) return found;
  }
#else
  Q_UNUSED(exeName);
#endif
  return QString();
}

QStringList knownExecutableCandidates(const QString& rawIdentity) {
  QString id = rawIdentity.trimmed().toLower();
  if (id.startsWith(QStringLiteral("app:"))) id = id.mid(4);
  id.replace(QRegularExpression(QStringLiteral("[^a-z0-9._-]+")),
             QStringLiteral("-"));

  if (id == QStringLiteral("vscode")) return {QStringLiteral("Code.exe")};
  if (id == QStringLiteral("google-chrome")) return {QStringLiteral("chrome.exe")};
  if (id == QStringLiteral("microsoft-edge")) return {QStringLiteral("msedge.exe")};
  if (id == QStringLiteral("wechat")) return {QStringLiteral("WeChat.exe")};
  if (id == QStringLiteral("jianying-pro") || id == QStringLiteral("capcut"))
    return {QStringLiteral("JianyingPro.exe"), QStringLiteral("CapCut.exe")};
  if (id == QStringLiteral("wallpaper-engine"))
    return {QStringLiteral("wallpaper64.exe"), QStringLiteral("wallpaper32.exe"),
            QStringLiteral("wallpaperui.exe")};
  if (id == QStringLiteral("steam")) return {QStringLiteral("steam.exe")};
  if (id == QStringLiteral("discord")) return {QStringLiteral("Discord.exe")};
  if (id == QStringLiteral("netease-cloud-music"))
    return {QStringLiteral("cloudmusic.exe")};
  if (id == QStringLiteral("file-explorer"))
    return {QStringLiteral("explorer.exe")};
  if (id == QStringLiteral("terminal"))
    return {QStringLiteral("WindowsTerminal.exe"), QStringLiteral("wt.exe")};

  if (id.endsWith(QStringLiteral(".exe"))) return {id};
  return {id + QStringLiteral(".exe")};
}

QString resolveIconFile(const QString& identity) {
  const QString raw = QUrl::fromPercentEncoding(identity.toUtf8()).trimmed();
  const QString direct = existingPathOrEmpty(raw);
  if (!direct.isEmpty()) return direct;

#if defined(Q_OS_WIN)
  for (const QString& exe : knownExecutableCandidates(raw)) {
    const QString fromRegistry = appPathRegistryValue(exe);
    if (!fromRegistry.isEmpty()) return fromRegistry;

    const QString fromPath = QStandardPaths::findExecutable(exe);
    if (!fromPath.isEmpty()) return fromPath;

    if (exe.compare(QStringLiteral("explorer.exe"), Qt::CaseInsensitive) == 0) {
      const QString explorer =
          QDir::fromNativeSeparators(qEnvironmentVariable("WINDIR")) +
          QStringLiteral("/explorer.exe");
      const QString found = existingPathOrEmpty(explorer);
      if (!found.isEmpty()) return found;
    }
  }
#endif

  return raw;
}

}  // namespace

AppIconImageProvider::AppIconImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

QPixmap AppIconImageProvider::requestPixmap(const QString& id, QSize* size,
                                            const QSize& requestedSize) {
  // QML 传入的 id 是 percent-encoded 路径。这里解码后交给 QFileIconProvider，
  // 由系统决定 exe/快捷方式/文件的最佳图标。
  const int requestedSide =
      qMax(requestedSize.width(), requestedSize.height());
  const int side = qBound(16, requestedSide > 0 ? requestedSide : 64, 256);
  const QString path = resolveIconFile(id);

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
