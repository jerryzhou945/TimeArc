#include "services/TagRepository.h"

#include <QDateTime>
#include <QDebug>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>

namespace {

const QString kConnectionName = QStringLiteral("timearc");

QSqlDatabase database() {
  QSqlDatabase db = QSqlDatabase::database(kConnectionName);
  if (!db.isValid() || !db.isOpen()) {
    qWarning() << "Database is not open.";
  }
  return db;
}

QVariantMap tagMapFromQuery(const QSqlQuery& query) {
  QVariantMap tag;
  tag.insert(QStringLiteral("id"), query.value(0).toInt());
  tag.insert(QStringLiteral("name"), query.value(1).toString());
  tag.insert(QStringLiteral("color"), query.value(2).toString());
  tag.insert(QStringLiteral("icon"), query.value(3).toString());
  tag.insert(QStringLiteral("createdAt"), query.value(4).toLongLong());
  return tag;
}

}  // namespace

TagRepository::TagRepository(QObject* parent) : QObject(parent) {}

QVariantList TagRepository::getAllTags() {
  QVariantList tags;
  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return tags;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    id,
    name,
    color,
    icon,
    created_at
FROM tags
ORDER BY id ASC;
)SQL"))) {
    qWarning() << "Failed to prepare getAllTags:" << query.lastError().text();
    return tags;
  }

  if (!query.exec()) {
    qWarning() << "Failed to query tags:" << query.lastError().text();
    return tags;
  }

  while (query.next()) {
    tags.append(tagMapFromQuery(query));
  }

  return tags;
}

QVariantMap TagRepository::getTagById(int tagId) {
  if (tagId <= 0) {
    qWarning() << "Invalid tag id:" << tagId;
    return QVariantMap();
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return QVariantMap();

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
SELECT
    id,
    name,
    color,
    icon,
    created_at
FROM tags
WHERE id = :id
LIMIT 1;
)SQL"))) {
    qWarning() << "Failed to prepare getTagById:" << query.lastError().text();
    return QVariantMap();
  }

  query.bindValue(QStringLiteral(":id"), tagId);

  if (!query.exec()) {
    qWarning() << "Failed to query tag by id:" << query.lastError().text();
    return QVariantMap();
  }

  if (!query.next()) return QVariantMap();
  return tagMapFromQuery(query);
}

bool TagRepository::createTag(const QString& name,
                              const QString& color,
                              const QString& icon) {
  const QString normalizedName = name.trimmed();
  const QString normalizedColor = color.trimmed();

  if (normalizedName.isEmpty() || normalizedColor.isEmpty()) {
    qWarning() << "Cannot create tag with empty name or color.";
    return false;
  }

  QSqlDatabase db = database();
  if (!db.isValid() || !db.isOpen()) return false;

  QSqlQuery query(db);
  if (!query.prepare(QStringLiteral(R"SQL(
INSERT INTO tags (
    name,
    color,
    icon,
    created_at
) VALUES (
    :name,
    :color,
    :icon,
    :created_at
);
)SQL"))) {
    qWarning() << "Failed to prepare createTag:" << query.lastError().text();
    return false;
  }

  query.bindValue(QStringLiteral(":name"), normalizedName);
  query.bindValue(QStringLiteral(":color"), normalizedColor);
  query.bindValue(QStringLiteral(":icon"), icon);
  query.bindValue(QStringLiteral(":created_at"),
                  QDateTime::currentSecsSinceEpoch());

  if (!query.exec()) {
    qWarning() << "Failed to create tag:" << query.lastError().text();
    return false;
  }

  return true;
}
