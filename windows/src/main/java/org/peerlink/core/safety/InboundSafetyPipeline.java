package org.peerlink.core.safety;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.security.ScannerProvider;
import org.peerlink.core.security.SecurityVerdict;

import java.io.IOException;
import java.nio.file.Path;
import java.util.*;

/**
 * Inbound File Safety Pipeline.
 *
 * Pipeline sequence:
 * Receive -> Quarantine -> Integrity verification -> File safety -> Malware scan -> Policy -> Commit
 *
 * Invariants:
 * - Never claim "safe" when scanner is unavailable or errors occur.
 * - Never silently execute, convert, rename, delete, or strip metadata.
 * - Enforce file size limits, archive expansion limits, recursion limits, and safe temporary storage.
 * - Report privacy implications and enforce explicit user consent before external scanning.
 */
public final class InboundSafetyPipeline {

    public static final long DEFAULT_MAX_FILE_SIZE_BYTES = 2L * 1024 * 1024 * 1024L; // 2 GB

    public record PipelineResult(
            boolean committed,
            PolicyDecision decision,
            SecurityVerdict verdict,
            String quarantineId,
            Path finalPath,
            List<String> details
    ) {}

    private final QuarantineZone quarantineZone;
    private final ScannerProvider scanner;
    private final ScanPolicy policy;
    private final ScanCache scanCache;
    private final long maxFileSizeBytes;

    public InboundSafetyPipeline(QuarantineZone quarantineZone, ScannerProvider scanner, ScanPolicy policy, ScanCache scanCache) {
        this(quarantineZone, scanner, policy, scanCache, DEFAULT_MAX_FILE_SIZE_BYTES);
    }

    public InboundSafetyPipeline(QuarantineZone quarantineZone, ScannerProvider scanner, ScanPolicy policy, ScanCache scanCache, long maxFileSizeBytes) {
        this.quarantineZone = Objects.requireNonNull(quarantineZone, "quarantineZone cannot be null");
        this.scanner = Objects.requireNonNull(scanner, "scanner cannot be null");
        this.policy = Objects.requireNonNull(policy, "policy cannot be null");
        this.scanCache = scanCache != null ? scanCache : new ScanCache();
        this.maxFileSizeBytes = maxFileSizeBytes > 0 ? maxFileSizeBytes : DEFAULT_MAX_FILE_SIZE_BYTES;
    }

    public PipelineResult processInboundFile(byte[] content, String relativePath, ContentHash expectedHash, String sourcePeerId, Path targetDestinationDir) throws IOException {
        List<String> details = new ArrayList<>();

        // 0. Pre-Flight Validation: Malicious Filenames, Traversal, Null Bytes
        if (relativePath == null || relativePath.isBlank() || relativePath.contains("\0") || relativePath.contains(":")
                || relativePath.startsWith("/") || relativePath.startsWith("\\")
                || (relativePath.length() >= 2 && Character.isLetter(relativePath.charAt(0)) && relativePath.charAt(1) == ':')) {
            details.add("Malicious path sequence or illegal characters detected in relative path: " + relativePath);
            return new PipelineResult(false, PolicyDecision.REJECT_AND_DELETE, SecurityVerdict.MALICIOUS, null, null, details);
        }

        Path normalizedRel = Path.of(relativePath).normalize();
        for (Path part : normalizedRel) {
            if ("..".equals(part.toString())) {
                details.add("Parent directory traversal prohibited: " + relativePath);
                return new PipelineResult(false, PolicyDecision.REJECT_AND_DELETE, SecurityVerdict.MALICIOUS, null, null, details);
            }
        }

        // File Size Limit Enforcement
        if (content != null && content.length > maxFileSizeBytes) {
            details.add("File size (" + content.length + " bytes) exceeds maximum allowable limit (" + maxFileSizeBytes + " bytes)");
            return new PipelineResult(false, PolicyDecision.REJECT_AND_DELETE, SecurityVerdict.UNSUPPORTED, null, null, details);
        }

        // 1. Stage into quarantine
        QuarantineRecord staged;
        try {
            staged = quarantineZone.stageInbound(content, relativePath, expectedHash, sourcePeerId);
            details.add("Staged into quarantine: " + staged.quarantineId());
        } catch (IOException e) {
            if (isVirusInterception(e)) {
                details.add("Host OS antimalware intercepted file during staging: " + e.getMessage());
                return new PipelineResult(false, PolicyDecision.REJECT_AND_DELETE, SecurityVerdict.MALICIOUS, "quarantine_intercepted", null, details);
            }
            throw e;
        }

        // 2. Integrity Verification
        boolean integrityValid;
        try {
            integrityValid = quarantineZone.verifyIntegrity(staged);
        } catch (IOException e) {
            if (isVirusInterception(e)) {
                quarantineZone.rejectAndDelete(staged);
                details.add("Host OS antimalware locked file during verification: " + e.getMessage());
                return new PipelineResult(false, PolicyDecision.REJECT_AND_DELETE, SecurityVerdict.MALICIOUS, staged.quarantineId(), null, details);
            }
            throw e;
        }

        if (!integrityValid) {
            quarantineZone.rejectAndDelete(staged);
            details.add("Integrity verification FAILED: ContentHash mismatch");
            return new PipelineResult(false, PolicyDecision.REJECT_AND_DELETE, SecurityVerdict.SCAN_FAILED, staged.quarantineId(), null, details);
        }
        details.add("Integrity verified cleanly");

        // 3. Archive Safety Check
        if (ArchiveSafetyInspector.isArchive(relativePath)) {
            ArchiveSafetyInspector.ArchiveSafetyVerdict archiveVerdict = ArchiveSafetyInspector.inspectZip(staged.stagedFile());
            if (!archiveVerdict.isSafe()) {
                if (archiveVerdict.isDecompressionBomb()) {
                    details.add("Decompression bomb defense triggered");
                    quarantineZone.rejectAndDelete(staged);
                    return new PipelineResult(false, PolicyDecision.REJECT_AND_DELETE, SecurityVerdict.MALICIOUS, staged.quarantineId(), null, details);
                }
                if (archiveVerdict.hasPathTraversal()) {
                    details.add("Path traversal detected in archive");
                    quarantineZone.rejectAndDelete(staged);
                    return new PipelineResult(false, PolicyDecision.REJECT_AND_DELETE, SecurityVerdict.MALICIOUS, staged.quarantineId(), null, details);
                }
                // Malformed / corrupt archive
                details.add("Malformed or corrupted archive detected: " + String.join("; ", archiveVerdict.findings()));
                quarantineZone.rejectAndDelete(staged);
                return new PipelineResult(false, PolicyDecision.REJECT_AND_DELETE, SecurityVerdict.SCAN_FAILED, staged.quarantineId(), null, details);
            }
        }

        // 4. Executable Inspection
        ExecutableSafetyInspector.ExecutableSafetyReport execReport = ExecutableSafetyInspector.inspect(staged.stagedFile(), relativePath);
        if (execReport.isDisguised()) {
            details.add("Disguised executable detected: " + execReport.detectedFormat());
            quarantineZone.rejectAndDelete(staged);
            return new PipelineResult(false, PolicyDecision.REJECT_AND_DELETE, SecurityVerdict.MALICIOUS, staged.quarantineId(), null, details);
        }
        if (execReport.isExecutable()) {
            details.add("Executable content detected: " + execReport.detectedFormat() + (execReport.isSigned() ? " (signed)" : " (unsigned)"));
        }

        // 5. Malware Scan (with Cache)
        ScanResult scanResult;
        Optional<ScanResult> cached = scanCache.get(expectedHash);
        if (cached.isPresent()) {
            scanResult = cached.get();
            details.add("Retrieved scan result from cache: " + scanResult.verdict());
        } else {
            if (!scanner.isAvailable()) {
                // INVARIANT: Never claim safe when scanner is unavailable
                scanResult = ScanResult.unavailable(scanner.getProviderName(), "Scanner offline or not configured");
                details.add("Scanner unavailable: " + scanResult.verdict());
            } else {
                try {
                    SecurityVerdict v = scanner.scanFile(staged.stagedFile().toString());
                    scanResult = new ScanResult(v, scanner.getProviderName(), null, 10, Map.of());
                    scanCache.put(expectedHash, scanResult);
                    details.add("Scanned by " + scanner.getProviderName() + ": " + v);
                } catch (SecurityException e) {
                    // Privacy policy violation or consent requirement
                    scanResult = ScanResult.unavailable(scanner.getProviderName(), "Privacy consent required: " + e.getMessage());
                    details.add("External scanning privacy constraint: " + e.getMessage());
                } catch (IOException e) {
                    if (isVirusInterception(e)) {
                        scanResult = ScanResult.malicious(scanner.getProviderName(), "HostOS.DetectedVirus", 1);
                        details.add("Host antimalware intercepted file: " + e.getMessage());
                    } else {
                        scanResult = ScanResult.failed(scanner.getProviderName(), e.getMessage());
                        details.add("Scanner I/O failure: " + e.getMessage());
                    }
                } catch (Exception e) {
                    // INVARIANT: Scanner crash, unhandled runtime exception, or timeout must NEVER convert to CLEAN
                    scanResult = ScanResult.failed(scanner.getProviderName(), "Scanner crash/timeout: " + e.getMessage());
                    details.add("Scanner crash/timeout caught: " + e.getMessage());
                }
            }
        }

        // 6. Policy Evaluation
        PolicyDecision decision = policy.evaluate(scanResult);
        details.add("Policy evaluated decision: " + decision);

        if (decision == PolicyDecision.PERMIT_COMMIT) {
            Path committedPath = quarantineZone.commitFile(staged, targetDestinationDir);
            details.add("Committed to destination: " + committedPath);
            return new PipelineResult(true, decision, scanResult.verdict(), staged.quarantineId(), committedPath, details);
        } else if (decision == PolicyDecision.REJECT_AND_DELETE) {
            quarantineZone.rejectAndDelete(staged);
            details.add("Rejected and deleted from quarantine");
            return new PipelineResult(false, decision, scanResult.verdict(), staged.quarantineId(), null, details);
        } else {
            // HOLD_IN_QUARANTINE_FOR_DECISION
            details.add("Held in quarantine pending user decision");
            return new PipelineResult(false, decision, scanResult.verdict(), staged.quarantineId(), null, details);
        }
    }

    private static boolean isVirusInterception(IOException e) {
        String msg = e.getMessage();
        return msg != null && (msg.toLowerCase().contains("virus") || msg.toLowerCase().contains("potentially unwanted software"));
    }
}