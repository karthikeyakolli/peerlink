package org.peerlink.windows.os.power;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class WindowsPowerManagerTest {

    @Test
    void testActiveTransferCounterAndSleepTransitions() {
        int initial = WindowsPowerManager.getActiveTransferCount();

        // Increment transfers
        WindowsPowerManager.preventSleepDuringTransfer();
        assertEquals(initial + 1, WindowsPowerManager.getActiveTransferCount());

        // Increment again
        WindowsPowerManager.preventSleepDuringTransfer();
        assertEquals(initial + 2, WindowsPowerManager.getActiveTransferCount());

        // Allow sleep for one
        WindowsPowerManager.allowSleep();
        assertEquals(initial + 1, WindowsPowerManager.getActiveTransferCount());

        // Allow sleep for second
        WindowsPowerManager.allowSleep();
        assertEquals(initial, WindowsPowerManager.getActiveTransferCount());
    }
}
