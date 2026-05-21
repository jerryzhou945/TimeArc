#ifndef APPREPOSITORY_H
#define APPREPOSITORY_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class AppRepository : public QObject {
  Q_OBJECT

 public:
  explicit AppRepository(QObject* parent = nullptr);

  Q_INVOKABLE QVariantMap getAppByIdentifier(const QString& appIdentifier);

  Q_INVOKABLE bool upsertApp(const QString& appIdentifier,
                             const QString& appName,
                             const QString& displayName,
                             const QString& iconPath,
                             const QString& executablePath,
                             const QString& platform);

  Q_INVOKABLE QVariantList getAllApps();
};

#endif
