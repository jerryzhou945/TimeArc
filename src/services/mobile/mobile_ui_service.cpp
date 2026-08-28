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
const QString kAvatarSetting =
    QStringLiteral("mobile_profile_avatar_path");
const QString kWechatAppIdSetting =
    QStringLiteral("mobile_share_wechat_app_id");
const QString kQqAppIdSetting = QStringLiteral("mobile_share_qq_app_id");

QString mobileDataDirectory() {
  const QString root =
      QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
  return QDir(root).filePath(QStringLiteral("mobile"));
}

QString wallpaperDirectory() {
  return QDir(mobileDataDirectory()).filePath(QStringLiteral("wallpaper"));
}

QString profileDirectory() {
  return QDir(mobileDataDirectory()).filePath(QStringLiteral("profile"));
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

void removeStaleAvatarFiles(const QString& activePath) {
  QDir directory(profileDirectory());
  if (!directory.exists()) return;
  const QString active = activePath.isEmpty()
                             ? QString()
                             : QFileInfo(activePath).absoluteFilePath();
  const QFileInfoList files = directory.entryInfoList(
      {QStringLiteral("avatar-*")}, QDir::Files);
  for (const QFileInfo& file : files) {
    if (!active.isEmpty() && file.absoluteFilePath() == active) continue;
    QFile::remove(file.absoluteFilePath());
  }
}

void removeAvatarFileLater(const QString& path) {
  if (path.isEmpty()) return;
  QTimer::singleShot(1500, [path]() {
    if (!QFileInfo::exists(path) || QFile::remove(path)) return;
    QTimer::singleShot(4000, [path]() {
      if (QFileInfo::exists(path) && !QFile::remove(path)) {
        qWarning() << "Avatar cleanup deferred until next launch:" << path;
      }
    });
  });
}

#ifdef Q_OS_ANDROID
void androidConfigureEdgeToEdge(bool light) {
  const QJniObject context =
      QNativeInterface::QAndroidApplication::context();
  if (!context.isValid()) return;
  QJniObject::callStaticMethod<void>(
      "com/timearc/mobile/ui/MobileUiBridge", "configureEdgeToEdge",
      "(Landroid/content/Context;Z)V", context.object<jobject>(),
      static_cast<jboolean>(light));
}

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

QString androidSaveImageToGallery(const QString& pathValue,
                                  const QString& albumName) {
  const QJniObject context =
      QNativeInterface::QAndroidApplication::context();
  if (!context.isValid()) return QString();
  const QJniObject path = QJniObject::fromString(pathValue);
  const QJniObject album = QJniObject::fromString(
      albumName.trimmed().isEmpty() ? QStringLiteral("TimeArc") : albumName);
  const QJniObject result = QJniObject::callStaticObjectMethod(
      "com/timearc/mobile/ui/MobileUiBridge", "saveImageToGallery",
      "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)"
      "Ljava/lang/String;",
      context.object<jobject>(), path.object<jstring>(),
      album.object<jstring>());
  return result.isValid() ? result.toString() : QString();
}

QString androidSocialShareStatus(const QString& channel,
                                 const QString& appId) {
  const QJniObject context =
      QNativeInterface::QAndroidApplication::context();
  if (!context.isValid()) return QStringLiteral("launch_failed");
  const QJniObject javaChannel = QJniObject::fromString(channel);
  const QJniObject javaAppId = QJniObject::fromString(appId);
  const QJniObject result = QJniObject::callStaticObjectMethod(
      "com/timearc/mobile/ui/MobileUiBridge", "socialShareStatus",
      "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)"
      "Ljava/lang/String;",
      context.object<jobject>(), javaChannel.object<jstring>(),
      javaAppId.object<jstring>());
  return result.isValid() ? result.toString()
                          : QStringLiteral("launch_failed");
}

QString androidShareImageToChannel(const QString& pathValue,
                                   const QString& channel,
                                   const QString& chooserTitle,
                                   const QString& appId) {
  const QJniObject context =
      QNativeInterface::QAndroidApplication::context();
  if (!context.isValid()) return QStringLiteral("launch_failed");
  const QJniObject path = QJniObject::fromString(pathValue);
  const QJniObject javaChannel = QJniObject::fromString(channel);
  const QJniObject title = QJniObject::fromString(chooserTitle);
  const QJniObject javaAppId = QJniObject::fromString(appId);
  const QJniObject result = QJniObject::callStaticObjectMethod(
      "com/timearc/mobile/ui/MobileUiBridge", "shareImageToChannel",
      "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;"
      "Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
      context.object<jobject>(), path.object<jstring>(),
      javaChannel.object<jstring>(), title.object<jstring>(),
      javaAppId.object<jstring>());
  return result.isValid() ? result.toString()
                          : QStringLiteral("launch_failed");
}
#endif

}  // namespace

MobileUiService::MobileUiService(SettingsRepository* settingsRepository,
                                 QObject* parent)
    : QObject(parent), settingsRepository_(settingsRepository) {
#ifdef Q_OS_ANDROID
  androidConfigureEdgeToEdge(false);
#endif
  if (!settingsRepository_) return;
  const QString saved =
      settingsRepository_->getValue(kWallpaperSetting).trimmed();
  if (!saved.isEmpty() && QFileInfo::exists(saved)) wallpaperPath_ = saved;
  removeStaleWallpaperFiles(wallpaperPath_);
  const QString savedAvatar =
      settingsRepository_->getValue(kAvatarSetting).trimmed();
  if (!savedAvatar.isEmpty() && QFileInfo::exists(savedAvatar)) {
    avatarPath_ = savedAvatar;
  }
  removeStaleAvatarFiles(avatarPath_);
}

void MobileUiService::setSystemBarsLight(bool light) {
#ifdef Q_OS_ANDROID
  androidConfigureEdgeToEdge(light);
#else
  Q_UNUSED(light);
#endif
}

QString MobileUiService::wallpaperUrl() const {
  return wallpaperPath_.isEmpty()
             ? QString()
             : QUrl::fromLocalFile(wallpaperPath_).toString();
}

QString MobileUiService::avatarUrl() const {
  return avatarPath_.isEmpty()
             ? QString()
             : QUrl::fromLocalFile(avatarPath_).toString();
}

QString MobileUiService::lastError() const { return lastError_; }

QString MobileUiService::lastSavedImagePath() const {
  return lastSavedImagePath_;
}

QString MobileUiService::wechatAppId() const {
  return settingsRepository_
             ? settingsRepository_->getValue(kWechatAppIdSetting).trimmed()
             : QString();
}

QString MobileUiService::qqAppId() const {
  return settingsRepository_
             ? settingsRepository_->getValue(kQqAppIdSetting).trimmed()
             : QString();
}

bool MobileUiService::importWallpaper(const QUrl& source) {
  setLastError(QString());
  if (!source.isValid() || source.isEmpty()) {
    setLastError(QStringLiteral("No usable image was selected."));
    return false;
  }
  if (!QDir().mkpath(wallpaperDirectory())) {
    setLastError(QStringLiteral("Could not create the wallpaper folder."));
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
    setLastError(QStringLiteral("This image could not be read. Please pick another local image."));
    return false;
  }

  if (!QFile::rename(temporary, finalPath)) {
    QFile::remove(temporary);
    setLastError(QStringLiteral("Could not save the wallpaper. Check your device storage."));
    return false;
  }

  if (settingsRepository_ &&
      !settingsRepository_->setValue(kWallpaperSetting, finalPath)) {
    QFile::remove(finalPath);
    setLastError(QStringLiteral("The wallpaper setting could not be saved."));
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
    setLastError(QStringLiteral("Could not restore the default background. Try again later."));
    return false;
  }
  const QString previous = wallpaperPath_;
  wallpaperPath_.clear();
  emit wallpaperChanged();
  removeWallpaperFileLater(previous);
  return true;
}

bool MobileUiService::importAvatar(const QUrl& source) {
  setLastError(QString());
  if (!source.isValid() || source.isEmpty()) {
    setLastError(QStringLiteral("No usable profile picture was selected."));
    return false;
  }
  if (!QDir().mkpath(profileDirectory())) {
    setLastError(QStringLiteral("Could not create the profile picture folder."));
    return false;
  }

  QString suffix = QFileInfo(source.path()).suffix().toLower();
  const QStringList allowed = {QStringLiteral("png"), QStringLiteral("jpg"),
                               QStringLiteral("jpeg"),
                               QStringLiteral("webp")};
  if (!allowed.contains(suffix)) suffix = QStringLiteral("img");
  const QString temporary =
      QDir(profileDirectory()).filePath(QStringLiteral("avatar-import.tmp"));
  const QString avatarId =
      QUuid::createUuid().toString(QUuid::WithoutBraces);
  const QString finalPath =
      QDir(profileDirectory())
          .filePath(QStringLiteral("avatar-%1.%2").arg(avatarId, suffix));
  QFile::remove(temporary);

  if (!copySourceToFile(source, temporary) ||
      QFileInfo(temporary).size() <= 0) {
    QFile::remove(temporary);
    setLastError(QStringLiteral("This picture could not be read. Please pick another local image."));
    return false;
  }
  if (!QFile::rename(temporary, finalPath)) {
    QFile::remove(temporary);
    setLastError(QStringLiteral("Could not save the profile picture. Check your device storage."));
    return false;
  }
  if (settingsRepository_ &&
      !settingsRepository_->setValue(kAvatarSetting, finalPath)) {
    QFile::remove(finalPath);
    setLastError(QStringLiteral("The profile picture setting could not be saved."));
    return false;
  }

  const QString previous = avatarPath_;
  avatarPath_ = finalPath;
  emit avatarChanged();
  if (previous != finalPath) removeAvatarFileLater(previous);
  return true;
}

bool MobileUiService::clearAvatar() {
  setLastError(QString());
  if (settingsRepository_ &&
      !settingsRepository_->setValue(kAvatarSetting, QStringLiteral(""))) {
    setLastError(QStringLiteral("Could not remove the profile picture. Try again later."));
    return false;
  }
  const QString previous = avatarPath_;
  avatarPath_.clear();
  emit avatarChanged();
  removeAvatarFileLater(previous);
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

bool MobileUiService::saveImageToGallery(const QUrl& source,
                                         const QString& albumName) {
  setLastError(QString());
  const QString path = localPathFor(source);
  if (path.isEmpty() || !QFileInfo::exists(path)) {
    setLastError(QStringLiteral("The share image is not ready yet. Save it again."));
    return false;
  }
#ifdef Q_OS_ANDROID
  const QString savedUri = androidSaveImageToGallery(path, albumName);
  if (savedUri.isEmpty()) {
    setLastError(QStringLiteral("Could not save to the system gallery. Check your storage."));
    return false;
  }
  setLastSavedImagePath(savedUri);
#else
  Q_UNUSED(albumName);
  setLastSavedImagePath(path);
#endif
  return true;
}

bool MobileUiService::shareImage(const QUrl& source,
                                 const QString& chooserTitle) {
  setLastError(QString());
  const QString path = localPathFor(source);
  if (path.isEmpty() || !QFileInfo::exists(path)) {
    setLastError(QStringLiteral("The share image is not ready yet. Save it again."));
    return false;
  }
  setLastSavedImagePath(path);
#ifdef Q_OS_ANDROID
  if (!androidShareImage(path, chooserTitle)) {
    setLastError(QStringLiteral("No app was found that can receive the image."));
    return false;
  }
#else
  Q_UNUSED(chooserTitle);
#endif
  return true;
}

bool MobileUiService::shareImageToChannel(const QUrl& source,
                                          const QString& channel,
                                          const QString& chooserTitle) {
  static const QStringList channels = {
      QStringLiteral("gallery"), QStringLiteral("moments"),
      QStringLiteral("qzone"), QStringLiteral("system")};
  const QString key = channel.trimmed().toLower();
  if (!channels.contains(key)) {
    setLastError(QStringLiteral("This share target is not supported."));
    return false;
  }
  const QString path = localPathFor(source);
  if (!saveImageToGallery(source, QStringLiteral("TimeArc"))) return false;
  if (key == QStringLiteral("gallery")) return true;

#ifdef Q_OS_ANDROID
  const QString result = androidShareImageToChannel(
      path, key, chooserTitle, socialAppId(key));
  if (result == QStringLiteral("launched")) return true;
  if (result == QStringLiteral("waiting_authorization")) {
    setLastError(QStringLiteral("Saved to gallery · waiting for platform approval"));
  } else if (result == QStringLiteral("client_missing")) {
    setLastError(QStringLiteral("Saved to gallery · target app not installed"));
  } else if (result == QStringLiteral("sdk_missing")) {
    setLastError(QStringLiteral("Saved to gallery · sharing component not enabled"));
  } else {
    setLastError(QStringLiteral("Saved to gallery · could not open the share target"));
  }
  return false;
#else
  Q_UNUSED(path);
  Q_UNUSED(chooserTitle);
  setLastError(QStringLiteral("Saved locally · this platform does not support that share target"));
  return false;
#endif
}

QVariantMap MobileUiService::socialShareStatus(
    const QString& channel) const {
  const QString key = channel.trimmed().toLower();
  QString code;
  if (key == QStringLiteral("gallery") || key == QStringLiteral("system")) {
    code = QStringLiteral("ready");
  } else if (key == QStringLiteral("moments") ||
             key == QStringLiteral("qzone")) {
#ifdef Q_OS_ANDROID
    code = androidSocialShareStatus(key, socialAppId(key));
#else
    code = socialAppId(key).isEmpty()
               ? QStringLiteral("waiting_authorization")
               : QStringLiteral("sdk_missing");
#endif
  } else {
    code = QStringLiteral("launch_failed");
  }
  QString label = QStringLiteral("Unavailable");
  if (code == QStringLiteral("ready")) label = QStringLiteral("Ready");
  if (code == QStringLiteral("waiting_authorization"))
    label = QStringLiteral("Waiting for platform approval");
  if (code == QStringLiteral("client_missing"))
    label = QStringLiteral("App not installed");
  if (code == QStringLiteral("sdk_missing"))
    label = QStringLiteral("Sharing component not enabled");
  return QVariantMap{{QStringLiteral("channel"), key},
                     {QStringLiteral("code"), code},
                     {QStringLiteral("label"), label},
                     {QStringLiteral("configured"),
                      !socialAppId(key).isEmpty()}};
}

bool MobileUiService::setSocialAppId(const QString& channel,
                                     const QString& value) {
  setLastError(QString());
  if (!settingsRepository_) {
    setLastError(QStringLiteral("Platform credentials cannot be saved in this environment."));
    return false;
  }
  const QString key = channel.trimmed().toLower();
  const QString normalized = value.trimmed();
  if ((key != QStringLiteral("moments") &&
       key != QStringLiteral("qzone")) ||
      normalized.size() > 128 ||
      normalized.contains(QRegularExpression(QStringLiteral("\\s")))) {
    setLastError(QStringLiteral("That AppID is not formatted correctly. Check it and try again."));
    return false;
  }
  const QString settingKey =
      key == QStringLiteral("moments") ? kWechatAppIdSetting
                                       : kQqAppIdSetting;
  if (!settingsRepository_->setValue(settingKey, normalized)) {
    setLastError(QStringLiteral("The AppID could not be saved on this device."));
    return false;
  }
  emit socialAppIdsChanged();
  return true;
}

QString MobileUiService::socialAppId(const QString& channel) const {
  if (!settingsRepository_) return QString();
  if (channel == QStringLiteral("moments"))
    return settingsRepository_->getValue(kWechatAppIdSetting).trimmed();
  if (channel == QStringLiteral("qzone"))
    return settingsRepository_->getValue(kQqAppIdSetting).trimmed();
  return QString();
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
