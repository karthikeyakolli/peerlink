package org.peerlink.windows.os.power;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Windows Power Management & Sleep Prevention.
 *
 * Uses Win32 SetThreadExecutionState via PowerShell P/Invoke to prevent
 * the host system from sleeping or suspending network adapters during active file transfers.
 */
public final class WindowsPowerManager {
    private static final Logger log = LoggerFactory.getLogger(WindowsPowerManager.class);

    private static final AtomicInteger activeTransferCount = new AtomicInteger(0);
    private static final AtomicBoolean sleepPrevented = new AtomicBoolean(false);

    private WindowsPowerManager() {}

    /**
     * Increments active transfer counter and prevents system standby.
     */
    public static synchronized void preventSleepDuringTransfer() {
        int count = activeTransferCount.incrementAndGet();
        if (count == 1) {
            setExecutionState(true);
        }
    }

    /**
     * Decrements active transfer counter and restores sleep when transfers hit zero.
     */
    public static synchronized void allowSleep() {
        int count = activeTransferCount.decrementAndGet();
        if (count <= 0) {
            activeTransferCount.set(0);
            setExecutionState(false);
        }
    }

    public static boolean isSleepPrevented() {
        return sleepPrevented.get();
    }

    public static int getActiveTransferCount() {
        return activeTransferCount.get();
    }

    private static void setExecutionState(boolean prevent) {
        if (!System.getProperty("os.name", "").toLowerCase().contains("win")) {
            return;
        }

        try {
            // ES_CONTINUOUS = 0x80000000, ES_SYSTEM_REQUIRED = 0x00000001, ES_AWAYMODE_REQUIRED = 0x00000040
            String command = prevent
                    ? "$code = '[DllImport(\"kernel32.dll\")] public static extern uint SetThreadExecutionState(uint esFlags);'; " +
                      "$type = Add-Type -MemberDefinition $code -Name Win32Power -Namespace Win32 -PassThru; " +
                      "[void]$type::SetThreadExecutionState(0x80000001)"
                    : "$code = '[DllImport(\"kernel32.dll\")] public static extern uint SetThreadExecutionState(uint esFlags);'; " +
                      "$type = Add-Type -MemberDefinition $code -Name Win32Power -Namespace Win32 -PassThru; " +
                      "[void]$type::SetThreadExecutionState(0x80000000)";

            new ProcessBuilder("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command).start();
            sleepPrevented.set(prevent);
            log.info("Windows execution state updated: sleepPrevented={}", prevent);
        } catch (Exception e) {
            log.warn("Failed to set Windows thread execution state: {}", e.getMessage());
        }
    }
}
