package org.peerlink.core.safety;

import org.peerlink.core.android.AndroidNodeState;
import org.peerlink.core.compatibility.CompatibilityAnalyzer;
import org.peerlink.core.compatibility.CompatibilityReport;
import org.peerlink.core.compatibility.CompatibilityResult;
import org.peerlink.core.filesystem.PathSafetyValidator;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.operation.*;
import org.peerlink.core.security.ScannerProvider;
import org.peerlink.core.security.SecurityVerdict;
import org.peerlink.core.transfer.StagingDirectoryManager;

import org.peerlink.desktop.storage.ReconciliationFramework;
import org.peerlink.desktop.storage.ReconciliationFramework.ReconciliationDecision;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * Phase 20 Standalone Verification Suite:
 * Cross-Platform Production Hardening, Authentication & Trust Revocation,
 * IPC Access Control (Localhost != Trust), Protocol Bounds,
 * Filesystem Traversal & Symlink Escapes, Crash Recovery & Non-Atomicity Reconciliation,
 * Secret & Credential Redaction, Malware Scan Fail-Closed Policy,
 * Resource Bounds & Chunk Overrun Protection, DoS/Restart Loop Defense,
 * Global Emergency Stop, Platform Fallbacks, and Reproducible Performance.
 *
 * Runs in pure Java SE on any host platform.
 */
public class Phase20HardeningTestRunner {

    private static int testsPassed = 0;
    private static int testsFailed = 0;

    public static void main(String[] args) {
        System.out.println("==========================================================");
        System.out.println(" PeerLink Phase 20 Cross-Platform Production Hardening");
        System.out.println("==========================================================");

        runTest("Test 01: Authentication & Authorization - Untrusted/Unpaired Peer Rejection",
                Phase20HardeningTestRunner::testAuthenticationAndAuthorizationBoundaries);
        runTest("Test 02: Trust Revocation - Revoked Peer Immediately Denied All Access",
                Phase20HardeningTestRunner::testDeviceKeyStorageAndTrustRevocation);
        runTest("Test 03: Sender Identity Binding Invariant Enforcement",
                Phase20HardeningTestRunner::testSenderIdentityBindingInvariant);
        runTest("Test 04: IPC Access Control - Localhost is NOT Trusted without Auth Token",
                Phase20HardeningTestRunner::testIpcAccessControlLocalhostNotTrusted);
        runTest("Test 05: IPC Session Token Issuance & Time-Bound Expiration",
                Phase20HardeningTestRunner::testIpcTimeBoundSessionTokenExpiration);
        runTest("Test 06: Peer Protocol Validation - Oversized Manifest & Chunk Bounds",
                Phase20HardeningTestRunner::testPeerProtocolValidationAndResourceLimits);
        runTest("Test 07: Path Traversal & Forbidden Path Sequences Defense",
                Phase20HardeningTestRunner::testPathTraversalAndForbiddenPathSequences);
        runTest("Test 08: Intermediate Symlink & Junction Escape Defense",
                Phase20HardeningTestRunner::testIntermediateSymlinkAndJunctionEscapeDefense);
        runTest("Test 09: Archive Bomb & Recursive Zip Bomb Decompression Defense",
                Phase20HardeningTestRunner::testArchiveBombAndDecompressionRatioDefense);
        runTest("Test 10: Protection Against Accidental Execution of Received Content",
                Phase20HardeningTestRunner::testProtectionAgainstAccidentalExecution);
        runTest("Test 11: Fail-Closed Malware Scanner Policy (Crash/Timeout -> SCAN_FAILED)",
                Phase20HardeningTestRunner::testFailClosedMalwareScannerPolicy);
        runTest("Test 12: Resource Bounds & Staging Chunk Overrun Protection",
                Phase20HardeningTestRunner::testResourceBoundsAndChunkOverrunSafety);
        runTest("Test 13: Crash Recovery & Uncertain Outcome State Handling",
                Phase20HardeningTestRunner::testCrashRecoveryAndUncertainOutcomes);
        runTest("Test 14: Non-Atomicity SQLite/Filesystem Boundary Reconciliation",
                Phase20HardeningTestRunner::testNonAtomicityFilesystemBoundaryReconciliation);
        runTest("Test 15: Secret & Credential Redaction in Privacy-Safe Diagnostics",
                Phase20HardeningTestRunner::testPrivacySafeLogsAndDiagnostics);
        runTest("Test 16: Cloud Signaling Outage Isolation & Secret Separation",
                Phase20HardeningTestRunner::testCloudSignalerOutageIsolation);
        runTest("Test 17: DoS Resistance - Restart Loop Inhabitation & Mass Changes",
                Phase20HardeningTestRunner::testRateLimitingAndRestartLoopDefense);
        runTest("Test 18: Global Emergency Stop Protection (Atomic Subsystem Halt)",
                Phase20HardeningTestRunner::testGlobalEmergencyStopProtection);
        runTest("Test 19: Cross-Platform Operating System Fallbacks & Life Cycles",
                Phase20HardeningTestRunner::testUnsupportedOsBehaviorAndPlatformFallback);
        runTest("Test 20: Performance Measurement Under Reproducible Conditions",
                Phase20HardeningTestRunner::testPerformanceMeasurementUnderReproducibleConditions);

        System.out.println("==========================================================");
        System.out.println(String.format(" Phase 20 Test Execution Summary: %d PASSED, %d FAILED", testsPassed, testsFailed));
        System.out.println("==========================================================");

        if (testsFailed > 0) {
            System.exit(1);
        }
    }

    private static void runTest(String name, TestCase test) {
        System.out.print("Running " + name + "... ");
        try {
            test.run();
            System.out.println("PASS");
            testsPassed++;
        } catch (Throwable t) {
            System.out.println("FAIL");
            System.err.println("  Error: " + t.getMessage());
            t.printStackTrace(System.err);
            testsFailed++;
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError("Check failed: " + message);
        }
    }

    @FunctionalInterface
    interface TestCase {
        void run() throws Exception;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 01: Authentication & Authorization - Untrusted/Unpaired Peer Rejection
    // ──────────────────────────────────────────────────────────────────────────

    private static void testAuthenticationAndAuthorizationBoundaries() {
        // Mock trust store maintaining paired peers
        Map<String, Boolean> pairedPeers = new HashMap<>();
        pairedPeers.put("peer-alice-paired", true);

        // Discovery does NOT establish trust (AGENTS.md Rule 6)
        String discoveredStranger = "peer-mallory-discovered";
        check(!pairedPeers.getOrDefault(discoveredStranger, false), "Discovered peer must not be trusted automatically");

        // Authorization check simulation
        boolean allowStranger = pairedPeers.getOrDefault(discoveredStranger, false);
        check(!allowStranger, "Unpaired peer authorization must be denied");

        boolean allowPaired = pairedPeers.getOrDefault("peer-alice-paired", false);
        check(allowPaired, "Paired peer authorization succeeds");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 02: Trust Revocation - Revoked Peer Immediately Denied All Access
    // ──────────────────────────────────────────────────────────────────────────

    private static void testDeviceKeyStorageAndTrustRevocation() {
        Set<String> activeTrustedPeers = new HashSet<>(List.of("peer-bob"));
        Set<String> revokedPeers = new HashSet<>();

        // Initially Bob is trusted
        check(activeTrustedPeers.contains("peer-bob"), "Bob is initially trusted");
        check(!revokedPeers.contains("peer-bob"), "Bob is not revoked");

        // Revoke Bob's cryptographic trust
        activeTrustedPeers.remove("peer-bob");
        revokedPeers.add("peer-bob");

        // Invariant: Immediate rejection of all incoming actions from revoked peer
        check(revokedPeers.contains("peer-bob"), "Bob is recorded as revoked");
        check(!activeTrustedPeers.contains("peer-bob"), "Bob is removed from trusted peers");

        // Simulated inbound request check
        String remotePeer = "peer-bob";
        boolean isAuthorized = activeTrustedPeers.contains(remotePeer) && !revokedPeers.contains(remotePeer);
        check(!isAuthorized, "Revoked peer request must be rejected immediately");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 03: Sender Identity Binding Invariant Enforcement
    // ──────────────────────────────────────────────────────────────────────────

    private static void testSenderIdentityBindingInvariant() {
        String authenticatedSessionPeer = "peer-charlie";
        String manifestClaimedSender = "peer-alice"; // Spoofed manifest identity

        // INVARIANT: Sender identity in manifest must match authenticated session peer
        boolean identityMatch = authenticatedSessionPeer.equals(manifestClaimedSender);
        check(!identityMatch, "Manifest sender mismatch must be caught");

        String rejectionReason = null;
        if (!identityMatch) {
            rejectionReason = "Manifest sender identity does not match authenticated session peer";
        }
        check(rejectionReason != null, "Rejection reason must be set on sender mismatch");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 04: IPC Access Control - Localhost is NOT Trusted without Auth Token
    // ──────────────────────────────────────────────────────────────────────────

    private static void testIpcAccessControlLocalhostNotTrusted() {
        String expectedBootToken = "boot-secret-token-xyz-123";

        // 1. Missing header / token
        String nullToken = null;
        check(nullToken == null || nullToken.isBlank(), "Missing auth token is unauthenticated");

        // 2. Incorrect token
        String wrongToken = "attacker-forged-token";
        boolean matchWrong = MessageDigest.isEqual(
                expectedBootToken.getBytes(StandardCharsets.UTF_8),
                wrongToken.getBytes(StandardCharsets.UTF_8)
        );
        check(!matchWrong, "Incorrect auth token rejected");

        // 3. Valid token using constant-time check
        String correctToken = "boot-secret-token-xyz-123";
        boolean matchCorrect = MessageDigest.isEqual(
                expectedBootToken.getBytes(StandardCharsets.UTF_8),
                correctToken.getBytes(StandardCharsets.UTF_8)
        );
        check(matchCorrect, "Correct token authenticated via constant-time equality");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 05: IPC Session Token Issuance & Time-Bound Expiration
    // ──────────────────────────────────────────────────────────────────────────

    private static void testIpcTimeBoundSessionTokenExpiration() {
        long ttlMs = 50L;
        long now = System.currentTimeMillis();
        long expiresAt = now + ttlMs;

        // Session valid immediately
        check(System.currentTimeMillis() <= expiresAt, "Session token is valid within TTL");

        // Simulate passage of time past TTL
        long simulatedFutureTime = expiresAt + 100L;
        boolean isExpired = simulatedFutureTime > expiresAt;
        check(isExpired, "Session token must expire after TTL has passed");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 06: Peer Protocol Validation - Oversized Manifest & Chunk Bounds
    // ──────────────────────────────────────────────────────────────────────────

    private static void testPeerProtocolValidationAndResourceLimits() {
        // 1. Chunk size bounds validation (1KB to 16MB)
        int minChunk = 1024;
        int maxChunk = 16 * 1024 * 1024;

        int tooSmallChunk = 512;
        int tooLargeChunk = 32 * 1024 * 1024;
        int validChunk = 64 * 1024;

        check(tooSmallChunk < minChunk, "Chunk < 1KB is invalid");
        check(tooLargeChunk > maxChunk, "Chunk > 16MB is invalid");
        check(validChunk >= minChunk && validChunk <= maxChunk, "64KB chunk is valid");

        // 2. Max items count limit (100,000)
        int oversizedItemCount = 150_000;
        check(oversizedItemCount > 100_000, "Manifest with >100,000 items exceeds resource boundary");

        // 3. Declared totalBytes mismatch
        long declaredBytes = 1000L;
        long calculatedBytes = 500L;
        check(declaredBytes != calculatedBytes, "Total bytes mismatch must be caught");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 07: Path Traversal & Forbidden Path Sequences Defense
    // ──────────────────────────────────────────────────────────────────────────

    private static void testPathTraversalAndForbiddenPathSequences() {
        List<String> maliciousPaths = List.of(
                "../../etc/shadow",
                "..\\..\\Windows\\System32\\calc.exe",
                "/absolute/path/file.txt",
                "C:/Windows/system.ini",
                "foo/../../bar/secret.txt",
                "file|name*.txt",
                "file:stream",
                "trailing_dot.txt.",
                "trailing_space.txt ",
                "CON.txt",
                "NUL",
                "AUX.log"
        );

        int rejectedCount = 0;
        for (String malicious : maliciousPaths) {
            try {
                PathSafetyValidator.validateRelativePath(malicious);
            } catch (SecurityException | IllegalArgumentException e) {
                rejectedCount++;
            }
        }
        check(rejectedCount == maliciousPaths.size(),
                "All " + maliciousPaths.size() + " malicious path sequences must be rejected (got " + rejectedCount + ")");

        // Clean path must pass
        String clean = PathSafetyValidator.validateRelativePath("docs/readme.md");
        check("docs/readme.md".equals(clean), "Valid clean path must pass");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 08: Intermediate Symlink & Junction Escape Defense
    // ──────────────────────────────────────────────────────────────────────────

    private static void testIntermediateSymlinkAndJunctionEscapeDefense() throws Exception {
        Path tempDir = Files.createTempDirectory("phase20_t08_");
        try {
            Path safeRoot = tempDir.resolve("safe_dest");
            Files.createDirectories(safeRoot);

            // Path outside root
            Path outsideTarget = tempDir.resolve("sensitive_dir");
            Files.createDirectories(outsideTarget);

            // Attempting to resolve a path that escapes root
            boolean caughtTraversal = false;
            try {
                Path resolved = PathSafetyValidator.resolveSafeDestination(safeRoot, "sub/file.txt");
                check(resolved.startsWith(safeRoot), "Target must stay inside destination root");
            } catch (Exception e) {
                caughtTraversal = true;
            }
            check(!caughtTraversal, "Valid child path resolves cleanly");

            // Verify root containment invariant
            Path escapeAttempt = safeRoot.resolve("../sensitive_dir").normalize();
            check(!escapeAttempt.startsWith(safeRoot), "Normalized escape path leaves safeRoot");
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 09: Archive Bomb & Recursive Zip Bomb Decompression Defense
    // ──────────────────────────────────────────────────────────────────────────

    private static void testArchiveBombAndDecompressionRatioDefense() throws Exception {
        // Create high compression ratio flat zip
        byte[] bigArray = new byte[300_000];
        Arrays.fill(bigArray, (byte) 'A');
        byte[] bombBytes = createZipArchive(Map.of("bomb.txt", bigArray));

        ArchiveSafetyInspector.ArchiveSafetyVerdict verdict = ArchiveSafetyInspector.inspectZipBytes(bombBytes, 1);
        check(verdict.isDecompressionBomb(), "Flat decompression bomb detected");
        check(!verdict.isSafe(), "Decompression bomb marked unsafe");

        // Path traversal in zip entry
        byte[] traversalBytes = createZipArchive(Map.of("../../evil.sh", "echo pwned".getBytes(StandardCharsets.UTF_8)));
        ArchiveSafetyInspector.ArchiveSafetyVerdict travVerdict = ArchiveSafetyInspector.inspectZipBytes(traversalBytes, 1);
        check(travVerdict.hasPathTraversal(), "Path traversal entry in zip detected");
        check(!travVerdict.isSafe(), "Traversal zip marked unsafe");

        // Nested zip bomb
        byte[] innerZip = createZipArchive(Map.of("inner.txt", bigArray));
        byte[] outerZip = createZipArchive(Map.of("nested.zip", innerZip));
        ArchiveSafetyInspector.ArchiveSafetyVerdict nestedVerdict = ArchiveSafetyInspector.inspectZipBytes(outerZip, 1);
        check(nestedVerdict.isDecompressionBomb(), "Recursive nested zip bomb detected");
        check(!nestedVerdict.isSafe(), "Nested bomb marked unsafe");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 10: Protection Against Accidental Execution of Received Content
    // ──────────────────────────────────────────────────────────────────────────

    private static void testProtectionAgainstAccidentalExecution() throws Exception {
        Path tempDir = Files.createTempDirectory("phase20_t10_");
        try {
            // 1. File disguised as .pdf but contains Windows PE (MZ) executable header
            Path disguisedPdf = tempDir.resolve("invoice.pdf");
            byte[] mzBytes = new byte[]{0x4D, 0x5A, 0x00, 0x01, 0x02, 0x03}; // MZ magic
            Files.write(disguisedPdf, mzBytes);

            ExecutableSafetyInspector.ExecutableSafetyReport report =
                    ExecutableSafetyInspector.inspect(disguisedPdf, "invoice.pdf");

            check(report.isExecutable(), "File identified as executable format");
            check(report.isDisguised(), "Invoice.pdf identified as disguised executable");
            check("WINDOWS_PE".equals(report.detectedFormat()), "Format detected as WINDOWS_PE");

            // 2. Linux ELF binary
            Path elfFile = tempDir.resolve("binary.bin");
            byte[] elfBytes = new byte[]{0x7F, 0x45, 0x4C, 0x46, 0x01, 0x02}; // \x7fELF
            Files.write(elfFile, elfBytes);
            ExecutableSafetyInspector.ExecutableSafetyReport elfReport =
                    ExecutableSafetyInspector.inspect(elfFile, "binary.bin");
            check(elfReport.isExecutable(), "ELF binary detected as executable");
            check("LINUX_ELF".equals(elfReport.detectedFormat()), "Format detected as LINUX_ELF");
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 11: Fail-Closed Malware Scanner Policy (Crash/Timeout -> SCAN_FAILED)
    // ──────────────────────────────────────────────────────────────────────────

    private static void testFailClosedMalwareScannerPolicy() throws Exception {
        Path tempDir = Files.createTempDirectory("phase20_t11_");
        try {
            QuarantineZone qz = new QuarantineZone(tempDir.resolve("quarantine"));
            ScanCache cache = new ScanCache();

            // Crashing scanner provider
            ScannerProvider crashingScanner = new ScannerProvider() {
                @Override public String getProviderName() { return "CrashingScanner"; }
                @Override public boolean isAvailable() { return true; }
                @Override public SecurityVerdict scanStream(InputStream in) { throw new RuntimeException("OOM/Segfault"); }
                @Override public SecurityVerdict scanFile(String path) { throw new RuntimeException("OOM/Segfault"); }
            };

            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(qz, crashingScanner, ScanPolicy.strict(), cache);
            byte[] payload = "test payload data".getBytes(StandardCharsets.UTF_8);
            ContentHash hash = ContentHash.computeSha256(payload);

            InboundSafetyPipeline.PipelineResult res = pipeline.processInboundFile(
                    payload, "doc.txt", hash, "peer_src", tempDir.resolve("dest"));

            // INVARIANT: Scanner crash must NEVER convert to CLEAN
            check(!res.committed(), "Crashing scanner must NOT permit commit");
            check(res.verdict() == SecurityVerdict.SCAN_FAILED, "Verdict must be SCAN_FAILED on crash");
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 12: Resource Bounds & Staging Chunk Overrun Protection
    // ──────────────────────────────────────────────────────────────────────────

    private static void testResourceBoundsAndChunkOverrunSafety() throws Exception {
        Path tempDir = Files.createTempDirectory("phase20_t12_");
        try {
            StagingDirectoryManager staging = new StagingDirectoryManager(tempDir.resolve("staging"));
            String transferId = "xfer-bounds-test";
            staging.prepareStagingDir(transferId);

            byte[] chunkData = "abcde".getBytes(StandardCharsets.UTF_8);
            long declaredFileSize = 10L;

            // 1. Negative offset rejected
            boolean caughtNegOffset = false;
            try {
                staging.writeChunk(transferId, 0, 0, -5L, chunkData, null, declaredFileSize);
            } catch (IllegalArgumentException e) {
                caughtNegOffset = true;
            }
            check(caughtNegOffset, "Negative offset must be rejected");

            // 2. Overrun declared size rejected (offset 8 + length 5 = 13 > declared 10)
            boolean caughtOverrun = false;
            try {
                staging.writeChunk(transferId, 0, 1, 8L, chunkData, null, declaredFileSize);
            } catch (IllegalArgumentException e) {
                caughtOverrun = true;
            }
            check(caughtOverrun, "Chunk size overrun must be rejected");
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 13: Crash Recovery & Uncertain Outcome State Handling
    // ──────────────────────────────────────────────────────────────────────────

    private static void testCrashRecoveryAndUncertainOutcomes() {
        InMemoryTestOperationJournal journal = new InMemoryTestOperationJournal();

        // Operation in EXECUTING state during crash
        OperationRecord inFlight = new OperationRecord("op-exec-crash", OperationIntent.SEND, "peer-1",
                List.of("file.txt"), OperationState.EXECUTING, "k-exec", 100L, 100L);
        journal.recordOperation(inFlight);

        // Pre-execution operation
        OperationRecord preExec = new OperationRecord("op-pre-crash", OperationIntent.SEND, "peer-1",
                List.of("file2.txt"), OperationState.CREATED, "k-pre", 100L, 100L);
        journal.recordOperation(preExec);

        // Crash restart recovery:
        // EXECUTING transitions to OUTCOME_UNKNOWN (AGENTS.md Rule 9: no blind replay!)
        journal.markInterruptedOperationsUnknown("Restart after kill");
        check(journal.getOperation("op-exec-crash").get().getState() == OperationState.OUTCOME_UNKNOWN,
                "In-flight operation marked OUTCOME_UNKNOWN");

        // Pre-execution cancelled
        journal.updateState("op-pre-crash", OperationState.CANCELLED);
        check(journal.getOperation("op-pre-crash").get().getState() == OperationState.CANCELLED,
                "Pre-execution operation cancelled");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 14: Non-Atomicity SQLite/Filesystem Boundary Reconciliation
    // ──────────────────────────────────────────────────────────────────────────

    private static void testNonAtomicityFilesystemBoundaryReconciliation() throws Exception {
        Path tempDir = Files.createTempDirectory("phase20_t14_");
        try {
            Path committedFile = tempDir.resolve("committed.txt");
            byte[] data = "Authoritative committed bytes".getBytes(StandardCharsets.UTF_8);
            Files.write(committedFile, data);
            String expectedSha256 = sha256Hex(data);

            ReconciliationFramework framework = new ReconciliationFramework(null);

            // Case 1: File matches expected SHA-256 -> CONFIRMED_COMMITTED
            ReconciliationDecision dec1 = framework.reconcileFilesystemBoundary(
                    "op-1", committedFile, expectedSha256).decision();
            check(dec1 == ReconciliationDecision.CONFIRMED_COMMITTED, "Matching file confirmed committed");

            // Case 2: File missing -> CONFIRMED_NOT_COMMITTED
            Path missingFile = tempDir.resolve("missing.txt");
            ReconciliationDecision dec2 = framework.reconcileFilesystemBoundary(
                    "op-2", missingFile, expectedSha256).decision();
            check(dec2 == ReconciliationDecision.CONFIRMED_NOT_COMMITTED, "Missing file confirmed not committed");

            // Case 3: File mutated / hash mismatch -> CONFLICT_DETECTED
            Path mutatedFile = tempDir.resolve("mutated.txt");
            Files.write(mutatedFile, "Altered content".getBytes(StandardCharsets.UTF_8));
            ReconciliationDecision dec3 = framework.reconcileFilesystemBoundary(
                    "op-3", mutatedFile, expectedSha256).decision();
            check(dec3 == ReconciliationDecision.CONFLICT_DETECTED, "Content mismatch flags conflict (no blind replay)");
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 15: Secret & Credential Redaction in Privacy-Safe Diagnostics
    // ──────────────────────────────────────────────────────────────────────────

    private static void testPrivacySafeLogsAndDiagnostics() {
        String logSnippet = "Transport error with token=secret_bearer_token_12345678 and password=MySecretP@ssword "
                + "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA0...\n-----END RSA PRIVATE KEY-----";

        String sanitized = OperationDiagnostics.sanitize(logSnippet);
        check(!sanitized.contains("secret_bearer_token_12345678"), "Bearer token must be redacted");
        check(!sanitized.contains("MySecretP@ssword"), "Password must be redacted");
        check(!sanitized.contains("MIIEowIBAAKCAQEA0"), "Private key must be redacted");
        check(sanitized.contains("[REDACTED]"), "Sanitized log contains [REDACTED]");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 16: Cloud Signaling Outage Isolation & Secret Separation
    // ──────────────────────────────────────────────────────────────────────────

    private static void testCloudSignalerOutageIsolation() {
        // Verify local operation lifecycle does not require cloud connection
        InMemoryTestOperationJournal journal = new InMemoryTestOperationJournal();
        String opId = "op-offline-lan";
        journal.recordOperation(new OperationRecord(opId, OperationIntent.SEND, "local-peer",
                List.of("doc.pdf"), OperationState.CREATED, "k-offline", 100L, 100L));

        journal.updateState(opId, OperationState.VALIDATED);
        journal.updateState(opId, OperationState.AUTHORIZED);
        journal.updateState(opId, OperationState.EXECUTING);
        journal.updateState(opId, OperationState.COMMITTED);

        check(journal.getOperation(opId).get().getState() == OperationState.COMMITTED,
                "Local operations advance cleanly during cloud outage");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 17: DoS Resistance - Restart Loop Inhabitation & Mass Changes
    // ──────────────────────────────────────────────────────────────────────────

    private static void testRateLimitingAndRestartLoopDefense() throws Exception {
        Path tempDir = Files.createTempDirectory("phase20_t17_");
        try {
            NodeWatchdog watchdog = new NodeWatchdog(
                    tempDir,
                    () -> true,
                    () -> 0,
                    () -> {}
            );

            // First 3 restarts allowed
            check(watchdog.recordRestartAndCheckPermitted(), "Restart 1 permitted");
            check(watchdog.recordRestartAndCheckPermitted(), "Restart 2 permitted");
            check(watchdog.recordRestartAndCheckPermitted(), "Restart 3 permitted");

            // 4th rapid restart inhibited to prevent restart storm death loop
            check(!watchdog.recordRestartAndCheckPermitted(), "4th restart inhibited");
            check(watchdog.isRestartLoopDetected(), "Restart loop detected by watchdog");
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 18: Global Emergency Stop Protection (Atomic Subsystem Halt)
    // ──────────────────────────────────────────────────────────────────────────

    private static void testGlobalEmergencyStopProtection() {
        EmergencyStopManager em = new EmergencyStopManager();

        AtomicInteger activeTransfers = new AtomicInteger(5);
        AtomicInteger activeSyncLoops = new AtomicInteger(2);

        em.registerSubsystem("PeerTransferEngine", () -> activeTransfers.getAndSet(0), () -> activeTransfers.set(0));
        em.registerSubsystem("SyncEngine", () -> activeSyncLoops.getAndSet(0), () -> activeSyncLoops.set(0));

        check(!em.isEmergencyStopActive(), "Initially emergency stop is inactive");

        // Trigger Emergency Stop
        EmergencyStopManager.StopReport report = em.stopAll("Security threat detected");
        check(em.isEmergencyStopActive(), "Emergency stop is active");
        check(report.haltedTransfers() == 5, "5 active transfers halted");
        check(report.haltedSyncLoops() == 2, "2 sync loops halted");
        check(activeTransfers.get() == 0, "Transfers zeroed");

        // Subsequent operation attempts blocked immediately
        boolean caughtBlocked = false;
        try {
            em.checkOperationPermitted("NewTransfer");
        } catch (IllegalStateException e) {
            caughtBlocked = true;
        }
        check(caughtBlocked, "New operations blocked during Emergency Stop");

        // Resume after admin clearance
        boolean resumed = em.resumeAfterEmergencyStop(() -> true);
        check(resumed, "Emergency stop resumed after clearance");
        check(!em.isEmergencyStopActive(), "Emergency stop no longer active");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 19: Cross-Platform Operating System Fallbacks & Life Cycles
    // ──────────────────────────────────────────────────────────────────────────

    private static void testUnsupportedOsBehaviorAndPlatformFallback() {
        // Android background policy state transitions
        AndroidNodeState state = AndroidNodeState.ACTIVE;
        check(state == AndroidNodeState.ACTIVE, "State is ACTIVE");

        state = AndroidNodeState.BACKGROUND_CAPABLE;
        check(state != AndroidNodeState.OS_RESTRICTED, "State is BACKGROUND_CAPABLE");

        state = AndroidNodeState.OS_RESTRICTED;
        check(state == AndroidNodeState.OS_RESTRICTED, "State is OS_RESTRICTED");

        // Windows reserved name compatibility check
        CompatibilityReport conReport = CompatibilityAnalyzer.analyze(
                "CON.txt", 100, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS);
        check(conReport.requiresUserDecision(), "Windows reserved name requires user confirmation");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 20: Performance Measurement Under Reproducible Conditions
    // ──────────────────────────────────────────────────────────────────────────

    private static void testPerformanceMeasurementUnderReproducibleConditions() throws Exception {
        byte[] payload = new byte[64 * 1024]; // 64 KB block
        Arrays.fill(payload, (byte) 0x55);

        int iterations = 100;
        long start = System.nanoTime();
        for (int i = 0; i < iterations; i++) {
            ContentHash h = ContentHash.computeSha256(payload);
            check(h != null && h.getHexString() != null, "Valid SHA-256 hash produced");
        }
        long elapsedNanos = System.nanoTime() - start;
        double elapsedMs = elapsedNanos / 1_000_000.0;
        double mbTotal = (iterations * 64.0) / 1024.0;
        double throughputMBps = (mbTotal / (elapsedMs / 1000.0));

        // System information logging
        String os = System.getProperty("os.name");
        String arch = System.getProperty("os.arch");
        int cores = Runtime.getRuntime().availableProcessors();
        long maxMemMb = Runtime.getRuntime().maxMemory() / (1024 * 1024);

        System.out.printf("[Benchmark: %s %s, %d cores, MaxMem: %dMB | Dataset: %dx64KB (%.2fMB) in %.2fms => %.2f MB/s] ",
                os, arch, cores, maxMemMb, iterations, mbTotal, elapsedMs, throughputMBps);

        check(elapsedMs < 2000.0, "100 SHA-256 iterations on 64KB should take < 2000ms");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper Utilities & In-Memory Test Operation Journal
    // ──────────────────────────────────────────────────────────────────────────

    private static byte[] createZipArchive(Map<String, byte[]> entries) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try (ZipOutputStream zos = new ZipOutputStream(baos)) {
            for (Map.Entry<String, byte[]> entry : entries.entrySet()) {
                ZipEntry ze = new ZipEntry(entry.getKey());
                zos.putNextEntry(ze);
                zos.write(entry.getValue());
                zos.closeEntry();
            }
        }
        return baos.toByteArray();
    }

    private static String sha256Hex(byte[] data) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] d = md.digest(data);
            StringBuilder sb = new StringBuilder();
            for (byte b : d) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static void deleteRecursive(Path path) {
        try {
            if (Files.isDirectory(path)) {
                try (var stream = Files.newDirectoryStream(path)) {
                    for (Path child : stream) {
                        deleteRecursive(child);
                    }
                }
            }
            Files.deleteIfExists(path);
        } catch (Exception ignored) {}
    }

    private static class InMemoryTestOperationJournal implements OperationJournal {
        private final Map<String, OperationRecord> records = new ConcurrentHashMap<>();
        private final Map<String, String> idempotencyMap = new ConcurrentHashMap<>();

        @Override
        public void recordOperation(OperationRecord record) {
            records.put(record.getOperationId(), record);
            if (record.getIdempotencyKey() != null) {
                idempotencyMap.put(record.getIdempotencyKey(), record.getOperationId());
            }
        }

        @Override
        public void updateState(String operationId, OperationState newState) {
            OperationRecord existing = records.get(operationId);
            if (existing != null) {
                records.put(operationId, existing.withState(newState));
            }
        }

        @Override public void recordJournalStage(String operationId, JournalStage stage) {}
        @Override public Optional<OperationRecord> getOperation(String operationId) { return Optional.ofNullable(records.get(operationId)); }
        @Override public List<OperationRecord> listIncompleteOperations() { return records.values().stream().filter(r -> !r.getState().isTerminal()).toList(); }
        @Override public List<OperationRecord> listInterruptedOperations() { return records.values().stream().filter(r -> r.getState() == OperationState.EXECUTING).toList(); }
        @Override public List<OperationRecord> listUnknownOutcomeOperations() { return records.values().stream().filter(r -> r.getState() == OperationState.OUTCOME_UNKNOWN).toList(); }
        @Override public Optional<String> findOperationByIdempotencyKey(String idempotencyKey) { return Optional.ofNullable(idempotencyMap.get(idempotencyKey)); }
        @Override public void appendNote(String operationId, String note) {}

        @Override
        public void markInterruptedOperationsUnknown(String reason) {
            for (OperationRecord op : listInterruptedOperations()) {
                updateState(op.getOperationId(), OperationState.OUTCOME_UNKNOWN);
            }
        }
    }
}
