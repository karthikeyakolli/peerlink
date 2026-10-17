package org.peerlink.app

import org.junit.Assert.*
import org.junit.Test
import org.peerlink.core.android.AndroidNodeContext

class AndroidNodeContextTest {

    @Test
    fun testContextBuilderDefaultValues() {
        val context = AndroidNodeContext.builder()
            .appInForeground(true)
            .powerSaveMode(false)
            .deviceIdleMode(false)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .batteryCharging(true)
            .batteryLevelPercent(95)
            .storagePermissionGranted(true)
            .notificationPermissionGranted(true)
            .nearbyDevicesPermissionGranted(true)
            .build()

        assertTrue(context.isAppInForeground)
        assertFalse(context.isPowerSaveMode)
        assertFalse(context.isDeviceIdleMode)
        assertEquals(AndroidNodeContext.NetworkType.WIFI, context.networkType)
        assertTrue(context.isBatteryCharging)
        assertEquals(95, context.batteryLevelPercent)
        assertTrue(context.isStoragePermissionGranted)
        assertTrue(context.isNotificationPermissionGranted)
        assertTrue(context.isNearbyDevicesPermissionGranted)
    }

    @Test
    fun testContextRestrictedState() {
        val context = AndroidNodeContext.builder()
            .appInForeground(false)
            .powerSaveMode(true)
            .deviceIdleMode(true)
            .networkType(AndroidNodeContext.NetworkType.OFFLINE)
            .batteryCharging(false)
            .batteryLevelPercent(15)
            .storagePermissionGranted(false)
            .notificationPermissionGranted(false)
            .nearbyDevicesPermissionGranted(false)
            .build()

        assertFalse(context.isAppInForeground)
        assertTrue(context.isPowerSaveMode)
        assertTrue(context.isDeviceIdleMode)
        assertEquals(AndroidNodeContext.NetworkType.OFFLINE, context.networkType)
        assertEquals(15, context.batteryLevelPercent)
        assertFalse(context.isStoragePermissionGranted)
    }
}
