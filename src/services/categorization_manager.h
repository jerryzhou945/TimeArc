// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_CATEGORIZATION_MANAGER_H
#define TIMEARC_SERVICES_CATEGORIZATION_MANAGER_H

#include <QObject>

#include <functional>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include "services/categorization/matcher.h"
#include "services/categorization/rule_set_json.h"

class SettingsRepository;

// Owns the categorization rule set: loads it, classifies through it, edits it,
// and persists it.
//
// The stored set is **derived from the machine's own tracking data**, not
// copied wholesale from the shipped table: on first run the manager reads the
// apps the service actually recorded, keeps only the default rules that cover
// them, and binds each rule to the name the service reported (so a rule reads
// "=Google Chrome.app", not the generic needle "chrome").
//
// Consequences, all intentional:
//   - a brand-new install has no rules, because it has no recorded apps yet;
//   - "Reset to defaults" is always available and re-derives from current data
//     rather than restoring a fixed table.
class CategorizationManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool customized READ customized NOTIFY rulesChanged)
  Q_PROPERTY(int newDefaultsCount READ newDefaultsCount NOTIFY rulesChanged)

 public:
  explicit CategorizationManager(QObject* parent = nullptr);

  // Persistence is optional: without a repository the manager stays in
  // the shipped defaults and every edit is refused, keeping tests hermetic.
  void setSettingsRepository(SettingsRepository* repository);

  // Supplies the apps the service has recorded. Set before the repository so
  // the first seed can see them. A std::function keeps the dependency one-way:
  // the read layer owns records, this object owns rules.
  void setRecordedAppsProvider(std::function<QVariantList()> provider);

  const TimeArc::Categorization::Matcher& matcher() const { return m_matcher; }

  // Bumped on every change so read layers can invalidate their caches.
  int generation() const { return m_generation; }
  bool customized() const { return m_customized; }
  int newDefaultsCount() const;

  Q_INVOKABLE void reload();
  Q_INVOKABLE void setLanguage(const QString& language);

  // ---- read -------------------------------------------------------------
  Q_INVOKABLE QString categoryLabel(const QString& categoryId) const;
  Q_INVOKABLE QVariantList categories() const;
  Q_INVOKABLE QVariantList rules() const;
  Q_INVOKABLE QVariantList rulesGroupedByCategory() const;
  Q_INVOKABLE QVariantMap rule(const QString& ruleId) const;
  // "Why this category?" - the winning rule, needle, score and runner-up.
  Q_INVOKABLE QVariantMap explain(const QString& appId,
                                  const QString& displayName,
                                  const QString& windowTitle) const;
  // How many of `apps` ([{appId, name}]) a rule currently claims.
  Q_INVOKABLE int matchCount(const QString& ruleId,
                             const QVariantList& apps) const;
  Q_INVOKABLE QStringList lintDraft(const QVariantMap& draft) const;
  // The exact needle that binds a rule to one chosen app, so QML never has to
  // reimplement normalization.
  Q_INVOKABLE QString appNeedleFor(const QString& appId,
                                   const QString& displayName) const;
  // The rule that owns this app when window titles are ignored.
  Q_INVOKABLE QVariantMap appRuleFor(const QString& appId,
                                     const QString& displayName) const;
  // Title rules that can fire for this app, listed under it in App Management.
  Q_INVOKABLE QVariantList titleRulesForApp(const QString& appId,
                                            const QString& displayName) const;

  // ---- write ------------------------------------------------------------
  Q_INVOKABLE bool setRuleCategory(const QString& ruleId,
                                   const QString& categoryId);
  Q_INVOKABLE bool setRuleEnabled(const QString& ruleId, bool enabled);
  Q_INVOKABLE bool updateRule(const QString& ruleId, const QVariantMap& fields);
  Q_INVOKABLE QString addRule(const QVariantMap& fields);
  Q_INVOKABLE bool deleteRule(const QString& ruleId);
  Q_INVOKABLE bool restoreRule(const QString& ruleId);
  Q_INVOKABLE bool restoreAllDefaults();
  Q_INVOKABLE bool setCategoryEnabled(const QString& categoryId, bool enabled);
  Q_INVOKABLE QString addCategory(const QString& name, const QString& color);
  // Rules in a deleted category move to `other`; `other` itself cannot go.
  Q_INVOKABLE bool deleteCategory(const QString& categoryId);
  // One app + several title matches - the shape the rule editor offers.
  Q_INVOKABLE QString addTitleRuleForApp(const QString& appId,
                                         const QString& displayName,
                                         const QString& name,
                                         const QStringList& titles,
                                         const QString& categoryId);
  Q_INVOKABLE bool adoptNewDefaults(const QStringList& ruleIds);

  // Inline assignment from the App Management card. `onlyThisApp` narrows to a
  // new exact rule instead of editing a rule that covers several apps.
  Q_INVOKABLE bool assignCategory(const QString& appId,
                                  const QString& displayName,
                                  const QString& windowTitle,
                                  const QString& categoryId, bool onlyThisApp);

  // Set by the read-layer switch; kept here so one object owns the contract.
  Q_INVOKABLE void setAutoClassify(bool autoClassify);
  bool autoClassify() const { return m_options.autoClassify; }

  const TimeArc::Categorization::MatchOptions& options() const {
    return m_options;
  }

  // Last load error, empty when the stored document parsed cleanly. A
  // non-empty value means the shipped defaults are in force and the UI must
  // say so rather than silently appearing to have lost the user's work.
  Q_INVOKABLE QString loadError() const { return m_loadError; }

 signals:
  void rulesChanged();

 private:
  TimeArc::Categorization::RuleSet workingSet() const;
  // Build a rule set covering only the recorded apps, bound to recorded names.
  TimeArc::Categorization::RuleSet seedFromRecords() const;
  bool materialize();
  void seedAndPersist();
  bool persist(const TimeArc::Categorization::RuleSet& set);
  void apply(TimeArc::Categorization::RuleSet set, bool customized);
  int indexOfRule(const QString& ruleId) const;
  QVariantMap ruleToVariant(const TimeArc::Categorization::Rule& rule) const;
  TimeArc::Categorization::Rule ruleFromVariant(
      const QVariantMap& fields, TimeArc::Categorization::Rule base) const;

  SettingsRepository* m_settings = nullptr;
  std::function<QVariantList()> m_recordedApps;
  int m_seededApps = 0;
  int m_seedVersion = 0;
  bool m_userEdited = false;
  TimeArc::Categorization::RuleSet m_defaults;
  TimeArc::Categorization::Matcher m_matcher;
  TimeArc::Categorization::MatchOptions m_options;
  QString m_loadError;
  int m_generation = 0;
  bool m_customized = false;
};

#endif  // TIMEARC_SERVICES_CATEGORIZATION_MANAGER_H
