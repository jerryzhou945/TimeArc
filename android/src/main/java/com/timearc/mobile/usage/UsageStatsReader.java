package com.timearc.mobile.usage;

import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

public final class UsageStatsReader {
    public static final String SOURCE_AGGREGATED_USAGE_STATS =
            "android_usage_stats_aggregate";

    private UsageStatsReader() {}

    public static String toTimeArcAppIdentifier(String packageName) {
        if (packageName == null || packageName.trim().isEmpty()) {
            return "";
        }
        return "android:" + packageName.trim();
    }

    public static List<UsageRecordDto> readTodayUsage(Context context) {
        Calendar calendar = Calendar.getInstance();
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        long beginMs = calendar.getTimeInMillis();
        long endMs = System.currentTimeMillis();
        return readAggregatedUsage(context, beginMs, endMs);
    }

    public static List<UsageRecordDto> readAggregatedUsage(
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

        Map<String, UsageStats> stats =
                usageStatsManager.queryAndAggregateUsageStats(beginMs, endMs);
        if (stats == null || stats.isEmpty()) {
            return Collections.emptyList();
        }

        PackageManager packageManager = context.getPackageManager();
        long syncedAtUnixSec = System.currentTimeMillis() / 1000L;
        ArrayList<UsageRecordDto> records = new ArrayList<>();

        for (Map.Entry<String, UsageStats> entry : stats.entrySet()) {
            UsageStats usageStats = entry.getValue();
            if (usageStats == null) {
                continue;
            }

            long foregroundMs = usageStats.getTotalTimeInForeground();
            if (foregroundMs <= 0L) {
                continue;
            }

            String packageName = entry.getKey();
            String label = resolveAppLabel(packageManager, packageName);
            records.add(new UsageRecordDto(
                    packageName,
                    toTimeArcAppIdentifier(packageName),
                    label,
                    usageStats.getFirstTimeStamp(),
                    usageStats.getLastTimeStamp(),
                    foregroundMs,
                    SOURCE_AGGREGATED_USAGE_STATS,
                    syncedAtUnixSec));
        }

        records.sort(new Comparator<UsageRecordDto>() {
            @Override
            public int compare(UsageRecordDto left, UsageRecordDto right) {
                return Long.compare(
                        right.totalTimeInForegroundMs,
                        left.totalTimeInForegroundMs);
            }
        });
        return records;
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
