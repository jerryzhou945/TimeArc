// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef MOBILEUISERVICE_H
#define MOBILEUISERVICE_H

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantMap>

class SettingsRepository;

class MobileUiService : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString wallpaperUrl READ wallpaperUrl NOTIFY wallpaperChanged)
  Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
  Q_PROPERTY(QString lastSavedImagePath READ lastSavedImagePath
                 NOTIFY lastSavedImagePathChanged)
  Q_PROPERTY(QString wechatAppId READ wechatAppId
                 NOTIFY socialAppIdsChanged)
  Q_PROPERTY(QString qqAppId READ qqAppId NOTIFY socialAppIdsChanged)

 public:
  explicit MobileUiService(SettingsRepository* settingsRepository,
                           QObject* parent = nullptr);

  QString wallpaperUrl() const;
  QString lastError() const;
  QString lastSavedImagePath() const;
  QString wechatAppId() const;
  QString qqAppId() const;

  Q_INVOKABLE bool importWallpaper(const QUrl& source);
  Q_INVOKABLE bool clearWallpaper();
  Q_INVOKABLE QString createShareImagePath(const QString& stem) const;
  Q_INVOKABLE bool saveImageToGallery(const QUrl& source,
                                      const QString& albumName = QString());
  Q_INVOKABLE bool shareImage(const QUrl& source,
                              const QString& chooserTitle);
  Q_INVOKABLE bool shareImageToChannel(const QUrl& source,
                                       const QString& channel,
                                       const QString& chooserTitle);
  Q_INVOKABLE QVariantMap socialShareStatus(const QString& channel) const;
  Q_INVOKABLE bool setSocialAppId(const QString& channel,
                                  const QString& value);

 signals:
  void wallpaperChanged();
  void lastErrorChanged();
  void lastSavedImagePathChanged();
  void socialAppIdsChanged();

 private:
  static QString sanitizedStem(const QString& value);
  static QString localPathFor(const QUrl& source);
  static bool copySourceToFile(const QUrl& source, const QString& targetPath);
  QString socialAppId(const QString& channel) const;
  void setLastError(const QString& value);
  void setLastSavedImagePath(const QString& value);

  SettingsRepository* settingsRepository_ = nullptr;
  QString wallpaperPath_;
  QString lastError_;
  QString lastSavedImagePath_;
};

#endif
