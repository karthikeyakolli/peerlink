package org.peerlink.core.sharing;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.peerlink.protocol.v1.ShareAuditEvent;
import org.peerlink.protocol.v1.SharePermission;
import org.peerlink.protocol.v1.ShareStatus;
import org.peerlink.protocol.v1.ShareType;

import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

public class SharingSystemTest {

    private static final String OWNER = "peer_owner";
    private static final String ALICE = "peer_alice";
    private static final String BOB   = "peer_bob";
    private static final String GUEST = "GUEST";
    private static final String SECRET = "sharing_test_secret_9876";

    private ShareAuditJournal journal;
    private ShareRegistry registry;

    @BeforeEach
    void setUp() {
        journal = new ShareAuditJournal();
        registry = new ShareRegistry(journal);
    }

    // ── 1. Valid share ───────────────────────────────────────────────────────

    @Test
    void testValidSharePeerSpecific() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).label("Docs for Alice").allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_BROWSE)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD)
                .secret(SECRET).build();
        registry.createShare(share);

        ShareCapability cap = registry.issueCapability(share.shareId(), ALICE,
                Set.of(SharePermission.SHARE_PERMISSION_BROWSE, SharePermission.SHARE_PERMISSION_DOWNLOAD), 60_000);
        AuthorizationDecision d = registry.authorizeUse(cap.toToken(), ALICE, SharePermission.SHARE_PERMISSION_DOWNLOAD, "op_1", 0);

        assertTrue(d.isAuthorized(), "Valid share must be authorized: " + d.getErrorMessage());
        assertEquals(ShareStatus.SHARE_STATUS_ACTIVE, registry.getStatus(share.shareId()));

        List<ShareAuditRecord> records = journal.findByShareId(share.shareId());
        assertTrue(records.stream().anyMatch(r -> r.event() == ShareAuditEvent.SHARE_AUDIT_CREATED));
        assertTrue(records.stream().anyMatch(r -> r.event() == ShareAuditEvent.SHARE_AUDIT_CAPABILITY_ISSUED));
        assertTrue(records.stream().anyMatch(r -> r.event() == ShareAuditEvent.SHARE_AUDIT_ACCESS_AUTHORIZED));
    }

    // ── 2. Expired share ─────────────────────────────────────────────────────

    @Test
    void testExpiredShareBlocksNewOperations() {
        long past = System.currentTimeMillis() - 60_000;
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD)
                .expiresAt(past).gracePeriodMs(0).secret(SECRET).build();
        registry.createShare(share);

        ShareCapability cap = ShareCapability.issue(share.shareId(), ShareType.SHARE_TYPE_TEMPORARY,
                Set.of(SharePermission.SHARE_PERMISSION_DOWNLOAD), past - 120_000, past, ALICE, SECRET);

        AuthorizationDecision d = registry.authorizeUse(cap.toToken(), ALICE, SharePermission.SHARE_PERMISSION_DOWNLOAD, "op_new", 0);

        assertFalse(d.isAuthorized());
        assertEquals(RejectReason.SHARE_EXPIRED, d.getRejectReason());
        assertEquals(ShareStatus.SHARE_STATUS_EXPIRED, registry.getStatus(share.shareId()));
        assertTrue(journal.findByEvent(ShareAuditEvent.SHARE_AUDIT_EXPIRED).size() >= 1);
    }

    // ── 3. Active transfer during expiry (grace period) ──────────────────────

    @Test
    void testActiveTransferCompletesWithinGracePeriod() {
        long now = System.currentTimeMillis();
        long expiresAt = now - 1_000;
        long gracePeriodMs = 60_000;

        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD)
                .expiresAt(expiresAt).gracePeriodMs(gracePeriodMs).secret(SECRET).build();
        registry.createShare(share);

        long operationStartedAt = expiresAt - 5_000;
        assertTrue(share.isActiveOperationAllowed(now, operationStartedAt));

        // Token expiry must cover the grace window so TOKEN_EXPIRED doesn't fire before the
        // share-level grace-period check. The grace extends to operationStartedAt + gracePeriodMs.
        long tokenExpiresAt = operationStartedAt + gracePeriodMs;
        ShareCapability cap = ShareCapability.issue(share.shareId(), ShareType.SHARE_TYPE_TEMPORARY,
                Set.of(SharePermission.SHARE_PERMISSION_DOWNLOAD), operationStartedAt, tokenExpiresAt, ALICE, SECRET);

        AuthorizationDecision d = registry.authorizeUse(cap.toToken(), ALICE, SharePermission.SHARE_PERMISSION_DOWNLOAD, "op_active", operationStartedAt);
        assertTrue(d.isAuthorized(), "Active operation within grace must be authorized");
    }

    @Test
    void testActiveTransferBlockedAfterGracePeriodExpires() {
        long now = System.currentTimeMillis();
        long gracePeriodMs = 30_000;
        long expiresAt = now - 90_000;
        long operationStartedAt = expiresAt - 5_000;

        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD)
                .expiresAt(expiresAt).gracePeriodMs(gracePeriodMs).secret(SECRET).build();
        registry.createShare(share);

        assertFalse(share.isActiveOperationAllowed(now, operationStartedAt));
    }

    // ── 4. Revoked share ─────────────────────────────────────────────────────

    @Test
    void testRevokedShareBlocksNewAccess() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD).secret(SECRET).build();
        registry.createShare(share);

        ShareCapability cap = registry.issueCapability(share.shareId(), ALICE,
                Set.of(SharePermission.SHARE_PERMISSION_DOWNLOAD), 3600_000);

        registry.revokeShare(share.shareId(), "Owner changed their mind", 0);
        assertTrue(registry.isRevoked(share.shareId()));
        assertEquals(ShareStatus.SHARE_STATUS_REVOKED, registry.getStatus(share.shareId()));

        AuthorizationDecision d = registry.authorizeUse(cap.toToken(), ALICE, SharePermission.SHARE_PERMISSION_DOWNLOAD, "op_after_revoke", 0);
        assertFalse(d.isAuthorized());
        assertEquals(RejectReason.SHARE_REVOKED, d.getRejectReason());
        assertTrue(journal.findByEvent(ShareAuditEvent.SHARE_AUDIT_REVOKED).size() >= 1);
    }

    @Test
    void testRevocationCannotEraseAlreadyDownloadedCopies() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD).secret(SECRET).build();
        registry.createShare(share);
        assertDoesNotThrow(() -> registry.revokeShare(share.shareId(), "Test revoke", 0));
        assertTrue(registry.isRevoked(share.shareId()));
    }

    // ── 5. One-time share — consumed ─────────────────────────────────────────

    @Test
    void testOneTimeShareConsumedAfterFirstOperation() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD_SINGLE)
                .oneTime().secret(SECRET).build();
        registry.createShare(share);

        String opId = "op_single_001";
        ShareCapability cap = registry.issueOneTimeCapability(share.shareId(), ALICE,
                Set.of(SharePermission.SHARE_PERMISSION_DOWNLOAD_SINGLE), 3600_000, opId);

        AuthorizationDecision first = registry.authorizeUse(cap.toToken(), ALICE, SharePermission.SHARE_PERMISSION_DOWNLOAD_SINGLE, opId, 0);
        assertTrue(first.isAuthorized());

        assertTrue(registry.markOneTimeConsumed(share.shareId(), opId));
        assertEquals(ShareStatus.SHARE_STATUS_CONSUMED, registry.getStatus(share.shareId()));
        assertTrue(journal.findByEvent(ShareAuditEvent.SHARE_AUDIT_CONSUMED).size() >= 1);
    }

    // ── 6. Same-operation retry permitted ────────────────────────────────────

    @Test
    void testOneTimeShareSameOperationRetryPermitted() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD_SINGLE)
                .oneTime().secret(SECRET).build();
        registry.createShare(share);

        String opId = "op_retry_002";
        ShareCapability cap = registry.issueOneTimeCapability(share.shareId(), ALICE,
                Set.of(SharePermission.SHARE_PERMISSION_DOWNLOAD_SINGLE), 3600_000, opId);
        registry.markOneTimeConsumed(share.shareId(), opId);

        AuthorizationDecision retry = registry.authorizeUse(cap.toToken(), ALICE, SharePermission.SHARE_PERMISSION_DOWNLOAD_SINGLE, opId, 0);
        assertTrue(retry.isAuthorized(), "Retry of same operation must be permitted");
        assertTrue(journal.findByEvent(ShareAuditEvent.SHARE_AUDIT_OPERATION_RETRY).size() >= 1);
    }

    // ── 7. New operation after one-time completion — rejected ─────────────────

    @Test
    void testNewOperationAfterOneTimeConsumptionRejected() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD_SINGLE)
                .oneTime().secret(SECRET).build();
        registry.createShare(share);

        String opId = "op_original_003";
        String newOpId = "op_new_different_004";
        ShareCapability cap = registry.issueOneTimeCapability(share.shareId(), ALICE,
                Set.of(SharePermission.SHARE_PERMISSION_DOWNLOAD_SINGLE), 3600_000, opId);
        registry.markOneTimeConsumed(share.shareId(), opId);

        AuthorizationDecision d = registry.authorizeUse(cap.toToken(), ALICE, SharePermission.SHARE_PERMISSION_DOWNLOAD_SINGLE, newOpId, 0);
        assertFalse(d.isAuthorized());
        assertEquals(RejectReason.ONE_TIME_CONSUMED, d.getRejectReason());
        assertTrue(d.getErrorMessage().contains(opId));
    }

    // ── 8. Owner offline ─────────────────────────────────────────────────────

    @Test
    void testOwnerOfflineShareUnavailable() {
        ShareCapability orphanCap = ShareCapability.issue("nonexistent_share_id", ShareType.SHARE_TYPE_PEER_SPECIFIC,
                Set.of(SharePermission.SHARE_PERMISSION_DOWNLOAD), System.currentTimeMillis(), 0L, ALICE, "some_secret");

        AuthorizationDecision d = registry.authorizeUse(orphanCap.toToken(), ALICE, SharePermission.SHARE_PERMISSION_DOWNLOAD, "op_offline", 0);
        assertFalse(d.isAuthorized());
        assertEquals(RejectReason.SHARE_NOT_FOUND, d.getRejectReason());
    }

    // ── 9. Guest access — isolated ───────────────────────────────────────────

    @Test
    void testGuestAccessIsolated() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).type(ShareType.SHARE_TYPE_GUEST)
                .permit(SharePermission.SHARE_PERMISSION_BROWSE)
                .permit(SharePermission.SHARE_PERMISSION_PREVIEW)
                .guestAllowed().expiresInMs(3600_000).secret(SECRET).build();
        registry.createShare(share);

        ShareCapability guestCap = registry.issueGuestCapability(share.shareId(),
                Set.of(SharePermission.SHARE_PERMISSION_BROWSE), 3600_000);

        assertTrue(guestCap.isGuestToken());
        assertFalse(guestCap.hasPermission(SharePermission.SHARE_PERMISSION_DOWNLOAD));

        AuthorizationDecision d = registry.authorizeUse(guestCap.toToken(), GUEST, SharePermission.SHARE_PERMISSION_BROWSE, "op_guest_1", 0);
        assertTrue(d.isAuthorized(), "Guest access with correct permissions must be authorized");
        assertTrue(journal.findByEvent(ShareAuditEvent.SHARE_AUDIT_GUEST_ACCESS).size() >= 1);
    }

    @Test
    void testGuestTokenCannotClaimTrustedPeerIdentity() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).permit(SharePermission.SHARE_PERMISSION_BROWSE)
                .guestAllowed().secret(SECRET).build();
        registry.createShare(share);

        ShareCapability guestCap = registry.issueGuestCapability(share.shareId(),
                Set.of(SharePermission.SHARE_PERMISSION_BROWSE), 3600_000);

        AuthorizationDecision d = registry.authorizeUse(guestCap.toToken(), ALICE,
                SharePermission.SHARE_PERMISSION_BROWSE, "op_spoof", 0);
        assertFalse(d.isAuthorized());
        assertEquals(RejectReason.GUEST_IDENTITY_VIOLATION, d.getRejectReason());
    }

    // ── 10. Capability token round-trip ──────────────────────────────────────

    @Test
    void testCapabilityTokenRoundTrip() {
        ShareCapability original = ShareCapability.issue("share_rt_001", ShareType.SHARE_TYPE_PEER_SPECIFIC,
                Set.of(SharePermission.SHARE_PERMISSION_BROWSE, SharePermission.SHARE_PERMISSION_DOWNLOAD),
                System.currentTimeMillis(), System.currentTimeMillis() + 3600_000, ALICE, SECRET);

        Optional<ShareCapability> parsedOpt = ShareCapability.fromToken(original.toToken());
        assertTrue(parsedOpt.isPresent());
        ShareCapability parsed = parsedOpt.get();
        assertEquals(original.tokenId(), parsed.tokenId());
        assertEquals(original.permissions(), parsed.permissions());
        assertTrue(parsed.verifySignature(SECRET));
    }

    @Test
    void testTamperedTokenSignatureDetected() {
        ShareCapability cap = ShareCapability.issue("share_tamper_001", ShareType.SHARE_TYPE_PEER_SPECIFIC,
                Set.of(SharePermission.SHARE_PERMISSION_DOWNLOAD), System.currentTimeMillis(), 0L, ALICE, SECRET);
        assertFalse(cap.verifySignature("wrong_secret_xyz"));
        assertTrue(ShareCapability.fromToken("definitely_not_a_token").isEmpty());
    }

    // ── 11. QR encoding ──────────────────────────────────────────────────────

    @Test
    void testQrEncodeAndDecodeCapability() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).type(ShareType.SHARE_TYPE_QR)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD)
                .guestAllowed().expiresInMs(3600_000).secret(SECRET).build();
        registry.createShare(share);

        ShareCapability cap = registry.issueGuestCapability(share.shareId(),
                Set.of(SharePermission.SHARE_PERMISSION_DOWNLOAD), 3600_000);
        String qrUri = ShareQrEncoder.encodeCapabilityUri(cap);

        assertTrue(qrUri.startsWith("peerlink://share?cap="));
        String token = ShareQrEncoder.decodeCapabilityToken(qrUri);
        Optional<ShareCapability> parsedOpt = ShareCapability.fromToken(token);
        assertTrue(parsedOpt.isPresent());
        assertEquals(cap.shareId(), parsedOpt.get().shareId());
    }

    // ── 12. Scoped permissions — cannot exceed ───────────────────────────────

    @Test
    void testPeerCannotExceedGrantedPermissions() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_BROWSE).secret(SECRET).build();
        registry.createShare(share);

        ShareCapability cap = registry.issueCapability(share.shareId(), ALICE,
                Set.of(SharePermission.SHARE_PERMISSION_BROWSE), 3600_000);
        AuthorizationDecision d = registry.authorizeUse(cap.toToken(), ALICE, SharePermission.SHARE_PERMISSION_DOWNLOAD, "op_exceed", 0);

        assertFalse(d.isAuthorized());
        assertEquals(RejectReason.INSUFFICIENT_PERMISSION, d.getRejectReason());
    }

    // ── 13. UI Approval State ────────────────────────────────────────────────

    @Test
    void testUiApprovalStateLifecycle() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD).secret(SECRET).build();
        registry.createShare(share);

        ShareApprovalState state = registry.getApprovalState(share.shareId());
        assertFalse(state.isOwnerApproved());

        registry.approveShare(share.shareId());
        assertTrue(registry.getApprovalState(share.shareId()).isOwnerApproved());

        registry.denyShare(share.shareId(), "Changed mind");
        ShareApprovalState denied = registry.getApprovalState(share.shareId());
        assertTrue(denied.isOwnerDenied());
        assertEquals("Changed mind", denied.getDenialReason());
    }

    // ── 14. Revocation grace — active operation survives ─────────────────────

    @Test
    void testRevocationGracePeriodAllowsActiveOperationToComplete() {
        long now = System.currentTimeMillis();
        long gracePeriodMs = 60_000;
        long operationStartedAt = now - 5_000;

        ShareRevocationRecord rev = new ShareRevocationRecord();
        rev.revoke(now, "test", gracePeriodMs, operationStartedAt);
        assertTrue(rev.isActiveOperationPermitted(now + 10_000));
        assertFalse(rev.isActiveOperationPermitted(now + gracePeriodMs + 5_000));
    }

    // ── 15. Determinism — permissions cannot be bypassed ─────────────────────

    @Test
    void testPermissionsAreDeterministicAndCannotBeBypassed() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE)
                .permit(SharePermission.SHARE_PERMISSION_PREVIEW).secret(SECRET).build();
        registry.createShare(share);

        ShareCapability cap = registry.issueCapability(share.shareId(), ALICE,
                Set.of(SharePermission.SHARE_PERMISSION_PREVIEW), 3600_000);

        for (int i = 0; i < 5; i++) {
            AuthorizationDecision d = registry.authorizeUse(cap.toToken(), ALICE, SharePermission.SHARE_PERMISSION_DOWNLOAD, "op_byp_" + i, 0);
            assertFalse(d.isAuthorized(), "Bypass attempt " + i + " must fail");
            assertEquals(RejectReason.INSUFFICIENT_PERMISSION, d.getRejectReason());
        }
    }

    // ── 16. Capability bound to issued peer ──────────────────────────────────

    @Test
    void testCapabilityBoundToIssuedPeer() {
        ShareObject share = ShareObjectBuilder.newShare()
                .owner(OWNER).allowPeer(ALICE).allowPeer(BOB)
                .permit(SharePermission.SHARE_PERMISSION_DOWNLOAD).secret(SECRET).build();
        registry.createShare(share);

        ShareCapability aliceCap = registry.issueCapability(share.shareId(), ALICE,
                Set.of(SharePermission.SHARE_PERMISSION_DOWNLOAD), 3600_000);

        AuthorizationDecision d = registry.authorizeUse(aliceCap.toToken(), BOB, SharePermission.SHARE_PERMISSION_DOWNLOAD, "op_bob", 0);
        assertFalse(d.isAuthorized());
        assertEquals(RejectReason.PEER_MISMATCH, d.getRejectReason());
    }
}