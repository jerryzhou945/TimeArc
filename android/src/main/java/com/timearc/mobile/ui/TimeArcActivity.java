// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 TimeArc contributors

package com.timearc.mobile.ui;

import android.os.Bundle;

import com.timearc.mobile.usage.UsageSyncScheduler;

public final class TimeArcActivity
        extends org.qtproject.qt.android.bindings.QtActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        MobileUiBridge.configureEdgeToEdge(this, false);
    }

    @Override
    protected void onResume() {
        super.onResume();
        MobileUiBridge.configureEdgeToEdge(this, false);
        UsageSyncScheduler.enqueueImmediateSync(this);
    }
}
