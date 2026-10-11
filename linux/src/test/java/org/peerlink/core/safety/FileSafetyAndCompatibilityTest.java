package org.peerlink.core.safety;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.compatibility.*;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.security.SecurityVerdict;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Phase 14: File Safety, Malware Scanning and Compatibility Tests")
class FileSafetyAndCompatibilityTest {

    @TempDir
    Path tempDir;

    private Path quarantineDir;
    private Path targetDestinationDir;
    private QuarantineZone quarantineZone;
    private SimulatedScanner simulatedScanner;
    private ScanCache scanCache;
    private InboundSafetyPipeline pipeline;

    @BeforeEach
    void setUp() throws IOException {
        quarantineDir = tempDir.resolve("quarantine");
        targetDestinationDir = tempDir.resolve("received_files");
        Files.createDirectories(quarantineDir);
        Files.createDirectories(targetDestinationDir);

        quarantineZone = new QuarantineZone(quarantineDir);
        simulatedScanner = new SimulatedScanner("TestScanner", true);
        scanCache = new ScanCache();
        pipeline = new InboundSafetyPipeline(quarantineZone, simulatedScanner, ScanPolicy.strict(), scanCache);
    }

    private byte[] createZipArchive(Map<String, byte[]> entries) throws IOException {
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

    // ── 1. Clean File ────────────────────────────────────────────────────────

    @Test
    @DisplayName("1. Clean file: Passes quarantine, integrity, scanner, policy, and commits to destination")
    void testCleanFile() throws IOException {
        byte[] content = "Hello PeerLink! Clean document content.".getBytes(StandardCharsets.UTF_8);
        ContentHash hash = ContentHash.computeSha256(content);

        InboundSafetyPipeline.PipelineResult result = pipeline.processInboundFile(
                content, "documents/welcome.txt", hash, "peer_alice", targetDestinationDir
        );

        assertTrue(result.committed());
        assertEquals(PolicyDecision.PERMIT_COMMIT, result.decision());
        assertEquals(SecurityVerdict.CLEAN, result.verdict());
        assertNotNull(result.finalPath());
        assertTrue(Files.exists(result.finalPath()));
        assertEquals("Hello PeerLink! Clean document content.", Files.readString(result.finalPath()));
    }

    // ── 2. Malicious Test Sample ─────────────────────────────────────────────

    @Test
    @DisplayName("2. Malicious test sample: Detected by scanner, policy rejects, deleted from quarantine")
    void testMaliciousTestSample() throws IOException {
        byte[] maliciousPayload = ("HARMFUL_PAYLOAD_" + SimulatedScanner.TEST_MALWARE_SIGNATURE).getBytes(StandardCharsets.UTF_8);
        ContentHash hash = ContentHash.computeSha256(maliciousPayload);

        InboundSafetyPipeline.PipelineResult result = pipeline.processInboundFile(
                maliciousPayload, "downloads/threat.bin", hash, "peer_bad", targetDestinationDir
        );

        assertFalse(result.committed());
        assertEquals(PolicyDecision.REJECT_AND_DELETE, result.decision());
        assertEquals(SecurityVerdict.MALICIOUS, result.verdict());
        assertNull(result.finalPath());

        assertFalse(Files.exists(targetDestinationDir.resolve("downloads/threat.bin")));
    }

    // ── 3. Scanner Unavailable ───────────────────────────────────────────────

    @Test
    @DisplayName("3. Scanner unavailable: Invariant verified — NEVER claims safe; held in quarantine for decision")
    void testScannerUnavailable() throws IOException {
        simulatedScanner.setAvailable(false);

        byte[] content = "Some normal data file".getBytes(StandardCharsets.UTF_8);
        ContentHash hash = ContentHash.computeSha256(content);

        InboundSafetyPipeline.PipelineResult result = pipeline.processInboundFile(
                content, "data/file.dat", hash, "peer_bob", targetDestinationDir
        );

        assertFalse(result.committed(), "Must NOT commit when scanner is unavailable under strict policy");
        assertEquals(PolicyDecision.HOLD_IN_QUARANTINE_FOR_DECISION, result.decision());
        assertEquals(SecurityVerdict.UNAVAILABLE, result.verdict());
        assertNotEquals(SecurityVerdict.CLEAN, result.verdict());
        assertNull(result.finalPath());
    }

    // ── 4. Archive ───────────────────────────────────────────────────────────

    @Test
    @DisplayName("4. Archive: Normal zip archive safely inspected without unsafe extraction and committed")
    void testArchive() throws IOException {
        Map<String, byte[]> files = new HashMap<>();
        files.put("readme.txt", "Package instructions".getBytes(StandardCharsets.UTF_8));
        files.put("data/table.csv", "id,name\n1,alpha\n2,beta\n".getBytes(StandardCharsets.UTF_8));
        byte[] zipBytes = createZipArchive(files);
        ContentHash hash = ContentHash.computeSha256(zipBytes);

        InboundSafetyPipeline.PipelineResult result = pipeline.processInboundFile(
                zipBytes, "archives/dataset.zip", hash, "peer_data", targetDestinationDir
        );

        assertTrue(result.committed());
        assertEquals(PolicyDecision.PERMIT_COMMIT, result.decision());
        assertEquals(SecurityVerdict.CLEAN, result.verdict());
        assertTrue(Files.exists(targetDestinationDir.resolve("archives/dataset.zip")));
    }

    // ── 5. Nested Archive ────────────────────────────────────────────────────

    @Test
    @DisplayName("5. Nested archive: Multi-level zip inspected recursively within recursion limits")
    void testNestedArchive() throws IOException {
        byte[] innerZip = createZipArchive(Map.of("inner.txt", "Inner level 2 content".getBytes(StandardCharsets.UTF_8)));
        byte[] outerZip = createZipArchive(Map.of("nested.zip", innerZip, "outer.txt", "Outer text".getBytes(StandardCharsets.UTF_8)));

        ArchiveSafetyInspector.ArchiveSafetyVerdict verdict = ArchiveSafetyInspector.inspectZipBytes(outerZip, 1);
        assertTrue(verdict.isSafe());
        assertEquals(2, verdict.totalEntries());
        assertFalse(verdict.isDecompressionBomb());
    }

    // ── 6. Decompression Bomb Defense ────────────────────────────────────────

    @Test
    @DisplayName("6. Decompression bomb defense: High compression ratio or size explosion rejected")
    void testDecompressionBombDefense() throws IOException {
        byte[] largeZeros = new byte[200_000];
        Arrays.fill(largeZeros, (byte) 'A');
        byte[] bombZip = createZipArchive(Map.of("huge_bomb.txt", largeZeros));
        ContentHash hash = ContentHash.computeSha256(bombZip);

        ArchiveSafetyInspector.ArchiveSafetyVerdict verdict = ArchiveSafetyInspector.inspectZipBytes(bombZip, 1);
        assertTrue(verdict.isDecompressionBomb(), "Decompression bomb ratio should be detected");
        assertFalse(verdict.isSafe());
        assertTrue(verdict.maxRatioObserved() > ArchiveSafetyInspector.MAX_COMPRESSION_RATIO);

        InboundSafetyPipeline.PipelineResult result = pipeline.processInboundFile(
                bombZip, "dangerous.zip", hash, "peer_attacker", targetDestinationDir
        );

        assertFalse(result.committed());
        assertEquals(PolicyDecision.REJECT_AND_DELETE, result.decision());
        assertEquals(SecurityVerdict.MALICIOUS, result.verdict());
    }

    // ── 7. Executable & Disguised Executable ──────────────────────────────────

    @Test
    @DisplayName("7. Executable handling: Disguised executable (PE MZ header named as .jpg) flagged and rejected")
    void testExecutable() throws IOException {
        byte[] disguisedPe = new byte[256];
        disguisedPe[0] = 0x4D; // M
        disguisedPe[1] = 0x5A; // Z
        byte[] filler = "This program cannot be run in DOS mode.".getBytes(StandardCharsets.UTF_8);
        System.arraycopy(filler, 0, disguisedPe, 2, filler.length);

        Path testFilePath = tempDir.resolve("profile.jpg");
        Files.write(testFilePath, disguisedPe);

        ExecutableSafetyInspector.ExecutableSafetyReport report = ExecutableSafetyInspector.inspect(testFilePath, "profile.jpg");
        assertTrue(report.isExecutable());
        assertTrue(report.isDisguised(), "Should detect disguised PE executable masked as image");
        assertEquals("WINDOWS_PE", report.detectedFormat());

        ContentHash hash = ContentHash.computeSha256(disguisedPe);
        InboundSafetyPipeline.PipelineResult result = pipeline.processInboundFile(
                disguisedPe, "profile.jpg", hash, "peer_untrusted", targetDestinationDir
        );

        assertFalse(result.committed());
        assertEquals(PolicyDecision.REJECT_AND_DELETE, result.decision());
        assertEquals(SecurityVerdict.MALICIOUS, result.verdict());
    }

    // ── 8. Unsigned Executable ───────────────────────────────────────────────

    @Test
    @DisplayName("8. Unsigned executable: Flags missing code signature; requires user decision (Never silently execute)")
    void testUnsignedExecutable() throws IOException {
        byte[] unsignedBinary = new byte[128];
        unsignedBinary[0] = 0x4D;
        unsignedBinary[1] = 0x5A;

        Path exePath = tempDir.resolve("installer.exe");
        Files.write(exePath, unsignedBinary);

        ExecutableSafetyInspector.ExecutableSafetyReport report = ExecutableSafetyInspector.inspect(exePath, "installer.exe");
        assertTrue(report.isExecutable());
        assertFalse(report.isSigned());
        assertTrue(report.warnings().stream().anyMatch(w -> w.contains("Unsigned executable")));

        CompatibilityReport comp = CompatibilityAnalyzer.analyze(
                "installer.exe", 128, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        );
        assertEquals(CompatibilityResult.REQUIRES_USER_DECISION, comp.overallResult());
        assertTrue(comp.requiresUserDecision());
    }

    // ── 9. Metadata GPS Inspection ───────────────────────────────────────────

    @Test
    @DisplayName("9. Metadata privacy: Detects embedded GPS tags and personal identifiers (Never silently strip)")
    void testMetadataGps() throws IOException {
        String exifSimulation = "ExifHeader\u0000\u0000exif:GPSLatitude=37.7749N\u0000exif:GPSLongitude=122.4194W\u0000CameraSerialNumber=SN987654321";
        byte[] imageBytes = exifSimulation.getBytes(StandardCharsets.ISO_8859_1);

        Path imgPath = tempDir.resolve("vacation.jpg");
        Files.write(imgPath, imageBytes);

        MetadataPrivacyInspector.MetadataPrivacyReport report = MetadataPrivacyInspector.inspect(imgPath);
        assertTrue(report.hasSensitiveMetadata());
        assertTrue(report.hasGpsCoordinates());
        assertNotNull(report.gpsDetails());
        assertTrue(report.personalIdentifiers().stream().anyMatch(id -> id.contains("Serial Number")));
    }

    // ── 10. Incompatible Filename ────────────────────────────────────────────

    @Test
    @DisplayName("10. Incompatible filename: Flags Windows reserved device names (CON.txt) and illegal characters")
    void testIncompatibleFilename() {
        CompatibilityReport conReport = CompatibilityAnalyzer.analyze(
                "documents/CON.txt", 1024, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        );
        assertEquals(CompatibilityResult.REQUIRES_USER_DECISION, conReport.overallResult());
        assertTrue(conReport.issues().stream().anyMatch(i -> i.code().equals("WINDOWS_RESERVED_NAME")));

        CompatibilityReport charReport = CompatibilityAnalyzer.analyze(
                "bad<char>name.txt", 512, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        );
        assertEquals(CompatibilityResult.INCOMPATIBLE, charReport.overallResult());
        assertTrue(charReport.issues().stream().anyMatch(i -> i.code().equals("WINDOWS_ILLEGAL_CHARACTERS")));

        CompatibilityReport safeReport = CompatibilityAnalyzer.analyze(
                "documents/normal_file.txt", 2048, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        );
        assertEquals(CompatibilityResult.COMPATIBLE, safeReport.overallResult());
    }

    // ── 11. OS-Specific Permission ───────────────────────────────────────────

    @Test
    @DisplayName("11. OS-specific permission: Flags POSIX mode 0755 and symlinks on Windows without silent stripping")
    void testOsSpecificPermission() {
        Map<String, String> meta = Map.of(
                "posix_permissions", "0755",
                "is_symlink", "true"
        );

        CompatibilityReport report = CompatibilityAnalyzer.analyze(
                "scripts/run.sh", 100, meta, CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        );

        assertTrue(report.requiresUserDecision());
        assertTrue(report.issues().stream().anyMatch(i -> i.code().equals("POSIX_PERMISSIONS_ON_WINDOWS")));
        assertTrue(report.issues().stream().anyMatch(i -> i.code().equals("SYMLINK_REPRESENTATION")));
    }

    // ── 12. Hash Mismatch ────────────────────────────────────────────────────

    @Test
    @DisplayName("12. Hash mismatch: Fails quarantine integrity verification; rejects before scanner or commit")
    void testHashMismatch() throws IOException {
        byte[] actualContent = "Tampered corrupted data in transit".getBytes(StandardCharsets.UTF_8);
        byte[] differentContent = "Original expected clean data".getBytes(StandardCharsets.UTF_8);
        ContentHash expectedHash = ContentHash.computeSha256(differentContent);

        InboundSafetyPipeline.PipelineResult result = pipeline.processInboundFile(
                actualContent, "docs/corrupt.txt", expectedHash, "peer_flaky", targetDestinationDir
        );

        assertFalse(result.committed());
        assertEquals(PolicyDecision.REJECT_AND_DELETE, result.decision());
        assertEquals(SecurityVerdict.SCAN_FAILED, result.verdict());
        assertNull(result.finalPath());

        assertFalse(Files.exists(targetDestinationDir.resolve("docs/corrupt.txt")));
    }
}