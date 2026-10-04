package org.peerlink.core.safety;

import org.peerlink.core.security.ScannerProvider;
import org.peerlink.core.security.SecurityVerdict;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

/**
 * Deterministic scanner provider for integration testing and simulated environments.
 */
public final class SimulatedScanner implements ScannerProvider {
    public static final String TEST_MALWARE_SIGNATURE = "PEERLINK-TEST-MALWARE-SIGNATURE-XYZ";
    public static final String TEST_SUSPICIOUS_SIGNATURE = "PEERLINK-TEST-SUSPICIOUS-SIGNATURE-ABC";

    private final String name;
    private boolean available;
    private final Set<String> maliciousSubstrings = new HashSet<>();
    private final Set<String> suspiciousSubstrings = new HashSet<>();
    private SecurityVerdict defaultVerdict = SecurityVerdict.CLEAN;

    public SimulatedScanner(String name, boolean available) {
        this.name = name;
        this.available = available;
        maliciousSubstrings.add(TEST_MALWARE_SIGNATURE);
        suspiciousSubstrings.add(TEST_SUSPICIOUS_SIGNATURE);
    }

    public void setAvailable(boolean available) {
        this.available = available;
    }

    public void addMaliciousSignature(String signature) {
        maliciousSubstrings.add(signature);
    }

    public void addSuspiciousSignature(String signature) {
        suspiciousSubstrings.add(signature);
    }

    public void setDefaultVerdict(SecurityVerdict verdict) {
        this.defaultVerdict = verdict;
    }

    @Override
    public String getProviderName() {
        return name;
    }

    @Override
    public boolean isAvailable() {
        return available;
    }

    @Override
    public SecurityVerdict scanStream(InputStream inputStream) throws IOException {
        if (!available) return SecurityVerdict.UNAVAILABLE;
        byte[] bytes = inputStream.readAllBytes();
        return evaluateBytes(bytes).verdict();
    }

    @Override
    public SecurityVerdict scanFile(String filePath) throws IOException {
        if (!available) return SecurityVerdict.UNAVAILABLE;
        Path path = Path.of(filePath);
        if (!Files.exists(path)) throw new IOException("File not found: " + filePath);
        byte[] bytes = Files.readAllBytes(path);
        return evaluateBytes(bytes).verdict();
    }

    public ScanResult scanPath(Path path) throws IOException {
        if (!available) {
            return ScanResult.unavailable(name, "Scanner daemon not responding or unavailable");
        }
        if (!Files.exists(path)) {
            return ScanResult.failed(name, "File not found: " + path);
        }
        byte[] bytes = Files.readAllBytes(path);
        return evaluateBytes(bytes);
    }

    private ScanResult evaluateBytes(byte[] bytes) {
        String content = new String(bytes);
        for (String m : maliciousSubstrings) {
            if (content.contains(m)) {
                return ScanResult.malicious(name, "Test.Malware.Signature", 5);
            }
        }
        for (String s : suspiciousSubstrings) {
            if (content.contains(s)) {
                return ScanResult.suspicious(name, "Suspicious heuristic pattern", 5);
            }
        }
        return new ScanResult(defaultVerdict, name, null, 2, Map.of());
    }
}