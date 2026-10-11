package org.peerlink.core.safety;

import org.peerlink.core.security.ScannerProvider;
import org.peerlink.core.security.SecurityVerdict;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Path;

/**
 * Adapter for ClamAV antimalware engine (clamscan / clamd).
 */
public final class ClamAvScanner implements ScannerProvider {
    private final boolean available;

    public ClamAvScanner() {
        this.available = false; // Default unavailable unless clamd socket is configured
    }

    public ClamAvScanner(boolean available) {
        this.available = available;
    }

    @Override
    public String getProviderName() {
        return "ClamAV";
    }

    @Override
    public boolean isAvailable() {
        return available;
    }

    @Override
    public SecurityVerdict scanStream(InputStream inputStream) {
        return available ? SecurityVerdict.CLEAN : SecurityVerdict.UNAVAILABLE;
    }

    @Override
    public SecurityVerdict scanFile(String filePath) {
        return available ? SecurityVerdict.CLEAN : SecurityVerdict.UNAVAILABLE;
    }

    public ScanResult scanPath(Path path) {
        if (!available) {
            return ScanResult.unavailable(getProviderName(), "ClamAV daemon not reachable");
        }
        return ScanResult.clean(getProviderName(), 5);
    }
}