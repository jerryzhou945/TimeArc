#ifndef SETTINGSREPOSITORY_H
#define SETTINGSREPOSITORY_H

#include <QObject>
#include <QString>
#include <QVariantMap>

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

  // 设置页导出（G-EXPORT）：整张 settings 表 (key -> value) 读成 QVariantMap，供 QML
  // 序列化成 JSON。只读，不动磁盘契约。
  Q_INVOKABLE QVariantMap getAllSettings();

  // 设置页导入（G-IMPORT 辅助）：读取本地文本文件内容（QML 无文件 IO，见 rules/04 §4）。
  // path 接受本地路径或 file:// URL；失败返回空串。只读取所选文件，不写 usage/契约文件。
  Q_INVOKABLE QString readTextFile(const QString& path);
};

#endif
