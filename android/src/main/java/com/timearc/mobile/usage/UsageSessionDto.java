package com.timearc.mobile.usage;

public final class UsageSessionDto {
    public final String packageName;
    public final String appIdentifier;
    public final String appLabel;
    public final long startTimeMs;
    public final long endTimeMs;
    public final long durationMs;
    public final String source;
    public final String confidence;

    public UsageSessionDto(
            String packageName,
            String appIdentifier,
            String appLabel,
            long startTimeMs,
            long endTimeMs,
            String source,
            String confidence) {
        this.packageName = packageName;
        this.appIdentifier = appIdentifier;
        this.appLabel = appLabel;
        this.startTimeMs = startTimeMs;
        this.endTimeMs = endTimeMs;
        this.durationMs = Math.max(0L, endTimeMs - startTimeMs);
        this.source = source;
        this.confidence = confidence == null || confidence.isEmpty()
                ? "observed"
                : confidence;
    }
}
