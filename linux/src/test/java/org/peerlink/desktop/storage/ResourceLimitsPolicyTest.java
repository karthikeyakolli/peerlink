package org.peerlink.desktop.storage;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.peerlink.core.event.NodeEvent;
import org.peerlink.core.event.NodeEventBus;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class ResourceLimitsPolicyTest {

    private NodeEventBus eventBus;
    private ResourceLimitsPolicy policy;
    private final List<NodeEvent> events = new ArrayList<>();

    @BeforeEach
    void setUp() {
        eventBus = new NodeEventBus(Runnable::run);
        eventBus.subscribe(events::add);
        policy = new ResourceLimitsPolicy(eventBus);
    }

    @Test
    void testAcceptOperationWithinLimits() {
        assertDoesNotThrow(() -> policy.checkCanAcceptOperation(50));
        assertTrue(events.isEmpty());
    }

    @Test
    void testWarningEmittedAtEightyPercentThreshold() {
        policy.checkCanAcceptOperation(80);
        assertEquals(1, events.size());
        assertTrue(events.get(0) instanceof NodeEvent.ResourceLimitWarning);
        NodeEvent.ResourceLimitWarning warning = (NodeEvent.ResourceLimitWarning) events.get(0);
        assertEquals(NodeEvent.ResourceKind.OPEN_OPERATIONS_COUNT, warning.resourceKind());
    }

    @Test
    void testHardLimitThrowsException() {
        assertThrows(ResourceLimitsPolicy.ResourceLimitException.class, () ->
                policy.checkCanAcceptOperation(ResourceLimitsPolicy.MAX_OPEN_OPERATIONS));
    }

    @Test
    void testJournalSizeWarningAndLimit() {
        policy.checkJournalSize(8000);
        assertEquals(1, events.size());

        policy.checkJournalSize(10000);
        assertEquals(2, events.size());
    }

    @Test
    void testDatabaseSizeWarningAndLimit() {
        policy.checkDatabaseSize((long) (ResourceLimitsPolicy.MAX_DATABASE_SIZE_BYTES * 0.85));
        assertEquals(1, events.size());

        policy.checkDatabaseSize(ResourceLimitsPolicy.MAX_DATABASE_SIZE_BYTES);
        assertEquals(2, events.size());
    }
}
