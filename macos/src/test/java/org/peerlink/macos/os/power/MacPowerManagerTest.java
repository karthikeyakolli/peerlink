package org.peerlink.macos.os.power;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class MacPowerManagerTest {

    private MacPowerManager powerManager;

    @BeforeEach
    void setUp() {
        // Simulation mode for deterministic non-macOS test execution
        powerManager = new MacPowerManager(true);
    }

    @AfterEach
    void tearDown() {
        powerManager.close();
    }

    @Test
    void testSleepLockLifecycle() {
        assertFalse(powerManager.isSleepInhibited());
        assertEquals(0, powerManager.getActiveLockCount());

        assertTrue(powerManager.acquireSleepLock("transfer-1"));
        assertTrue(powerManager.isSleepInhibited());
        assertEquals(1, powerManager.getActiveLockCount());

        // Concurrent transfer increments count
        assertTrue(powerManager.acquireSleepLock("transfer-2"));
        assertEquals(2, powerManager.getActiveLockCount());

        // Releasing first transfer keeps lock active for second
        assertTrue(powerManager.releaseSleepLock("transfer-1"));
        assertTrue(powerManager.isSleepInhibited());
        assertEquals(1, powerManager.getActiveLockCount());

        // Releasing second transfer clears sleep inhibition
        assertTrue(powerManager.releaseSleepLock("transfer-2"));
        assertFalse(powerManager.isSleepInhibited());
        assertEquals(0, powerManager.getActiveLockCount());
    }

    @Test
    void testInvalidTransferIdRejection() {
        assertFalse(powerManager.acquireSleepLock(null));
        assertFalse(powerManager.acquireSleepLock(""));
        assertFalse(powerManager.releaseSleepLock(null));
    }
}
