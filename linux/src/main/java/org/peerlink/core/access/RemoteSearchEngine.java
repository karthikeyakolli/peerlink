package org.peerlink.core.access;

import org.peerlink.protocol.v1.RemoteObjectReference;

import java.io.IOException;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.*;

/**
 * Local search engine executing queries directly within an authorized share.
 *
 * <p>Privacy & Architecture Guarantees:
 * <ul>
 *   <li>The search query is visible ONLY to the authorized remote peer over an encrypted session.</li>
 *   <li>The central backend never receives, indexes, or queries private file data.</li>
 *   <li>Search is bounded by maxDepth, maxResults, timeoutMs, and cooperative cancellation.</li>
 * </ul>
 */
public final class RemoteSearchEngine {

    public static final int DEFAULT_MAX_DEPTH = 5;
    public static final int ABSOLUTE_MAX_DEPTH = 10;
    public static final int DEFAULT_MAX_RESULTS = 50;
    public static final int ABSOLUTE_MAX_RESULTS = 500;
    public static final long DEFAULT_TIMEOUT_MS = 5000L;

    private final PathSandboxValidator validator;

    public record SearchResult(
            List<RemoteObjectReference> matches,
            String nextCursor,
            boolean hasMore,
            int totalFound,
            boolean timedOut
    ) {}

    public RemoteSearchEngine() {
        this(new PathSandboxValidator());
    }

    public RemoteSearchEngine(PathSandboxValidator validator) {
        this.validator = validator;
    }

    /**
     * Executes a search within the shared root directory.
     *
     * @param shareRoot the base shared root
     * @param relativeScope relative folder to start search in (empty for root)
     * @param query search query term or pattern
     * @param requestedMaxResults result limit
     * @param requestedMaxDepth traversal depth limit
     * @param timeoutMs search timeout in milliseconds
     * @param cursor offset cursor
     * @param token cancellation token
     * @return SearchResult containing matching items
     */
    public SearchResult search(
            Path shareRoot,
            String relativeScope,
            String query,
            int requestedMaxResults,
            int requestedMaxDepth,
            long timeoutMs,
            String cursor,
            CancellationToken token
    ) throws PathSandboxValidator.PathTraversalException, IOException, CancellationToken.OperationCancelledException {
        if (token != null) {
            token.throwIfCancelled();
        }

        Path startDir = validator.resolveAndValidate(shareRoot, relativeScope);
        if (!Files.exists(startDir) || !Files.isDirectory(startDir)) {
            throw new NoSuchFileException("Search scope does not exist: " + relativeScope);
        }

        int maxResults = requestedMaxResults <= 0 ? DEFAULT_MAX_RESULTS : Math.min(requestedMaxResults, ABSOLUTE_MAX_RESULTS);
        int maxDepth = requestedMaxDepth <= 0 ? DEFAULT_MAX_DEPTH : Math.min(requestedMaxDepth, ABSOLUTE_MAX_DEPTH);
        long effectiveTimeout = timeoutMs <= 0 ? DEFAULT_TIMEOUT_MS : Math.min(timeoutMs, 30_000L);
        long deadline = System.currentTimeMillis() + effectiveTimeout;

        int parsedOffset = 0;
        if (cursor != null && !cursor.isBlank()) {
            try {
                parsedOffset = Integer.parseInt(cursor);
            } catch (NumberFormatException ignored) {}
        }
        final int offset = parsedOffset;
        final int targetLimit = offset + maxResults + 1;

        String normalizedQuery = (query == null) ? "" : query.trim().toLowerCase(Locale.ROOT);
        List<Path> matchingPaths = new ArrayList<>();
        boolean[] timedOut = new boolean[]{false};

        Files.walkFileTree(startDir, EnumSet.noneOf(FileVisitOption.class), maxDepth, new SimpleFileVisitor<Path>() {
            @Override
            public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) throws IOException {
                if (token != null && token.isCancelled()) {
                    return FileVisitResult.TERMINATE;
                }
                if (System.currentTimeMillis() > deadline) {
                    timedOut[0] = true;
                    return FileVisitResult.TERMINATE;
                }
                // Check if directory matches query (except the startDir itself)
                if (!dir.equals(startDir) && matches(dir.getFileName().toString(), normalizedQuery)) {
                    matchingPaths.add(dir);
                }
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                if (token != null && token.isCancelled()) {
                    return FileVisitResult.TERMINATE;
                }
                if (System.currentTimeMillis() > deadline) {
                    timedOut[0] = true;
                    return FileVisitResult.TERMINATE;
                }

                if (matches(file.getFileName().toString(), normalizedQuery)) {
                    matchingPaths.add(file);
                }

                // If collected enough entries to satisfy current page + more
                if (matchingPaths.size() >= targetLimit) {
                    return FileVisitResult.TERMINATE;
                }

                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult visitFileFailed(Path file, IOException exc) {
                // Skip unreadable files gracefully
                return FileVisitResult.CONTINUE;
            }
        });

        if (token != null) {
            token.throwIfCancelled();
        }

        int totalFound = matchingPaths.size();
        int fromIndex = Math.min(offset, totalFound);
        int toIndex = Math.min(fromIndex + maxResults, totalFound);
        boolean hasMore = toIndex < totalFound;
        String nextCursor = hasMore ? String.valueOf(toIndex) : "";

        List<RemoteObjectReference> references = new ArrayList<>();
        for (int i = fromIndex; i < toIndex; i++) {
            references.add(RemoteFolderBrowser.toRemoteObjectReference(shareRoot, matchingPaths.get(i)));
        }

        return new SearchResult(references, nextCursor, hasMore, totalFound, timedOut[0]);
    }

    private static boolean matches(String fileName, String query) {
        if (query.isEmpty()) return true;
        String lowerName = fileName.toLowerCase(Locale.ROOT);
        // Simple wildcard match or substring match
        if (query.startsWith("*.") && query.length() > 2) {
            String ext = query.substring(2);
            return lowerName.endsWith("." + ext);
        }
        return lowerName.contains(query);
    }
}
