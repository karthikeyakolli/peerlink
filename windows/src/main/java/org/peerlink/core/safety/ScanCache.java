package org.peerlink.core.safety;

import org.peerlink.core.model.ContentHash;

import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory scan cache to prevent redundant scans of identical content hashes.
 * Invariant: Never caches UNAVAILABLE or SCAN_FAILED verdicts.
 */
public final class ScanCache {
    private static final long DEFAULT_TTL_MS = 24 * 3600 * 1000L; // 24 hours

    private record CacheEntry(ScanResult result, String scannerVersion, long cachedAtUtcMs) {}

    private final Map<String, CacheEntry> cache = new ConcurrentHashMap<>();
    private final long ttlMs;

    public ScanCache() {
        this(DEFAULT_TTL_MS);
    }

    public ScanCache(long ttlMs) {
        this.ttlMs = ttlMs;
    }

    public Optional<ScanResult> get(ContentHash hash) {
        return get(hash, null);
    }

    public Optional<ScanResult> get(ContentHash hash, String expectedScannerVersion) {
        Objects.requireNonNull(hash, "hash cannot be null");
        CacheEntry entry = cache.get(hash.getHexString());
        if (entry == null) return Optional.empty();

        if (System.currentTimeMillis() - entry.cachedAtUtcMs > ttlMs) {
            cache.remove(hash.getHexString());
            return Optional.empty();
        }

        if (expectedScannerVersion != null && !expectedScannerVersion.isBlank()
                && entry.scannerVersion != null && !entry.scannerVersion.equals(expectedScannerVersion)) {
            // Scanner definition or version changed — invalidate cached verdict
            cache.remove(hash.getHexString());
            return Optional.empty();
        }

        return Optional.of(entry.result);
    }

    public void put(ContentHash hash, ScanResult result) {
        put(hash, result, "default");
    }

    public void put(ContentHash hash, ScanResult result, String scannerVersion) {
        Objects.requireNonNull(hash, "hash cannot be null");
        Objects.requireNonNull(result, "result cannot be null");

        if (result.verdict().isSafeToCommit() || result.verdict().isKnownThreat()) {
            cache.put(hash.getHexString(), new CacheEntry(result, scannerVersion != null ? scannerVersion : "default", System.currentTimeMillis()));
        }
    }

    public void invalidateByScannerVersion(String outdatedVersion) {
        if (outdatedVersion == null) return;
        cache.entrySet().removeIf(e -> outdatedVersion.equals(e.getValue().scannerVersion()));
    }

    public boolean isStale(ContentHash hash, long maxAgeMs) {
        Objects.requireNonNull(hash, "hash cannot be null");
        CacheEntry entry = cache.get(hash.getHexString());
        if (entry == null) return true;
        return (System.currentTimeMillis() - entry.cachedAtUtcMs()) > maxAgeMs;
    }

    public void clear() {
        cache.clear();
    }

    public int size() {
        return cache.size();
    }
}