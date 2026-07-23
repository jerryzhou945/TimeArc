// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef MOBILEUISERVICE_H
#define MOBILEUISERVICE_H

#include <QObject>
#include <QString>
#include <QUrl>

class SettingsRepository;

class MobileUiService : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString wallpaperUrl READ wallpaperUrl NOTIFY wallpaperChanged)
  Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
  Q_PROPERTY(QString lastSavedImagePath READ lastSavedImagePath
                 NOTIFY lastSavedImagePathChanged)

 public:
  explicit MobileUiService(SettingsRepository* settingsRepository,
                           QObject* parent = nullptr);

  QString wallpaperUrl() const;
  QString lastError() const;
  QString lastSavedImagePath() const;

  Q_INVOKABLE bool importWallpaper(const QUrl& source);
  Q_INVOKABLE bool clearWallpaper();
  Q_INVOKABLE QString createShareImagePath(const QString& stem) const;
  Q_INVOKABLE bool saveImageToGallery(const QUrl& source,
                                      const QString& albumName = QString());
  Q_INVOKABLE bool shareImage(const QUrl& source,
                              const QString& chooserTitle);

 signals:
  void wallpaperChanged();
  void lastErrorChanged();
  void lastSavedImagePathChanged();

 private:
  static QString sanitizedStem(const QString& value);
  static QString localPathFor(const QUrl& source);
  static bool copySourceToFile(const QUrl& source, const QString& targetPath);
  void setLastError(const QString& value);
  void setLastSavedImagePath(const QString& value);

  SettingsRepository* settingsRepository_ = nullptr;
  QString wallpaperPath_;
  QString lastError_;
  QString lastSavedImagePath_;
};

#endif
