package com.timearc.mobile.usage;

import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Build;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public final class UsageEventsReader {
    public static final String SOURCE_USAGE_EVENTS = "android_usage_events";

    private UsageEventsReader() {}

    public static List<UsageSessionDto> readRecentSessions(
            Context context,
            long beginMs,
            long endMs) {
        if (context == null || beginMs < 0 || endMs <= beginMs) {
            return Collections.emptyList();
        }
        if (!UsageAccessBridge.hasUsageAccess(context)) {
            return Collections.emptyList();
        }

        UsageStatsManager usageStatsManager =
                (UsageStatsManager) context.getSystemService(Context.USAGE_STATS_SERVICE);
        if (usageStatsManager == null) {
            return Collections.emptyList();
        }

        UsageEvents events = usageStatsManager.queryEvents(beginMs, endMs);
        if (events == null) {
            return Collections.emptyList();
        }

        PackageManager packageManager = context.getPackageManager();
        Map<String, Long> openSessions = new HashMap<>();
        ArrayList<UsageSessionDto> sessions = new ArrayList<>();
        UsageEvents.Event event = new UsageEvents.Event();

        while (events.hasNextEvent()) {
            events.getNextEvent(event);
            String packageName = event.getPackageName();
            if (packageName == null || packageName.isEmpty()) {
                continue;
            }

            long eventTimeMs = event.getTimeStamp();
            if (isForegroundEvent(event.getEventType())) {
                openSessions.put(packageName, eventTimeMs);
                continue;
            }

            if (!isBackgroundEvent(event.getEventType())) {
                continue;
            }

            Long startTimeMs = openSessions.remove(packageName);
            if (startTimeMs == null || eventTimeMs <= startTimeMs) {
                continue;
            }

            sessions.add(new UsageSessionDto(
                    packageName,
                    UsageStatsReader.toTimeArcAppIdentifier(packageName),
                    resolveAppLabel(packageManager, packageName),
                    startTimeMs,
                    eventTimeMs,
                    SOURCE_USAGE_EVENTS));
        }

        for (Map.Entry<String, Long> entry : openSessions.entrySet()) {
            long startTimeMs = entry.getValue();
            if (endMs > startTimeMs) {
                String packageName = entry.getKey();
                sessions.add(new UsageSessionDto(
                        packageName,
                        UsageStatsReader.toTimeArcAppIdentifier(packageName),
                        resolveAppLabel(packageManager, packageName),
                        startTimeMs,
                        endMs,
                        SOURCE_USAGE_EVENTS));
            }
        }

        return sessions;
    }

    private static boolean isForegroundEvent(int eventType) {
        return eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        eventType == UsageEvents.Event.ACTIVITY_RESUMED);
    }

    private static boolean isBackgroundEvent(int eventType) {
        return eventType == UsageEvents.Event.MOVE_TO_BACKGROUND ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        eventType == UsageEvents.Event.ACTIVITY_PAUSED);
    }

    private static String resolveAppLabel(
            PackageManager packageManager,
            String packageName) {
        if (packageManager == null || packageName == null || packageName.isEmpty()) {
            return packageName == null ? "" : packageName;
        }

        try {
            ApplicationInfo info = packageManager.getApplicationInfo(packageName, 0);
            CharSequence label = packageManager.getApplicationLabel(info);
            if (label != null && label.length() > 0) {
                return label.toString();
            }
        } catch (PackageManager.NameNotFoundException ignored) {
        }
        return packageName;
    }
}
