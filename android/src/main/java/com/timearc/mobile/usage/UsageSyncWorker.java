package com.timearc.mobile.usage;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import java.util.Calendar;

public final class UsageSyncWorker extends Worker {
    private static final int RECENT_SESSION_LOOKBACK_DAYS = 3;

    public UsageSyncWorker(
            @NonNull Context context,
            @NonNull WorkerParameters params) {
        super(context, params);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context context = getApplicationContext();
        if (!UsageAccessBridge.hasUsageAccess(context)) {
            return Result.success();
        }

        long endMs = System.currentTimeMillis();
        long aggregateBeginMs = startOfTodayMs();
        boolean aggregateOk = AndroidUsageNativeBridge.syncAggregatedUsage(
                context,
                aggregateBeginMs,
                endMs);

        long sessionsBeginMs = endMs -
                TimeUnitDays.toMillis(RECENT_SESSION_LOOKBACK_DAYS);
        boolean sessionsOk = AndroidUsageNativeBridge.syncRecentSessions(
                context,
                sessionsBeginMs,
                endMs);

        return aggregateOk && sessionsOk ? Result.success() : Result.retry();
    }

    private static long startOfTodayMs() {
        Calendar calendar = Calendar.getInstance();
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar.getTimeInMillis();
    }

    private static final class TimeUnitDays {
        private TimeUnitDays() {}

        static long toMillis(int days) {
            return days * 24L * 60L * 60L * 1000L;
        }
    }
}
