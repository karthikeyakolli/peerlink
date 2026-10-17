package org.peerlink.core.transfer.ephemeral;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("EphemeralSessionRegistry Lifecycle & Automatic Shredding")
class EphemeralSessionRegistryTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("Single-view policy triggers immediate crypto-shred on first view access")
    void testSingleViewBurnPolicy() throws IOException {
        Path file = tempDir.resolve("one_time_doc.txt");
        Files.writeString(file, "Confidential financial projection");

        try (EphemeralSessionRegistry registry = new EphemeralSessionRegistry()) {
            EphemeralTransferPolicy policy = EphemeralTransferPolicy.burnAfterOneView();
            registry.registerSession("tx-001", file, policy);

            assertEquals(1, registry.getActiveSessionCount());
            assertTrue(Files.exists(file));

            // Record first view
            boolean permitted = registry.recordViewAccess("tx-001");
            assertTrue(permitted, "First view should be permitted");

            // Since allowedViews is 1, it should shred immediately
            assertFalse(Files.exists(file), "File must be shredded after single view");
            assertEquals(0, registry.getActiveSessionCount(), "Session must be removed after shredding");

            // Subsequent view attempts should be rejected
            assertFalse(registry.recordViewAccess("tx-001"), "Subsequent view must be rejected");
        }
    }

    @Test
    @DisplayName("TTL expiration triggers automatic background shredding")
    void testTtlAutoExpiry() throws Exception {
        Path file = tempDir.resolve("expiring_token.json");
        Files.writeString(file, "{\"secret\": \"jwt-token-123\"}");

        try (EphemeralSessionRegistry registry = new EphemeralSessionRegistry()) {
            // Set 1-second TTL
            EphemeralTransferPolicy policy = EphemeralTransferPolicy.timeLimited(1);
            EphemeralSessionRegistry.EphemeralSession session = registry.registerSession("tx-002", file, policy);

            assertTrue(Files.exists(file));

            // Wait for TTL to expire and sentinel to run
            Boolean shredded = session.shredCompletion().get(3, TimeUnit.SECONDS);
            assertTrue(shredded);
            assertFalse(Files.exists(file), "File must be auto-shredded by background sentinel upon TTL expiry");
        }
    }

    @Test
    @DisplayName("Manual force-cancellation immediately shreds the file")
    void testManualCancellation() throws IOException {
        Path file = tempDir.resolve("revoked.txt");
        Files.writeString(file, "Revoked payload");

        try (EphemeralSessionRegistry registry = new EphemeralSessionRegistry()) {
            registry.registerSession("tx-003", file, EphemeralTransferPolicy.burnAfterOneView());
            assertTrue(Files.exists(file));

            boolean shredded = registry.cancelAndShred("tx-003");
            assertTrue(shredded);
            assertFalse(Files.exists(file));
        }
    }
}
