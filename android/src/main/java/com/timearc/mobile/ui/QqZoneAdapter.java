// SPDX-License-Identifier: GPL-3.0-or-later

package com.timearc.mobile.ui;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Bundle;

import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.ArrayList;

public final class QqZoneAdapter {
    private static final String QQ_PACKAGE = "com.tencent.mobileqq";
    private static final String QZONE_PACKAGE = "com.qzone";

    private QqZoneAdapter() {
    }

    public static String status(Context context, String appId) {
        if (appId == null || appId.trim().isEmpty()) {
            return "waiting_authorization";
        }
        if (!isPackageInstalled(context, QQ_PACKAGE)
                && !isPackageInstalled(context, QZONE_PACKAGE)) {
            return "client_missing";
        }
        try {
            Class.forName("com.tencent.tauth.Tencent");
            Class.forName("com.tencent.tauth.IUiListener");
            return "ready";
        } catch (Throwable ignored) {
            return "sdk_missing";
        }
    }

    public static String share(Context context, String imagePath,
                               String appId, String summary) {
        String current = status(context, appId);
        if (!"ready".equals(current)) {
            return current;
        }
        if (!(context instanceof Activity)) {
            return "launch_failed";
        }
        try {
            Class<?> tencentClass = Class.forName("com.tencent.tauth.Tencent");
            Object tencent = tencentClass
                    .getMethod("createInstance", String.class, Context.class)
                    .invoke(null, appId.trim(), context.getApplicationContext());

            Bundle values = new Bundle();
            values.putInt("req_type", 4);
            values.putString("summary",
                    summary == null ? "TimeArc 时间纪念卡" : summary);
            ArrayList<String> images = new ArrayList<>();
            images.add(imagePath);
            values.putStringArrayList("imageUrl", images);

            Class<?> listenerClass = Class.forName(
                    "com.tencent.tauth.IUiListener");
            Object listener = Proxy.newProxyInstance(
                    listenerClass.getClassLoader(),
                    new Class<?>[]{listenerClass},
                    (proxy, method, args) -> null);
            Method publishToQzone = tencentClass.getMethod(
                    "publishToQzone",
                    Activity.class,
                    Bundle.class,
                    listenerClass);
            publishToQzone.invoke(
                    tencent, (Activity) context, values, listener);
            return "launched";
        } catch (Throwable ignored) {
            return "launch_failed";
        }
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
