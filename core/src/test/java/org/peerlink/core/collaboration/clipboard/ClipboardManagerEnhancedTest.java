package org.peerlink.core.collaboration.clipboard;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Enhanced ClipboardManager Tests")
class ClipboardManagerEnhancedTest {

    @Test
    @DisplayName("Publishing images is supported when in TEXT_AND_SUPPORTED_IMAGE mode")
    void publishesImagesInSupportedMode() throws IOException {
        ClipboardManager manager = new ClipboardManager("peer_a", ClipboardSyncMode.TEXT_AND_SUPPORTED_IMAGE);
        byte[] fakePng = new byte[] { (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

        Optional<ClipboardItem> item = manager.publishLocalImage(fakePng);
        assertTrue(item.isPresent());
        assertEquals(ClipboardItemType.IMAGE, item.get().getType());
        assertArrayEquals(fakePng, item.get().getPayload());

        assertEquals(1, manager.getHistory().size());
    }

    @Test
    @DisplayName("Image publish returns empty when mode is TEXT-only")
    void imagePublishBlockedInTextOnlyMode() throws IOException {
        ClipboardManager manager = new ClipboardManager("peer_a", ClipboardSyncMode.TEXT);
        byte[] fakePng = new byte[] { 1, 2, 3 };

        Optional<ClipboardItem> item = manager.publishLocalImage(fakePng);
        assertTrue(item.isEmpty(), "Image publishing must be empty when sync mode is TEXT-only");
    }

    @Test
    @DisplayName("Maintains bounded history ring buffer and supports clearHistory()")
    void historyRingBufferAndClear() throws IOException {
        ClipboardManager manager = new ClipboardManager("peer_a", ClipboardSyncMode.TEXT);

        for (int i = 1; i <= 60; i++) {
            manager.publishLocalText("Message " + i);
        }

        List<ClipboardItem> history = manager.getHistory();
        assertEquals(50, history.size(), "History size must cap at 50");
        assertEquals("Message 60", new String(history.get(0).getPayload()));

        manager.clearHistory();
        assertTrue(manager.getHistory().isEmpty());
        assertTrue(manager.getCurrentItem().isEmpty());
    }
}
