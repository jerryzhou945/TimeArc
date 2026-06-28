package com.timearc.mobile.usage;

import android.content.Context;

import java.util.List;

public final class AndroidUsageNativeBridge {
    private AndroidUsageNativeBridge() {}

    public static boolean syncAggregatedUsage(
            Context context,
            long beginMs,
            long endMs) {
        List<UsageRecordDto> records =
                UsageStatsReader.readAggregatedUsage(context, beginMs, endMs);
        return nativeSyncAggregatedUsage(
                records.toArray(new UsageRecordDto[0]),
                beginMs,
                endMs);
    }

    public static boolean syncRecentSessions(
            Context context,
            long beginMs,
            long endMs) {
        List<UsageSessionDto> sessions =
                UsageEventsReader.readRecentSessions(context, beginMs, endMs);
        return nativeSyncRecentSessions(
                sessions.toArray(new UsageSessionDto[0]),
                beginMs,
                endMs);
    }

    public static boolean syncUsageWindow(
            Context context,
            long beginMs,
            long endMs) {
        boolean aggregateOk = syncAggregatedUsage(context, beginMs, endMs);
        boolean sessionsOk = syncRecentSessions(context, beginMs, endMs);
        return aggregateOk && sessionsOk;
    }

    private static native boolean nativeSyncAggregatedUsage(
            UsageRecordDto[] records,
            long beginMs,
            long endMs);

    private static native boolean nativeSyncRecentSessions(
            UsageSessionDto[] sessions,
            long beginMs,
            long endMs);
}
