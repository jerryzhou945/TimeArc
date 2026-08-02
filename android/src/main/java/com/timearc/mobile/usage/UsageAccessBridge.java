package com.timearc.mobile.usage;

import android.app.Activity;
import android.app.AppOpsManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Process;
import android.provider.Settings;
import android.util.Log;

public final class UsageAccessBridge {
    private static final String TAG = "TimeArcUsageAccess";

    private UsageAccessBridge() {}

    public static boolean hasUsageAccess(Context context) {
        if (context == null) {
            return false;
        }

        try {
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
        } catch (Throwable failure) {
            Log.w(TAG, "Usage Access is unavailable in this Android environment", failure);
            return false;
        }
    }

    public static Intent usageAccessSettingsIntent(Context context) {
        Intent intent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
        if (context != null) {
            intent.setData(Uri.parse("package:" + context.getPackageName()));
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return intent;
    }

    private static boolean canResolve(Context context, Intent intent) {
        return context.getPackageManager().resolveActivity(intent, 0) != null;
    }

    public static boolean openUsageAccessSettings(Activity activity) {
        return openUsageAccessSettings((Context) activity);
    }

    public static boolean openUsageAccessSettings(Context context) {
        if (context == null) {
            return false;
        }
        try {
            Intent intent = usageAccessSettingsIntent(context);
            if (!canResolve(context, intent)) {
                Log.w(TAG, "No Usage Access settings activity is available");
                return false;
            }
            context.startActivity(intent);
            return true;
        } catch (Throwable failure) {
            Log.w(TAG, "Could not open Usage Access settings", failure);
            return false;
        }
    }
}
