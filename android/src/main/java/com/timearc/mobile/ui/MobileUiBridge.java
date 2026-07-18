// SPDX-License-Identifier: GPL-3.0-or-later

package com.timearc.mobile.ui;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

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
}
