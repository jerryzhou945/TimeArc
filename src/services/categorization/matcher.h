// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_CATEGORIZATION_MATCHER_H
#define TIMEARC_SERVICES_CATEGORIZATION_MATCHER_H

#include <QString>
#include <QVector>

#include "services/categorization/rule.h"

namespace TimeArc::Categorization {

struct Resolution {
  bool matched = false;
  QString ruleId;      // empty when nothing matched
  QString identity;    // rule id, or a fallback key derived from the app
  QString category;    // after category gating
  QString needle;      // the needle that won, for "why this category?"
  int score = 0;
  int conditions = 0;
};

struct MatchOptions {
  // The read-layer switch. Off stops inference but leaves rules the user
  // created or edited in force, because those are not inference.
  bool autoClassify = true;
  QString language = QStringLiteral("en");
};

inline QString fallbackIdentity(const QString& normalizedDisplayName,
                                const QString& normalizedAppId) {
  // Matches the identity scheme the previous read layer produced, so stored
  // hidden_apps / app_display_names keys survive the upgrade.
  if (!normalizedDisplayName.isEmpty())
    return QStringLiteral("exe:") + normalizedDisplayName;
  if (!normalizedAppId.isEmpty())
    return QStringLiteral("path:") + normalizedAppId;
  return QStringLiteral("app:unknown");
}

// A rule with its needles parsed once. Indices, not pointers, so the owning
// RuleSet stays copyable without dangling.
struct CompiledRule {
  int index = -1;
  QVector<Needle> app;
  QVector<Needle> title;
};

class Matcher {
 public:
  Matcher() = default;
  explicit Matcher(RuleSet set) : m_set(std::move(set)) { compile(); }

  const RuleSet& ruleSet() const { return m_set; }

  void setRuleSet(RuleSet set) {
    m_set = std::move(set);
    compile();
  }

  // score = 100 x conditions matched
  //       +  50 when the winning needle is exact
  //       +  length of the longest matched needle
  //
  // Counting conditions is what makes a title refinement outrank a bare app
  // match: site.youtube (gate + title) beats app.chrome (gate only), so
  // YouTube in a browser is Video and the rest of that browser is Browsing.
  Resolution resolve(const QString& appId, const QString& displayName,
                     const QString& windowTitle,
                     const MatchOptions& options = MatchOptions()) const {
    const QString identityName = normalize(displayName);
    const QString identityId = normalize(appId);
    const QString title = normalize(windowTitle);

    QStringList components;
    if (!identityName.isEmpty()) components << identityName;
    if (!identityId.isEmpty()) components << identityId;
    const QString identity = joinIdentity(identityName, identityId);
    const QStringList titleComponents =
        title.isEmpty() ? QStringList() : QStringList{title};

    Resolution best;
    int bestOrder = 0;
    for (const CompiledRule& compiled : m_compiled) {
      const Rule& rule = m_set.rules.at(compiled.index);
      if (!rule.enabled) continue;

      int conditions = 0;
      int longest = 0;
      bool exact = false;
      QString needle;

      // Every rule names an app. That app is the gate, and it is what makes a
      // title needle safe: a title can only ever refine the app it is bound to.
      if (!compiled.app.isEmpty()) {
        const Hit gate = matchAny(compiled.app, identity, components);
        if (!gate.matched) continue;
        ++conditions;
        longest = gate.length;
        exact = gate.exact;
        needle = gate.needle;
      }

      if (!compiled.title.isEmpty()) {
        const Hit hit = matchAny(compiled.title, title, titleComponents);
        if (!hit.matched) continue;
        ++conditions;
        if (hit.length > longest) {
          longest = hit.length;
          exact = hit.exact;
          needle = hit.needle;
        }
      }

      if (conditions == 0) continue;  // a rule that matches nothing

      const int score = 100 * conditions + (exact ? 50 : 0) + longest;
      const bool better =
          !best.matched || score > best.score ||
          (score == best.score && rule.order < bestOrder) ||
          (score == best.score && rule.order == bestOrder &&
           rule.id < best.ruleId);
      if (!better) continue;

      best.matched = true;
      best.ruleId = rule.id;
      // `ref` normally means "restore from this shipped rule" and broad
      // defaults can materialize several unrelated applications (for example
      // Opera and Brave). Only explicitly approved multi-process aliases may
      // use it as a shared statistics/icon identity.
      const QString ref = rule.ref.trimmed();
      best.identity = ref == QStringLiteral("app:wechat") ? ref : rule.id;
      best.category = rule.category;
      best.needle = needle;
      best.score = score;
      best.conditions = conditions;
      bestOrder = rule.order;
    }

    if (!best.matched) {
      best.identity = fallbackIdentity(identityName, identityId);
      best.category = QStringLiteral("other");
      return best;
    }

    best.category = gateCategory(best.ruleId, best.category, options);
    return best;
  }

  // Does this rule's app-side gate admit the app, ignoring window titles?
  // Used to list a rule under the app it can fire for.
  bool ruleAdmitsApp(const QString& ruleId, const QString& appId,
                     const QString& displayName) const {
    const QString identityName = normalize(displayName);
    const QString identityId = normalize(appId);
    QStringList components;
    if (!identityName.isEmpty()) components << identityName;
    if (!identityId.isEmpty()) components << identityId;
    const QString identity = joinIdentity(identityName, identityId);

    for (const CompiledRule& compiled : m_compiled) {
      const Rule& rule = m_set.rules.at(compiled.index);
      if (rule.id != ruleId) continue;
      if (compiled.app.isEmpty()) return false;
      return matchAny(compiled.app, identity, components).matched;
    }
    return false;
  }

  QString labelFor(const QString& ruleId, const QString& language) const {
    for (const Rule& rule : m_set.rules) {
      if (rule.id == ruleId) return displayLabel(rule, language);
    }
    return QString();
  }

 private:
  // A disabled category collapses to "other" - this is what game_mode: off
  // becomes, generalized to every category.
  QString gateCategory(const QString& ruleId, const QString& category,
                       const MatchOptions& options) const {
    const CategoryDef* definition = m_set.category(category);
    if (definition != nullptr && !definition->enabled) {
      return QStringLiteral("other");
    }
    if (!options.autoClassify) {
      for (const Rule& rule : m_set.rules) {
        if (rule.id == ruleId) {
          return rule.userTouched ? category : QStringLiteral("other");
        }
      }
      return QStringLiteral("other");
    }
    return category;
  }

  void compile() {
    m_compiled.clear();
    m_compiled.reserve(m_set.rules.size());
    for (int index = 0; index < m_set.rules.size(); ++index) {
      const Rule& rule = m_set.rules.at(index);
      CompiledRule compiled;
      compiled.index = index;
      compiled.app = parseNeedles(rule.app);
      compiled.title = parseNeedles(rule.title);
      m_compiled.append(compiled);
    }
  }

  RuleSet m_set;
  QVector<CompiledRule> m_compiled;
};

}  // namespace TimeArc::Categorization

#endif  // TIMEARC_SERVICES_CATEGORIZATION_MATCHER_H
