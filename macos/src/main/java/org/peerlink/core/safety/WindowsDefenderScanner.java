package org.peerlink.core.safety;

import org.peerlink.core.security.ScannerProvider;
import org.peerlink.core.security.SecurityVerdict;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

/**
 * Native adapter for Microsoft Defender (MpCmdRun.exe).
 */
public final class WindowsDefenderScanner implements ScannerProvider {
    private static final String DEFENDER_PATH_1 = "C:\\Program Files\\Windows Defender\\MpCmdRun.exe";
    private static final String DEFENDER_PATH_2 = "C:\\ProgramData\\Microsoft\\Windows Defender\\Platform";

    private final String executablePath;
    private final boolean available;

    public WindowsDefenderScanner() {
        this(findDefenderExecutable());
    }

    public WindowsDefenderScanner(String executablePath) {
        this.executablePath = executablePath;
        this.available = executablePath != null && new File(executablePath).canExecute();
    }

    private static String findDefenderExecutable() {
        if (new File(DEFENDER_PATH_1).canExecute()) return DEFENDER_PATH_1;
        return null;
    }

    @Override
    public String getProviderName() {
        return "Windows Defender";
    }

    @Override
    public boolean isAvailable() {
        return available;
    }

    @Override
    public SecurityVerdict scanStream(InputStream inputStream) throws IOException {
        if (!available) return SecurityVerdict.UNAVAILABLE;
        Path temp = Files.createTempFile("defender_scan_", ".tmp");
        try {
            Files.write(temp, inputStream.readAllBytes());
            return scanFile(temp.toString());
        } finally {
            Files.deleteIfExists(temp);
        }
    }

    @Override
    public SecurityVerdict scanFile(String filePath) throws IOException {
        if (!available) return SecurityVerdict.UNAVAILABLE;
        ScanResult res = scanPath(Path.of(filePath));
        return res.verdict();
    }

    public ScanResult scanPath(Path path) throws IOException {
        if (!available) {
            return ScanResult.unavailable(getProviderName(), "Windows Defender CLI not found or inaccessible");
        }
        long start = System.currentTimeMillis();
        ProcessBuilder pb = new ProcessBuilder(executablePath, "-Scan", "-ScanType", "3", "-File", path.toAbsolutePath().toString(), "-DisableRemediation");
        try {
            Process process = pb.start();
            int exitCode = process.waitFor();
            long duration = System.currentTimeMillis() - start;

            // MpCmdRun exit codes:
            // 0 = Clean
            // 2 = Threat detected
            if (exitCode == 0) {
                return ScanResult.clean(getProviderName(), duration);
            } else if (exitCode == 2) {
                return ScanResult.malicious(getProviderName(), "WinDefender.DetectedThreat", duration);
            } else {
                return ScanResult.failed(getProviderName(), "Defender exited with code " + exitCode);
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return ScanResult.failed(getProviderName(), "Scan interrupted: " + e.getMessage());
        }
    }
}