package com.timearc.mobile.usage;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.os.Build;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

public final class AndroidAppMetadataResolver {
    private static final int ICON_SIZE_PX = 96;

    private AndroidAppMetadataResolver() {}

    public static final class AppMetadata {
        public final String label;
        public final String iconPath;

        AppMetadata(String label, String iconPath) {
            this.label = label == null ? "" : label;
            this.iconPath = iconPath == null ? "" : iconPath;
        }
    }

    public static AppMetadata resolve(Context context, String packageName) {
        if (context == null || packageName == null || packageName.trim().isEmpty()) {
            return new AppMetadata(packageName == null ? "" : packageName, "");
        }

        PackageManager packageManager = context.getPackageManager();
        String label = packageName;
        String iconPath = "";

        try {
            ApplicationInfo info = getApplicationInfo(packageManager, packageName);
            CharSequence appLabel = packageManager.getApplicationLabel(info);
            if (appLabel != null && appLabel.length() > 0) {
                label = appLabel.toString();
            }
            iconPath = writeIconPng(context, packageManager, packageName);
        } catch (PackageManager.NameNotFoundException ignored) {
        }

        return new AppMetadata(label, iconPath);
    }

    private static ApplicationInfo getApplicationInfo(
            PackageManager packageManager,
            String packageName) throws PackageManager.NameNotFoundException {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0));
        }
        return packageManager.getApplicationInfo(packageName, 0);
    }

    private static String writeIconPng(
            Context context,
            PackageManager packageManager,
            String packageName) {
        try {
            File iconDir = new File(context.getFilesDir(), "app-icons");
            if (!iconDir.exists() && !iconDir.mkdirs()) {
                return "";
            }

            File iconFile = new File(iconDir, safeFileName(packageName) + ".png");
            if (iconFile.isFile() && iconFile.length() > 0L) {
                return iconFile.getAbsolutePath();
            }

            Drawable drawable = packageManager.getApplicationIcon(packageName);
            Bitmap bitmap = drawableToBitmap(drawable);
            try (FileOutputStream stream = new FileOutputStream(iconFile)) {
                if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                    return "";
                }
            }
            return iconFile.getAbsolutePath();
        } catch (PackageManager.NameNotFoundException | IOException | RuntimeException ignored) {
            return "";
        }
    }

    private static Bitmap drawableToBitmap(Drawable drawable) {
        Bitmap bitmap =
                Bitmap.createBitmap(ICON_SIZE_PX, ICON_SIZE_PX, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        drawable.setBounds(0, 0, ICON_SIZE_PX, ICON_SIZE_PX);
        drawable.draw(canvas);
        return bitmap;
    }

    private static String safeFileName(String packageName) {
        return packageName.replaceAll("[^A-Za-z0-9._-]", "_");
    }
}
