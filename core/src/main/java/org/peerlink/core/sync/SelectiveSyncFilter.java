package org.peerlink.core.sync;

import java.util.*;
import java.util.regex.Pattern;

/**
 * Filter controlling which objects participate in sync.
 *
 * <p>Rules:
 * <ul>
 *   <li>Exclusions take precedence over inclusions.</li>
 *   <li>An empty inclusion list means all objects are included (subject to exclusions).</li>
 *   <li>Filters operate on relative paths — no knowledge of filesystem roots.</li>
 *   <li>Pattern matching uses glob-style: {@code *} = any segment chars, {@code **} = any path.</li>
 * </ul>
 */
public final class SelectiveSyncFilter {

    private final List<String> includeGlobs;
    private final List<String> excludeGlobs;
    private final long maxFileSizeBytes;  // 0 = no limit
    private final boolean includeDirectories;
    private final PeerLinkIgnoreEngine ignoreEngine;

    public SelectiveSyncFilter(PeerLinkIgnoreEngine ignoreEngine) {
        this(null, null, 0, true, ignoreEngine);
    }

    public SelectiveSyncFilter(List<String> includeGlobs, List<String> excludeGlobs,
                                long maxFileSizeBytes, boolean includeDirectories) {
        this(includeGlobs, excludeGlobs, maxFileSizeBytes, includeDirectories, null);
    }

    public SelectiveSyncFilter(List<String> includeGlobs, List<String> excludeGlobs,
                                long maxFileSizeBytes, boolean includeDirectories,
                                PeerLinkIgnoreEngine ignoreEngine) {
        this.includeGlobs = includeGlobs != null ? new ArrayList<>(includeGlobs) : new ArrayList<>();
        this.excludeGlobs = excludeGlobs != null ? new ArrayList<>(excludeGlobs) : new ArrayList<>();
        this.maxFileSizeBytes = maxFileSizeBytes;
        this.includeDirectories = includeDirectories;
        this.ignoreEngine = ignoreEngine;
    }

    public static SelectiveSyncFilter acceptAll() {
        return new SelectiveSyncFilter(null, null, 0, true, null);
    }

    /**
     * Returns true if this object should participate in sync.
     */
    public boolean accepts(String relativePath, long sizeBytes, boolean isDirectory) {
        if (isDirectory && !includeDirectories) return false;
        if (maxFileSizeBytes > 0 && !isDirectory && sizeBytes > maxFileSizeBytes) return false;
        if (ignoreEngine != null && ignoreEngine.isIgnored(relativePath, isDirectory)) return false;
        // Exclusion wins over inclusion
        for (String glob : excludeGlobs) {
            if (matchesGlob(relativePath, glob)) return false;
        }
        if (includeGlobs.isEmpty()) return true;
        for (String glob : includeGlobs) {
            if (matchesGlob(relativePath, glob)) return true;
        }
        return false;
    }

    /**
     * Simple glob matcher supporting {@code *} (any non-separator chars) and {@code **} (any path).
     */
    private static boolean matchesGlob(String path, String glob) {
        String regex = glob
                .replace(".", "\\.")
                .replace("**", "\u0000")  // placeholder for **
                .replace("*", "[^/]*")
                .replace("\u0000", ".*");
        return Pattern.compile(regex).matcher(path).matches();
    }
}