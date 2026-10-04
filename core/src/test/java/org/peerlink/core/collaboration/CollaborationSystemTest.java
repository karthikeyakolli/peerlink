package org.peerlink.core.collaboration;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.collaboration.clipboard.*;
import org.peerlink.core.collaboration.smart.*;
import org.peerlink.core.collaboration.workspace.*;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.peerlink.core.operation.OperationIntent;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Phase 15: Shared Spaces, Clipboard and Smart Operations Tests")
class CollaborationSystemTest {

    @TempDir
    Path tempDir;

    private static final String OWNER = "peer_owner";
    private static final String ADMIN = "peer_admin";
    private static final String EDITOR = "peer_editor";
    private static final String CONTRIBUTOR = "peer_contributor";
    private static final String VIEWER = "peer_viewer";
    private static final String OBSERVER = "peer_observer";

    private SharedWorkspace workspace;

    @BeforeEach
    void setUp() {
        workspace = new SharedWorkspace("ws_001", "Team Space", OWNER);
        workspace.inviteMember(OWNER, ADMIN, WorkspaceRole.ADMIN);
        workspace.inviteMember(OWNER, EDITOR, WorkspaceRole.EDITOR);
        workspace.inviteMember(OWNER, CONTRIBUTOR, WorkspaceRole.CONTRIBUTOR);
        workspace.inviteMember(OWNER, VIEWER, WorkspaceRole.VIEWER);
        workspace.inviteMember(OWNER, OBSERVER, WorkspaceRole.OBSERVER);
    }

    // ── 1. Workspace Role Restrictions ───────────────────────────────────────

    @Test
    @DisplayName("1. Workspace role restrictions: Enforces granular permission bounds for all 6 roles")
    void testWorkspaceRoleRestrictions() {
        long epoch = workspace.getPolicyEpoch();

        // OBSERVER: Can view metadata, CANNOT read payload, CANNOT write, CANNOT delete
        assertTrue(workspace.authorizeAction(OBSERVER, WorkspaceAction.VIEW_METADATA, epoch));
        assertFalse(workspace.authorizeAction(OBSERVER, WorkspaceAction.READ_PAYLOAD, epoch));
        assertFalse(workspace.authorizeAction(OBSERVER, WorkspaceAction.WRITE_FILE, epoch));
        assertFalse(workspace.authorizeAction(OBSERVER, WorkspaceAction.DELETE_FILE, epoch));

        // VIEWER: Can view metadata and read payload, CANNOT write or delete
        assertTrue(workspace.authorizeAction(VIEWER, WorkspaceAction.VIEW_METADATA, epoch));
        assertTrue(workspace.authorizeAction(VIEWER, WorkspaceAction.READ_PAYLOAD, epoch));
        assertFalse(workspace.authorizeAction(VIEWER, WorkspaceAction.WRITE_FILE, epoch));
        assertFalse(workspace.authorizeAction(VIEWER, WorkspaceAction.DELETE_FILE, epoch));

        // CONTRIBUTOR: Can write, CANNOT delete or admin
        assertTrue(workspace.authorizeAction(CONTRIBUTOR, WorkspaceAction.WRITE_FILE, epoch));
        assertFalse(workspace.authorizeAction(CONTRIBUTOR, WorkspaceAction.DELETE_FILE, epoch));
        assertFalse(workspace.authorizeAction(CONTRIBUTOR, WorkspaceAction.INVITE_MEMBER, epoch));

        // EDITOR: Can write and delete, CANNOT admin
        assertTrue(workspace.authorizeAction(EDITOR, WorkspaceAction.WRITE_FILE, epoch));
        assertTrue(workspace.authorizeAction(EDITOR, WorkspaceAction.DELETE_FILE, epoch));
        assertFalse(workspace.authorizeAction(EDITOR, WorkspaceAction.INVITE_MEMBER, epoch));

        // ADMIN: Can admin, write, delete, invite
        assertTrue(workspace.authorizeAction(ADMIN, WorkspaceAction.WRITE_FILE, epoch));
        assertTrue(workspace.authorizeAction(ADMIN, WorkspaceAction.DELETE_FILE, epoch));
        assertTrue(workspace.authorizeAction(ADMIN, WorkspaceAction.INVITE_MEMBER, epoch));
        assertTrue(workspace.authorizeAction(ADMIN, WorkspaceAction.CHANGE_ROLE, epoch));

        // File lineage modification record by authorized editor
        ObjectIdentity docId = ObjectIdentity.generate();
        ContentHash docHash = ContentHash.computeSha256("Doc v1".getBytes(StandardCharsets.UTF_8));
        FileBranchLineage lineage = workspace.recordFileModification(EDITOR, docId, "doc.txt", docHash, 0, epoch);
        assertEquals(1, lineage.getVersionSequence());
        assertEquals(EDITOR, lineage.getModifierPeerId());
        assertNotNull(lineage.getLineageHash());

        // Unauthorized write by viewer throws SecurityException
        assertThrows(SecurityException.class, () ->
                workspace.recordFileModification(VIEWER, docId, "doc.txt", docHash, 1, epoch)
        );
    }

    // ── 2. Membership Removal ────────────────────────────────────────────────

    @Test
    @DisplayName("2. Membership removal: Removed member loses access; owner cannot be removed")
    void testMembershipRemoval() {
        long epochBefore = workspace.getPolicyEpoch();
        assertTrue(workspace.authorizeAction(EDITOR, WorkspaceAction.WRITE_FILE, epochBefore));

        // Admin removes editor
        workspace.removeMember(ADMIN, EDITOR);
        long epochAfter = workspace.getPolicyEpoch();
        assertTrue(epochAfter > epochBefore, "Epoch must increment upon member removal");

        // Removed editor is unauthorized
        assertFalse(workspace.authorizeAction(EDITOR, WorkspaceAction.READ_PAYLOAD, epochAfter));
        assertFalse(workspace.authorizeAction(EDITOR, WorkspaceAction.WRITE_FILE, epochAfter));

        // Cannot remove owner
        assertThrows(IllegalStateException.class, () -> workspace.removeMember(ADMIN, OWNER));
    }

    // ── 3. Revoked Member ────────────────────────────────────────────────────

    @Test
    @DisplayName("3. Revoked member: Revoked member is blacklisted and cannot be re-invited; owner cannot be revoked")
    void testRevokedMember() {
        workspace.revokeMember(ADMIN, CONTRIBUTOR, "Policy violation");
        long epoch = workspace.getPolicyEpoch();

        // Revoked member cannot perform any action
        assertFalse(workspace.authorizeAction(CONTRIBUTOR, WorkspaceAction.VIEW_METADATA, epoch));
        assertTrue(workspace.getRevokedPeers().contains(CONTRIBUTOR));

        // Attempting to re-invite revoked member fails
        assertThrows(IllegalStateException.class, () ->
                workspace.inviteMember(ADMIN, CONTRIBUTOR, WorkspaceRole.CONTRIBUTOR)
        );

        // Owner cannot be revoked
        assertThrows(IllegalStateException.class, () ->
                workspace.revokeMember(ADMIN, OWNER, "Rogue admin attempt")
        );
    }

    // ── 4. Policy Epoch Change ───────────────────────────────────────────────

    @Test
    @DisplayName("4. Policy epoch change: Operations prepared under older policy epoch are rejected")
    void testPolicyEpochChange() {
        long initialEpoch = workspace.getPolicyEpoch();
        assertTrue(workspace.authorizeAction(EDITOR, WorkspaceAction.WRITE_FILE, initialEpoch));

        // An administrative action occurs (role change), bumping the epoch
        workspace.changeRole(ADMIN, VIEWER, WorkspaceRole.CONTRIBUTOR);
        long newEpoch = workspace.getPolicyEpoch();
        assertTrue(newEpoch > initialEpoch);

        // Invariant: In-flight operation presenting stale epoch is invalidated
        assertFalse(workspace.authorizeAction(EDITOR, WorkspaceAction.WRITE_FILE, initialEpoch),
                "Action with stale epoch must be rejected");

        // Action presenting current epoch succeeds
        assertTrue(workspace.authorizeAction(EDITOR, WorkspaceAction.WRITE_FILE, newEpoch));
    }

    // ── 5. Clipboard Loop Prevention ─────────────────────────────────────────

    @Test
    @DisplayName("5. Clipboard loop prevention: Drops echoed items originating from self or duplicate hash")
    void testClipboardLoop() throws IOException {
        String peerA = "peer_node_a";
        ClipboardManager clipA = new ClipboardManager(peerA, ClipboardSyncMode.TEXT);

        // Peer A publishes text
        Optional<ClipboardItem> published = clipA.publishLocalText("Hello World Clipboard Sync");
        assertTrue(published.isPresent());
        ClipboardItem item = published.get();

        // If the same item echoes back to Peer A from network, it must be DROPPED
        boolean acceptedEcho = clipA.receiveRemoteItem(item);
        assertFalse(acceptedEcho, "Self-originating clipboard item must be dropped to prevent loops");

        // Another peer B receives it cleanly
        ClipboardManager clipB = new ClipboardManager("peer_node_b", ClipboardSyncMode.TEXT);
        boolean acceptedB = clipB.receiveRemoteItem(item);
        assertTrue(acceptedB, "Remote peer B should accept item");

        // If peer B receives duplicate item with identical contentHash again, it is dropped
        boolean duplicateB = clipB.receiveRemoteItem(item);
        assertFalse(duplicateB, "Duplicate hash within TTL must be dropped to prevent redundant updates");
    }

    // ── 6. Clipboard Sensitivity Inspection ──────────────────────────────────

    @Test
    @DisplayName("6. Clipboard sensitivity: Blocks automated broadcast of private keys, tokens, or credentials")
    void testClipboardSensitivity() {
        ClipboardManager clip = new ClipboardManager("peer_local", ClipboardSyncMode.TEXT);

        // RSA Private Key
        String privateKey = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA0...\n-----END RSA PRIVATE KEY-----";
        assertThrows(SecurityException.class, () -> clip.publishLocalText(privateKey));

        // JWT token
        String jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozGz...";
        assertThrows(SecurityException.class, () -> clip.publishLocalText(jwt));

        // API Key
        String apiKey = "ghp_1234567890abcdef1234567890abcdef1234";
        assertThrows(SecurityException.class, () -> clip.publishLocalText(apiKey));

        // Credit card
        String cc = "Payment card number: 4111111111111111";
        assertThrows(SecurityException.class, () -> clip.publishLocalText(cc));

        // Benign text succeeds
        assertDoesNotThrow(() -> clip.publishLocalText("https://docs.peerlink.org/architecture"));
    }

    // ── 7. Scheduled Operation after File Move ────────────────────────────────

    @Test
    @DisplayName("7. Scheduled operation after file move: Re-resolves current path via ObjectIdentity (Never replayers stale paths)")
    void testScheduledOperationAfterFileMove() throws IOException {
        Path origPath = tempDir.resolve("original_folder/document.pdf");
        Files.createDirectories(origPath.getParent());
        Files.writeString(origPath, "Important contract text");

        ObjectIdentity objId = ObjectIdentity.generate();
        ContentHash expectedHash = ContentHash.computeSha256("Important contract text".getBytes(StandardCharsets.UTF_8));

        // Mock resolver tracking object location
        Map<ObjectIdentity, Path> registry = new ConcurrentHashMap<>();
        registry.put(objId, origPath);

        SmartOperationScheduler.ObjectPathResolver resolver = id -> Optional.ofNullable(registry.get(id));
        SmartOperationScheduler.SystemEnvironment env = new SmartOperationScheduler.SystemEnvironment() {
            @Override public boolean isConnectedToPeer(String peerId) { return true; }
            @Override public boolean isNetworkSatisfied(NetworkPolicy policy) { return true; }
            @Override public boolean isPowerSatisfied(PowerPolicy policy) { return true; }
            @Override public boolean isOperationCompleted(String operationId) { return true; }
        };

        SmartOperationScheduler scheduler = new SmartOperationScheduler(resolver, env);

        ScheduledOperation op = new ScheduledOperation(
                "op_sched_1", "idemp_sched_1", OperationIntent.SMART_ACTION,
                objId, "peer_target", null, NetworkPolicy.ANY, PowerPolicy.ANY,
                UserPolicy.AUTOMATIC, expectedHash, System.currentTimeMillis() + 60000
        );
        scheduler.schedule(op);

        // Move the file on disk to a completely different location!
        Path movedPath = tempDir.resolve("archived_documents/2026/renamed_contract.pdf");
        Files.createDirectories(movedPath.getParent());
        Files.move(origPath, movedPath);
        registry.put(objId, movedPath); // ObjectIdentity now maps to movedPath

        // Execute scheduled operation: current-state revalidation resolves moved path without error
        boolean executed = scheduler.executeIfReady("op_sched_1");
        assertTrue(executed, "Scheduled operation should re-resolve moved path via ObjectIdentity and succeed");
        assertEquals(ScheduledOperation.Status.COMPLETED, op.getStatus());
    }

    // ── 8. Offline Scheduled Action ──────────────────────────────────────────

    @Test
    @DisplayName("8. Offline scheduled action: Holds execution and flags BLOCKED_BY_POLICY when peer is offline")
    void testOfflineScheduledAction() throws IOException {
        Path filePath = tempDir.resolve("file.txt");
        Files.writeString(filePath, "Pending content");
        ObjectIdentity objId = ObjectIdentity.generate();
        ContentHash hash = ContentHash.computeSha256("Pending content".getBytes(StandardCharsets.UTF_8));

        SmartOperationScheduler.ObjectPathResolver resolver = id -> Optional.of(filePath);
        SmartOperationScheduler.SystemEnvironment offlineEnv = new SmartOperationScheduler.SystemEnvironment() {
            @Override public boolean isConnectedToPeer(String peerId) { return false; } // Target peer is offline!
            @Override public boolean isNetworkSatisfied(NetworkPolicy policy) { return true; }
            @Override public boolean isPowerSatisfied(PowerPolicy policy) { return true; }
            @Override public boolean isOperationCompleted(String operationId) { return true; }
        };

        SmartOperationScheduler scheduler = new SmartOperationScheduler(resolver, offlineEnv);

        ScheduledOperation op = new ScheduledOperation(
                "op_offline_1", "idemp_offline_1", OperationIntent.SMART_ACTION,
                objId, "peer_offline_target", null, NetworkPolicy.ANY, PowerPolicy.ANY,
                UserPolicy.AUTOMATIC, hash, System.currentTimeMillis()
        );
        scheduler.schedule(op);

        boolean executed = scheduler.executeIfReady("op_offline_1");
        assertFalse(executed, "Should not execute while target peer is offline");
        assertEquals(ScheduledOperation.Status.BLOCKED_BY_POLICY, op.getStatus());
        assertFalse(op.isExecuted());
    }

    // ── 9. Duplicate Execution Prevention ────────────────────────────────────

    @Test
    @DisplayName("9. Duplicate execution: Prevents duplicate execution via idempotency key and completed status")
    void testDuplicateExecution() throws IOException {
        Path filePath = tempDir.resolve("single_run.txt");
        Files.writeString(filePath, "Execute only once");
        ObjectIdentity objId = ObjectIdentity.generate();
        ContentHash hash = ContentHash.computeSha256("Execute only once".getBytes(StandardCharsets.UTF_8));

        SmartOperationScheduler.ObjectPathResolver resolver = id -> Optional.of(filePath);
        SmartOperationScheduler.SystemEnvironment env = new SmartOperationScheduler.SystemEnvironment() {
            @Override public boolean isConnectedToPeer(String peerId) { return true; }
            @Override public boolean isNetworkSatisfied(NetworkPolicy policy) { return true; }
            @Override public boolean isPowerSatisfied(PowerPolicy policy) { return true; }
            @Override public boolean isOperationCompleted(String operationId) { return true; }
        };

        SmartOperationScheduler scheduler = new SmartOperationScheduler(resolver, env);

        ScheduledOperation op = new ScheduledOperation(
                "op_dup_1", "idemp_unique_key_999", OperationIntent.SMART_ACTION,
                objId, "peer_dest", null, NetworkPolicy.ANY, PowerPolicy.ANY,
                UserPolicy.AUTOMATIC, hash, System.currentTimeMillis()
        );
        scheduler.schedule(op);

        // First execution succeeds
        assertTrue(scheduler.executeIfReady("op_dup_1"));
        assertEquals(ScheduledOperation.Status.COMPLETED, op.getStatus());

        // Second execution attempt is rejected
        assertFalse(scheduler.executeIfReady("op_dup_1"), "Duplicate execution must be rejected");

        // Attempting to schedule another operation with identical idempotency key is rejected
        ScheduledOperation opDuplicateIdemp = new ScheduledOperation(
                "op_dup_2", "idemp_unique_key_999", OperationIntent.SMART_ACTION,
                objId, "peer_dest", null, NetworkPolicy.ANY, PowerPolicy.ANY,
                UserPolicy.AUTOMATIC, hash, System.currentTimeMillis()
        );
        assertThrows(IllegalStateException.class, () -> scheduler.schedule(opDuplicateIdemp));
    }
}