// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_CATEGORIZATION_RULE_SET_JSON_H
#define TIMEARC_SERVICES_CATEGORIZATION_RULE_SET_JSON_H

#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QSet>
#include <QStringList>

#include "services/categorization/default_rules.h"
#include "services/categorization/rule.h"

// The stored form. Simpler than the built-in form on purpose: no icon, no
// color, no locale map. `name` is written only when the user renamed
// something, so an untouched materialized rule still resolves its localized
// label from `ref` against the shipped table.
namespace TimeArc::Categorization {

inline constexpr int kMaxRules = 500;
inline constexpr int kMaxNeedlesPerRule = 32;

// ------------------------------------------------------------------ write

inline QJsonArray toJsonArray(const QStringList& values) {
  QJsonArray array;
  for (const QString& value : values) array.append(value);
  return array;
}

inline QJsonObject ruleToJson(const Rule& rule) {
  QJsonObject object;
  object.insert(QStringLiteral("id"), rule.id);
  if (!rule.ref.trimmed().isEmpty())
    object.insert(QStringLiteral("ref"), rule.ref);
  if (!rule.name.trimmed().isEmpty())
    object.insert(QStringLiteral("name"), rule.name);
  object.insert(QStringLiteral("category"), rule.category);
  if (!rule.app.isEmpty())
    object.insert(QStringLiteral("app"), toJsonArray(rule.app));
  if (!rule.title.isEmpty())
    object.insert(QStringLiteral("title"), toJsonArray(rule.title));
  object.insert(QStringLiteral("enabled"), rule.enabled);
  if (rule.order != 0) object.insert(QStringLiteral("order"), rule.order);
  if (rule.userTouched) object.insert(QStringLiteral("touched"), true);
  return object;
}

inline QJsonObject categoryToJson(const CategoryDef& category) {
  QJsonObject object;
  object.insert(QStringLiteral("id"), category.id);
  if (!category.ref.trimmed().isEmpty())
    object.insert(QStringLiteral("ref"), category.ref);
  if (!category.name.trimmed().isEmpty())
    object.insert(QStringLiteral("name"), category.name);
  if (!category.color.trimmed().isEmpty())
    object.insert(QStringLiteral("color"), category.color);
  if (!category.traits.isEmpty())
    object.insert(QStringLiteral("traits"), toJsonArray(category.traits));
  object.insert(QStringLiteral("enabled"), category.enabled);
  return object;
}

inline QJsonObject ruleSetToJson(const RuleSet& set) {
  QJsonObject object;
  object.insert(QStringLiteral("schema"), set.schema);
  object.insert(QStringLiteral("fromDefaults"), set.fromDefaults);

  QJsonArray categories;
  for (const CategoryDef& category : set.categories)
    categories.append(categoryToJson(category));
  object.insert(QStringLiteral("categories"), categories);

  QJsonArray rules;
  for (const Rule& rule : set.rules) rules.append(ruleToJson(rule));
  object.insert(QStringLiteral("rules"), rules);
  return object;
}

// ------------------------------------------------------------------- read

inline QStringList toStringList(const QJsonValue& value) {
  QStringList list;
  for (const QJsonValue& entry : value.toArray()) {
    const QString text = entry.toString().trimmed();
    if (!text.isEmpty()) list << text;
  }
  return list;
}

// Rehydrate presentation from the shipped table. A stored entry carries no
// label or icon; `ref` is how it gets them back, and a user-supplied `name`
// overrides them.
inline void rehydrate(Rule* rule, const RuleSet& defaults) {
  if (rule == nullptr || rule->ref.trimmed().isEmpty()) return;
  for (const Rule& shipped : defaults.rules) {
    if (shipped.id != rule->ref) continue;
    rule->label = shipped.label;
    rule->icon = shipped.icon;
    return;
  }
}

inline void rehydrate(CategoryDef* category, const RuleSet& defaults) {
  if (category == nullptr || category->ref.trimmed().isEmpty()) return;
  for (const CategoryDef& shipped : defaults.categories) {
    if (shipped.id != category->ref) continue;
    category->label = shipped.label;
    return;
  }
}

inline RuleSet ruleSetFromJson(const QJsonObject& object,
                               const RuleSet& defaults, QStringList* errors) {
  RuleSet set;
  set.schema = object.value(QStringLiteral("schema")).toInt(0);
  set.fromDefaults = object.value(QStringLiteral("fromDefaults")).toInt(0);

  if (set.schema != 1 && errors != nullptr) {
    *errors << QStringLiteral("unsupported schema: %1").arg(set.schema);
    return set;
  }

  for (const QJsonValue& value :
       object.value(QStringLiteral("categories")).toArray()) {
    const QJsonObject entry = value.toObject();
    CategoryDef category;
    category.id = entry.value(QStringLiteral("id")).toString().trimmed();
    if (category.id.isEmpty()) continue;
    category.ref = entry.value(QStringLiteral("ref")).toString().trimmed();
    category.name = entry.value(QStringLiteral("name")).toString().trimmed();
    category.color = entry.value(QStringLiteral("color")).toString().trimmed();
    category.traits = toStringList(entry.value(QStringLiteral("traits")));
    category.enabled = entry.value(QStringLiteral("enabled")).toBool(true);
    rehydrate(&category, defaults);
    set.categories.append(category);
  }

  for (const QJsonValue& value :
       object.value(QStringLiteral("rules")).toArray()) {
    const QJsonObject entry = value.toObject();
    Rule rule;
    rule.id = entry.value(QStringLiteral("id")).toString().trimmed();
    if (rule.id.isEmpty()) continue;
    rule.ref = entry.value(QStringLiteral("ref")).toString().trimmed();
    rule.name = entry.value(QStringLiteral("name")).toString().trimmed();
    rule.category = entry.value(QStringLiteral("category")).toString().trimmed();
    rule.app = toStringList(entry.value(QStringLiteral("app")));
    rule.title = toStringList(entry.value(QStringLiteral("title")));
    rule.enabled = entry.value(QStringLiteral("enabled")).toBool(true);
    rule.order = entry.value(QStringLiteral("order")).toInt(0);
    rule.userTouched = entry.value(QStringLiteral("touched")).toBool(false);
    rehydrate(&rule, defaults);
    set.rules.append(rule);
  }

  return set;
}

// ------------------------------------------------------------------- lint

inline QStringList lint(const RuleSet& set) {
  QStringList problems;

  if (set.schema != 1)
    problems << QStringLiteral("unsupported schema: %1").arg(set.schema);
  if (set.rules.size() > kMaxRules)
    problems << QStringLiteral("too many rules: %1").arg(set.rules.size());

  QSet<QString> categoryIds;
  for (const CategoryDef& category : set.categories) {
    if (categoryIds.contains(category.id))
      problems << QStringLiteral("duplicate category id: %1").arg(category.id);
    categoryIds.insert(category.id);
  }

  QSet<QString> ruleIds;
  for (const Rule& rule : set.rules) {
    if (ruleIds.contains(rule.id))
      problems << QStringLiteral("duplicate rule id: %1").arg(rule.id);
    ruleIds.insert(rule.id);

    if (!categoryIds.contains(rule.category)) {
      problems << QStringLiteral("rule %1 references unknown category %2")
                      .arg(rule.id, rule.category);
    }
    if (rule.app.isEmpty() && rule.title.isEmpty()) {
      problems << QStringLiteral("rule %1 matches nothing").arg(rule.id);
    }
    // The structural guard: a title needle with no app would let a page title
    // named "...game..." reclassify whatever happened to be on screen.
    if (!rule.title.isEmpty() && rule.app.isEmpty()) {
      problems << QStringLiteral("rule %1 has a title match with no app")
                      .arg(rule.id);
    }
    if (rule.app.size() + rule.title.size() > kMaxNeedlesPerRule) {
      problems << QStringLiteral("rule %1 has too many needles").arg(rule.id);
    }
    for (const QString& raw : rule.app + rule.title) {
      const Needle needle = parseNeedle(raw);
      if (needle.text.isEmpty()) {
        problems << QStringLiteral("rule %1 has an empty needle").arg(rule.id);
        continue;
      }
      // Short Latin substrings match far too much; require exactness there.
      if (needle.kind == NeedleKind::Contains && needle.text.size() < 3 &&
          needle.text.at(0).unicode() < 0x80) {
        problems << QStringLiteral("rule %1 needle '%2' is too short for a "
                                   "substring match; use '='")
                        .arg(rule.id, needle.text);
      }
    }
  }

  return problems;
}

}  // namespace TimeArc::Categorization

#endif  // TIMEARC_SERVICES_CATEGORIZATION_RULE_SET_JSON_H
