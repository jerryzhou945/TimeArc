package com.timearc.mobile.usage;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import java.util.Calendar;

public final class UsageSyncWorker extends Worker {
    private static final int RECENT_SESSION_LOOKBACK_DAYS = 35;

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
            AndroidUsageNativeBridge.notifySyncFinished(false);
            return Result.success();
        }

        long endMs = System.currentTimeMillis();
        Calendar calendar = startOfPreviousMonth();
        long dayStartMs = calendar.getTimeInMillis();
        boolean aggregateOk = true;
        while (dayStartMs < endMs) {
            calendar.add(Calendar.DAY_OF_MONTH, 1);
            long dayEndMs = Math.min(calendar.getTimeInMillis(), endMs);
            if (!AndroidUsageNativeBridge.syncAggregatedUsage(context, dayStartMs, dayEndMs)) {
                aggregateOk = false;
                break;
            }
            dayStartMs = dayEndMs;
        }

        long sessionsBeginMs = endMs -
                TimeUnitDays.toMillis(RECENT_SESSION_LOOKBACK_DAYS);
        boolean sessionsOk = AndroidUsageNativeBridge.syncRecentSessions(
                context,
                sessionsBeginMs,
                endMs);

        boolean syncOk = aggregateOk && sessionsOk;
        AndroidUsageNativeBridge.notifySyncFinished(syncOk);
        return syncOk ? Result.success() : Result.retry();
    }

    private static Calendar startOfPreviousMonth() {
        Calendar calendar = Calendar.getInstance();
        calendar.set(Calendar.DAY_OF_MONTH, 1);
        calendar.add(Calendar.MONTH, -1);
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar;
    }

    private static final class TimeUnitDays {
        private TimeUnitDays() {}

        static long toMillis(int days) {
            return days * 24L * 60L * 60L * 1000L;
        }
    }
}
