package org.peerlink.linux.os.power;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Linux Power & Suspend Management.
 *
 * Coordinates systemd-inhibit or org.freedesktop.PowerManagement.Inhibit
 * to prevent system sleep/standby while active file transfers are in flight.
 */
public final class LinuxPowerManager {
    private static final Logger log = LoggerFactory.getLogger(LinuxPowerManager.class);

    private static final AtomicInteger activeTransferCount = new AtomicInteger(0);
    private static final AtomicBoolean sleepPrevented = new AtomicBoolean(false);
    private static Process inhibitProcess = null;

    private LinuxPowerManager() {}

    public static synchronized void preventSleepDuringTransfer() {
        int count = activeTransferCount.incrementAndGet();
        if (count == 1) {
            setInhibitState(true);
        }
    }

    public static synchronized void allowSleep() {
        int count = activeTransferCount.decrementAndGet();
        if (count <= 0) {
            activeTransferCount.set(0);
            setInhibitState(false);
        }
    }

    public static boolean isSleepPrevented() {
        return sleepPrevented.get();
    }

    public static int getActiveTransferCount() {
        return activeTransferCount.get();
    }

    private static void setInhibitState(boolean prevent) {
        if (!System.getProperty("os.name", "").toLowerCase().contains("linux")) {
            sleepPrevented.set(prevent);
            return;
        }

        try {
            if (prevent) {
                // Launch systemd-inhibit process holding sleep lock
                inhibitProcess = new ProcessBuilder(
                        "systemd-inhibit",
                        "--why=PeerLink active P2P transfer in progress",
                        "--mode=block",
                        "--what=idle:sleep",
                        "sleep", "infinity"
                ).start();
                sleepPrevented.set(true);
                log.info("Acquired Linux systemd-inhibit sleep lock");
            } else {
                if (inhibitProcess != null && inhibitProcess.isAlive()) {
                    inhibitProcess.destroy();
                    inhibitProcess = null;
                }
                sleepPrevented.set(false);
                log.info("Released Linux systemd-inhibit sleep lock");
            }
        } catch (Exception e) {
            log.debug("systemd-inhibit invocation unviable: {}", e.getMessage());
            sleepPrevented.set(prevent);
        }
    }
}
