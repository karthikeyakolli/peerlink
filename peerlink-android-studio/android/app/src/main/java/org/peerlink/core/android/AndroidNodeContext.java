package org.peerlink.core.android;

import java.util.Objects;

/**
 * Snapshot of Android device environmental constraints and hardware status.
 */
public final class AndroidNodeContext {

    public enum NetworkType {
        OFFLINE,
        WIFI,
        ETHERNET,
        CELLULAR_UNMETERED,
        CELLULAR_METERED,
        OTHER
    }

    private final boolean appInForeground;
    private final boolean activeForegroundService;
    private final boolean powerSaveMode;
    private final boolean deviceIdleMode; // Doze mode
    private final boolean dataSaverActive;
    private final NetworkType networkType;
    private final boolean batteryCharging;
    private final int batteryLevelPercent;
    private final boolean storagePermissionGranted;
    private final boolean notificationPermissionGranted;
    private final boolean nearbyDevicesPermissionGranted;
    private final boolean localNetworkPermissionGranted;
    private final boolean cameraPermissionGranted;

    public AndroidNodeContext(Builder builder) {
        this.appInForeground = builder.appInForeground;
        this.activeForegroundService = builder.activeForegroundService;
        this.powerSaveMode = builder.powerSaveMode;
        this.deviceIdleMode = builder.deviceIdleMode;
        this.dataSaverActive = builder.dataSaverActive;
        this.networkType = builder.networkType;
        this.batteryCharging = builder.batteryCharging;
        this.batteryLevelPercent = builder.batteryLevelPercent;
        this.storagePermissionGranted = builder.storagePermissionGranted;
        this.notificationPermissionGranted = builder.notificationPermissionGranted;
        this.nearbyDevicesPermissionGranted = builder.nearbyDevicesPermissionGranted;
        this.localNetworkPermissionGranted = builder.localNetworkPermissionGranted;
        this.cameraPermissionGranted = builder.cameraPermissionGranted;
    }

    public boolean isAppInForeground() {
        return appInForeground;
    }

    public boolean hasActiveForegroundService() {
        return activeForegroundService;
    }

    public boolean isPowerSaveMode() {
        return powerSaveMode;
    }

    public boolean isDeviceIdleMode() {
        return deviceIdleMode;
    }

    public boolean isDataSaverActive() {
        return dataSaverActive;
    }

    public NetworkType getNetworkType() {
        return networkType;
    }

    public boolean isBatteryCharging() {
        return batteryCharging;
    }

    public int getBatteryLevelPercent() {
        return batteryLevelPercent;
    }

    public boolean isStoragePermissionGranted() {
        return storagePermissionGranted;
    }

    public boolean isNotificationPermissionGranted() {
        return notificationPermissionGranted;
    }

    public boolean isNearbyDevicesPermissionGranted() {
        return nearbyDevicesPermissionGranted;
    }

    public boolean isLocalNetworkPermissionGranted() {
        return localNetworkPermissionGranted;
    }

    public boolean isCameraPermissionGranted() {
        return cameraPermissionGranted;
    }

    public static Builder builder() {
        return new Builder();
    }

    public static final class Builder {
        private boolean appInForeground = true;
        private boolean activeForegroundService = false;
        private boolean powerSaveMode = false;
        private boolean deviceIdleMode = false;
        private boolean dataSaverActive = false;
        private NetworkType networkType = NetworkType.WIFI;
        private boolean batteryCharging = true;
        private int batteryLevelPercent = 100;
        private boolean storagePermissionGranted = true;
        private boolean notificationPermissionGranted = true;
        private boolean nearbyDevicesPermissionGranted = true;
        private boolean localNetworkPermissionGranted = true;
        private boolean cameraPermissionGranted = true;

        public Builder appInForeground(boolean appInForeground) {
            this.appInForeground = appInForeground;
            return this;
        }

        public Builder activeForegroundService(boolean activeForegroundService) {
            this.activeForegroundService = activeForegroundService;
            return this;
        }

        public Builder powerSaveMode(boolean powerSaveMode) {
            this.powerSaveMode = powerSaveMode;
            return this;
        }

        public Builder deviceIdleMode(boolean deviceIdleMode) {
            this.deviceIdleMode = deviceIdleMode;
            return this;
        }

        public Builder dataSaverActive(boolean dataSaverActive) {
            this.dataSaverActive = dataSaverActive;
            return this;
        }

        public Builder networkType(NetworkType networkType) {
            this.networkType = Objects.requireNonNull(networkType, "networkType must not be null");
            return this;
        }

        public Builder batteryCharging(boolean batteryCharging) {
            this.batteryCharging = batteryCharging;
            return this;
        }

        public Builder batteryLevelPercent(int batteryLevelPercent) {
            this.batteryLevelPercent = batteryLevelPercent;
            return this;
        }

        public Builder storagePermissionGranted(boolean storagePermissionGranted) {
            this.storagePermissionGranted = storagePermissionGranted;
            return this;
        }

        public Builder notificationPermissionGranted(boolean notificationPermissionGranted) {
            this.notificationPermissionGranted = notificationPermissionGranted;
            return this;
        }

        public Builder nearbyDevicesPermissionGranted(boolean nearbyDevicesPermissionGranted) {
            this.nearbyDevicesPermissionGranted = nearbyDevicesPermissionGranted;
            return this;
        }

        public Builder localNetworkPermissionGranted(boolean localNetworkPermissionGranted) {
            this.localNetworkPermissionGranted = localNetworkPermissionGranted;
            return this;
        }

        public Builder cameraPermissionGranted(boolean cameraPermissionGranted) {
            this.cameraPermissionGranted = cameraPermissionGranted;
            return this;
        }

        public AndroidNodeContext build() {
            return new AndroidNodeContext(this);
        }
    }
}
