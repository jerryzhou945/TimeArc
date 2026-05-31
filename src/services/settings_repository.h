#ifndef SETTINGSREPOSITORY_H
#define SETTINGSREPOSITORY_H

#include <QObject>
#include <QString>

class ManualProjectRepository;

class SettingsRepository : public QObject {
  Q_OBJECT

 public:
  explicit SettingsRepository(QObject* parent = nullptr);

  Q_INVOKABLE QString getValue(const QString& key,
                               const QString& defaultValue = QString());

  Q_INVOKABLE bool setValue(const QString& key, const QString& value);

  Q_INVOKABLE bool getBool(const QString& key, bool defaultValue = false);

  Q_INVOKABLE bool setBool(const QString& key, bool value);

  Q_INVOKABLE bool migrateLegacyQSettings(
      ManualProjectRepository* manualProjectRepository);
};

#endif
