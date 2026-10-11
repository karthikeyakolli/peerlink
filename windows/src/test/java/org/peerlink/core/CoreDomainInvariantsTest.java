package org.peerlink.core;

import org.junit.jupiter.api.Test;
import org.peerlink.core.error.ErrorCode;
import org.peerlink.core.error.PeerLinkException;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.peerlink.core.model.VersionMetadata;
import org.peerlink.core.operation.OperationIntent;
import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;
import org.peerlink.core.operation.OperationStateMachine;
import org.peerlink.core.security.SecurityVerdict;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class CoreDomainInvariantsTest {

    @Test
    void testObjectIdentityIsNotPathOrHash() {
        ObjectIdentity id1 = ObjectIdentity.generate();
        ObjectIdentity id2 = ObjectIdentity.generate();
        assertNotEquals(id1, id2);
        assertTrue(id1.getValue().startsWith("obj_"));
    }

    @Test
    void testContentHashComputationAndVerification() {
        byte[] data = "PeerLink immutable content verification test".getBytes(StandardCharsets.UTF_8);
        ContentHash hash = ContentHash.computeSha256(data);

        assertEquals(ContentHash.Algorithm.SHA256, hash.getAlgorithm());
        assertTrue(hash.matches(data));
        assertFalse(hash.matches("tampered data".getBytes(StandardCharsets.UTF_8)));
    }

    @Test
    void testTimestampsAreNotSyncConflictTruth() {
        // Version 1
        VersionMetadata v1 = VersionMetadata.genesis("v1");

        // Concurrent divergent versions originating from v1
        VersionMetadata v2a = v1.createChild("v2a");
        VersionMetadata v2b = v1.createChild("v2b");

        // Even if v2b has a later physical timestamp, they are in a causal conflict
        assertTrue(v2a.conflictsWith(v2b), "Concurrent versions with common ancestor must conflict");
        assertTrue(v2b.conflictsWith(v2a));
        assertFalse(v1.conflictsWith(v2a), "Ancestor does not conflict with direct child");
    }

    @Test
    void testOperationLifecycleTransitions() {
        OperationRecord op = OperationRecord.create(
                "op_test_1",
                OperationIntent.SEND,
                "peer_local",
                List.of("obj_123"),
                "idemp_key_1"
        );
        assertEquals(OperationState.CREATED, op.getState());

        // Valid transition path
        OperationStateMachine.validateTransition(OperationState.CREATED, OperationState.VALIDATED);
        OperationStateMachine.validateTransition(OperationState.VALIDATED, OperationState.AUTHORIZED);
        OperationStateMachine.validateTransition(OperationState.AUTHORIZED, OperationState.EXECUTING);
        OperationStateMachine.validateTransition(OperationState.EXECUTING, OperationState.COMMITTED);

        // Invalid jump: cannot jump from CREATED directly to COMMITTED
        assertThrows(IllegalStateException.class, () ->
                OperationStateMachine.validateTransition(OperationState.CREATED, OperationState.COMMITTED)
        );

        // Cannot transition out of terminal state COMMITTED
        assertThrows(IllegalStateException.class, () ->
                OperationStateMachine.validateTransition(OperationState.COMMITTED, OperationState.EXECUTING)
        );
    }

    @Test
    void testSecurityVerdictsUnavailableIsNotClean() {
        assertNotEquals(SecurityVerdict.CLEAN, SecurityVerdict.UNAVAILABLE);
        assertNotEquals(SecurityVerdict.CLEAN, SecurityVerdict.UNKNOWN);
    }

    @Test
    void testStructuredExceptions() {
        PeerLinkException ex = new PeerLinkException(ErrorCode.UNAUTHORIZED_IPC_CLIENT, "Access denied without local token");
        assertEquals(ErrorCode.UNAUTHORIZED_IPC_CLIENT, ex.getErrorCode());
        assertFalse(ex.getErrorCode().isRetryable());
    }
}
