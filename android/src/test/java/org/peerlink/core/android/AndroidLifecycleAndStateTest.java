package org.peerlink.core.android;

import org.junit.jupiter.api.Test;

import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

class AndroidLifecycleAndStateTest {

    @Test
    void testForegroundAndBackgroundTransitions() {
        // Initial state: Foreground app with unmetered Wi-Fi and good battery
        AndroidNodeContext initialContext = AndroidNodeContext.builder()
                .appInForeground(true)
                .activeForegroundService(false)
                .networkType(AndroidNodeContext.NetworkType.WIFI_UNMETERED)
                .batteryLevelPercent(80)
                .batteryCharging(false)
                .deviceIdleMode(false)
                .powerSaveMode(false)
                .dataSaverActive(false)
                .storagePermissionGranted(true)
                .build();

        AndroidNodeStateMachine sm = new AndroidNodeStateMachine(initialContext);
        assertEquals(AndroidNodeState.ACTIVE, sm.getCurrentState());

        AtomicInteger transitionCount = new AtomicInteger(0);
        sm.addListener((oldState, newState, ctx) -> {
            transitionCount.incrementAndGet();
        });

        // Transition 1: Background app without foreground service -> BACKGROUND_CAPABLE
        AndroidNodeContext bgContext = initialContext.toBuilder()
                .appInForeground(false)
                .build();
        sm.updateContext(bgContext);
        assertEquals(AndroidNodeState.BACKGROUND_CAPABLE, sm.getCurrentState());
        assertEquals(1, transitionCount.get());

        // Transition 2: Start foreground data sync service while backgrounded -> ACTIVE
        AndroidNodeContext fgsContext = bgContext.toBuilder()
                .activeForegroundService(true)
                .build();
        sm.updateContext(fgsContext);
        assertEquals(AndroidNodeState.ACTIVE, sm.getCurrentState());
        assertEquals(2, transitionCount.get());

        // Transition 3: Foreground service stops, device enters Doze (Idle) -> OS_RESTRICTED
        AndroidNodeContext dozeContext = bgContext.toBuilder()
                .activeForegroundService(false)
                .deviceIdleMode(true)
                .build();
        sm.updateContext(dozeContext);
        assertEquals(AndroidNodeState.OS_RESTRICTED, sm.getCurrentState());
        assertEquals(3, transitionCount.get());
    }

    @Test
    void testPowerSaverAndBatteryConstraints() {
        AndroidNodeContext baseBgContext = AndroidNodeContext.builder()
                .appInForeground(false)
                .activeForegroundService(false)
                .networkType(AndroidNodeContext.NetworkType.WIFI_UNMETERED)
                .batteryLevelPercent(50)
                .batteryCharging(false)
                .deviceIdleMode(false)
                .powerSaveMode(false)
                .dataSaverActive(false)
                .storagePermissionGranted(true)
                .build();

        AndroidNodeStateMachine sm = new AndroidNodeStateMachine(baseBgContext);
        assertEquals(AndroidNodeState.BACKGROUND_CAPABLE, sm.getCurrentState());

        // Low battery <= 15% and not charging -> OS_RESTRICTED
        AndroidNodeContext lowBatteryContext = baseBgContext.toBuilder()
                .batteryLevelPercent(10)
                .batteryCharging(false)
                .build();
        sm.updateContext(lowBatteryContext);
        assertEquals(AndroidNodeState.OS_RESTRICTED, sm.getCurrentState());

        // Plugging into charger lifts battery restriction -> BACKGROUND_CAPABLE
        AndroidNodeContext chargingContext = lowBatteryContext.toBuilder()
                .batteryCharging(true)
                .build();
        sm.updateContext(chargingContext);
        assertEquals(AndroidNodeState.BACKGROUND_CAPABLE, sm.getCurrentState());

        // Enabling Power Save Mode -> OS_RESTRICTED
        AndroidNodeContext pwrSaveContext = chargingContext.toBuilder()
                .powerSaveMode(true)
                .build();
        sm.updateContext(pwrSaveContext);
        assertEquals(AndroidNodeState.OS_RESTRICTED, sm.getCurrentState());
    }

    @Test
    void testStoragePermissionDenialAndOfflineUnavailability() {
        AndroidNodeContext context = AndroidNodeContext.builder()
                .appInForeground(true)
                .activeForegroundService(false)
                .networkType(AndroidNodeContext.NetworkType.WIFI_UNMETERED)
                .batteryLevelPercent(90)
                .storagePermissionGranted(true)
                .build();

        AndroidNodeStateMachine sm = new AndroidNodeStateMachine(context);
        assertEquals(AndroidNodeState.ACTIVE, sm.getCurrentState());

        // Storage permission revoked by user -> UNAVAILABLE
        AndroidNodeContext noStorageContext = context.toBuilder()
                .storagePermissionGranted(false)
                .build();
        sm.updateContext(noStorageContext);
        assertEquals(AndroidNodeState.UNAVAILABLE, sm.getCurrentState());

        // Network goes offline -> UNAVAILABLE
        AndroidNodeContext offlineContext = context.toBuilder()
                .networkType(AndroidNodeContext.NetworkType.OFFLINE)
                .build();
        sm.updateContext(offlineContext);
        assertEquals(AndroidNodeState.UNAVAILABLE, sm.getCurrentState());
    }
}
