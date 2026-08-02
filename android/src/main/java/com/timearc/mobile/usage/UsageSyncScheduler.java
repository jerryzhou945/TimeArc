package com.timearc.mobile.usage;

import android.content.Context;
import android.util.Log;

import androidx.work.Configuration;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.ExistingWorkPolicy;
import androidx.work.OneTimeWorkRequest;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;

import java.util.concurrent.TimeUnit;

public final class UsageSyncScheduler {
    private static final String TAG = "TimeArcUsageSync";
    public static final String PERIODIC_WORK_NAME = "timearc_android_usage_sync";
    public static final String IMMEDIATE_WORK_NAME = "timearc_android_usage_sync_now";
    public static final int PERIODIC_MINUTES = 15;

    private UsageSyncScheduler() {}

    private static WorkManager workManager(Context context) {
        if (context == null) {
            return null;
        }
        Context appContext = context.getApplicationContext();
        if (appContext == null) {
            appContext = context;
        }
        try {
            try {
                WorkManager.initialize(
                        appContext,
                        new Configuration.Builder().build());
            } catch (IllegalStateException alreadyInitialized) {
                // Normal Android builds may initialize WorkManager elsewhere.
            }
            return WorkManager.getInstance(appContext);
        } catch (Throwable failure) {
            Log.w(TAG, "WorkManager is unavailable in this Android environment", failure);
            return null;
        }
    }

    public static boolean enqueuePeriodicSync(Context context) {
        WorkManager manager = workManager(context);
        if (manager == null) {
            return false;
        }

        try {
            PeriodicWorkRequest request =
                    new PeriodicWorkRequest.Builder(
                            UsageSyncWorker.class,
                            PERIODIC_MINUTES,
                            TimeUnit.MINUTES)
                            .build();
            manager.enqueueUniquePeriodicWork(
                        PERIODIC_WORK_NAME,
                        ExistingPeriodicWorkPolicy.UPDATE,
                        request);
            return true;
        } catch (Throwable failure) {
            Log.w(TAG, "Could not enqueue periodic usage sync", failure);
            return false;
        }
    }

    public static boolean enqueueImmediateSync(Context context) {
        WorkManager manager = workManager(context);
        if (manager == null) {
            return false;
        }

        try {
            OneTimeWorkRequest request =
                    new OneTimeWorkRequest.Builder(UsageSyncWorker.class).build();
            manager.enqueueUniqueWork(
                        IMMEDIATE_WORK_NAME,
                        ExistingWorkPolicy.REPLACE,
                        request);
            return true;
        } catch (Throwable failure) {
            Log.w(TAG, "Could not enqueue immediate usage sync", failure);
            return false;
        }
    }
}
