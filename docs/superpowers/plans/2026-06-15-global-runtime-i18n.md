# Global Runtime I18n Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add global runtime language switching with English-first coverage and Japanese core fallback.

**Architecture:** Keep Chinese source strings as fallback and add a shared QML helper for runtime translations. Inject the existing `languageMode` into shell-loaded pages and translate visible desktop/mobile labels without touching service data.

**Tech Stack:** Qt 6 QML, JavaScript QML library, existing `settingsRepository`, harness build tools.

---

### Task 1: I18n Foundation

**Files:**
- Create: `qml/desktop/components/I18n.js`
- Modify: `.harness/rules/04-ui-conventions.md`

- [ ] Add `I18n.js` with `t(lang, source)`, `sentence(lang, key, params)`, and app/category helpers.
- [ ] Update UI language rule to permit runtime translation helpers with Chinese fallback.
- [ ] Run harness check before committing.

### Task 2: Shell And Settings

**Files:**
- Modify: `qml/desktop/DesktopAppShell.qml`
- Modify: `qml/desktop/pages/DesktopProfilePage.qml`

- [ ] Import `I18n.js` and translate shell navigation, welcome copy, tooltips, and notices.
- [ ] Translate settings tabs, row labels, descriptions, buttons, dialogs, toasts, and language choices.
- [ ] Add eliding/wrapping safeguards to compact settings controls where translated labels can be longer.
- [ ] Build and smoke the language switch.

### Task 3: Main Desktop Pages

**Files:**
- Modify: `qml/desktop/pages/DesktopHomePage.qml`
- Modify: `qml/desktop/pages/DesktopStatsPage.qml`
- Modify: `qml/desktop/pages/DesktopCalenderPage.qml`
- Modify: `qml/desktop/pages/DesktopTimerPage.qml`

- [ ] Route fixed labels, empty states, dialogs, and dynamic sentence templates through `I18n.js`.
- [ ] Keep user-entered project names and raw stored data unchanged.
- [ ] Build and smoke desktop navigation.

### Task 4: Memory Lake And Mobile Basics

**Files:**
- Modify: `qml/desktop/pages/DesktopMemoryLakePage.qml`
- Modify: `qml/desktop/pages/DesktopMonthlyRecapPage.qml`
- Modify: `qml/desktop/memorylake/*.qml`
- Modify: `qml/mobile/*.qml`

- [ ] Translate Memory Lake fixed labels, recap labels, card controls, memo controls, and mobile core labels.
- [ ] Preserve generated report data while translating fixed display labels around it.
- [ ] Run build, GUI smoke, Qt log scan, and harness check.
