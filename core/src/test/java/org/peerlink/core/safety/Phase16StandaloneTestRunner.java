package org.peerlink.core.safety;

import org.peerlink.core.capability.CapabilityRegistry;
import org.peerlink.core.compatibility.*;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.security.ScannerProvider;
import org.peerlink.core.security.SecurityVerdict;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * Phase 16 Standalone Verification Suite:
 * File Safety, Malware Scanning, Bounded Parsing, Archive Bomb Defense,
 * Privacy Consent Enforcement, Protocol Compatibility vs File Compatibility Separation.
 *
 * Runs in pure Java SE on any host platform.
 */
public class Phase16StandaloneTestRunner {

    private static int testsPassed = 0;
    private static int testsFailed = 0;

    public static void main(String[] args) {
        System.out.println("==========================================================");
        System.out.println(" PeerLink Phase 16 File Safety, Scanning & Compatibility");
        System.out.println("==========================================================");

        runTest("Test 01: Clean Inbound File Pipeline Execution", Phase16StandaloneTestRunner::testCleanInboundFilePipeline);
        runTest("Test 02: Malicious Payload Detection & Quarantine Deletion", Phase16StandaloneTestRunner::testMaliciousPayloadDetectionAndDeletion);
        runTest("Test 03: Scanner Unavailability Never Claims Safe", Phase16StandaloneTestRunner::testScannerUnavailabilityNeverClaimsSafe);
        runTest("Test 04: Scanner Failure & Error Transparency", Phase16StandaloneTestRunner::testScannerFailureTransparency);
        runTest("Test 05: Scan Cache Rules: Never Cache Unavailable or Failed Verdicts", Phase16StandaloneTestRunner::testScanCacheRules);
        runTest("Test 06: Decompression Bomb Defense: Compression Ratio Limit", Phase16StandaloneTestRunner::testDecompressionBombCompressionRatio);
        runTest("Test 07: Archive Safety: Max Recursion Depth Defense", Phase16StandaloneTestRunner::testArchiveMaxRecursionDepth);
        runTest("Test 08: Archive Safety: Entry Path Traversal & Null Bytes Rejected", Phase16StandaloneTestRunner::testArchivePathTraversalAndNullBytes);
        runTest("Test 09: Malformed & Corrupted Archive Content Rejection", Phase16StandaloneTestRunner::testMalformedArchiveRejection);
        runTest("Test 10: Disguised Executable Header Detection", Phase16StandaloneTestRunner::testDisguisedExecutableDetection);
        runTest("Test 11: Unsigned Executable Inspection (Never Auto-Execute)", Phase16StandaloneTestRunner::testUnsignedExecutableInspection);
        runTest("Test 12: Inbound File Size Limit Enforcement", Phase16StandaloneTestRunner::testInboundFileSizeLimitEnforcement);
        runTest("Test 13: Malicious Inbound Relative Paths & Traversal Rejection", Phase16StandaloneTestRunner::testMaliciousInboundPathTraversalRejection);
        runTest("Test 14: Windows Reserved Device Names (Never Silently Rename)", Phase16StandaloneTestRunner::testWindowsReservedDeviceNames);
        runTest("Test 15: Windows Illegal Characters & Trailing Spaces", Phase16StandaloneTestRunner::testWindowsIllegalCharactersAndTrailingSpaces);
        runTest("Test 16: POSIX Permissions & Symlinks Preserved on Windows", Phase16StandaloneTestRunner::testPosixPermissionsAndSymlinksOnWindows);
        runTest("Test 17: Metadata Privacy: Sensitive GPS Coordinates & Device Serials", Phase16StandaloneTestRunner::testMetadataPrivacySensitiveGps);
        runTest("Test 18: External Scanner Privacy Consent Enforcement", Phase16StandaloneTestRunner::testExternalScannerPrivacyConsentEnforcement);
        runTest("Test 19: Protocol Compatibility: Schema & Version Negotiation", Phase16StandaloneTestRunner::testProtocolCompatibilityNegotiation);
        runTest("Test 20: Clean Separation: Protocol vs File Compatibility", Phase16StandaloneTestRunner::testProtocolVsFileCompatibilitySeparation);

        System.out.println("==========================================================");
        System.out.printf(" Phase 16 Test Execution Summary: %d PASSED, %d FAILED%n", testsPassed, testsFailed);
        System.out.println("==========================================================");

        if (testsFailed > 0) {
            System.exit(1);
        }
    }

    private static void runTest(String name, TestCase testCase) {
        try {
            testCase.run();
            System.out.println("[PASS] " + name);
            testsPassed++;
        } catch (Throwable t) {
            System.err.println("[FAIL] " + name + ": " + t.getMessage());
            t.printStackTrace(System.err);
            testsFailed++;
        }
    }

    @FunctionalInterface
    interface TestCase {
        void run() throws Exception;
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError("Assertion failed: " + message);
        }
    }

    private static Path createTempDirectory(String prefix) throws IOException {
        return Files.createTempDirectory(prefix);
    }

    private static void deleteRecursive(Path path) {
        try {
            if (Files.isDirectory(path)) {
                try (var s = Files.walk(path)) {
                    s.sorted(Comparator.reverseOrder()).forEach(p -> {
                        try { Files.deleteIfExists(p); } catch (Exception ignored) {}
                    });
                }
            } else {
                Files.deleteIfExists(path);
            }
        } catch (Exception ignored) {}
    }

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

    // ── 1. Clean Inbound File Pipeline Execution ──────────────────────────────

    private static void testCleanInboundFilePipeline() throws Exception {
        Path root = createTempDirectory("phase16_t01_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            QuarantineZone qz = new QuarantineZone(qDir);
            SimulatedScanner scanner = new SimulatedScanner("TestScanner", true);
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(qz, scanner, ScanPolicy.strict(), new ScanCache());

            byte[] content = "Hello PeerLink! Clean inbound text content.".getBytes(StandardCharsets.UTF_8);
            ContentHash hash = ContentHash.computeSha256(content);

            InboundSafetyPipeline.PipelineResult res = pipeline.processInboundFile(
                    content, "docs/welcome.txt", hash, "peer_alice", destDir
            );

            check(res.committed(), "File must be committed");
            check(res.decision() == PolicyDecision.PERMIT_COMMIT, "Decision is PERMIT_COMMIT");
            check(res.verdict() == SecurityVerdict.CLEAN, "Verdict is CLEAN");
            check(res.finalPath() != null && Files.exists(res.finalPath()), "Committed file exists");
            check(Files.readString(res.finalPath()).equals("Hello PeerLink! Clean inbound text content."), "Content match");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 2. Malicious Payload Detection & Quarantine Deletion ──────────────────

    private static void testMaliciousPayloadDetectionAndDeletion() throws Exception {
        Path root = createTempDirectory("phase16_t02_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            QuarantineZone qz = new QuarantineZone(qDir);
            SimulatedScanner scanner = new SimulatedScanner("TestScanner", true);
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(qz, scanner, ScanPolicy.strict(), new ScanCache());

            byte[] payload = ("INFECTED_" + SimulatedScanner.TEST_MALWARE_SIGNATURE).getBytes(StandardCharsets.UTF_8);
            ContentHash hash = ContentHash.computeSha256(payload);

            InboundSafetyPipeline.PipelineResult res = pipeline.processInboundFile(
                    payload, "threat.bin", hash, "peer_bad", destDir
            );

            check(!res.committed(), "Must NOT commit malicious payload");
            check(res.decision() == PolicyDecision.REJECT_AND_DELETE, "Policy decision is REJECT_AND_DELETE");
            check(res.verdict() == SecurityVerdict.MALICIOUS, "Verdict is MALICIOUS");
            check(!Files.exists(destDir.resolve("threat.bin")), "Threat not written to destination");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 3. Scanner Unavailability Never Claims Safe ───────────────────────────

    private static void testScannerUnavailabilityNeverClaimsSafe() throws Exception {
        Path root = createTempDirectory("phase16_t03_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            QuarantineZone qz = new QuarantineZone(qDir);
            SimulatedScanner scanner = new SimulatedScanner("OfflineScanner", false); // Scanner offline
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(qz, scanner, ScanPolicy.strict(), new ScanCache());

            byte[] content = "Clean data file with offline scanner".getBytes(StandardCharsets.UTF_8);
            ContentHash hash = ContentHash.computeSha256(content);

            InboundSafetyPipeline.PipelineResult res = pipeline.processInboundFile(
                    content, "data/unscanned.txt", hash, "peer_sender", destDir
            );

            check(!res.committed(), "Must NOT commit unscanned file");
            check(res.verdict() == SecurityVerdict.UNAVAILABLE, "Verdict must be UNAVAILABLE");
            check(res.verdict() != SecurityVerdict.CLEAN, "Must NEVER claim CLEAN when scanner is unavailable");
            check(res.decision() == PolicyDecision.HOLD_IN_QUARANTINE_FOR_DECISION, "Held in quarantine for user decision");
            check(!Files.exists(destDir.resolve("data/unscanned.txt")), "Not committed to destination");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 4. Scanner Failure & Error Transparency ───────────────────────────────

    private static void testScannerFailureTransparency() throws Exception {
        Path root = createTempDirectory("phase16_t04_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            QuarantineZone qz = new QuarantineZone(qDir);

            // Scanner that throws an unexpected error / crash
            ScannerProvider faultyScanner = new ScannerProvider() {
                @Override
                public String getProviderName() { return "CrashingScanner"; }
                @Override
                public boolean isAvailable() { return true; }
                @Override
                public SecurityVerdict scanStream(java.io.InputStream inputStream) throws IOException {
                    throw new IOException("Scanner daemon crashed with SIGSEGV (Process terminated)");
                }
                @Override
                public SecurityVerdict scanFile(String filePath) throws IOException {
                    throw new IOException("Scanner daemon crashed with SIGSEGV (Process terminated)");
                }
            };

            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(qz, faultyScanner, ScanPolicy.strict(), new ScanCache());

            byte[] content = "Important document for scanning".getBytes(StandardCharsets.UTF_8);
            ContentHash hash = ContentHash.computeSha256(content);

            InboundSafetyPipeline.PipelineResult res = pipeline.processInboundFile(
                    content, "docs/important.pdf", hash, "peer_sender", destDir
            );

            check(!res.committed(), "Failed scan must NOT be committed");
            check(res.verdict() == SecurityVerdict.SCAN_FAILED, "Verdict must be SCAN_FAILED");
            check(res.decision() == PolicyDecision.HOLD_IN_QUARANTINE_FOR_DECISION, "Held in quarantine");
            check(res.details().stream().anyMatch(d -> d.contains("Scanner I/O failure")), "Explicit failure reason logged");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 5. Scan Cache Rules: Never Cache Unavailable or Failed Verdicts ──────

    private static void testScanCacheRules() throws Exception {
        ScanCache cache = new ScanCache();
        ContentHash cleanHash = ContentHash.computeSha256(new byte[]{1, 2, 3});
        ContentHash malHash = ContentHash.computeSha256(new byte[]{4, 5, 6});
        ContentHash unavailHash = ContentHash.computeSha256(new byte[]{7, 8, 9});
        ContentHash failHash = ContentHash.computeSha256(new byte[]{10, 11, 12});

        // 1. Clean is cached
        cache.put(cleanHash, ScanResult.clean("TestScanner", 10));
        check(cache.get(cleanHash).isPresent(), "Clean verdict is cached");
        check(cache.get(cleanHash).get().verdict() == SecurityVerdict.CLEAN, "Cached verdict is CLEAN");

        // 2. Malicious is cached
        cache.put(malHash, ScanResult.malicious("TestScanner", "Trojan.Generic", 15));
        check(cache.get(malHash).isPresent(), "Malicious verdict is cached");

        // 3. UNAVAILABLE must NEVER be cached
        cache.put(unavailHash, ScanResult.unavailable("TestScanner", "Daemon offline"));
        check(cache.get(unavailHash).isEmpty(), "UNAVAILABLE verdict must NEVER be cached");

        // 4. SCAN_FAILED must NEVER be cached
        cache.put(failHash, ScanResult.failed("TestScanner", "Timeout"));
        check(cache.get(failHash).isEmpty(), "SCAN_FAILED verdict must NEVER be cached");
    }

    // ── 6. Decompression Bomb Defense: Compression Ratio Limit ────────────────

    private static void testDecompressionBombCompressionRatio() throws Exception {
        Path root = createTempDirectory("phase16_t06_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            QuarantineZone qz = new QuarantineZone(qDir);
            SimulatedScanner scanner = new SimulatedScanner("TestScanner", true);
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(qz, scanner, ScanPolicy.strict(), new ScanCache());

            // Create a payload of repetitive bytes that compresses at > 100:1 ratio
            byte[] repetitive = new byte[300_000];
            Arrays.fill(repetitive, (byte) 'Z');
            byte[] bombZip = createZipArchive(Map.of("ratio_bomb.txt", repetitive));
            ContentHash hash = ContentHash.computeSha256(bombZip);

            ArchiveSafetyInspector.ArchiveSafetyVerdict verdict = ArchiveSafetyInspector.inspectZipBytes(bombZip, 1);
            check(verdict.isDecompressionBomb(), "Decompression bomb flag raised");
            check(!verdict.isSafe(), "Archive not safe");
            check(verdict.maxRatioObserved() > ArchiveSafetyInspector.MAX_COMPRESSION_RATIO, "Ratio exceeded limit");

            InboundSafetyPipeline.PipelineResult res = pipeline.processInboundFile(
                    bombZip, "download.zip", hash, "peer_attacker", destDir
            );

            check(!res.committed(), "Bomb archive must NOT be committed");
            check(res.decision() == PolicyDecision.REJECT_AND_DELETE, "Rejected and deleted");
            check(res.verdict() == SecurityVerdict.MALICIOUS, "Verdict is MALICIOUS");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 7. Archive Safety: Max Recursion Depth Defense ────────────────────────

    private static void testArchiveMaxRecursionDepth() throws Exception {
        // Construct nesting depth 4 (exceeding MAX_RECURSION_DEPTH of 3)
        byte[] level4 = createZipArchive(Map.of("leaf.txt", "Core leaf content".getBytes(StandardCharsets.UTF_8)));
        byte[] level3 = createZipArchive(Map.of("level4.zip", level4));
        byte[] level2 = createZipArchive(Map.of("level3.zip", level3));
        byte[] level1 = createZipArchive(Map.of("level2.zip", level2));

        ArchiveSafetyInspector.ArchiveSafetyVerdict verdict = ArchiveSafetyInspector.inspectZipBytes(level1, 1);
        check(!verdict.isSafe(), "Archive with depth > 3 is not safe");
        check(verdict.isDecompressionBomb(), "Exceeding recursion depth classifies as decompression bomb");
        check(verdict.findings().stream().anyMatch(f -> f.contains("recursion depth")), "Findings explain depth exceeded");
    }

    // ── 8. Archive Safety: Entry Path Traversal & Null Bytes Rejected ─────────

    private static void testArchivePathTraversalAndNullBytes() throws Exception {
        // Construct zip with traversal entry
        byte[] traversalZip = createZipArchive(Map.of("../../etc/shadow", "root:*:0:0:root".getBytes(StandardCharsets.UTF_8)));
        ArchiveSafetyInspector.ArchiveSafetyVerdict v1 = ArchiveSafetyInspector.inspectZipBytes(traversalZip, 1);
        check(!v1.isSafe(), "Archive with path traversal is not safe");
        check(v1.hasPathTraversal(), "hasPathTraversal flag set");

        // Construct zip with null byte entry
        byte[] nullByteZip = createZipArchive(Map.of("document.pdf\0.exe", "dangerous code".getBytes(StandardCharsets.UTF_8)));
        ArchiveSafetyInspector.ArchiveSafetyVerdict v2 = ArchiveSafetyInspector.inspectZipBytes(nullByteZip, 1);
        check(!v2.isSafe(), "Archive with null byte entry is not safe");
        check(v2.hasPathTraversal(), "Path traversal/illegal sequence detected");
    }

    // ── 9. Malformed & Corrupted Archive Content Rejection ────────────────────

    private static void testMalformedArchiveRejection() throws Exception {
        Path root = createTempDirectory("phase16_t09_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            QuarantineZone qz = new QuarantineZone(qDir);
            SimulatedScanner scanner = new SimulatedScanner("TestScanner", true);
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(qz, scanner, ScanPolicy.strict(), new ScanCache());

            // Corrupted zip: valid PK header followed by garbage/truncated bytes
            byte[] corruptZip = new byte[]{0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00, 0x42, 0x41, 0x44};
            ContentHash hash = ContentHash.computeSha256(corruptZip);

            InboundSafetyPipeline.PipelineResult res = pipeline.processInboundFile(
                    corruptZip, "corrupted.zip", hash, "peer_sender", destDir
            );

            check(!res.committed(), "Corrupted archive must NOT be committed");
            check(res.decision() == PolicyDecision.REJECT_AND_DELETE, "Rejected and deleted");
            check(res.verdict() == SecurityVerdict.SCAN_FAILED, "Verdict is SCAN_FAILED for malformed archive");
            check(res.details().stream().anyMatch(d -> d.contains("Malformed or corrupted archive")), "Details describe corruption");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 10. Disguised Executable Header Detection ─────────────────────────────

    private static void testDisguisedExecutableDetection() throws Exception {
        Path root = createTempDirectory("phase16_t10_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            QuarantineZone qz = new QuarantineZone(qDir);
            SimulatedScanner scanner = new SimulatedScanner("TestScanner", true);
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(qz, scanner, ScanPolicy.strict(), new ScanCache());

            // Windows PE (MZ) binary disguised as a .png image
            byte[] disguised = new byte[128];
            disguised[0] = 0x4D; // M
            disguised[1] = 0x5A; // Z
            ContentHash hash = ContentHash.computeSha256(disguised);

            InboundSafetyPipeline.PipelineResult res = pipeline.processInboundFile(
                    disguised, "avatar.png", hash, "peer_attacker", destDir
            );

            check(!res.committed(), "Disguised executable must NOT be committed");
            check(res.decision() == PolicyDecision.REJECT_AND_DELETE, "Rejected and deleted");
            check(res.verdict() == SecurityVerdict.MALICIOUS, "Verdict is MALICIOUS");
            check(res.details().stream().anyMatch(d -> d.contains("Disguised executable detected")), "Disguise warning recorded");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 11. Unsigned Executable Inspection (Never Auto-Execute) ───────────────

    private static void testUnsignedExecutableInspection() throws Exception {
        byte[] unsignedPe = new byte[64];
        unsignedPe[0] = 0x4D;
        unsignedPe[1] = 0x5A;

        Path tempFile = Files.createTempFile("unsigned_", ".exe");
        try {
            Files.write(tempFile, unsignedPe);
            ExecutableSafetyInspector.ExecutableSafetyReport report = ExecutableSafetyInspector.inspect(tempFile, "tool.exe");

            check(report.isExecutable(), "Recognized as executable");
            check(!report.isSigned(), "Flagged as unsigned");
            check(report.warnings().stream().anyMatch(w -> w.contains("Unsigned executable")), "Unsigned warning present");

            CompatibilityReport comp = CompatibilityAnalyzer.analyze("tool.exe", 64, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS);
            check(comp.requiresUserDecision(), "Requires explicit user decision");
            check(comp.issues().stream().anyMatch(i -> i.code().equals("EXECUTABLE_RECEIVED")), "EXECUTABLE_RECEIVED issue logged");
        } finally {
            Files.deleteIfExists(tempFile);
        }
    }

    // ── 12. Inbound File Size Limit Enforcement ───────────────────────────────

    private static void testInboundFileSizeLimitEnforcement() throws Exception {
        Path root = createTempDirectory("phase16_t12_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            QuarantineZone qz = new QuarantineZone(qDir);
            SimulatedScanner scanner = new SimulatedScanner("TestScanner", true);

            // Configure pipeline with 10 KB max file size limit
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(qz, scanner, ScanPolicy.strict(), new ScanCache(), 10 * 1024L);

            byte[] oversized = new byte[20 * 1024]; // 20 KB
            ContentHash hash = ContentHash.computeSha256(oversized);

            InboundSafetyPipeline.PipelineResult res = pipeline.processInboundFile(
                    oversized, "data/large.bin", hash, "peer_sender", destDir
            );

            check(!res.committed(), "Oversized file must NOT be committed");
            check(res.decision() == PolicyDecision.REJECT_AND_DELETE, "Rejected");
            check(res.verdict() == SecurityVerdict.UNSUPPORTED, "Verdict is UNSUPPORTED for oversized file");
            check(res.details().stream().anyMatch(d -> d.contains("exceeds maximum allowable limit")), "Logged size limit reason");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 13. Malicious Inbound Relative Paths & Traversal Rejection ────────────

    private static void testMaliciousInboundPathTraversalRejection() throws Exception {
        Path root = createTempDirectory("phase16_t13_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            QuarantineZone qz = new QuarantineZone(qDir);
            SimulatedScanner scanner = new SimulatedScanner("TestScanner", true);
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(qz, scanner, ScanPolicy.strict(), new ScanCache());

            byte[] content = "Payload".getBytes(StandardCharsets.UTF_8);
            ContentHash hash = ContentHash.computeSha256(content);

            // 1. Directory traversal
            InboundSafetyPipeline.PipelineResult r1 = pipeline.processInboundFile(content, "../../evil.sh", hash, "peer_bad", destDir);
            check(!r1.committed() && r1.verdict() == SecurityVerdict.MALICIOUS, "Relative traversal rejected");

            // 2. Null byte in relative path
            InboundSafetyPipeline.PipelineResult r2 = pipeline.processInboundFile(content, "normal.txt\0.exe", hash, "peer_bad", destDir);
            check(!r2.committed() && r2.verdict() == SecurityVerdict.MALICIOUS, "Null byte in path rejected");

            // 3. Absolute prefix
            InboundSafetyPipeline.PipelineResult r3 = pipeline.processInboundFile(content, "/etc/passwd", hash, "peer_bad", destDir);
            check(!r3.committed() && r3.verdict() == SecurityVerdict.MALICIOUS, "Absolute leading slash rejected");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 14. Windows Reserved Device Names (Never Silently Rename) ─────────────

    private static void testWindowsReservedDeviceNames() {
        String[] reserved = new String[]{"CON.txt", "aux.json", "prn.pdf", "NUL", "COM1.dat", "LPT9.log"};
        for (String name : reserved) {
            CompatibilityReport rep = CompatibilityAnalyzer.analyze(
                    "folder/" + name, 100, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
            );
            check(rep.requiresUserDecision(), "Reserved name '" + name + "' requires user decision");
            check(rep.issues().stream().anyMatch(i -> i.code().equals("WINDOWS_RESERVED_NAME")), "WINDOWS_RESERVED_NAME issue logged");
        }
    }

    // ── 15. Windows Illegal Characters & Trailing Spaces ──────────────────────

    private static void testWindowsIllegalCharactersAndTrailingSpaces() {
        // Illegal characters
        CompatibilityReport charRep = CompatibilityAnalyzer.analyze(
                "report<2026>.txt", 500, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        );
        check(charRep.overallResult() == CompatibilityResult.INCOMPATIBLE, "Illegal char < > flagged INCOMPATIBLE");

        // Trailing dot
        CompatibilityReport dotRep = CompatibilityAnalyzer.analyze(
                "trailing_dot.", 200, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        );
        check(dotRep.requiresUserDecision(), "Trailing dot requires user decision");
        check(dotRep.issues().stream().anyMatch(i -> i.code().equals("TRAILING_DOT_OR_SPACE")), "TRAILING_DOT_OR_SPACE logged");

        // Trailing space
        CompatibilityReport spaceRep = CompatibilityAnalyzer.analyze(
                "trailing_space ", 200, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        );
        check(spaceRep.requiresUserDecision(), "Trailing space requires user decision");
    }

    // ── 16. POSIX Permissions & Symlinks Preserved on Windows ─────────────────

    private static void testPosixPermissionsAndSymlinksOnWindows() {
        Map<String, String> meta = Map.of(
                "posix_permissions", "0755",
                "is_symlink", "true",
                "extended_attributes", "user.checksum=abc123"
        );

        CompatibilityReport rep = CompatibilityAnalyzer.analyze(
                "deploy.sh", 1024, meta, CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        );

        check(rep.requiresUserDecision(), "Symlink requires user decision");
        check(rep.issues().stream().anyMatch(i -> i.code().equals("POSIX_PERMISSIONS_ON_WINDOWS")), "POSIX permissions issue recorded");
        check(rep.issues().stream().anyMatch(i -> i.code().equals("SYMLINK_REPRESENTATION")), "Symlink issue recorded");
        check(rep.issues().stream().anyMatch(i -> i.code().equals("EXTENDED_ATTRIBUTES_LIMITATION")), "Extended attributes issue recorded");
    }

    // ── 17. Metadata Privacy: Sensitive GPS Coordinates & Device Serials ──────

    private static void testMetadataPrivacySensitiveGps() throws Exception {
        String exifSim = "ExifMetadata\u0000exif:GPSLatitude=34.0522N\u0000exif:GPSLongitude=118.2437W\u0000InternalSerialNumber=CAM-998877\u0000dc:creator=JohnDoe";
        Path img = Files.createTempFile("photo_", ".jpg");
        try {
            Files.write(img, exifSim.getBytes(StandardCharsets.ISO_8859_1));
            MetadataPrivacyInspector.MetadataPrivacyReport rep = MetadataPrivacyInspector.inspect(img);

            check(rep.hasSensitiveMetadata(), "Sensitive metadata detected");
            check(rep.hasGpsCoordinates(), "GPS coordinates detected");
            check(rep.personalIdentifiers().stream().anyMatch(id -> id.contains("Serial Number")), "Serial number detected");
            check(rep.personalIdentifiers().stream().anyMatch(id -> id.contains("Author/Creator")), "Creator name detected");
        } finally {
            Files.deleteIfExists(img);
        }
    }

    // ── 18. External Scanner Privacy Consent Enforcement ──────────────────────

    private static void testExternalScannerPrivacyConsentEnforcement() throws Exception {
        // 1. Without consent: Must refuse to transmit user files!
        ExternalScanningProvider noConsentProvider = new ExternalScanningProvider(
                "CloudAV", "https://api.cloudav.security/scan", false
        );

        check(!noConsentProvider.isAvailable(), "Provider unavailable without user consent");
        boolean threw = false;
        try {
            noConsentProvider.scanFile("sensitive_user_doc.pdf");
        } catch (SecurityException e) {
            threw = true;
            check(e.getMessage().contains("Privacy policy violation"), "Explicit privacy violation reported");
        }
        check(threw, "SecurityException thrown when transmitting without consent");

        // 2. With explicit user consent: Permitted to scan
        ExternalScanningProvider consentProvider = new ExternalScanningProvider(
                "CloudAV", "https://api.cloudav.security/scan", true
        );
        check(consentProvider.isAvailable(), "Provider available when consent granted");
        check(consentProvider.scanFile("any_doc.pdf") == SecurityVerdict.CLEAN, "Scan permitted with user consent");
    }

    // ── 19. Protocol Compatibility: Schema & Version Negotiation ──────────────

    private static void testProtocolCompatibilityNegotiation() {
        CapabilityRegistry caps = new CapabilityRegistry(Set.of("tls_1_3", "chunk_transfer", "e2e_encryption"));
        ProtocolCompatibilityNegotiator negotiator = new ProtocolCompatibilityNegotiator(
                1, 1, "peerlink.v1", caps, Set.of("e2e_encryption")
        );

        // Mutually compatible peer
        var res1 = negotiator.negotiate(1, 1, "peerlink.v1", Set.of("e2e_encryption", "tls_1_3"), true);
        check(res1.isCompatible(), "v1 peers are compatible");
        check(res1.negotiatedVersion() == 1, "Negotiated version 1");
        check(res1.negotiatedCapabilities().contains("e2e_encryption"), "Negotiated e2e_encryption");

        // Incompatible version peer (v2 only peer)
        var res2 = negotiator.negotiate(2, 2, "peerlink.v2", Set.of("e2e_encryption"), true);
        check(!res2.isCompatible(), "Incompatible protocol version rejected");
        check(res2.incompatibilityReasons().stream().anyMatch(r -> r.contains("Protocol version mismatch")), "Version mismatch logged");

        // Missing required capability peer
        var res3 = negotiator.negotiate(1, 1, "peerlink.v1", Set.of("tls_1_3"), true);
        check(!res3.isCompatible(), "Peer missing required e2e_encryption rejected");
        check(res3.incompatibilityReasons().stream().anyMatch(r -> r.contains("Required protocol capability missing")), "Missing capability logged");

        // Unencrypted transport rejected
        var res4 = negotiator.negotiate(1, 1, "peerlink.v1", Set.of("e2e_encryption"), false);
        check(!res4.isCompatible(), "Unencrypted transport rejected");
        check(res4.incompatibilityReasons().stream().anyMatch(r -> r.contains("Transport security requirement violated")), "Transport violation logged");
    }

    // ── 20. Clean Separation: Protocol vs File Compatibility ──────────────────

    private static void testProtocolVsFileCompatibilitySeparation() {
        // Demonstrate that Protocol Compatibility operates strictly on schemas and negotiation,
        // while File Compatibility operates strictly on filenames, path semantics, and storage constraints.

        // 1. Protocol compatibility is independently evaluated for the transport session
        CapabilityRegistry caps = new CapabilityRegistry(Set.of("noise_protocol", "e2e_encryption"));
        ProtocolCompatibilityNegotiator protoNeg = new ProtocolCompatibilityNegotiator(caps);
        var protoRes = protoNeg.negotiate(1, 1, "peerlink.v1", Set.of("e2e_encryption"), true);
        check(protoRes.isCompatible(), "Protocol connection is fully compatible");

        // 2. An inbound file inside this compatible protocol session might have storage incompatibilities
        CompatibilityReport fileRes = CompatibilityAnalyzer.analyze(
                "bad:name.txt", 1024, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        );
        check(fileRes.overallResult() == CompatibilityResult.INCOMPATIBLE, "File is storage-incompatible on Windows due to illegal ':'");

        // Neither layer confuses its duties with the other:
        // Protocol layer ensures channel framing & schemas; File layer evaluates platform file semantics.
    }
}
