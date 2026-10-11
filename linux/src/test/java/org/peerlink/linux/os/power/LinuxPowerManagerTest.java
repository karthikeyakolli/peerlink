package org.peerlink.linux.os.power;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class LinuxPowerManagerTest {

    @Test
    void testActiveTransferCounterAndSleepInhibitTransitions() {
        int initial = LinuxPowerManager.getActiveTransferCount();

        // Increment transfers
        LinuxPowerManager.preventSleepDuringTransfer();
        assertEquals(initial + 1, LinuxPowerManager.getActiveTransferCount());

        // Increment again
        LinuxPowerManager.preventSleepDuringTransfer();
        assertEquals(initial + 2, LinuxPowerManager.getActiveTransferCount());

        // Allow sleep for one
        LinuxPowerManager.allowSleep();
        assertEquals(initial + 1, LinuxPowerManager.getActiveTransferCount());

        // Allow sleep for second
        LinuxPowerManager.allowSleep();
        assertEquals(initial, LinuxPowerManager.getActiveTransferCount());
    }
}
