# Error Report - stats-aggregate-fact-category

## Metadata

- Level: **L2**
- Track: **C**
- Topic: stats-aggregate-fact-category
- Recorded: 2026-08-28T06:57:16Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

I18n.aggregateFact() passes a category ID through category()->t(), whose dictionaries are keyed by English source strings, so the week/month/year summary fact prints the raw id ('dev is the longest-recorded category...') in en, zh and ja. Sibling card StatsCategoryDistribution routes the same value through categorizationManager.categoryLabel() correctly.

## 2. Evidence

```
    return report.monthLabelParts ? yearMonthLabel(lang, report.monthLabelParts)
                                  : (report.monthLabel || "")
}

function reportTitle(lang, report) {
    if (!report)
        return ""
    return report.titleKey ? fromModel(lang, report.titleKey, report.titleParams)
                           : (report.title || "")
}

function reportRange(lang, model) {
    if (!model)
        return ""
    return model.rangeDates ? dateRange(lang, model.rangeDates)
                            : (model.rangeText || "")
}

// Trend bars and the aggregate fact come from StatsViewModel.js, which is kept
// free of I18n so the Node regression tests can run it. It emits a label key
// plus an index; the rendering happens here.
function trendLabel(lang, bar) {
    if (!bar)
        return ""
    if (bar.label)
        return t(lang, bar.label)
    if (bar.labelKey === "weekOfMonth")
        return sentence(lang, "weekOfMonth", {n: bar.labelIndex + 1})
    if (bar.labelKey === "monthOfYear")
        return monthShort(lang, bar.labelIndex)
    if (bar.labelKey === "weekdayNarrow")
        return weekdaysNarrow(lang)[bar.labelIndex] || String(bar.labelIndex + 1)
    return ""
}

function aggregateFact(lang, fact) {
    if (!fact || !fact.key)
        return ""
    var p = fact.params || {}
    return sentence(lang, fact.key, {
        category: category(lang, p.category),
        range: t(lang, p.range),
        peak: trendLabel(lang, {label: p.peakLabel,
                                labelKey: p.peakLabelKey,
                                labelIndex: p.peakLabelIndex})
    })
}

// Enumeration separator differs by script: English lists with ", ", Chinese and
// Japanese with the full-width "、".
function appsText(lang, apps) {
    if (!apps || apps.length === 0)
        return ""
    return apps.join(langKey(lang) === "en" ? ", " : "、")
}
```

## 3. Root cause

- Immediate cause: I18n.aggregateFact() resolved the fact's category through category() -> t(), whose dictionaries are keyed by English source strings. The value it receives is a category id, so t() found no entry and returned the id verbatim -- in English too, since t() returns its argument unchanged there.
- Underlying cause: The rule table (including user-created categories) is the only thing that can turn a category id into a label, and I18n.js cannot reach it. The sibling card on the same screen already went through CategorizationManager.categoryLabel().
- Why the harness/checklists did not prevent it: The zh/ja symmetry pass checks that keys exist in both tables; it cannot know that a *value* handed to t() at runtime was never a key in the first place.

## 4. Fix

- Files changed: qml/desktop/pages/DesktopStatsPage.qml, qml/shared/I18n.js
- Short description: New DesktopStatsPage.aggregateFactText() resolves the category id via categoryLabel() before I18n composes the sentence; I18n.aggregateFact() gained a comment stating that it must never be handed a raw id.
- Commit: pending commit

## 5. Prevention

One-off, no harness change needed.
