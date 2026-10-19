package org.peerlink.core.access;

import org.peerlink.protocol.v1.ObjectId;
import org.peerlink.protocol.v1.ObjectType;
import org.peerlink.protocol.v1.RemoteObjectReference;

import java.io.IOException;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Stream;

/**
 * Service for securely browsing remote folders within an authorized share root.
 */
public final class RemoteFolderBrowser {

    public static final int DEFAULT_PAGE_SIZE = 50;
    public static final int MAX_PAGE_SIZE = 500;

    private final PathSandboxValidator validator;

    public record BrowseResult(
            List<RemoteObjectReference> items,
            String nextCursor,
            boolean hasMore,
            int totalInDirectory
    ) {}

    public RemoteFolderBrowser() {
        this(new PathSandboxValidator());
    }

    public RemoteFolderBrowser(PathSandboxValidator validator) {
        this.validator = validator;
    }

    /**
     * Browses a directory relative to the share root with pagination and cancellation support.
     *
     * @param shareRoot shared directory root
     * @param relativePath relative folder path within the share
     * @param requestedPageSize requested page size (1 to 500)
     * @param cursor pagination cursor (opaque offset string)
     * @param token cancellation token
     * @return BrowseResult
     * @throws PathSandboxValidator.PathTraversalException on traversal attempt
     * @throws IOException on directory read error
     * @throws CancellationToken.OperationCancelledException if cancelled
     */
    public BrowseResult browse(
            Path shareRoot,
            String relativePath,
            int requestedPageSize,
            String cursor,
            CancellationToken token
    ) throws PathSandboxValidator.PathTraversalException, IOException, CancellationToken.OperationCancelledException {
        if (token != null) {
            token.throwIfCancelled();
        }

        Path targetDir = validator.resolveAndValidate(shareRoot, relativePath);
        if (!Files.exists(targetDir)) {
            throw new NoSuchFileException("Path does not exist: " + relativePath);
        }
        if (!Files.isDirectory(targetDir)) {
            throw new NotDirectoryException("Path is not a directory: " + relativePath);
        }

        int pageSize = requestedPageSize <= 0 ? DEFAULT_PAGE_SIZE : Math.min(requestedPageSize, MAX_PAGE_SIZE);
        int offset = 0;
        if (cursor != null && !cursor.isBlank()) {
            try {
                offset = Integer.parseInt(cursor);
            } catch (NumberFormatException ignored) {}
        }

        List<Path> allEntries = new ArrayList<>();
        try (Stream<Path> stream = Files.list(targetDir)) {
            // Sort deterministically: directories first, then alphabetically case-insensitive
            stream.forEach(p -> {
                if (token != null && token.isCancelled()) {
                    return;
                }
                allEntries.add(p);
            });
        }

        if (token != null) {
            token.throwIfCancelled();
        }

        allEntries.sort((p1, p2) -> {
            boolean d1 = Files.isDirectory(p1);
            boolean d2 = Files.isDirectory(p2);
            if (d1 != d2) return d1 ? -1 : 1;
            return p1.getFileName().toString().compareToIgnoreCase(p2.getFileName().toString());
        });

        int total = allEntries.size();
        int fromIndex = Math.min(offset, total);
        int toIndex = Math.min(fromIndex + pageSize, total);
        boolean hasMore = toIndex < total;
        String nextCursor = hasMore ? String.valueOf(toIndex) : "";

        List<RemoteObjectReference> items = new ArrayList<>();
        for (int i = fromIndex; i < toIndex; i++) {
            if (token != null) {
                token.throwIfCancelled();
            }
            Path entry = allEntries.get(i);
            items.add(toRemoteObjectReference(shareRoot, entry));
        }

        return new BrowseResult(items, nextCursor, hasMore, total);
    }

    /**
     * Resolves metadata for a single item.
     */
    public RemoteObjectReference getMetadata(Path shareRoot, String relativePath)
            throws PathSandboxValidator.PathTraversalException, IOException {
        Path target = validator.resolveAndValidate(shareRoot, relativePath);
        if (!Files.exists(target)) {
            throw new NoSuchFileException("Target does not exist: " + relativePath);
        }
        return toRemoteObjectReference(shareRoot, target);
    }

    /**
     * Converts a local file/directory path to a RemoteObjectReference.
     */
    public static RemoteObjectReference toRemoteObjectReference(Path shareRoot, Path path) {
        String fileName = path.getFileName().toString();
        Path relativePath = shareRoot.toAbsolutePath().normalize().relativize(path.toAbsolutePath().normalize());
        String relPathStr = relativePath.toString().replace('\\', '/');

        boolean isDir = Files.isDirectory(path);
        boolean isSymlink = Files.isSymbolicLink(path);
        boolean isExec = SafePreviewEngine.isExecutable(path);
        boolean isPreviewable = SafePreviewEngine.isPreviewable(path);
        boolean isHidden = false;
        long size = 0;
        long modifiedUtc = 0;

        try {
            isHidden = Files.isHidden(path);
            if (!isDir && Files.isRegularFile(path)) {
                size = Files.size(path);
            }
            modifiedUtc = Files.getLastModifiedTime(path).toMillis();
        } catch (IOException ignored) {}

        String mimeType = isDir ? "inode/directory" : SafePreviewEngine.detectMimeType(path);

        // Deterministic synthetic object ID based on share-relative path
        String objectIdVal = "obj_" + Integer.toHexString(relPathStr.hashCode()) + "_" + size;

        Map<String, String> attrs = new HashMap<>();
        attrs.put("isReadable", String.valueOf(Files.isReadable(path)));
        attrs.put("isArchive", String.valueOf(SafePreviewEngine.isArchive(path)));

        return RemoteObjectReference.newBuilder()
                .setObjectId(ObjectId.newBuilder().setValue(objectIdVal).build())
                .setRelativePath(relPathStr)
                .setDisplayName(fileName)
                .setObjectType(isDir ? ObjectType.OBJECT_TYPE_DIRECTORY : ObjectType.OBJECT_TYPE_FILE)
                .setByteSize(size)
                .setMimeType(mimeType)
                .setModifiedTimeUtcMs(modifiedUtc)
                .setIsSymlink(isSymlink)
                .setIsExecutable(isExec)
                .setIsPreviewable(isPreviewable)
                .setIsHidden(isHidden)
                .putAllAttributes(attrs)
                .build();
    }
}
