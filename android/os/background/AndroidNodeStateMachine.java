package org.peerlink.core.android;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Objects;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Authoritative state machine computing and monitoring the Android node's capability state.
 * Prevents treating battery/constrained mobile devices like desktop daemons.
 */
public class AndroidNodeStateMachine {
    private static final Logger log = LoggerFactory.getLogger(AndroidNodeStateMachine.class);

    public interface StateChangeListener {
        void onStateChanged(AndroidNodeState oldState, AndroidNodeState newState, AndroidNodeContext context);
    }

    private final List<StateChangeListener> listeners = new CopyOnWriteArrayList<>();
    private AndroidNodeContext currentContext;
    private AndroidNodeState currentState;

    public AndroidNodeStateMachine(AndroidNodeContext initialContext) {
        this.currentContext = Objects.requireNonNull(initialContext, "initialContext must not be null");
        this.currentState = evaluateState(this.currentContext);
        log.info("AndroidNodeStateMachine initialized with state: {}", this.currentState);
    }

    public synchronized AndroidNodeState getCurrentState() {
        return currentState;
    }

    public synchronized AndroidNodeContext getCurrentContext() {
        return currentContext;
    }

    public void addListener(StateChangeListener listener) {
        listeners.add(Objects.requireNonNull(listener, "listener must not be null"));
    }

    public void removeListener(StateChangeListener listener) {
        listeners.remove(listener);
    }

    /**
     * Updates the environmental context and recalculates the node state.
     * Fires listeners on any state transition.
     */
    public synchronized AndroidNodeState updateContext(AndroidNodeContext newContext) {
        Objects.requireNonNull(newContext, "newContext must not be null");
        this.currentContext = newContext;
        AndroidNodeState newState = evaluateState(newContext);

        if (newState != currentState) {
            AndroidNodeState oldState = currentState;
            currentState = newState;
            log.info("AndroidNodeState transition: {} -> {} (fg={}, fgs={}, net={}, doze={}, pwrSave={})",
                    oldState, newState,
                    newContext.isAppInForeground(),
                    newContext.hasActiveForegroundService(),
                    newContext.getNetworkType(),
                    newContext.isDeviceIdleMode(),
                    newContext.isPowerSaveMode());

            for (StateChangeListener listener : listeners) {
                try {
                    listener.onStateChanged(oldState, newState, newContext);
                } catch (Exception e) {
                    log.error("Error invoking StateChangeListener", e);
                }
            }
        }
        return currentState;
    }

    /**
     * Evaluates Android OS constraints deterministically.
     */
    public static AndroidNodeState evaluateState(AndroidNodeContext ctx) {
        // 1. Critical unavailability check: network offline or critical storage permission denied
        if (ctx.getNetworkType() == AndroidNodeContext.NetworkType.OFFLINE) {
            return AndroidNodeState.UNAVAILABLE;
        }
        if (!ctx.isStoragePermissionGranted()) {
            return AndroidNodeState.UNAVAILABLE;
        }

        // 2. Active execution: Foreground app OR active Foreground Service with ongoing transfer
        if (ctx.isAppInForeground() || ctx.hasActiveForegroundService()) {
            return AndroidNodeState.ACTIVE;
        }

        // 3. Background execution evaluation (App is backgrounded, no foreground service)
        // If device is in Doze mode (Device Idle), OS freezes network sockets and alarms
        if (ctx.isDeviceIdleMode()) {
            return AndroidNodeState.OS_RESTRICTED;
        }

        // If Power Saver mode is explicitly active, OS restricts background work
        if (ctx.isPowerSaveMode()) {
            return AndroidNodeState.OS_RESTRICTED;
        }

        // If Data Saver is active and network is metered, background transfers are blocked
        if (ctx.isDataSaverActive() && ctx.getNetworkType() == AndroidNodeContext.NetworkType.CELLULAR_METERED) {
            return AndroidNodeState.OS_RESTRICTED;
        }

        // Battery critical and not charging: restrict background transfers to save device
        if (ctx.getBatteryLevelPercent() <= 15 && !ctx.isBatteryCharging()) {
            return AndroidNodeState.OS_RESTRICTED;
        }

        // Otherwise, background conditions allow opportunistic WorkManager jobs (charging or unmetered Wi-Fi)
        return AndroidNodeState.BACKGROUND_CAPABLE;
    }
}
