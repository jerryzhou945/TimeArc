package com.timearc.mobile.usage;

public final class UsageRecordDto {
    public final String packageName;
    public final String appIdentifier;
    public final String appLabel;
    public final String appIconPath;
    public final long firstTimeStampMs;
    public final long lastTimeStampMs;
    public final long totalTimeInForegroundMs;
    public final String source;
    public final long syncedAtUnixSec;

    public UsageRecordDto(
            String packageName,
            String appIdentifier,
            String appLabel,
            String appIconPath,
            long firstTimeStampMs,
            long lastTimeStampMs,
            long totalTimeInForegroundMs,
            String source,
            long syncedAtUnixSec) {
        this.packageName = packageName;
        this.appIdentifier = appIdentifier;
        this.appLabel = appLabel;
        this.appIconPath = appIconPath == null ? "" : appIconPath;
        this.firstTimeStampMs = firstTimeStampMs;
        this.lastTimeStampMs = lastTimeStampMs;
        this.totalTimeInForegroundMs = totalTimeInForegroundMs;
        this.source = source;
        this.syncedAtUnixSec = syncedAtUnixSec;
    }
}
