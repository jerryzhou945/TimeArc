// SPDX-License-Identifier: GPL-3.0-or-later

#include "services/categorization_manager.h"

#include <QDateTime>
#include <QMetaType>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QSet>

#include <algorithm>

#include "services/settings_repository.h"

namespace {

using namespace TimeArc::Categorization;

const QString kStorageKey = QStringLiteral("categorization");

// 播种算法的版本。改了推导方式就 +1：没被用户改过的表会在下次启动自动重播，
// 用户不需要知道「去按一下恢复默认」。
constexpr int kSeedVersion = 2;

QStringList stringListFrom(const QVariant& value) {
  QStringList list;
  if (value.metaType().id() == QMetaType::QStringList) {
    list = value.toStringList();
  } else if (value.canConvert<QVariantList>()) {
    for (const QVariant& entry : value.toList()) {
      list << entry.toString();
    }
  } else {
    const QString text = value.toString();
    if (!text.trimmed().isEmpty()) {
      for (const QString& part : text.split(QLatin1Char(','))) list << part;
    }
  }
  QStringList cleaned;
  for (const QString& entry : list) {
    const QString trimmed = entry.trimmed();
    if (!trimmed.isEmpty()) cleaned << trimmed;
  }
  return cleaned;
}

}  // namespace

CategorizationManager::CategorizationManager(QObject* parent)
    : QObject(parent), m_defaults(defaultRuleSet()) {
  m_matcher.setRuleSet(m_defaults);
}

void CategorizationManager::setRecordedAppsProvider(
    std::function<QVariantList()> provider) {
  m_recordedApps = std::move(provider);
}

void CategorizationManager::setSettingsRepository(
    SettingsRepository* repository) {
  m_settings = repository;
  reload();
}

void CategorizationManager::setLanguage(const QString& language) {
  const QString normalized = language.trimmed().isEmpty()
                                 ? QStringLiteral("en")
                                 : language.trimmed();
  if (m_options.language == normalized) return;
  m_options.language = normalized;
  emit rulesChanged();  // labels change; classification does not
}

void CategorizationManager::setAutoClassify(bool autoClassify) {
  if (m_options.autoClassify == autoClassify) return;
  m_options.autoClassify = autoClassify;
  ++m_generation;
  emit rulesChanged();
}

// A stored document that fails to parse or lint must never be applied
// silently: fall back to the shipped defaults and keep the reason, so the UI
// can say what happened instead of appearing to have lost the user's work.
void CategorizationManager::reload() {
  m_loadError.clear();

  if (m_settings != nullptr) {
    m_options.language = m_settings->languageMode();
  }

  if (m_settings == nullptr) {
    apply(m_defaults, false);
    return;
  }

  const QString raw = m_settings->getValue(kStorageKey);
  if (raw.trimmed().isEmpty()) {
    seedAndPersist();
    return;
  }

  QJsonParseError parseError;
  const QJsonDocument document =
      QJsonDocument::fromJson(raw.toUtf8(), &parseError);
  if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
    m_loadError = parseError.errorString();
    apply(m_defaults, false);
    return;
  }

  QStringList problems;
  const QJsonObject object = document.object();
  RuleSet stored = ruleSetFromJson(object, m_defaults, &problems);
  problems += lint(stored);
  if (!problems.isEmpty()) {
    m_loadError = problems.join(QStringLiteral("; "));
    apply(m_defaults, false);
    return;
  }

  m_seededApps = object.value(QStringLiteral("seededApps")).toInt(0);
  m_seedVersion = object.value(QStringLiteral("seedVersion")).toInt(0);
  m_userEdited = object.value(QStringLiteral("userEdited")).toBool(false);

  const bool haveRecords = m_recordedApps && !m_recordedApps().isEmpty();
  // 两种情况自动重播：全新安装当时还没有采集数据；或者播种算法升级了。
  // 用户动过就绝不自作主张——把规则删光也是他的选择。
  if (!m_userEdited && haveRecords &&
      (m_seededApps == 0 || m_seedVersion < kSeedVersion)) {
    seedAndPersist();
    return;
  }

  apply(stored, m_userEdited);
}

// 按**这台机器实际采集到的应用**逐个生成规则：每个应用恰好一条应用级规则，绑定
// 服务记录到的名字，类别取匹配得最好的出厂规则；出厂表里没有的应用也照样写一条
// （类别 other），所以规则表就是这台机器用过的软件清单，App Management 里每一行
// 都能点开看到属于它的规则。带标题的出厂规则（站点）额外挂到命中的那个应用上。
//
// 这与「在界面里选一个应用」走的是同一条路：一条规则 = 一个应用 + 精确绑定。
TimeArc::Categorization::RuleSet CategorizationManager::seedFromRecords() const {
  RuleSet seeded;
  seeded.schema = 1;
  seeded.fromDefaults = m_defaults.fromDefaults;

  seeded.categories = m_defaults.categories;
  for (CategoryDef& category : seeded.categories) {
    if (category.ref.trimmed().isEmpty()) category.ref = category.id;
  }

  QVariantList apps = m_recordedApps ? m_recordedApps() : QVariantList();
  if (apps.isEmpty()) return seeded;  // 全新安装：没有数据，就没有规则

  // 用得多的应用先挑 id：同一条出厂规则被多个应用命中时（Foxit 阅读器和它的
  // 更新服务），本尊保住原 id，其余带后缀，不会互相吞掉。
  std::sort(apps.begin(), apps.end(),
            [](const QVariant& left, const QVariant& right) {
              return left.toMap().value(QStringLiteral("seconds")).toLongLong() >
                     right.toMap().value(QStringLiteral("seconds")).toLongLong();
            });

  // 应用级出厂规则单独成表，好借用 matcher 的打分挑「最匹配的那一条」，而不是让
  // 第一条碰上的规则把应用吃掉。
  RuleSet appLevelDefaults;
  appLevelDefaults.categories = m_defaults.categories;
  for (const Rule& shipped : m_defaults.rules) {
    if (shipped.title.isEmpty()) appLevelDefaults.rules.append(shipped);
  }
  const Matcher appLevelProbe(appLevelDefaults);
  const Matcher probe(m_defaults);

  QSet<QString> usedIds;
  const auto uniqueId = [&usedIds](const QString& base,
                                   const QString& recorded) {
    if (!usedIds.contains(base)) return base;
    QString slug = TimeArc::Categorization::normalize(recorded);
    slug.replace(QLatin1Char(' '), QLatin1Char('-'));
    QString candidate = base + QLatin1Char('@') + slug;
    int suffix = 2;
    while (usedIds.contains(candidate)) {
      candidate = base + QLatin1Char('@') + slug + QStringLiteral("-%1").arg(suffix++);
    }
    return candidate;
  };

  for (const QVariant& value : apps) {
    const QVariantMap app = value.toMap();
    const QString appId = app.value(QStringLiteral("appId")).toString();
    const QString displayName =
        app.value(QStringLiteral("displayName")).toString();
    const QString recorded =
        displayName.trimmed().isEmpty() ? appId.trimmed() : displayName.trimmed();
    if (recorded.isEmpty()) continue;
    const QString needle = QStringLiteral("=") + recorded;

    // 1) 这个应用自己的规则。
    const Resolution best =
        appLevelProbe.resolve(appId, displayName, QString(), m_options);
    Rule rule;
    if (best.matched) {
      for (const Rule& shipped : appLevelDefaults.rules) {
        if (shipped.id != best.ruleId) continue;
        rule = shipped;
        rule.ref = shipped.id;
        break;
      }
    } else {
      // 出厂表不认识它：仍旧写一条，用采集到的名字，归到 other。身份沿用读层
      // 对未知应用的 exe: 方案，已存的隐藏/改名偏好因此继续有效。
      rule.id = TimeArc::Categorization::fallbackIdentity(
          TimeArc::Categorization::normalize(displayName),
          TimeArc::Categorization::normalize(appId));
      rule.category = QStringLiteral("other");
      rule.name = recorded;
    }
    rule.id = uniqueId(rule.id, recorded);
    rule.app = QStringList{needle};
    usedIds.insert(rule.id);
    seeded.rules.append(rule);

    // 2) 能落到这个应用上的标题规则（浏览器里的站点等）。
    for (const Rule& shipped : m_defaults.rules) {
      if (shipped.title.isEmpty()) continue;
      if (!probe.ruleAdmitsApp(shipped.id, appId, displayName)) continue;
      Rule titleRule = shipped;
      titleRule.ref = shipped.id;
      titleRule.id = uniqueId(shipped.id, recorded);
      titleRule.app = QStringList{needle};
      usedIds.insert(titleRule.id);
      seeded.rules.append(titleRule);
    }
  }
  return seeded;
}

void CategorizationManager::seedAndPersist() {
  const RuleSet seeded = seedFromRecords();
  m_seededApps = m_recordedApps ? m_recordedApps().size() : 0;
  m_seedVersion = kSeedVersion;
  m_userEdited = false;
  persist(seeded);
  apply(seeded, false);
}

void CategorizationManager::apply(RuleSet set, bool customized) {
  m_matcher.setRuleSet(std::move(set));
  m_customized = customized;
  ++m_generation;
  emit rulesChanged();
}

RuleSet CategorizationManager::workingSet() const { return m_matcher.ruleSet(); }

// 规则集始终是实打实存在的（播种时就写了），所以这里只负责标记「用户动过」，
// 让自动补种不再插手。
bool CategorizationManager::materialize() {
  if (m_settings == nullptr) return false;
  m_userEdited = true;
  return true;
}

bool CategorizationManager::persist(const RuleSet& set) {
  if (m_settings == nullptr) return false;
  QJsonObject object = ruleSetToJson(set);
  object.insert(QStringLiteral("seededApps"), m_seededApps);
  object.insert(QStringLiteral("seedVersion"), m_seedVersion);
  object.insert(QStringLiteral("userEdited"), m_userEdited);
  const QJsonDocument document(object);
  return m_settings->setValue(
      kStorageKey, QString::fromUtf8(document.toJson(QJsonDocument::Compact)));
}

int CategorizationManager::indexOfRule(const QString& ruleId) const {
  const RuleSet& set = m_matcher.ruleSet();
  for (int index = 0; index < set.rules.size(); ++index) {
    if (set.rules.at(index).id == ruleId) return index;
  }
  return -1;
}

// ----------------------------------------------------------------- reading

QString CategorizationManager::categoryLabel(const QString& categoryId) const {
  const CategoryDef* definition = m_matcher.ruleSet().category(categoryId);
  if (definition == nullptr) return categoryId;
  return displayLabel(*definition, m_options.language);
}

QVariantList CategorizationManager::categories() const {
  QVariantList result;
  for (const CategoryDef& category : m_matcher.ruleSet().categories) {
    QVariantMap item;
    item.insert(QStringLiteral("id"), category.id);
    item.insert(QStringLiteral("label"),
                displayLabel(category, m_options.language));
    item.insert(QStringLiteral("color"), category.color);
    item.insert(QStringLiteral("traits"), category.traits);
    item.insert(QStringLiteral("enabled"), category.enabled);
    item.insert(QStringLiteral("isUser"), category.ref.isEmpty() &&
                                              !category.name.isEmpty());
    result.append(item);
  }
  return result;
}

QVariantMap CategorizationManager::ruleToVariant(const Rule& rule) const {
  QVariantMap item;
  item.insert(QStringLiteral("id"), rule.id);
  item.insert(QStringLiteral("ref"), rule.ref);
  item.insert(QStringLiteral("name"), rule.name);
  item.insert(QStringLiteral("label"), displayLabel(rule, m_options.language));
  item.insert(QStringLiteral("category"), rule.category);
  item.insert(QStringLiteral("categoryLabel"), categoryLabel(rule.category));
  item.insert(QStringLiteral("app"), rule.app);
  item.insert(QStringLiteral("title"), rule.title);
  item.insert(QStringLiteral("enabled"), rule.enabled);
  item.insert(QStringLiteral("order"), rule.order);
  item.insert(QStringLiteral("icon"), rule.icon);

  // A user-created rule has nothing to restore to; a materialized one does,
  // and only shows "modified" when it actually differs from the default.
  bool restorable = false;
  bool modified = false;
  if (!rule.ref.trimmed().isEmpty()) {
    for (const Rule& shipped : m_defaults.rules) {
      if (shipped.id != rule.ref) continue;
      restorable = true;
      modified = rule.category != shipped.category || rule.app != shipped.app ||
                 rule.title != shipped.title ||
                 !rule.name.trimmed().isEmpty() || !rule.enabled;
      break;
    }
  }
  item.insert(QStringLiteral("restorable"), restorable);
  item.insert(QStringLiteral("modified"), modified);
  item.insert(QStringLiteral("isUser"), rule.ref.trimmed().isEmpty());

  // The one-line summary the settings row renders.
  QStringList parts;
  const auto summarize = [](const QString& prefix, const QStringList& needles) {
    if (needles.isEmpty()) return QString();
    QStringList shown = needles.mid(0, 2);
    QString text = prefix + QStringLiteral(": ") +
                   shown.join(QStringLiteral(", "));
    if (needles.size() > shown.size()) {
      text += QStringLiteral(", +%1").arg(needles.size() - shown.size());
    }
    return text;
  };
  const QString appPart = summarize(tr("app"), rule.app);
  const QString titlePart = summarize(tr("title"), rule.title);
  if (!appPart.isEmpty()) parts << appPart;
  if (!titlePart.isEmpty()) parts << titlePart;
  item.insert(QStringLiteral("summary"),
              parts.join(QStringLiteral(" · ")));
  return item;
}

QVariantList CategorizationManager::rules() const {
  QVariantList result;
  for (const Rule& rule : m_matcher.ruleSet().rules) {
    result.append(ruleToVariant(rule));
  }
  return result;
}

QVariantMap CategorizationManager::rule(const QString& ruleId) const {
  const int index = indexOfRule(ruleId);
  if (index < 0) return QVariantMap();
  return ruleToVariant(m_matcher.ruleSet().rules.at(index));
}

QVariantList CategorizationManager::rulesGroupedByCategory() const {
  QVariantList result;
  for (const CategoryDef& category : m_matcher.ruleSet().categories) {
    QVariantList members;
    for (const Rule& rule : m_matcher.ruleSet().rules) {
      if (rule.category == category.id) members.append(ruleToVariant(rule));
    }
    QVariantMap group;
    group.insert(QStringLiteral("id"), category.id);
    group.insert(QStringLiteral("label"),
                 displayLabel(category, m_options.language));
    group.insert(QStringLiteral("color"), category.color);
    group.insert(QStringLiteral("enabled"), category.enabled);
    group.insert(QStringLiteral("traits"), category.traits);
    group.insert(QStringLiteral("rules"), members);
    group.insert(QStringLiteral("ruleCount"), members.size());
    result.append(group);
  }
  return result;
}

QVariantMap CategorizationManager::explain(const QString& appId,
                                           const QString& displayName,
                                           const QString& windowTitle) const {
  const Resolution resolution =
      m_matcher.resolve(appId, displayName, windowTitle, m_options);
  QVariantMap result;
  result.insert(QStringLiteral("matched"), resolution.matched);
  result.insert(QStringLiteral("ruleId"), resolution.ruleId);
  result.insert(QStringLiteral("identity"), resolution.identity);
  result.insert(QStringLiteral("category"), resolution.category);
  result.insert(QStringLiteral("categoryLabel"),
                categoryLabel(resolution.category));
  result.insert(QStringLiteral("needle"), resolution.needle);
  result.insert(QStringLiteral("score"), resolution.score);
  result.insert(QStringLiteral("conditions"), resolution.conditions);
  if (resolution.matched) {
    result.insert(QStringLiteral("ruleLabel"),
                  m_matcher.labelFor(resolution.ruleId, m_options.language));
  }

  // Runner-up: resolve again with the winner disabled.
  if (resolution.matched) {
    RuleSet reduced = m_matcher.ruleSet();
    for (Rule& rule : reduced.rules) {
      if (rule.id == resolution.ruleId) rule.enabled = false;
    }
    const Matcher runnerUpMatcher(reduced);
    const Resolution runnerUp =
        runnerUpMatcher.resolve(appId, displayName, windowTitle, m_options);
    if (runnerUp.matched) {
      QVariantMap second;
      second.insert(QStringLiteral("ruleId"), runnerUp.ruleId);
      second.insert(QStringLiteral("ruleLabel"),
                    runnerUpMatcher.labelFor(runnerUp.ruleId,
                                             m_options.language));
      second.insert(QStringLiteral("category"), runnerUp.category);
      second.insert(QStringLiteral("score"), runnerUp.score);
      result.insert(QStringLiteral("runnerUp"), second);
    }
  }
  return result;
}

int CategorizationManager::matchCount(const QString& ruleId,
                                      const QVariantList& apps) const {
  int count = 0;
  for (const QVariant& value : apps) {
    const QVariantMap app = value.toMap();
    const Resolution resolution = m_matcher.resolve(
        app.value(QStringLiteral("appId")).toString(),
        app.value(QStringLiteral("appName")).toString(),
        app.value(QStringLiteral("windowTitle")).toString(), m_options);
    if (resolution.ruleId == ruleId) ++count;
  }
  return count;
}

QStringList CategorizationManager::lintDraft(const QVariantMap& draft) const {
  RuleSet probe = m_matcher.ruleSet();
  Rule candidate = ruleFromVariant(draft, Rule());
  if (candidate.id.trimmed().isEmpty()) {
    candidate.id = QStringLiteral("user.__draft__");
  }
  bool replaced = false;
  for (Rule& rule : probe.rules) {
    if (rule.id == candidate.id) {
      rule = candidate;
      replaced = true;
      break;
    }
  }
  if (!replaced) probe.rules.append(candidate);

  QStringList mine;
  for (const QString& problem : lint(probe)) {
    if (problem.contains(candidate.id)) mine << problem;
  }
  return mine;
}

// ----------------------------------------------------------------- writing

Rule CategorizationManager::ruleFromVariant(const QVariantMap& fields,
                                            Rule base) const {
  if (fields.contains(QStringLiteral("id")))
    base.id = fields.value(QStringLiteral("id")).toString().trimmed();
  if (fields.contains(QStringLiteral("name")))
    base.name = fields.value(QStringLiteral("name")).toString().trimmed();
  if (fields.contains(QStringLiteral("category")))
    base.category = fields.value(QStringLiteral("category")).toString().trimmed();
  if (fields.contains(QStringLiteral("app")))
    base.app = stringListFrom(fields.value(QStringLiteral("app")));
  if (fields.contains(QStringLiteral("title")))
    base.title = stringListFrom(fields.value(QStringLiteral("title")));
  if (fields.contains(QStringLiteral("enabled")))
    base.enabled = fields.value(QStringLiteral("enabled")).toBool();
  if (fields.contains(QStringLiteral("order")))
    base.order = fields.value(QStringLiteral("order")).toInt();
  return base;
}

bool CategorizationManager::setRuleCategory(const QString& ruleId,
                                            const QString& categoryId) {
  QVariantMap fields;
  fields.insert(QStringLiteral("category"), categoryId);
  return updateRule(ruleId, fields);
}

bool CategorizationManager::setRuleEnabled(const QString& ruleId,
                                           bool enabled) {
  QVariantMap fields;
  fields.insert(QStringLiteral("enabled"), enabled);
  return updateRule(ruleId, fields);
}

bool CategorizationManager::updateRule(const QString& ruleId,
                                       const QVariantMap& fields) {
  if (!materialize()) return false;
  RuleSet set = workingSet();
  bool found = false;
  for (Rule& rule : set.rules) {
    if (rule.id != ruleId) continue;
    const QString keptId = rule.id;
    rule = ruleFromVariant(fields, rule);
    rule.id = keptId;  // identity is not editable
    rule.userTouched = true;
    found = true;
    break;
  }
  if (!found) return false;
  if (!lint(set).isEmpty()) return false;
  if (!persist(set)) return false;
  apply(set, true);
  return true;
}

QString CategorizationManager::addRule(const QVariantMap& fields) {
  if (!materialize()) return QString();
  RuleSet set = workingSet();
  Rule rule = ruleFromVariant(fields, Rule());
  rule.id = QStringLiteral("user.%1")
                .arg(QDateTime::currentSecsSinceEpoch());
  int suffix = 1;
  while (indexOfRule(rule.id) >= 0) {
    rule.id = QStringLiteral("user.%1-%2")
                  .arg(QDateTime::currentSecsSinceEpoch())
                  .arg(suffix++);
  }
  rule.ref.clear();
  rule.userTouched = true;
  rule.enabled = true;
  set.rules.append(rule);
  if (!lint(set).isEmpty()) return QString();
  if (!persist(set)) return QString();
  apply(set, true);
  return rule.id;
}

bool CategorizationManager::deleteRule(const QString& ruleId) {
  if (!materialize()) return false;
  RuleSet set = workingSet();
  const int before = set.rules.size();
  for (int index = set.rules.size() - 1; index >= 0; --index) {
    if (set.rules.at(index).id == ruleId) set.rules.removeAt(index);
  }
  if (set.rules.size() == before) return false;
  if (!persist(set)) return false;
  apply(set, true);
  return true;
}

bool CategorizationManager::restoreRule(const QString& ruleId) {
  if (!m_customized) return true;  // already at defaults
  RuleSet set = workingSet();
  for (Rule& rule : set.rules) {
    if (rule.id != ruleId) continue;
    if (rule.ref.trimmed().isEmpty()) return false;  // nothing to restore to
    for (const Rule& shipped : m_defaults.rules) {
      if (shipped.id != rule.ref) continue;
      const QString keptId = rule.id;
      const QString keptRef = rule.ref;
      rule = shipped;
      rule.id = keptId;
      rule.ref = keptRef;
      rule.userTouched = false;
      if (!persist(set)) return false;
      apply(set, true);
      return true;
    }
    return false;
  }
  return false;
}

// 「恢复默认」不是取回一张固定的表，而是**按当前采集数据重新推导**一次：录到了
// 哪些应用，就写哪些应用的出厂规则。
bool CategorizationManager::restoreAllDefaults() {
  if (m_settings == nullptr) return false;
  m_loadError.clear();
  seedAndPersist();
  return true;
}

bool CategorizationManager::setCategoryEnabled(const QString& categoryId,
                                               bool enabled) {
  if (!materialize()) return false;
  RuleSet set = workingSet();
  bool found = false;
  for (CategoryDef& category : set.categories) {
    if (category.id != categoryId) continue;
    category.enabled = enabled;
    found = true;
    break;
  }
  if (!found) return false;
  if (!persist(set)) return false;
  apply(set, true);
  return true;
}

QString CategorizationManager::addCategory(const QString& name,
                                           const QString& color) {
  if (!materialize()) return QString();
  const QString trimmed = name.trimmed();
  if (trimmed.isEmpty()) return QString();

  RuleSet set = workingSet();
  QString id = TimeArc::Categorization::normalize(trimmed);
  id.replace(QLatin1Char(' '), QLatin1Char('-'));
  if (id.isEmpty()) id = QStringLiteral("category");
  QString candidate = id;
  int suffix = 1;
  while (set.category(candidate) != nullptr) {
    candidate = id + QStringLiteral("-%1").arg(++suffix);
  }

  CategoryDef category;
  category.id = candidate;
  category.name = trimmed;
  category.color = color.trimmed();
  category.enabled = true;
  set.categories.append(category);
  if (!persist(set)) return QString();
  apply(set, true);
  return candidate;
}

// 只算「这台机器用得到」的新出厂规则：覆盖了已采集应用、但当前表里还没有的。
int CategorizationManager::newDefaultsCount() const {
  const RuleSet candidates = seedFromRecords();
  QSet<QString> known;
  for (const Rule& rule : m_matcher.ruleSet().rules) known.insert(rule.id);
  int count = 0;
  for (const Rule& candidate : candidates.rules) {
    if (!known.contains(candidate.id)) ++count;
  }
  return count;
}

bool CategorizationManager::adoptNewDefaults(const QStringList& ruleIds) {
  const RuleSet candidates = seedFromRecords();
  RuleSet set = workingSet();
  QSet<QString> known;
  for (const Rule& rule : set.rules) known.insert(rule.id);
  bool changed = false;
  for (const Rule& candidate : candidates.rules) {
    if (known.contains(candidate.id)) continue;
    if (!ruleIds.isEmpty() && !ruleIds.contains(candidate.id)) continue;
    set.rules.append(candidate);  // 已按实际记录绑定好
    changed = true;
  }
  if (!changed) return true;
  set.fromDefaults = m_defaults.fromDefaults;
  if (!persist(set)) return false;
  apply(set, true);
  return true;
}

// The App Management dropdown. Editing the matched rule is right when it
// covers only this app; when it covers several, "only this app" mints a
// narrow exact rule that outranks the broad one by the exactness bonus.
bool CategorizationManager::assignCategory(const QString& appId,
                                           const QString& displayName,
                                           const QString& windowTitle,
                                           const QString& categoryId,
                                           bool onlyThisApp) {
  if (categoryId.trimmed().isEmpty()) return false;
  if (!materialize()) return false;

  const Resolution resolution =
      m_matcher.resolve(appId, displayName, windowTitle, m_options);

  if (resolution.matched && !onlyThisApp) {
    return setRuleCategory(resolution.ruleId, categoryId);
  }

  const QString identity = TimeArc::Categorization::normalize(displayName);
  QVariantMap fields;
  fields.insert(QStringLiteral("category"), categoryId);
  fields.insert(QStringLiteral("name"),
                displayName.trimmed().isEmpty() ? appId : displayName.trimmed());
  fields.insert(QStringLiteral("app"),
                QStringList{QStringLiteral("=") +
                            (identity.isEmpty()
                                 ? TimeArc::Categorization::normalize(appId)
                                 : identity)});
  return !addRule(fields).isEmpty();
}

// --------------------------------------------------- per-app rule browsing

QVariantMap CategorizationManager::appRuleFor(const QString& appId,
                                              const QString& displayName) const {
  // 忽略窗口标题解析 → 拿到「这个应用本身」归谁管，而不是它当前在看的站点。
  const Resolution resolution =
      m_matcher.resolve(appId, displayName, QString(), m_options);
  if (!resolution.matched) return QVariantMap();
  return rule(resolution.ruleId);
}

QVariantList CategorizationManager::titleRulesForApp(
    const QString& appId, const QString& displayName) const {
  QVariantList result;
  for (const Rule& candidate : m_matcher.ruleSet().rules) {
    if (candidate.title.isEmpty()) continue;
    if (!m_matcher.ruleAdmitsApp(candidate.id, appId, displayName)) continue;
    result.append(ruleToVariant(candidate));
  }
  return result;
}

QString CategorizationManager::addTitleRuleForApp(const QString& appId,
                                                  const QString& displayName,
                                                  const QString& name,
                                                  const QStringList& titles,
                                                  const QString& categoryId) {
  QStringList cleaned;
  for (const QString& title : titles) {
    const QString trimmed = title.trimmed();
    if (!trimmed.isEmpty()) cleaned << trimmed;
  }
  if (cleaned.isEmpty() || categoryId.trimmed().isEmpty()) return QString();

  // 标题规则永远绑在**一个应用**上：范围就是那个应用，没有"所有浏览器"这种
  // 说不清指向哪儿的设置。
  const QString identity = TimeArc::Categorization::normalize(displayName);
  const QString appNeedle =
      QStringLiteral("=") + (identity.isEmpty()
                                 ? TimeArc::Categorization::normalize(appId)
                                 : identity);
  if (appNeedle.size() <= 1) return QString();

  QVariantMap fields;
  fields.insert(QStringLiteral("name"), name.trimmed());
  fields.insert(QStringLiteral("category"), categoryId);
  fields.insert(QStringLiteral("app"), QStringList{appNeedle});
  fields.insert(QStringLiteral("title"), cleaned);
  return addRule(fields);
}

bool CategorizationManager::deleteCategory(const QString& categoryId) {
  if (categoryId == QStringLiteral("other")) return false;
  if (!materialize()) return false;

  RuleSet set = workingSet();
  bool found = false;
  for (int index = set.categories.size() - 1; index >= 0; --index) {
    if (set.categories.at(index).id != categoryId) continue;
    set.categories.removeAt(index);
    found = true;
  }
  if (!found) return false;

  // 规则不跟着一起消失：归到 other，用户能重新分配，不会静默丢历史归类。
  for (Rule& rule : set.rules) {
    if (rule.category == categoryId) {
      rule.category = QStringLiteral("other");
      rule.userTouched = true;
    }
  }
  if (!lint(set).isEmpty()) return false;
  if (!persist(set)) return false;
  apply(set, true);
  return true;
}

// 保留服务记录到的原样字符串（"Google Chrome.app"），匹配时才归一化。这样规则里
// 显示的就是采集到的东西，用户一眼认得出来。
QString CategorizationManager::appNeedleFor(const QString& appId,
                                            const QString& displayName) const {
  const QString body = displayName.trimmed().isEmpty() ? appId.trimmed()
                                                       : displayName.trimmed();
  return body.isEmpty() ? QString() : QStringLiteral("=") + body;
}
