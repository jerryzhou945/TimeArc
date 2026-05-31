#ifndef TAGREPOSITORY_H
#define TAGREPOSITORY_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class TagRepository : public QObject {
  Q_OBJECT

 public:
  explicit TagRepository(QObject* parent = nullptr);

  Q_INVOKABLE QVariantList getAllTags();

  Q_INVOKABLE QVariantMap getTagById(int tagId);

  Q_INVOKABLE bool createTag(const QString& name,
                             const QString& color,
                             const QString& icon = QString());
};

#endif
