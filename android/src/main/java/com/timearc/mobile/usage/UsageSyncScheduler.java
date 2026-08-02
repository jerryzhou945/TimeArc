package com.timearc.mobile.usage;

import android.content.Context;

import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.ExistingWorkPolicy;
import androidx.work.OneTimeWorkRequest;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;

import java.util.concurrent.TimeUnit;

public final class UsageSyncScheduler {
    public static final String PERIODIC_WORK_NAME = "timearc_android_usage_sync";
    public static final String IMMEDIATE_WORK_NAME = "timearc_android_usage_sync_now";
    public static final int PERIODIC_MINUTES = 15;

    private UsageSyncScheduler() {}

    public static void enqueuePeriodicSync(Context context) {
        if (context == null) {
            return;
        }

        PeriodicWorkRequest request =
                new PeriodicWorkRequest.Builder(
                        UsageSyncWorker.class,
                        PERIODIC_MINUTES,
                        TimeUnit.MINUTES)
                        .build();
        WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                        PERIODIC_WORK_NAME,
                        ExistingPeriodicWorkPolicy.UPDATE,
                        request);
    }

    public static void enqueueImmediateSync(Context context) {
        if (context == null) {
            return;
        }

        OneTimeWorkRequest request =
                new OneTimeWorkRequest.Builder(UsageSyncWorker.class).build();
        WorkManager.getInstance(context)
                .enqueueUniqueWork(
                        IMMEDIATE_WORK_NAME,
                        ExistingWorkPolicy.REPLACE,
                        request);
    }
}
