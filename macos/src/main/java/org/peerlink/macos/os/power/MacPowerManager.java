package org.peerlink.macos.os.power;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/**
 * macOS Power Management integration.
 * Prevents system idle sleep during active file transfers using macOS /usr/bin/caffeinate,
 * with reference-counted lock acquisition and release.
 */
public class MacPowerManager {

    private static final Logger log = LoggerFactory.getLogger(MacPowerManager.class);

    private final Set<String> activeTransferIds = Collections.synchronizedSet(new HashSet<>());
    private Process caffeinateProcess = null;
    private final boolean simulationMode;

    public MacPowerManager() {
        this(false);
    }

    public MacPowerManager(boolean simulationMode) {
        this.simulationMode = simulationMode;
    }

    /**
     * Acquires a system sleep lock for an active transfer.
     */
    public synchronized boolean acquireSleepLock(String transferId) {
        if (transferId == null || transferId.isBlank()) {
            return false;
        }

        activeTransferIds.add(transferId);
        log.info("Acquired macOS sleep lock for transfer {}. Total active locks: {}",
                transferId, activeTransferIds.size());

        if (caffeinateProcess == null || !caffeinateProcess.isAlive()) {
            startCaffeinateProcess();
        }

        return true;
    }

    /**
     * Releases the sleep lock for a completed or failed transfer.
     */
    public synchronized boolean releaseSleepLock(String transferId) {
        if (transferId == null) {
            return false;
        }

        boolean removed = activeTransferIds.remove(transferId);
        log.info("Released macOS sleep lock for transfer {}. Remaining locks: {}",
                transferId, activeTransferIds.size());

        if (activeTransferIds.isEmpty() && caffeinateProcess != null) {
            stopCaffeinateProcess();
        }

        return removed;
    }

    private void startCaffeinateProcess() {
        if (simulationMode) {
            log.debug("Simulation mode: caffeinate process start simulated");
            return;
        }

        try {
            ProcessBuilder pb = new ProcessBuilder("/usr/bin/caffeinate", "-i", "-s", "-m");
            caffeinateProcess = pb.start();
            log.info("Spawned macOS caffeinate process (PID: {}) to inhibit system sleep", caffeinateProcess.pid());
        } catch (IOException e) {
            log.warn("Failed to spawn macOS caffeinate process (sleep lock unavailable): {}", e.getMessage());
            caffeinateProcess = null;
        }
    }

    private void stopCaffeinateProcess() {
        if (caffeinateProcess != null) {
            try {
                caffeinateProcess.destroy();
                log.info("Terminated macOS caffeinate sleep lock process");
            } catch (Exception e) {
                log.warn("Error stopping caffeinate process: {}", e.getMessage());
            } finally {
                caffeinateProcess = null;
            }
        }
    }

    public synchronized int getActiveLockCount() {
        return activeTransferIds.size();
    }

    public synchronized boolean isSleepInhibited() {
        return !activeTransferIds.isEmpty();
    }

    public synchronized void close() {
        activeTransferIds.clear();
        stopCaffeinateProcess();
    }
}
