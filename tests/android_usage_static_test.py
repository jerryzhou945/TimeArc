from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main():
    main_cpp = read("src/main.cpp")
    manifest = read("android/AndroidManifest.xml")
    record_dto = read("android/src/main/java/com/timearc/mobile/usage/UsageRecordDto.java")
    session_dto = read("android/src/main/java/com/timearc/mobile/usage/UsageSessionDto.java")
    stats_reader = read("android/src/main/java/com/timearc/mobile/usage/UsageStatsReader.java")
    events_reader = read("android/src/main/java/com/timearc/mobile/usage/UsageEventsReader.java")
    sync_worker = read("android/src/main/java/com/timearc/mobile/usage/UsageSyncWorker.java")
    jni_bridge = read("src/services/mobile/android_usage_jni_bridge.cpp")
    mobile_repo_h = read("src/services/mobile/mobile_usage_repository.h")
    mobile_repo_cpp = read("src/services/mobile/mobile_usage_repository.cpp")
    app_repo_cpp = read("src/services/app_repository.cpp")
    mobile_shell = read("qml/mobile/MobileAppShell.qml")
    stats_page = read("qml/mobile/pages/MobileStatsPage.qml")
    app_icon = read("qml/mobile/components/MobileAppIcon.qml")

    require(main_cpp, "#if defined(Q_OS_ANDROID)",
            "Android-gated lifecycle sync")
    require(main_cpp, "applicationStateChanged",
            "application foreground lifecycle signal")
    require(main_cpp, "Qt::ApplicationActive",
            "foreground active-state filter")
    require(main_cpp, "mobileUsageService.requestImmediateSync()",
            "foreground resume usage sync request")

    require(manifest, "android.permission.QUERY_ALL_PACKAGES",
            "Android package visibility for app labels/icons")
    require(record_dto, "appIconPath", "aggregated usage icon path DTO field")
    require(session_dto, "appIconPath", "usage session icon path DTO field")
    require(stats_reader, "AndroidAppMetadataResolver.resolve",
            "aggregated usage metadata resolver")
    require(events_reader, "AndroidAppMetadataResolver.resolve",
            "usage event metadata resolver")
    require(sync_worker, "RECENT_SESSION_LOOKBACK_DAYS = 35",
            "monthly session lookback")
    require(sync_worker, "startOfPreviousMonthMs",
            "current and previous month aggregate backfill")
    require(jni_bridge, "\"appIconPath\"", "JNI icon path field extraction")
    require(mobile_repo_h, "const QString& appIconPath",
            "mobile repository icon path parameter")
    require(mobile_repo_cpp, "normalizedAppIconPath",
            "mobile repository normalized icon path")
    require(app_repo_cpp, "excluded.app_icon_path IS NULL",
            "app icon path NULL preservation on updates")
    require(app_repo_cpp, "THEN apps.app_icon_path",
            "app icon path empty-string preservation on updates")
    require(stats_page, "MobileUsageRankRow",
            "mobile stats shared usage ranking row")
    require(app_icon, "appIconPath",
            "mobile shared app icon source")
    require(app_icon, "Image {", "mobile shared real app icon rendering")
    require(mobile_shell, "ensureUsageAccessOnboarding",
            "first-run Usage Access onboarding")
    require(mobile_shell, "android_usage_access_prompted",
            "persistent Usage Access prompt guard")
    require(mobile_shell, "openUsageAccessSettings()",
            "automatic Usage Access settings handoff")

    print("Android usage static checks passed")


if __name__ == "__main__":
    main()
