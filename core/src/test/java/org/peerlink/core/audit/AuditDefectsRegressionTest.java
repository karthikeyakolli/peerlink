package org.peerlink.core.audit;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.access.PathSandboxValidator;
import org.peerlink.core.backup.*;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.peerlink.core.safety.QuarantineRecord;
import org.peerlink.core.safety.QuarantineZone;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

public class AuditDefectsRegressionTest {

    @TempDir
    Path tempDir;

    private Path restoreTargetDir;
    private Path quarantineDir;
    private Path destinationDir;

    @BeforeEach
    void setUp() throws IOException {
        restoreTargetDir = tempDir.resolve("restore_target");
        quarantineDir = tempDir.resolve("quarantine");
        destinationDir = tempDir.resolve("destination");

        Files.createDirectories(restoreTargetDir);
        Files.createDirectories(quarantineDir);
        Files.createDirectories(destinationDir);
    }

    @Test
    @DisplayName("Audit Defect 1: RestoreExecutor must reject relative paths escaping targetDirectory")
    void testRestoreExecutorPathTraversalRejected() throws Exception {
        byte[] payload = "malicious payload".getBytes(StandardCharsets.UTF_8);
        ContentHash hash = ContentHash.computeSha256(payload);

        InMemoryBackupTarget target = new InMemoryBackupTarget();
        target.storePayload(hash.getHexString(), payload);

        ObjectIdentity objId = ObjectIdentity.generate();
        HistoricalVersion maliciousItem = new HistoricalVersion(
                objId,
                "../../escaped_secret.txt",
                hash,
                payload.length,
                1,
                System.currentTimeMillis(),
                false,
                hash.getHexString(),
                false,
                false
        );

        RestorePlan plan = new RestorePlan(
                "bkp_1",
                restoreTargetDir,
                RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION,
                Map.of(objId.getValue(), maliciousItem),
                List.of(),
                payload.length,
                false
        );

        RestoreExecutionResult result = RestoreExecutor.execute(plan, target, null, 100);

        // Outside file must NOT exist
        Path outsideFile = tempDir.resolve("escaped_secret.txt");
        assertFalse(Files.exists(outsideFile), "RestoreExecutor must NOT write outside targetDirectory!");
        // The restore must have failed or recorded error
        assertFalse(result.success(), "Restore should be marked as failure on traversal attempt");
        assertFalse(result.errors().isEmpty(), "Errors list should report traversal attempt");
    }

    @Test
    @DisplayName("Audit Defect 2: QuarantineZone commitFile must reject relative paths escaping destination")
    void testQuarantineZoneCommitPathTraversalRejected() throws Exception {
        QuarantineZone zone = new QuarantineZone(quarantineDir);
        byte[] payload = "test data".getBytes(StandardCharsets.UTF_8);
        ContentHash hash = ContentHash.computeSha256(payload);

        QuarantineRecord record = zone.stageInbound(payload, "../../escaped_q.txt", hash, "peer_attacker");

        assertThrows(SecurityException.class, () -> {
            zone.commitFile(record, destinationDir);
        }, "QuarantineZone.commitFile must throw SecurityException on path traversal");

        Path outsideFile = tempDir.resolve("escaped_q.txt");
        assertFalse(Files.exists(outsideFile), "File must not be committed outside destination directory");
    }

    @Test
    @DisplayName("Audit Defect 3: PathSandboxValidator must reject non-existent paths through symlinked directories")
    void testPathSandboxValidatorIntermediateSymlinkToOutside() throws Exception {
        Path outsideDir = tempDir.resolve("outside_system");
        Path shareRoot = tempDir.resolve("share_root");
        Files.createDirectories(outsideDir);
        Files.createDirectories(shareRoot);

        Path symlinkDir = shareRoot.resolve("sym_dir");
        try {
            Files.createSymbolicLink(symlinkDir, outsideDir);
        } catch (UnsupportedOperationException | IOException e) {
            // If OS/filesystem does not support symlink creation in test environment, skip symlink test
            return;
        }

        PathSandboxValidator validator = new PathSandboxValidator(true);

        // Child does not exist yet!
        assertThrows(PathSandboxValidator.PathTraversalException.class, () -> {
            validator.resolveAndValidate(shareRoot, "sym_dir/non_existent_child.txt");
        }, "PathSandboxValidator must reject non-existent child inside symlinked external directory");
    }

    @Test
    @DisplayName("Audit Defect 4: BackupEngine partial backup must reject path traversal")
    void testBackupEnginePartialBackupPathTraversalRejected() throws Exception {
        Path sourceDir = tempDir.resolve("source");
        Files.createDirectories(sourceDir);

        // Put a sensitive file outside source
        Path outsideSecret = tempDir.resolve("secret.key");
        Files.writeString(outsideSecret, "super_secret_key");

        InMemoryBackupTarget target = new InMemoryBackupTarget();
        BackupEngine engine = new BackupEngine(target);
        BackupJobConfig config = new BackupJobConfig(
                "job_1", "test_job", sourceDir, "target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        assertThrows(SecurityException.class, () -> {
            engine.performPartialBackup(config, Set.of("../../secret.key"));
        }, "BackupEngine.performPartialBackup must throw SecurityException on path traversal attempt");
    }
}
