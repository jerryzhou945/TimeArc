// SPDX-License-Identifier: GPL-3.0-or-later

package com.timearc.mobile.ui;

import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import java.io.ByteArrayOutputStream;
import java.lang.reflect.Field;
import java.lang.reflect.Method;

public final class WeChatMomentsAdapter {
    private static final String WECHAT_PACKAGE = "com.tencent.mm";
    private static final int WXSceneTimeline = 1;

    private WeChatMomentsAdapter() {
    }

    public static String status(Context context, String appId) {
        if (appId == null || appId.trim().isEmpty()) {
            return "waiting_authorization";
        }
        if (!isPackageInstalled(context, WECHAT_PACKAGE)) {
            return "client_missing";
        }
        try {
            Class.forName("com.tencent.mm.opensdk.openapi.WXAPIFactory");
            Class.forName("com.tencent.mm.opensdk.modelmsg.SendMessageToWX$Req");
            return "ready";
        } catch (Throwable ignored) {
            return "sdk_missing";
        }
    }

    public static String share(Context context, String imagePath,
                               String appId) {
        String current = status(context, appId);
        if (!"ready".equals(current)) {
            return current;
        }
        try {
            Class<?> factory = Class.forName(
                    "com.tencent.mm.opensdk.openapi.WXAPIFactory");
            Method create = factory.getMethod(
                    "createWXAPI", Context.class, String.class, boolean.class);
            Object api = create.invoke(null, context, appId.trim(), true);
            api.getClass().getMethod("registerApp", String.class)
                    .invoke(api, appId.trim());

            Class<?> imageObjectClass = Class.forName(
                    "com.tencent.mm.opensdk.modelmsg.WXImageObject");
            Object imageObject = imageObjectClass
                    .getConstructor(String.class)
                    .newInstance(imagePath);

            Class<?> mediaObjectClass = Class.forName(
                    "com.tencent.mm.opensdk.modelmsg.WXMediaMessage$IMediaObject");
            Class<?> messageClass = Class.forName(
                    "com.tencent.mm.opensdk.modelmsg.WXMediaMessage");
            Object message = messageClass
                    .getConstructor(mediaObjectClass)
                    .newInstance(imageObject);
            byte[] thumbnail = thumbnailFor(imagePath);
            if (thumbnail.length > 0) {
                messageClass.getField("thumbData").set(message, thumbnail);
            }

            Class<?> requestClass = Class.forName(
                    "com.tencent.mm.opensdk.modelmsg.SendMessageToWX$Req");
            Object request = requestClass.getConstructor().newInstance();
            requestClass.getField("transaction").set(
                    request, "timearc-" + System.currentTimeMillis());
            requestClass.getField("message").set(request, message);
            Field scene = requestClass.getField("scene");
            scene.setInt(request, WXSceneTimeline);

            Class<?> baseRequestClass = Class.forName(
                    "com.tencent.mm.opensdk.modelbase.BaseReq");
            Object accepted = api.getClass()
                    .getMethod("sendReq", baseRequestClass)
                    .invoke(api, request);
            return Boolean.TRUE.equals(accepted) ? "launched" : "launch_failed";
        } catch (Throwable ignored) {
            return "launch_failed";
        }
    }

    private static byte[] thumbnailFor(String imagePath) {
        Bitmap source = BitmapFactory.decodeFile(imagePath);
        if (source == null) {
            return new byte[0];
        }
        Bitmap thumbnail = Bitmap.createScaledBitmap(source, 120, 214, true);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        thumbnail.compress(Bitmap.CompressFormat.JPEG, 72, output);
        if (thumbnail != source) {
            thumbnail.recycle();
        }
        source.recycle();
        return output.toByteArray();
    }

    private static boolean isPackageInstalled(Context context,
                                              String packageName) {
        if (context == null) {
            return false;
        }
        try {
            context.getPackageManager().getPackageInfo(packageName, 0);
            return true;
        } catch (PackageManager.NameNotFoundException ignored) {
            return false;
        }
    }
}
