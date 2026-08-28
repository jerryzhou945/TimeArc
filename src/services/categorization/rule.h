// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_CATEGORIZATION_RULE_H
#define TIMEARC_SERVICES_CATEGORIZATION_RULE_H

#include <QHash>
#include <QRegularExpression>
#include <QString>
#include <QStringList>
#include <QVector>

#include "services/categorization/normalize.h"

namespace TimeArc::Categorization {

// ---------------------------------------------------------------- needles

enum class NeedleKind { Contains, Exact, Word };

// A needle carries its normalized text, so authored spelling and observed
// text meet after the same transformation. "chrome.exe" and "Chrome.exe"
// both become "chrome".
struct Needle {
  NeedleKind kind = NeedleKind::Contains;
  QString text;
};

inline Needle parseNeedle(const QString& raw) {
  Needle needle;
  QString body = raw.trimmed();
  if (body.startsWith(QLatin1Char('='))) {
    needle.kind = NeedleKind::Exact;
    body = body.mid(1);
  } else if (body.startsWith(QLatin1String("word:"))) {
    needle.kind = NeedleKind::Word;
    body = body.mid(5);
  }
  needle.text = normalize(body);
  return needle;
}

inline QVector<Needle> parseNeedles(const QStringList& raw) {
  QVector<Needle> needles;
  needles.reserve(raw.size());
  for (const QString& entry : raw) {
    const Needle needle = parseNeedle(entry);
    if (!needle.text.isEmpty()) needles.append(needle);
  }
  return needles;
}

struct Hit {
  bool matched = false;
  int length = 0;
  bool exact = false;
  QString needle;
};

inline bool matchesWord(const QString& haystack, const QString& needle) {
  const QString pattern = QStringLiteral("(?<![a-z0-9])") +
                          QRegularExpression::escape(needle) +
                          QStringLiteral("(?![a-z0-9])");
  const QRegularExpression expression(pattern);
  return expression.isValid() && expression.match(haystack).hasMatch();
}

// `components` are the individual normalized fields; `haystack` is their join.
// Exact needles must equal one whole component - never the join, which would
// never match anything.
inline Hit matchNeedle(const Needle& needle, const QString& haystack,
                       const QStringList& components) {
  Hit hit;
  if (needle.text.isEmpty()) return hit;

  switch (needle.kind) {
    case NeedleKind::Exact:
      for (const QString& component : components) {
        if (component == needle.text) {
          return Hit{true, static_cast<int>(needle.text.size()), true,
                     needle.text};
        }
      }
      return hit;
    case NeedleKind::Word:
      if (matchesWord(haystack, needle.text)) {
        return Hit{true, static_cast<int>(needle.text.size()), false,
                   needle.text};
      }
      return hit;
    case NeedleKind::Contains:
      if (haystack.contains(needle.text)) {
        return Hit{true, static_cast<int>(needle.text.size()), false,
                   needle.text};
      }
      return hit;
  }
  return hit;
}

// Longest match wins, so "visual studio code" outranks "code" with no ordering
// discipline in the table. An exact needle breaks a length tie.
inline Hit matchAny(const QVector<Needle>& needles, const QString& haystack,
                    const QStringList& components) {
  Hit best;
  for (const Needle& needle : needles) {
    const Hit hit = matchNeedle(needle, haystack, components);
    if (!hit.matched) continue;
    if (!best.matched || hit.length > best.length ||
        (hit.length == best.length && hit.exact && !best.exact)) {
      best = hit;
    }
  }
  return best;
}

// ------------------------------------------------------------------ model

struct CategoryDef {
  QString id;
  QHash<QString, QString> label;  // built-in only; "en" is required
  QString name;                   // set only when the user renamed it
  QString ref;                    // built-in id this was materialized from
  QString color;                  // set only when the user picked one
  QStringList traits;             // focus | entertainment | deprioritize
  bool enabled = true;

  bool hasTrait(const QString& trait) const { return traits.contains(trait); }
};

struct Rule {
  QString id;
  QString ref;                    // built-in id this was materialized from
  QString name;                   // set only when the user renamed it
  QHash<QString, QString> label;  // built-in only; "en" is required
  QString icon;                   // built-in only
  QString category;
  QStringList app;                // needles against identity text
  QStringList title;              // needles against title text
  bool enabled = true;
  int order = 0;
  bool userTouched = false;       // survives auto_classify: off

  bool consultsTitle() const { return !title.isEmpty(); }
};

// English-first: "en" is required, every other locale optional and falling
// back to it. A user-supplied `name` is a single string and always wins.
inline QString displayLabel(const Rule& rule, const QString& language) {
  if (!rule.name.trimmed().isEmpty()) return rule.name;
  const QString localized = rule.label.value(language);
  if (!localized.trimmed().isEmpty()) return localized;
  const QString english = rule.label.value(QStringLiteral("en"));
  if (!english.trimmed().isEmpty()) return english;
  return rule.app.isEmpty() ? rule.id : rule.app.first();
}

inline QString displayLabel(const CategoryDef& category,
                            const QString& language) {
  if (!category.name.trimmed().isEmpty()) return category.name;
  const QString localized = category.label.value(language);
  if (!localized.trimmed().isEmpty()) return localized;
  const QString english = category.label.value(QStringLiteral("en"));
  return english.trimmed().isEmpty() ? category.id : english;
}

struct RuleSet {
  int schema = 1;
  int fromDefaults = 0;
  QVector<CategoryDef> categories;
  QVector<Rule> rules;

  const CategoryDef* category(const QString& id) const {
    for (const CategoryDef& definition : categories) {
      if (definition.id == id) return &definition;
    }
    return nullptr;
  }
};

}  // namespace TimeArc::Categorization

#endif  // TIMEARC_SERVICES_CATEGORIZATION_RULE_H
