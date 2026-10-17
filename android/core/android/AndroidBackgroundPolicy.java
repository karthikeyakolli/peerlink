package org.peerlink.core.android;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Enforces Android WorkManager and Foreground Service scheduling constraints.
 * Ensures PeerLink respects OS battery conservation, Doze mode, and data usage limits.
 */
public final class AndroidBackgroundPolicy {
    private static final Logger log = LoggerFactory.getLogger(AndroidBackgroundPolicy.class);

    // Minimum size or duration that mandates a Foreground Service with persistent notification
    public static final long FOREGROUND_SERVICE_SIZE_THRESHOLD_BYTES = 5 * 1024 * 1024L; // 5 MB
    public static final int FOREGROUND_SERVICE_DURATION_THRESHOLD_SEC = 5; // 5 seconds

    private AndroidBackgroundPolicy() {}

    /**
     * Determines if opportunistic background sync (via WorkManager) is permissible.
     */
    public static boolean canRunBackgroundSync(AndroidNodeContext ctx) {
        if (ctx.isDeviceIdleMode() || ctx.isPowerSaveMode()) {
            log.debug("Background sync blocked: device in Doze or Power Save mode");
            return false;
        }

        if (ctx.getNetworkType() == AndroidNodeContext.NetworkType.OFFLINE) {
            return false;
        }

        // On metered network, only sync if Data Saver is off and battery is healthy
        if (ctx.getNetworkType() == AndroidNodeContext.NetworkType.CELLULAR_METERED) {
            if (ctx.isDataSaverActive()) return false;
            return ctx.getBatteryLevelPercent() > 30 || ctx.isBatteryCharging();
        }

        // On Wi-Fi / unmetered: allowed if battery > 15% or charging
        return ctx.getBatteryLevelPercent() > 15 || ctx.isBatteryCharging();
    }

    /**
     * Determines if automated background backup is permissible.
     * Stricter than sync: requires unmetered network and charging or high battery (> 50%).
     */
    public static boolean canRunBackgroundBackup(AndroidNodeContext ctx) {
        if (ctx.isDeviceIdleMode() || ctx.isPowerSaveMode()) {
            return false;
        }

        if (ctx.getNetworkType() != AndroidNodeContext.NetworkType.WIFI &&
            ctx.getNetworkType() != AndroidNodeContext.NetworkType.ETHERNET &&
            ctx.getNetworkType() != AndroidNodeContext.NetworkType.CELLULAR_UNMETERED) {
            log.debug("Background backup requires unmetered network");
            return false;
        }

        return ctx.isBatteryCharging() || ctx.getBatteryLevelPercent() >= 60;
    }

    /**
     * Evaluates whether an active transfer operation requires promoting the app
     * to a Foreground Service (with FOREGROUND_SERVICE_TYPE_DATA_SYNC).
     */
    public static boolean requiresForegroundService(long totalBytes, int estimatedSeconds) {
        return totalBytes >= FOREGROUND_SERVICE_SIZE_THRESHOLD_BYTES ||
               estimatedSeconds >= FOREGROUND_SERVICE_DURATION_THRESHOLD_SEC;
    }

    /**
     * Evaluates if active transfer throughput should be throttled due to environmental constraints.
     */
    public static boolean shouldThrottleTransfer(AndroidNodeContext ctx) {
        if (ctx.getNetworkType() == AndroidNodeContext.NetworkType.CELLULAR_METERED) {
            return true;
        }
        return !ctx.isBatteryCharging() && ctx.getBatteryLevelPercent() <= 20;
    }
}
