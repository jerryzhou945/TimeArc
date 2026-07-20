// SPDX-License-Identifier: GPL-3.0-or-later

#include "services/mobile/mobile_ui_service.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QUuid>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QtCore/qcoreapplication_platform.h>
#endif

#include "services/settings_repository.h"

namespace {

const QString kWallpaperSetting = QStringLiteral("mobile_wallpaper_path");

QString mobileDataDirectory() {
  const QString root =
      QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
  return QDir(root).filePath(QStringLiteral("mobile"));
}

QString wallpaperDirectory() {
  return QDir(mobileDataDirectory()).filePath(QStringLiteral("wallpaper"));
}

QString shareDirectory() {
  return QDir(mobileDataDirectory()).filePath(QStringLiteral("share"));
}

void removeStaleWallpaperFiles(const QString& activePath) {
  QDir directory(wallpaperDirectory());
  if (!directory.exists()) return;
  const QString active = activePath.isEmpty()
                             ? QString()
                             : QFileInfo(activePath).absoluteFilePath();
  const QFileInfoList files = directory.entryInfoList(
      {QStringLiteral("wallpaper-*")}, QDir::Files);
  for (const QFileInfo& file : files) {
    if (!active.isEmpty() && file.absoluteFilePath() == active) continue;
    QFile::remove(file.absoluteFilePath());
  }
}

void removeWallpaperFileLater(const QString& path) {
  if (path.isEmpty()) return;
  QTimer::singleShot(1500, [path]() {
    if (!QFileInfo::exists(path) || QFile::remove(path)) return;
    QTimer::singleShot(4000, [path]() {
      if (QFileInfo::exists(path) && !QFile::remove(path)) {
        qWarning() << "Wallpaper cleanup deferred until next launch:" << path;
      }
    });
  });
}

#ifdef Q_OS_ANDROID
bool androidCopyUri(const QUrl& source, const QString& targetPath) {
  const QJniObject context =
      QNativeInterface::QAndroidApplication::context();
  if (!context.isValid()) return false;
  const QJniObject uri = QJniObject::fromString(source.toString());
  const QJniObject path = QJniObject::fromString(targetPath);
  return QJniObject::callStaticMethod<jboolean>(
      "com/timearc/mobile/ui/MobileUiBridge", "copyUriToFile",
      "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)Z",
      context.object<jobject>(), uri.object<jstring>(),
      path.object<jstring>());
}

bool androidShareImage(const QString& pathValue,
                       const QString& chooserTitle) {
  const QJniObject context =
      QNativeInterface::QAndroidApplication::context();
  if (!context.isValid()) return false;
  const QJniObject path = QJniObject::fromString(pathValue);
  const QJniObject title = QJniObject::fromString(chooserTitle);
  return QJniObject::callStaticMethod<jboolean>(
      "com/timearc/mobile/ui/MobileUiBridge", "shareImage",
      "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)Z",
      context.object<jobject>(), path.object<jstring>(),
      title.object<jstring>());
}
#endif

}  // namespace

MobileUiService::MobileUiService(SettingsRepository* settingsRepository,
                                 QObject* parent)
    : QObject(parent), settingsRepository_(settingsRepository) {
  if (!settingsRepository_) return;
  const QString saved =
      settingsRepository_->getValue(kWallpaperSetting).trimmed();
  if (!saved.isEmpty() && QFileInfo::exists(saved)) wallpaperPath_ = saved;
  removeStaleWallpaperFiles(wallpaperPath_);
}

QString MobileUiService::wallpaperUrl() const {
  return wallpaperPath_.isEmpty()
             ? QString()
             : QUrl::fromLocalFile(wallpaperPath_).toString();
}

QString MobileUiService::lastError() const { return lastError_; }

QString MobileUiService::lastSavedImagePath() const {
  return lastSavedImagePath_;
}

bool MobileUiService::importWallpaper(const QUrl& source) {
  setLastError(QString());
  if (!source.isValid() || source.isEmpty()) {
    setLastError(QStringLiteral("没有选择可用的图片。"));
    return false;
  }
  if (!QDir().mkpath(wallpaperDirectory())) {
    setLastError(QStringLiteral("无法创建壁纸存储目录。"));
    return false;
  }

  QString suffix = QFileInfo(source.path()).suffix().toLower();
  const QStringList allowed = {QStringLiteral("png"), QStringLiteral("jpg"),
                               QStringLiteral("jpeg"), QStringLiteral("webp")};
  if (!allowed.contains(suffix)) suffix = QStringLiteral("img");
  const QString temporary =
      QDir(wallpaperDirectory()).filePath(QStringLiteral("import.tmp"));
  const QString wallpaperId =
      QUuid::createUuid().toString(QUuid::WithoutBraces);
  const QString finalPath =
      QDir(wallpaperDirectory())
          .filePath(QStringLiteral("wallpaper-%1.%2")
                        .arg(wallpaperId, suffix));
  QFile::remove(temporary);

  if (!copySourceToFile(source, temporary) ||
      QFileInfo(temporary).size() <= 0) {
    QFile::remove(temporary);
    setLastError(QStringLiteral("这张图片无法读取，请重新选择本地图片。"));
    return false;
  }

  if (!QFile::rename(temporary, finalPath)) {
    QFile::remove(temporary);
    setLastError(QStringLiteral("壁纸保存失败，请检查设备存储空间。"));
    return false;
  }

  if (settingsRepository_ &&
      !settingsRepository_->setValue(kWallpaperSetting, finalPath)) {
    QFile::remove(finalPath);
    setLastError(QStringLiteral("壁纸设置未能保存。"));
    return false;
  }

  const QString previous = wallpaperPath_;
  wallpaperPath_ = finalPath;
  emit wallpaperChanged();
  if (previous != finalPath) removeWallpaperFileLater(previous);
  return true;
}

bool MobileUiService::clearWallpaper() {
  setLastError(QString());
  if (settingsRepository_ &&
      !settingsRepository_->setValue(kWallpaperSetting, QStringLiteral(""))) {
    setLastError(QStringLiteral("恢复默认背景失败，请稍后重试。"));
    return false;
  }
  const QString previous = wallpaperPath_;
  wallpaperPath_.clear();
  emit wallpaperChanged();
  removeWallpaperFileLater(previous);
  return true;
}

QString MobileUiService::createShareImagePath(const QString& stem) const {
  if (!QDir().mkpath(shareDirectory())) return QString();
  const QString timestamp =
      QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss"));
  return QDir(shareDirectory())
      .filePath(QStringLiteral("timearc-%1-%2.png")
                    .arg(sanitizedStem(stem), timestamp));
}

bool MobileUiService::shareImage(const QUrl& source,
                                 const QString& chooserTitle) {
  setLastError(QString());
  const QString path = localPathFor(source);
  if (path.isEmpty() || !QFileInfo::exists(path)) {
    setLastError(QStringLiteral("分享图片尚未生成，请重新保存。"));
    return false;
  }
  setLastSavedImagePath(path);
#ifdef Q_OS_ANDROID
  if (!androidShareImage(path, chooserTitle)) {
    setLastError(QStringLiteral("没有找到可接收图片的分享应用。"));
    return false;
  }
#else
  Q_UNUSED(chooserTitle);
#endif
  return true;
}

QString MobileUiService::sanitizedStem(const QString& value) {
  QString result = value.trimmed();
  result.replace(QRegularExpression(QStringLiteral(R"([^\p{L}\p{N}]+)")),
                 QStringLiteral("-"));
  result = result.left(36);
  while (result.startsWith(QLatin1Char('-'))) result.remove(0, 1);
  while (result.endsWith(QLatin1Char('-'))) result.chop(1);
  return result.isEmpty() ? QStringLiteral("memory") : result;
}

QString MobileUiService::localPathFor(const QUrl& source) {
  if (source.isLocalFile()) return source.toLocalFile();
  if (source.scheme().isEmpty()) return source.toString();
  return QString();
}

bool MobileUiService::copySourceToFile(const QUrl& source,
                                       const QString& targetPath) {
#ifdef Q_OS_ANDROID
  if (source.scheme().compare(QStringLiteral("content"),
                              Qt::CaseInsensitive) == 0) {
    return androidCopyUri(source, targetPath);
  }
#endif
  const QString path = localPathFor(source);
  return !path.isEmpty() && QFile::copy(path, targetPath);
}

void MobileUiService::setLastError(const QString& value) {
  if (lastError_ == value) return;
  lastError_ = value;
  emit lastErrorChanged();
}

void MobileUiService::setLastSavedImagePath(const QString& value) {
  if (lastSavedImagePath_ == value) return;
  lastSavedImagePath_ = value;
  emit lastSavedImagePathChanged();
}
