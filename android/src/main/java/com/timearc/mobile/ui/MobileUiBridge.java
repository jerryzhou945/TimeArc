// SPDX-License-Identifier: GPL-3.0-or-later

package com.timearc.mobile.ui;

import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;

import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

public final class MobileUiBridge {
    private MobileUiBridge() {
    }

    public static boolean copyUriToFile(Context context, String uriValue,
                                        String targetPath) {
        if (context == null || uriValue == null || targetPath == null) {
            return false;
        }
        try (InputStream input = context.getContentResolver()
                .openInputStream(Uri.parse(uriValue));
             FileOutputStream output = new FileOutputStream(targetPath)) {
            if (input == null) {
                return false;
            }
            byte[] buffer = new byte[64 * 1024];
            int read;
            while ((read = input.read(buffer)) >= 0) {
                output.write(buffer, 0, read);
            }
            output.flush();
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }

    public static boolean shareImage(Context context, String pathValue,
                                     String title) {
        if (context == null || pathValue == null) {
            return false;
        }
        try {
            File file = new File(pathValue);
            Uri uri = FileProvider.getUriForFile(
                    context, context.getPackageName() + ".qtprovider", file);
            Intent intent = new Intent(Intent.ACTION_SEND);
            intent.setType("image/png");
            intent.putExtra(Intent.EXTRA_STREAM, uri);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            Intent chooser = Intent.createChooser(
                    intent, title == null ? "分享时间纪念卡" : title);
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(chooser);
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }

    public static String saveImageToGallery(Context context, String pathValue,
                                            String albumName) {
        if (context == null || pathValue == null) {
            return "";
        }
        File source = new File(pathValue);
        if (!source.isFile() || source.length() <= 0) {
            return "";
        }
        String safeAlbum = albumName == null || albumName.trim().isEmpty()
                ? "TimeArc" : albumName.trim();
        String displayName = source.getName().endsWith(".png")
                ? source.getName()
                : "timearc-" + System.currentTimeMillis() + ".png";

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentValues values = new ContentValues();
            values.put(MediaStore.MediaColumns.DISPLAY_NAME, displayName);
            values.put(MediaStore.MediaColumns.MIME_TYPE, "image/png");
            values.put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/TimeArc");
            values.put(MediaStore.MediaColumns.IS_PENDING, 1);
            Uri target = null;
            try {
                target = context.getContentResolver().insert(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
                if (target == null) {
                    return "";
                }
                try (InputStream input = new FileInputStream(source);
                     OutputStream output = context.getContentResolver()
                             .openOutputStream(target, "w")) {
                    if (output == null) {
                        context.getContentResolver().delete(target, null, null);
                        return "";
                    }
                    copyStream(input, output);
                }
                ContentValues ready = new ContentValues();
                ready.put(MediaStore.MediaColumns.IS_PENDING, 0);
                context.getContentResolver().update(target, ready, null, null);
                return target.toString();
            } catch (Exception ignored) {
                if (target != null) {
                    context.getContentResolver().delete(target, null, null);
                }
                return "";
            }
        }

        File pictures = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_PICTURES);
        File directory = new File(pictures, safeAlbum);
        if (!directory.exists() && !directory.mkdirs()) {
            return "";
        }
        File target = new File(directory, displayName);
        try (InputStream input = new FileInputStream(source);
             OutputStream output = new FileOutputStream(target)) {
            copyStream(input, output);
            MediaScannerConnection.scanFile(
                    context,
                    new String[]{target.getAbsolutePath()},
                    new String[]{"image/png"},
                    null);
            return Uri.fromFile(target).toString();
        } catch (Exception ignored) {
            if (target.exists()) {
                target.delete();
            }
            return "";
        }
    }

    public static String socialShareStatus(Context context, String channel,
                                           String appId) {
        if ("moments".equals(channel)) {
            return WeChatMomentsAdapter.status(context, appId);
        }
        if ("qzone".equals(channel)) {
            return QqZoneAdapter.status(context, appId);
        }
        if ("gallery".equals(channel) || "system".equals(channel)) {
            return "ready";
        }
        return "launch_failed";
    }

    public static String shareImageToChannel(
            Context context, String pathValue, String channel,
            String title, String appId) {
        if ("moments".equals(channel)) {
            return WeChatMomentsAdapter.share(context, pathValue, appId);
        }
        if ("qzone".equals(channel)) {
            return QqZoneAdapter.share(
                    context, pathValue, appId,
                    title == null ? "TimeArc 时间纪念卡" : title);
        }
        if ("system".equals(channel)) {
            return shareImage(context, pathValue, title)
                    ? "launched" : "launch_failed";
        }
        if ("gallery".equals(channel)) {
            return "saved";
        }
        return "launch_failed";
    }

    private static void copyStream(InputStream input, OutputStream output)
            throws Exception {
        byte[] buffer = new byte[64 * 1024];
        int read;
        while ((read = input.read(buffer)) >= 0) {
            output.write(buffer, 0, read);
        }
        output.flush();
    }
}
