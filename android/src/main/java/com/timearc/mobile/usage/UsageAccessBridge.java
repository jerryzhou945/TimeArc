package com.timearc.mobile.usage;

import android.app.Activity;
import android.app.AppOpsManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Process;
import android.provider.Settings;

public final class UsageAccessBridge {
    private UsageAccessBridge() {}

    public static boolean hasUsageAccess(Context context) {
        if (context == null) {
            return false;
        }

        AppOpsManager appOps =
                (AppOpsManager) context.getSystemService(Context.APP_OPS_SERVICE);
        if (appOps == null) {
            return false;
        }

        int mode;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            mode = appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.getPackageName());
        } else {
            mode = appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.getPackageName());
        }

        return mode == AppOpsManager.MODE_ALLOWED;
    }

    public static Intent usageAccessSettingsIntent(Context context) {
        Intent intent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
        if (context != null) {
            intent.setData(Uri.parse("package:" + context.getPackageName()));
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return intent;
    }

    public static void openUsageAccessSettings(Activity activity) {
        if (activity == null) {
            return;
        }
        activity.startActivity(usageAccessSettingsIntent(activity));
    }

    public static void openUsageAccessSettings(Context context) {
        if (context == null) {
            return;
        }
        context.startActivity(usageAccessSettingsIntent(context));
    }
}
