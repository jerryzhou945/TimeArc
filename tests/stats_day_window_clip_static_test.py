"""Guards the two read-layer contracts the stats page depends on.

1. Windowing. Every windowed read path selects records by interval
   *intersection* and clips the interval to the window, so a session crossing
   midnight is split across the days it actually spans. The old shape --
   "record.startUnixSec >= start && record.startUnixSec <= end", then use the
   whole interval -- charged a 17.6h cross-midnight session entirely to its
   start day (2026-08-03 printed 36h19m).

2. Source. The stats page reads frontmost_sessions only. media_sessions runs
   concurrently with the foreground app, so mixing both into one app list makes
   the same second countable twice under two different apps -- which put
   2026-08-04/05 at 24.06h even after the clip was in place.

3. Counted length. Every interval is [start, start + active_sec). A foreground
   session stays open across idle (CHARTER v0.11), so duration_sec is wall clock
   and includes the locked screen -- loginwindow was 74.9h wall against 9.1h
   active. Wall clock survives only where the question is "when", not "how long".

4. Per-app hiding. An app resolves to more than one group key across rule-table
   versions (rule hit -> app:macos-shell; no hit -> legacy exe:loginwindow), so
   hidden-ness is matched against every alias, and stored keys are canonicalized
   by the settings layer so unhiding can remove them.

Reports: journal/errors/20260828-{094718,101917,1049xx,1051xx}-C-*.md
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def reject(text, needle, label):
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


def body_of(text, signature):
    """Return the source of one function, from its signature to the next top-level }."""
    start = text.index(signature)
    end = text.index("\n}\n", start)
    return text[start:end]


def main():
    cpp = read("src/services/usage_stat_manager.cpp")
    header = read("src/services/usage_stat_manager.h")
    stats_qml = read("qml/desktop/pages/DesktopStatsPage.qml")

    # --- 1. Windowing: intersect and clip, never select on start alone. ---
    require(header, "struct ClipWindow", "ClipWindow declaration")
    require(header, "bool clip(qint64 recStartUnixSec, quint64 durationSec",
            "ClipWindow::clip signature")
    require(header, "static ClipWindow clipWindowForDates", "date-window adapter")
    require(header, "static ClipWindow clipWindowForBounds", "bounds-window adapter")

    # The window is half-open, and QML passes the period's last second.
    require(cpp, "clipped.end = endUnixSec + 1", "closed-to-half-open conversion")
    # DST-safe day arithmetic: startOfDay(), never a bare +86400.
    require(cpp, "window.to.addDays(1).startOfDay().toSecsSinceEpoch()",
            "DST-safe window end")

    # No read path may reselect on the record's start alone.
    reject(cpp, "record.startUnixSec >= startUnixSec",
           "start-only window predicate")
    reject(cpp, "record.startUnixSec < startUnixSec",
           "start-only window predicate")
    # The start-day membership helpers this fix orphaned must stay gone.
    reject(header, "bool matchesRange(", "orphaned start-day range helper")
    reject(header, "bool matchesYearMonth(", "orphaned start-day month helper")

    # --- 2. Source: the stats page is frontmost-only, end to end. ---
    # Its read paths are named for the caliber they enforce...
    for method in (
        "foregroundSoftwareForWindow",
        "foregroundSoftwareSecondsForWindow",
        "foregroundDailySecondsForRange",
        "foregroundMonthlySecondsForYear",
        "foregroundFocusStatsForWindow",
        "foregroundApps",
    ):
        require(header, method, f"stats-page read path {method}")

    # ...and the page calls nothing from the active (foreground-union-audio) set.
    for method in (
        "activeSoftwareForWindow",
        "activeSoftwareForRange",
        "activeSoftwareForMonth",
        "dailySecondsForRange",
        "dailySecondsForMonth",
        "monthlySecondsForYear",
        "focusStatsForWindow",
        "allApps",
    ):
        reject(stats_qml, f"usageStatManager.{method}(",
               f"active-caliber call on the stats page: {method}")

    # The four hand-rolled record loops the stats page uses must filter source
    # themselves -- they do not go through aggregateSoftware's sourceFilter.
    for signature in (
        "QVariantList UsageStatManager::foregroundDailySecondsForRange(",
        "QVariantList UsageStatManager::foregroundMonthlySecondsForYear(",
        "QVariantMap UsageStatManager::foregroundFocusStatsForWindow(",
    ):
        body = body_of(cpp, signature)
        require(body, "matchesSource(record, kForegroundSource)",
                f"foreground source guard in {signature}")

    # allApps() stays all-source: settings needs every app the service ever saw.
    require(cpp, "return allAppsImpl(QString(), &m_allAppsCache",
            "all-source allApps() for the settings inventory")
    require(cpp, "return allAppsImpl(kForegroundSource, &m_foregroundAppsCache",
            "frontmost-only foregroundApps() for the stats page")
    # Two calibers, two caches -- one cache keyed only on generation would serve
    # whichever caller asked first.
    require(header, "m_foregroundAppsGeneration", "separate foregroundApps cache")

    # --- 3. Counted length is active_sec, not wall clock. ---
    require(cpp, "fs.active_sec", "active_sec in the frontmost read query")
    # media_sessions has no active column; the loader reads one shape, so the
    # media query backfills duration into the same slot.
    require(cpp, "ms.duration_sec, ms.rowid,\n       ms.duration_sec",
            "media active-length backfill")
    require(header, "quint64 activeSec = 0;", "UsageRecord::activeSec")
    # Nothing may build a counted interval out of the wall-clock span.
    reject(cpp, "window.clip(record.startUnixSec, record.durationSec",
           "wall-clock span fed to the window clip")
    for signature in (
        "QVariantList UsageStatManager::dailySecondsForMonth(",
        "QVariantList UsageStatManager::foregroundDailySecondsForRange(",
        "QVariantList UsageStatManager::foregroundMonthlySecondsForYear(",
        "QVariantList UsageStatManager::allAppsImpl(",
        "QVariantList UsageStatManager::recordedAppIdentities(",
    ):
        body = body_of(cpp, signature)
        require(body, "record.activeSec", f"active length in {signature}")

    # --- 4. Hiding matches every alias an app can resolve to. ---
    require(cpp, "QStringList UsageStatManager::activityAliases(",
            "alias enumeration")
    require(cpp, "fallbackIdentity(", "legacy identity among the aliases")
    require(header, "canonicalHiddenKeys", "stored-key canonicalization")
    # No read path may test the hidden set against a single key again.
    reject(cpp, "m_hiddenKeys.contains(key)", "single-key hidden test")
    reject(cpp, "m_hiddenKeys.contains(mergedKey)", "single-key hidden test")
    reject(cpp, "m_hiddenKeys.contains(entry.groupKey)", "single-key hidden test")
    # The settings layer writes the canonical list back, or unhiding cannot
    # remove a stale key that only the alias match still sees.
    for qml_path in ("qml/desktop/DesktopAppShell.qml",
                     "qml/desktop/pages/DesktopProfilePage.qml"):
        require(read(qml_path), "canonicalHiddenKeys",
                f"hidden-key canonicalization in {qml_path}")

    # --- 5. app_display_name_overrides keys the same way, so it drifts too. ---
    require(cpp, "QString UsageStatManager::displayNameOverrideFor(",
            "alias-aware override lookup")
    require(header, "canonicalDisplayNameKeys", "override-key canonicalization")
    # No read site may look the override map up by a single key again.
    for needle in ("m_displayNameOverrides.value(aggregate.groupKey)",
                   "m_displayNameOverrides.value(app.groupKey)",
                   "m_displayNameOverrides.value(entry.groupKey)"):
        reject(cpp, needle, "single-key override lookup")
    # Overrides must be pushed at startup, not only while the settings page
    # happens to be the instantiated one -- pageLoader builds one page at a time.
    shell = read("qml/desktop/DesktopAppShell.qml")
    require(shell, "setAppDisplayNameOverrides",
            "startup push of display-name overrides")
    require(shell, "canonicalDisplayNameKeys",
            "override canonicalization in the shell")

    # Aggregation cores clip before they accumulate.
    for signature in (
        "QVariantList UsageStatManager::aggregateSoftware(",
        "QVariantList UsageStatManager::foregroundSegmentsImpl(",
    ):
        body = body_of(cpp, signature)
        require(body, "window.clip(record.startUnixSec, record.activeSec",
                f"clip call in {signature}")
        reject(body, "{record.startUnixSec, endUnixSec}",
               f"unclipped interval in {signature}")

    # A truncated record must not vote for its category with its full length.
    aggregate = body_of(cpp, "QVariantList UsageStatManager::aggregateSoftware(")
    reject(aggregate, "+=\n        record.durationSec;",
           "category weight from unclipped duration")

    # Day/month bucketing splits a record across the buckets it spans.
    require(cpp, "void forEachLocalDaySlice(", "local-day slicing helper")
    for signature in (
        "QVariantList UsageStatManager::dailySecondsForMonth(",
        "QVariantList UsageStatManager::foregroundDailySecondsForRange(",
        "QVariantList UsageStatManager::foregroundMonthlySecondsForYear(",
    ):
        body = body_of(cpp, signature)
        require(body, "forEachLocalDaySlice(record.startUnixSec",
                f"day slicing in {signature}")

    focus = body_of(cpp, "QVariantMap UsageStatManager::foregroundFocusStatsForWindow(")
    require(focus, "clipWindowForBounds(startUnixSec, endUnixSec)",
            "clipped window in focusStatsForWindow")

    # forEachLocalDaySlice must not be able to spin forever on a bad timezone.
    slicer = body_of(cpp, "void forEachLocalDaySlice(")
    require(slicer, "if (dayEnd <= cursor) break;", "day-slice progress guard")

    print("stats_day_window_clip_static_test: ok")


if __name__ == "__main__":
    main()
