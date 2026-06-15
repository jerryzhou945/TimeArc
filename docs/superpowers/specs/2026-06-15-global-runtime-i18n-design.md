# Global Runtime I18n Design

## Goal

TimeArc should support a global language setting, with English coverage across the main UI and Japanese coverage for the core navigation path. Switching language must not change the data contract or destabilize layouts.

## Architecture

Chinese remains the source/fallback language in QML. A shared `I18n.js` helper maps Chinese UI strings and app display names to runtime English/Japanese strings. Pages receive `languageMode` from `DesktopAppShell` and use the helper for visible UI text.

## Data Flow

`DesktopProfilePage` writes `language_mode` to `settingsRepository`. `DesktopAppShell` reads that value, injects it into loaded pages, and page bindings recompute translated text. The service, SQLite schema, jsonl records, and app usage aggregation are unchanged.

## Scope

English should cover shell navigation, settings, home, statistics, calendar, memory lake, recap, timer/memo core controls, empty states, dialogs, and fixed labels. Japanese should cover the same core labels where practical, falling back to Chinese for missed edge strings.

## Layout Rules

Longer translated text should use existing constrained widths, `elide`, wrapping, or smaller local text sizing where needed. No page should rely on English text fitting by luck inside fixed-size controls.

## Testing

Verification uses the project build wrapper, GUI smoke launch, Qt log scan, and harness check. A manual smoke path switches `language_mode` among Chinese, English, and Japanese and navigates through the main desktop pages.
