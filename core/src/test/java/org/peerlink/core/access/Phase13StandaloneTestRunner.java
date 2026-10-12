package org.peerlink.core.access;

import org.peerlink.core.sharing.OneTimeConsumptionTracker;
import org.peerlink.core.sharing.ShareCapability;
import org.peerlink.core.sharing.ShareRevocationRecord;
import org.peerlink.protocol.v1.AccessScope;
import org.peerlink.protocol.v1.SharePermission;
import org.peerlink.protocol.v1.ShareType;

import java.io.*;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * Phase 13 Standalone Verification Suite:
 * Access, Remote Browsing, Sharing, Bounded Reads, Safe Previews, Destination Isolation,
 * and Real Two-Node Network Request Demonstration.
 *
 * Runs in pure Java SE on any host environment.
 */
public class Phase13StandaloneTestRunner {

    private static int testsPassed = 0;
    private static int testsFailed = 0;

    public static void main(String[] args) {
        System.out.println("==========================================================");
        System.out.println(" PeerLink Phase 13 Access, Remote Browsing & Sharing Suite");
        System.out.println("==========================================================");

        runTest("Test 01: Share Creation & Authoritative Local Node Registration", Phase13StandaloneTestRunner::testShareCreationAndLookup);
        runTest("Test 02: Unauthorized Paired Peer Rejection (No Implicit Filesystem Access)", Phase13StandaloneTestRunner::testUnauthorizedPeerRejection);
        runTest("Test 03: Expired Share Blocks New Operations Immediately", Phase13StandaloneTestRunner::testExpiredShareBlocksNewOperations);
        runTest("Test 04: Active In-Flight Operation Allowed Within Grace Period", Phase13StandaloneTestRunner::testActiveOperationWithinGracePeriod);
        runTest("Test 05: Owner Revocation Immediately Blocks New Operations", Phase13StandaloneTestRunner::testRevokedShareBlocksNewOperations);
        runTest("Test 06: One-Time Share Single Consumption & Idempotent Retry", Phase13StandaloneTestRunner::testOneTimeShareSingleConsumptionAndRetry);
        runTest("Test 07: Cryptographic Token Requirement Enforcement", Phase13StandaloneTestRunner::testTokenRequirementEnforced);
        runTest("Test 08: Tampered Token Signature Rejection", Phase13StandaloneTestRunner::testTamperedTokenSignatureRejection);
        runTest("Test 09: Guest Sharing Isolation & Identity Claim Protection", Phase13StandaloneTestRunner::testGuestSharingConstraints);
        runTest("Test 10: Path Traversal Rejection (.., Drive Letters, UNC, ADS, Null Bytes)", Phase13StandaloneTestRunner::testPathTraversalRejection);
        runTest("Test 11: Safe Preview Strictly Rejects Executable Files", Phase13StandaloneTestRunner::testSafePreviewRejectsExecutables);
        runTest("Test 12: Safe Preview Bounded Byte Reads & Truncation", Phase13StandaloneTestRunner::testSafePreviewBoundedRead);
        runTest("Test 13: Bounded File Reader On-Demand Retrieval & Resource Protection", Phase13StandaloneTestRunner::testBoundedFileReaderOnDemandRetrieval);
        runTest("Test 14: Safe Destination Handler Commits Staged Files Non-Executable", Phase13StandaloneTestRunner::testSafeDestinationHandler);
        runTest("Test 15: Safe Destination Handler Rejects Cryptographic Hash Mismatch", Phase13StandaloneTestRunner::testSafeDestinationHandlerHashMismatch);
        runTest("Test 16: Safe Destination Handler Rejects Destination Traversal Escape", Phase13StandaloneTestRunner::testDestinationPathTraversalRejection);
        runTest("Test 17: Remote Folder Browser Deterministic Sorting & Pagination Limits", Phase13StandaloneTestRunner::testRemoteFolderBrowserBoundedPagination);
        runTest("Test 18: Remote Search Engine Max Depth & Resource Exhaustion Protection", Phase13StandaloneTestRunner::testRemoteSearchEngineDepthAndLimits);
        runTest("Test 19: Archive Inspector Zip-Slip Malicious Entry Detection", Phase13StandaloneTestRunner::testArchiveInspectorZipSlipDetection);
        runTest("Test 20: Real Two-Node Network Request Demonstration (Wire Protocol)", Phase13StandaloneTestRunner::testTwoNodeNetworkRequestExchange);

        System.out.println("\n==========================================================");
        System.out.printf(" Phase 13 Test Execution Summary: %d PASSED, %d FAILED\n", testsPassed, testsFailed);
        System.out.println("==========================================================");

        if (testsFailed > 0) {
            System.exit(1);
        } else {
            System.exit(0);
        }
    }

    private static void runTest(String name, TestCase testCase) {
        try {
            testCase.run();
            System.out.println("[PASS] " + name);
            testsPassed++;
        } catch (Throwable t) {
            System.err.println("[FAIL] " + name + " -> " + t.getMessage());
            t.printStackTrace(System.err);
            testsFailed++;
        }
    }

    @FunctionalInterface
    interface TestCase {
        void run() throws Exception;
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (expected instanceof Number && actual instanceof Number) {
            if (((Number) expected).longValue() != ((Number) actual).longValue()) {
                throw new AssertionError(message + " (expected: " + expected + ", got: " + actual + ")");
            }
            return;
        }
        if (!Objects.equals(expected, actual)) {
            throw new AssertionError(message + " (expected: " + expected + ", got: " + actual + ")");
        }
    }

    private static void assertTrue(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message + " (expected true)");
        }
    }

    private static void assertFalse(boolean condition, String message) {
        if (condition) {
            throw new AssertionError(message + " (expected false)");
        }
    }

    private static void assertNotNull(Object obj, String message) {
        if (obj == null) {
            throw new AssertionError(message + " (expected non-null)");
        }
    }

    @FunctionalInterface
    interface Executable {
        void execute() throws Throwable;
    }

    private static <T extends Throwable> T assertThrows(Class<T> expectedType, Executable executable) {
        try {
            executable.execute();
        } catch (Throwable t) {
            if (expectedType.isInstance(t)) {
                return expectedType.cast(t);
            }
            throw new AssertionError("Expected exception " + expectedType.getName() + " but caught " + t.getClass().getName(), t);
        }
        throw new AssertionError("Expected exception " + expectedType.getName() + " was not thrown");
    }

    // =========================================================================
    // Test Implementations
    // =========================================================================

    private static void testShareCreationAndLookup() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_share_test_1");
        try {
            ShareManager manager = new ShareManager();
            ShareDefinition share = new ShareDefinition(
                    "share_001", "Photos", tempDir,
                    Set.of("peer_alice", "peer_bob"),
                    Set.of(AccessScope.ACCESS_SCOPE_BROWSE, AccessScope.ACCESS_SCOPE_PREVIEW),
                    System.currentTimeMillis(), 0L, "secret_key_123"
            );
            manager.registerShare(share);

            assertTrue(manager.getShare("share_001").isPresent(), "Share must be registered");
            assertEquals("Photos", manager.getShare("share_001").get().displayName(), "Display name must match");
            assertEquals(1, manager.getAllShares().size(), "Active shares count must be 1");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testUnauthorizedPeerRejection() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_share_test_2");
        try {
            ShareManager manager = new ShareManager();
            ShareDefinition share = new ShareDefinition(
                    "share_sec", "Confidential", tempDir,
                    Set.of("peer_alice"),
                    Set.of(AccessScope.ACCESS_SCOPE_BROWSE),
                    System.currentTimeMillis(), 0L, "sec_123"
            );
            manager.registerShare(share);

            // Peer Bob is paired/trusted generally, but NOT in this share's allowed list
            ShareManager.ValidationResult res = manager.validateAccess("share_sec", "peer_bob", AccessScope.ACCESS_SCOPE_BROWSE, null);
            assertFalse(res.isAuthorized(), "Paired peer Bob must NOT gain automatic access");
            assertEquals(ShareManager.ValidationResult.RejectReason.PEER_NOT_ALLOWED, res.rejectReason(), "Must reject PEER_NOT_ALLOWED");

            // Peer Alice is in allowed list
            ShareManager.ValidationResult aliceRes = manager.validateAccess("share_sec", "peer_alice", AccessScope.ACCESS_SCOPE_BROWSE, null);
            assertTrue(aliceRes.isAuthorized(), "Authorized peer Alice must be permitted");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testExpiredShareBlocksNewOperations() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_share_test_3");
        try {
            ShareManager manager = new ShareManager();
            long past = System.currentTimeMillis() - 10_000L;
            ShareDefinition share = new ShareDefinition(
                    "share_exp", "Temporary Docs", tempDir,
                    Set.of("peer_alice"),
                    Set.of(AccessScope.ACCESS_SCOPE_BROWSE),
                    past - 60_000L, past, "sec_exp"
            );
            manager.registerShare(share);

            // New operation started at currentTime (past expiry)
            ShareManager.ValidationResult res = manager.validateAccess("share_exp", "peer_alice", AccessScope.ACCESS_SCOPE_BROWSE, null, "op_new", 0L);
            assertFalse(res.isAuthorized(), "Expired share must reject new operations");
            assertEquals(ShareManager.ValidationResult.RejectReason.SHARE_EXPIRED, res.rejectReason(), "Reject reason must be SHARE_EXPIRED");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testActiveOperationWithinGracePeriod() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_share_test_4");
        try {
            ShareManager manager = new ShareManager();
            long now = System.currentTimeMillis();
            long expiresAt = now - 2_000L; // Expired 2s ago
            long gracePeriodMs = 15_000L; // 15s grace window

            ShareDefinition share = new ShareDefinition(
                    "share_grace", "Grace Docs", tempDir,
                    Set.of("peer_alice"),
                    Set.of(AccessScope.ACCESS_SCOPE_DOWNLOAD),
                    now - 60_000L, expiresAt, gracePeriodMs, false, false, false, "sec_grace"
            );
            manager.registerShare(share);

            // Operation started 5s ago (before expiry, now running in grace window)
            long opStartedAt = expiresAt - 3_000L;
            ShareManager.ValidationResult inGrace = manager.validateAccess(
                    "share_grace", "peer_alice", AccessScope.ACCESS_SCOPE_DOWNLOAD, null, "op_inflight", opStartedAt);
            assertTrue(inGrace.isAuthorized(), "In-flight operation within grace window must be permitted");

            // Operation started 30s ago (exceeded grace window)
            long opTooOld = now - 20_000L;
            ShareManager.ValidationResult expiredGrace = manager.validateAccess(
                    "share_grace", "peer_alice", AccessScope.ACCESS_SCOPE_DOWNLOAD, null, "op_inflight_old", opTooOld);
            assertFalse(expiredGrace.isAuthorized(), "In-flight operation past grace window must be rejected");
            assertEquals(ShareManager.ValidationResult.RejectReason.SHARE_EXPIRED, expiredGrace.rejectReason(), "Must reject with SHARE_EXPIRED");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testRevokedShareBlocksNewOperations() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_share_test_5");
        try {
            ShareManager manager = new ShareManager();
            ShareDefinition share = new ShareDefinition(
                    "share_rev", "Sensitive Project", tempDir,
                    Set.of("peer_alice"),
                    Set.of(AccessScope.ACCESS_SCOPE_BROWSE),
                    System.currentTimeMillis(), 0L, "sec_rev"
            );
            manager.registerShare(share);

            assertTrue(manager.validateAccess("share_rev", "peer_alice", AccessScope.ACCESS_SCOPE_BROWSE, null).isAuthorized(), "Active share allowed");

            // Owner revokes share
            manager.revokeShare("share_rev", "Security leak suspected");
            assertTrue(manager.isRevoked("share_rev"), "Share must be marked revoked");
            assertEquals("Security leak suspected", manager.getRevocationReason("share_rev").get(), "Reason recorded");

            // New operation
            ShareManager.ValidationResult revRes = manager.validateAccess("share_rev", "peer_alice", AccessScope.ACCESS_SCOPE_BROWSE, null);
            assertFalse(revRes.isAuthorized(), "Revoked share must reject new operations");
            assertEquals(ShareManager.ValidationResult.RejectReason.SHARE_REVOKED, revRes.rejectReason(), "Must reject with SHARE_REVOKED");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testOneTimeShareSingleConsumptionAndRetry() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_share_test_6");
        try {
            ShareManager manager = new ShareManager();
            ShareDefinition share = new ShareDefinition(
                    "share_one", "One-Time File", tempDir,
                    Set.of("peer_alice"),
                    Set.of(AccessScope.ACCESS_SCOPE_DOWNLOAD),
                    System.currentTimeMillis(), 0L, 30_000L, true, false, false, "sec_one"
            );
            manager.registerShare(share);

            // First operation op_A is authorized
            ShareManager.ValidationResult first = manager.validateAccess(
                    "share_one", "peer_alice", AccessScope.ACCESS_SCOPE_DOWNLOAD, null, "op_A", 0L);
            assertTrue(first.isAuthorized(), "First operation must be authorized");

            // Mark consumed by op_A
            manager.markOneTimeConsumed("share_one", "op_A");
            assertTrue(manager.isOneTimeConsumed("share_one"), "Must be marked consumed");

            // Idempotent retry of op_A is authorized
            ShareManager.ValidationResult retry = manager.validateAccess(
                    "share_one", "peer_alice", AccessScope.ACCESS_SCOPE_DOWNLOAD, null, "op_A", 0L);
            assertTrue(retry.isAuthorized(), "Idempotent retry of same operation ID must be permitted");

            // New operation op_B is rejected
            ShareManager.ValidationResult opB = manager.validateAccess(
                    "share_one", "peer_alice", AccessScope.ACCESS_SCOPE_DOWNLOAD, null, "op_B", 0L);
            assertFalse(opB.isAuthorized(), "New operation op_B on consumed one-time share must be rejected");
            assertEquals(ShareManager.ValidationResult.RejectReason.ONE_TIME_CONSUMED, opB.rejectReason(), "Must reject ONE_TIME_CONSUMED");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testTokenRequirementEnforced() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_share_test_7");
        try {
            ShareManager manager = new ShareManager();
            ShareDefinition share = new ShareDefinition(
                    "share_tok", "Token Required", tempDir,
                    Set.of("peer_alice"),
                    Set.of(AccessScope.ACCESS_SCOPE_BROWSE),
                    System.currentTimeMillis(), 0L, 30_000L, false, true, false, "sec_tok"
            );
            manager.registerShare(share);

            // Alice without token is rejected
            ShareManager.ValidationResult noTok = manager.validateAccess(
                    "share_tok", "peer_alice", AccessScope.ACCESS_SCOPE_BROWSE, null);
            assertFalse(noTok.isAuthorized(), "Access without token must be rejected when token required");
            assertEquals(ShareManager.ValidationResult.RejectReason.TOKEN_REQUIRED, noTok.rejectReason(), "Must reject TOKEN_REQUIRED");

            // Alice with valid token is authorized
            AccessGrant grant = manager.issueGrant("share_tok", "peer_alice", Set.of(AccessScope.ACCESS_SCOPE_BROWSE), 60_000L);
            ShareManager.ValidationResult withTok = manager.validateAccess(
                    "share_tok", "peer_alice", AccessScope.ACCESS_SCOPE_BROWSE, grant.toToken());
            assertTrue(withTok.isAuthorized(), "Access with valid token must be authorized");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testTamperedTokenSignatureRejection() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_share_test_8");
        try {
            ShareManager manager = new ShareManager();
            ShareDefinition share = new ShareDefinition(
                    "share_tamper", "Protected", tempDir,
                    Set.of("peer_alice", "peer_eve"),
                    Set.of(AccessScope.ACCESS_SCOPE_BROWSE),
                    System.currentTimeMillis(), 0L, 30_000L, false, true, false, "sec_tamper"
            );
            manager.registerShare(share);

            AccessGrant grant = manager.issueGrant("share_tamper", "peer_alice", Set.of(AccessScope.ACCESS_SCOPE_BROWSE), 60_000L);

            // Forge/tamper by altering requester peer ID
            AccessGrant forged = new AccessGrant(
                    grant.grantId(), grant.shareId(), "peer_eve", grant.scopes(),
                    grant.issuedAtUtcMs(), grant.expiresAtUtcMs(), grant.signatureHex()
            );

            ShareManager.ValidationResult tampered = manager.validateAccess(
                    "share_tamper", "peer_eve", AccessScope.ACCESS_SCOPE_BROWSE, forged.toToken());
            assertFalse(tampered.isAuthorized(), "Tampered signature must be rejected");
            assertEquals(ShareManager.ValidationResult.RejectReason.INVALID_SIGNATURE, tampered.rejectReason(), "Must reject INVALID_SIGNATURE");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testGuestSharingConstraints() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_share_test_9");
        try {
            ShareManager manager = new ShareManager();
            ShareDefinition share = new ShareDefinition(
                    "share_guest", "Public Showcase", tempDir,
                    Set.of(),
                    Set.of(AccessScope.ACCESS_SCOPE_BROWSE),
                    System.currentTimeMillis(), 0L, 30_000L, false, true, true, "sec_guest"
            );
            manager.registerShare(share);

            // Valid guest token
            ShareCapability guestCap = ShareCapability.issueGuest(
                    "share_guest", Set.of(SharePermission.SHARE_PERMISSION_BROWSE),
                    System.currentTimeMillis(), System.currentTimeMillis() + 60_000L, "sec_guest");

            ShareManager.ValidationResult guestOk = manager.validateAccess(
                    "share_guest", "GUEST", AccessScope.ACCESS_SCOPE_BROWSE, guestCap.toToken());
            assertTrue(guestOk.isAuthorized(), "Guest token under GUEST identity must be authorized");

            // Guest token claiming a trusted peer identity
            ShareManager.ValidationResult guestEve = manager.validateAccess(
                    "share_guest", "peer_trusted_alice", AccessScope.ACCESS_SCOPE_BROWSE, guestCap.toToken());
            assertFalse(guestEve.isAuthorized(), "Guest token cannot bind trusted peer identity");
            assertEquals(ShareManager.ValidationResult.RejectReason.GUEST_IDENTITY_VIOLATION, guestEve.rejectReason(), "Must reject GUEST_IDENTITY_VIOLATION");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testPathTraversalRejection() throws IOException, PathSandboxValidator.PathTraversalException {
        Path root = Files.createTempDirectory("peerlink_traversal_root");
        try {
            PathSandboxValidator validator = new PathSandboxValidator();

            // 1. Parent directory traversal
            assertThrows(PathSandboxValidator.PathTraversalException.class, () -> validator.resolveAndValidate(root, "../secret.txt"));
            assertThrows(PathSandboxValidator.PathTraversalException.class, () -> validator.resolveAndValidate(root, "docs/../../etc/passwd"));

            // 2. Drive letter injection
            assertThrows(PathSandboxValidator.PathTraversalException.class, () -> validator.resolveAndValidate(root, "C:\\Windows\\System32"));
            assertThrows(PathSandboxValidator.PathTraversalException.class, () -> validator.resolveAndValidate(root, "D:file.txt"));

            // 3. UNC prefix
            assertThrows(PathSandboxValidator.PathTraversalException.class, () -> validator.resolveAndValidate(root, "\\\\192.168.1.1\\admin$"));

            // 4. Alternate data stream
            assertThrows(PathSandboxValidator.PathTraversalException.class, () -> validator.resolveAndValidate(root, "file.txt:$DATA"));

            // 5. Null byte poison
            assertThrows(PathSandboxValidator.PathTraversalException.class, () -> validator.resolveAndValidate(root, "file.txt\0.jpg"));

            // Safe relative path succeeds
            Path safe = validator.resolveAndValidate(root, "documents/report.txt");
            assertTrue(safe.startsWith(root), "Safe path must stay within root");
        } finally {
            deleteRecursively(root);
        }
    }

    private static void testSafePreviewRejectsExecutables() throws IOException, SafePreviewEngine.UnsafePreviewException {
        Path tempDir = Files.createTempDirectory("peerlink_preview_test");
        try {
            Path exeFile = tempDir.resolve("malicious.exe");
            Files.writeString(exeFile, "MZ simulated executable");

            Path shFile = tempDir.resolve("script.sh");
            Files.writeString(shFile, "#!/bin/bash\necho bad");

            Path txtFile = tempDir.resolve("readme.txt");
            Files.writeString(txtFile, "Hello safe text world!");

            SafePreviewEngine engine = new SafePreviewEngine();

            // Executable extensions rejected
            assertThrows(SafePreviewEngine.UnsafePreviewException.class, () -> engine.generatePreview(exeFile, 1024));
            assertThrows(SafePreviewEngine.UnsafePreviewException.class, () -> engine.generatePreview(shFile, 1024));

            // Safe text file permitted
            SafePreviewEngine.PreviewResult preview = engine.generatePreview(txtFile, 1024);
            assertEquals("text/plain", preview.mimeType(), "Mime type must be text/plain");
            assertEquals("Hello safe text world!", new String(preview.data(), StandardCharsets.UTF_8), "Preview content must match");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testSafePreviewBoundedRead() throws IOException, SafePreviewEngine.UnsafePreviewException {
        Path tempDir = Files.createTempDirectory("peerlink_preview_bounded");
        try {
            Path largeText = tempDir.resolve("large.txt");
            byte[] bigContent = new byte[100 * 1024]; // 100 KB
            Arrays.fill(bigContent, (byte) 'A');
            Files.write(largeText, bigContent);

            SafePreviewEngine engine = new SafePreviewEngine();
            SafePreviewEngine.PreviewResult result = engine.generatePreview(largeText, 10 * 1024); // Request 10 KB

            assertEquals(10 * 1024, result.data().length, "Preview must be bounded to 10KB");
            assertTrue(result.isTruncated(), "Truncated flag must be true");
            assertEquals(100 * 1024, result.originalSizeBytes(), "Original size must be 100KB");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testBoundedFileReaderOnDemandRetrieval() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_bounded_reader");
        try {
            Path file = tempDir.resolve("document.pdf");
            byte[] content = "PDF content for testing on-demand bounded read".getBytes(StandardCharsets.UTF_8);
            Files.write(file, content);

            BoundedFileReader.ReadResult res = BoundedFileReader.readBounded(file, 4096);
            assertTrue(res.isComplete(), "File under limit must be read completely");
            assertEquals(content.length, res.data().length, "Byte count must match");
            assertEquals((long) content.length, res.totalFileSizeBytes(), "Total size must match");
            assertNotNull(res.sha256Hex(), "SHA-256 must be calculated");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testSafeDestinationHandler() throws Exception {
        Path destRoot = Files.createTempDirectory("peerlink_dest_test");
        try {
            SafeDestinationHandler handler = new SafeDestinationHandler(destRoot);
            byte[] fileBytes = "Verified destination content".getBytes(StandardCharsets.UTF_8);

            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(fileBytes);
            String hashHex = bytesToHex(md.digest());

            Path committed = handler.commitContent("reports/final_2026.txt", fileBytes, hashHex);

            assertTrue(Files.exists(committed), "Committed file must exist in destination");
            assertEquals("Verified destination content", Files.readString(committed), "Content must match");
            assertTrue(committed.startsWith(destRoot), "File must be inside destRoot");

            // Verify temporary .part staging file was cleaned up
            try (var stream = Files.list(committed.getParent())) {
                boolean hasPart = stream.anyMatch(p -> p.getFileName().toString().contains(".part"));
                assertFalse(hasPart, "Staging .part file must be cleaned up");
            }
        } finally {
            deleteRecursively(destRoot);
        }
    }

    private static void testSafeDestinationHandlerHashMismatch() throws Exception {
        Path destRoot = Files.createTempDirectory("peerlink_dest_mismatch");
        try {
            SafeDestinationHandler handler = new SafeDestinationHandler(destRoot);
            byte[] fileBytes = "Real content".getBytes(StandardCharsets.UTF_8);
            String wrongHash = "0000000000000000000000000000000000000000000000000000000000000000";

            assertThrows(SecurityException.class, () -> handler.commitContent("corrupted.txt", fileBytes, wrongHash));

            Path target = destRoot.resolve("corrupted.txt");
            assertFalse(Files.exists(target), "File with mismatched hash must NEVER be committed to destination");
        } finally {
            deleteRecursively(destRoot);
        }
    }

    private static void testDestinationPathTraversalRejection() throws IOException {
        Path destRoot = Files.createTempDirectory("peerlink_dest_traversal");
        try {
            SafeDestinationHandler handler = new SafeDestinationHandler(destRoot);
            byte[] fileBytes = "Attempted escape".getBytes(StandardCharsets.UTF_8);

            assertThrows(PathSandboxValidator.PathTraversalException.class, () ->
                    handler.commitContent("../../evil.txt", fileBytes, null));
        } finally {
            deleteRecursively(destRoot);
        }
    }

    private static void testRemoteFolderBrowserBoundedPagination() throws IOException, CancellationToken.OperationCancelledException, PathSandboxValidator.PathTraversalException {
        Path root = Files.createTempDirectory("peerlink_browser_test");
        try {
            Files.writeString(root.resolve("b_doc.txt"), "b");
            Files.writeString(root.resolve("a_doc.txt"), "a");
            Files.createDirectories(root.resolve("z_subfolder"));
            Files.createDirectories(root.resolve("a_subfolder"));

            RemoteFolderBrowser browser = new RemoteFolderBrowser();
            RemoteFolderBrowser.BrowseResult res = browser.browse(root, "", 2, "0", null);

            assertEquals(2, res.items().size(), "Page size of 2 must return 2 items");
            assertTrue(res.hasMore(), "Has more must be true");
            assertEquals("2", res.nextCursor(), "Next cursor must be 2");

            // Directories sorted first
            assertEquals("a_subfolder", res.items().get(0).getDisplayName(), "Directory must be listed first");
            assertEquals("z_subfolder", res.items().get(1).getDisplayName(), "Directory must be listed second");
        } finally {
            deleteRecursively(root);
        }
    }

    private static void testRemoteSearchEngineDepthAndLimits() throws IOException, CancellationToken.OperationCancelledException, PathSandboxValidator.PathTraversalException {
        Path root = Files.createTempDirectory("peerlink_search_test");
        try {
            Path d1 = root.resolve("level1");
            Path d2 = d1.resolve("level2");
            Path d3 = d2.resolve("level3");
            Files.createDirectories(d3);

            Files.writeString(root.resolve("match_root.txt"), "match");
            Files.writeString(d1.resolve("match_d1.txt"), "match");
            Files.writeString(d2.resolve("match_d2.txt"), "match");
            Files.writeString(d3.resolve("match_d3.txt"), "match");

            RemoteSearchEngine engine = new RemoteSearchEngine();

            // Search with maxDepth = 2 should only find match_root and match_d1 (excluding level2 and level3)
            RemoteSearchEngine.SearchResult res = engine.search(root, "", "match", 50, 2, 3000, null, null);
            assertEquals(2, res.matches().size(), "Search bounded by depth 2 must only return 2 matches");
        } finally {
            deleteRecursively(root);
        }
    }

    private static void testArchiveInspectorZipSlipDetection() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_archive_test");
        try {
            Path zipFile = tempDir.resolve("archive.zip");
            try (ZipOutputStream zos = new ZipOutputStream(Files.newOutputStream(zipFile))) {
                ZipEntry safe = new ZipEntry("content/safe.txt");
                zos.putNextEntry(safe);
                zos.write("safe".getBytes(StandardCharsets.UTF_8));
                zos.closeEntry();

                ZipEntry slip = new ZipEntry("../../evil.exe");
                zos.putNextEntry(slip);
                zos.write("malicious".getBytes(StandardCharsets.UTF_8));
                zos.closeEntry();
            }

            ArchiveInspector inspector = new ArchiveInspector();
            var entries = inspector.inspectZip(zipFile);

            assertEquals(2, entries.size(), "Archive must contain 2 entries");
            assertTrue(entries.get(0).getIsSafe(), "Entry 0 must be safe");
            assertFalse(entries.get(1).getIsSafe(), "Zip-slip entry 1 must be flagged unsafe");
            assertTrue(entries.get(1).getWarning().contains("Zip-Slip"), "Warning must mention Zip-Slip");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testTwoNodeNetworkRequestExchange() throws Exception {
        Path nodeBSharedDir = Files.createTempDirectory("node_b_shared");
        Path nodeADownloadsDir = Files.createTempDirectory("node_a_downloads");

        try {
            // Setup Node B shared files
            Files.writeString(nodeBSharedDir.resolve("contract.pdf"), "Official PeerLink Node B Contract 2026");
            Files.writeString(nodeBSharedDir.resolve("notes.txt"), "Meeting notes from Node B");

            ShareManager nodeBShareManager = new ShareManager();
            ShareDefinition share = new ShareDefinition(
                    "share_node_b", "Node B Shared Space", nodeBSharedDir,
                    Set.of("peer_node_a"),
                    Set.of(AccessScope.ACCESS_SCOPE_FULL),
                    System.currentTimeMillis(), 0L, "node_b_auth_secret_777"
            );
            nodeBShareManager.registerShare(share);

            AccessGrant grant = nodeBShareManager.issueGrant("share_node_b", "peer_node_a", Set.of(AccessScope.ACCESS_SCOPE_FULL), 60_000L);
            String validToken = grant.toToken();

            // Start Node B ServerSocket
            ServerSocket serverSocket = new ServerSocket(0);
            int serverPort = serverSocket.getLocalPort();
            AtomicBoolean serverRunning = new AtomicBoolean(true);

            Thread serverThread = new Thread(() -> {
                try {
                    while (serverRunning.get()) {
                        Socket socket = serverSocket.accept();
                        DataInputStream in = new DataInputStream(socket.getInputStream());
                        DataOutputStream out = new DataOutputStream(socket.getOutputStream());

                        // Read request framing: [command (UTF)] [shareId (UTF)] [relPath (UTF)] [token (UTF)]
                        String cmd = in.readUTF();
                        String shareId = in.readUTF();
                        String relPath = in.readUTF();
                        String token = in.readUTF();

                        AccessScope reqScope = switch (cmd) {
                            case "BROWSE" -> AccessScope.ACCESS_SCOPE_BROWSE;
                            case "DOWNLOAD" -> AccessScope.ACCESS_SCOPE_DOWNLOAD;
                            default -> AccessScope.ACCESS_SCOPE_READ_METADATA;
                        };

                        ShareManager.ValidationResult val = nodeBShareManager.validateAccess(shareId, "peer_node_a", reqScope, token);
                        if (!val.isAuthorized()) {
                            out.writeBoolean(false);
                            out.writeUTF(val.errorMessage());
                            out.flush();
                            socket.close();
                            continue;
                        }

                        Path targetFile = nodeBSharedDir.resolve(relPath).normalize();
                        if (!targetFile.startsWith(nodeBSharedDir)) {
                            out.writeBoolean(false);
                            out.writeUTF("Path traversal rejected");
                            out.flush();
                            socket.close();
                            continue;
                        }

                        if ("BROWSE".equals(cmd)) {
                            out.writeBoolean(true);
                            List<String> files = new ArrayList<>();
                            try (var stream = Files.list(nodeBSharedDir)) {
                                stream.forEach(p -> files.add(p.getFileName().toString()));
                            }
                            out.writeInt(files.size());
                            for (String f : files) out.writeUTF(f);
                        } else if ("DOWNLOAD".equals(cmd)) {
                            out.writeBoolean(true);
                            BoundedFileReader.ReadResult readRes = BoundedFileReader.readBounded(targetFile, 1024 * 1024);
                            out.writeUTF(readRes.sha256Hex());
                            out.writeInt(readRes.data().length);
                            out.write(readRes.data());
                        }

                        out.flush();
                        socket.close();
                    }
                } catch (Exception ignored) {
                }
            });
            serverThread.setDaemon(true);
            serverThread.start();

            // Node A connects and executes real wire requests
            try {
                // 1. Node A requests BROWSE over socket
                try (Socket clientSocket = new Socket("127.0.0.1", serverPort)) {
                    DataOutputStream out = new DataOutputStream(clientSocket.getOutputStream());
                    DataInputStream in = new DataInputStream(clientSocket.getInputStream());

                    out.writeUTF("BROWSE");
                    out.writeUTF("share_node_b");
                    out.writeUTF("");
                    out.writeUTF(validToken);
                    out.flush();

                    boolean success = in.readBoolean();
                    assertTrue(success, "Node A browse request to Node B must succeed over wire");
                    int count = in.readInt();
                    assertEquals(2, count, "Node B must return 2 shared files");
                }

                // 2. Node A requests DOWNLOAD of contract.pdf over socket
                byte[] retrievedBytes;
                String retrievedHash;
                try (Socket clientSocket = new Socket("127.0.0.1", serverPort)) {
                    DataOutputStream out = new DataOutputStream(clientSocket.getOutputStream());
                    DataInputStream in = new DataInputStream(clientSocket.getInputStream());

                    out.writeUTF("DOWNLOAD");
                    out.writeUTF("share_node_b");
                    out.writeUTF("contract.pdf");
                    out.writeUTF(validToken);
                    out.flush();

                    boolean success = in.readBoolean();
                    assertTrue(success, "Node A download request to Node B must succeed over wire");
                    retrievedHash = in.readUTF();
                    int len = in.readInt();
                    retrievedBytes = new byte[len];
                    in.readFully(retrievedBytes);
                }

                // 3. Node A commits retrieved content using SafeDestinationHandler
                SafeDestinationHandler nodeADestHandler = new SafeDestinationHandler(nodeADownloadsDir);
                Path localFile = nodeADestHandler.commitContent("contract_from_b.pdf", retrievedBytes, retrievedHash);

                assertTrue(Files.exists(localFile), "Retrieved file must be safely committed to Node A destination");
                assertEquals("Official PeerLink Node B Contract 2026", Files.readString(localFile), "File content must match bit-for-bit");
                assertTrue(localFile.startsWith(nodeADownloadsDir), "File must be strictly quarantined within Node A downloads directory");

            } finally {
                serverRunning.set(false);
                serverSocket.close();
            }

        } finally {
            deleteRecursively(nodeBSharedDir);
            deleteRecursively(nodeADownloadsDir);
        }
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    private static void deleteRecursively(Path root) {
        try {
            if (Files.exists(root)) {
                Files.walk(root)
                        .sorted(Comparator.reverseOrder())
                        .forEach(p -> {
                            try {
                                Files.deleteIfExists(p);
                            } catch (IOException ignored) {}
                        });
            }
        } catch (IOException ignored) {}
    }
}
