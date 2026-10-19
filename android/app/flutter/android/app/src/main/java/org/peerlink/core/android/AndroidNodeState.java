package org.peerlink.core.android;

/**
 * Android-specific node lifecycle and capability states.
 * Android OS strictly constrains background execution, battery, and networking.
 */
public enum AndroidNodeState {
    /**
     * App is in the active foreground, or a Foreground Service with an active
     * notification is keeping high-performance networking and transfers alive.
     */
    ACTIVE,

    /**
     * App is in the background, but operating under allowed system conditions
     * (e.g. WorkManager job running on unmetered network/charging, or background
     * task within grace period). Sockets may be throttled.
     */
    BACKGROUND_CAPABLE,

    /**
     * Android OS is restricting background activity:
     * - Doze mode (Device Idle)
     * - Battery Saver mode enabled
     * - Background Data Saver restricted
     * - Background clipboard access prohibited (Android 10+)
     */
    OS_RESTRICTED,

    /**
     * Node cannot operate:
     * - Network disconnected or in Airplane mode
     * - Process terminating or killed
     * - Missing critical required permissions
     */
    UNAVAILABLE
}
