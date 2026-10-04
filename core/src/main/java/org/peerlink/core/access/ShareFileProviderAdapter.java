package org.peerlink.core.access;

import org.peerlink.core.filesystem.PeerFileHandle;
import org.peerlink.core.filesystem.PeerFileProvider;
import org.peerlink.core.model.ObjectIdentity;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.stream.Stream;

/**
 * Optional platform-neutral filesystem provider adapter backed by an authorized ShareDefinition.
 */
public final class ShareFileProviderAdapter implements PeerFileProvider {

    private final ShareDefinition share;
    private final PathSandboxValidator validator;

    public ShareFileProviderAdapter(ShareDefinition share) {
        this.share = share;
        this.validator = new PathSandboxValidator();
    }

    @Override
    public Optional<PeerFileHandle> resolve(ObjectIdentity objectId) throws IOException {
        if (objectId == null) return Optional.empty();
        return resolveByPhysicalPath(objectId.getValue());
    }

    @Override
    public Optional<PeerFileHandle> resolveByPhysicalPath(String physicalPathOrUri) throws IOException {
        try {
            Path safePath = validator.resolveAndValidate(share.rootDirectory(), physicalPathOrUri);
            if (!Files.exists(safePath)) {
                return Optional.empty();
            }
            return Optional.of(new PathPeerFileHandle(safePath, share.rootDirectory()));
        } catch (PathSandboxValidator.PathTraversalException e) {
            throw new IOException("Path traversal rejected: " + physicalPathOrUri, e);
        }
    }

    @Override
    public List<PeerFileHandle> listChildren(PeerFileHandle directory) throws IOException {
        if (!directory.isDirectory()) {
            return List.of();
        }
        Optional<PeerFileHandle> resolved = resolveByPhysicalPath(directory.getDisplayName());
        if (resolved.isEmpty()) {
            return List.of();
        }
        Path dirPath = ((PathPeerFileHandle) resolved.get()).path();
        List<PeerFileHandle> children = new ArrayList<>();
        try (Stream<Path> stream = Files.list(dirPath)) {
            stream.forEach(child -> children.add(new PathPeerFileHandle(child, share.rootDirectory())));
        }
        return children;
    }

    @Override
    public boolean delete(PeerFileHandle handle) throws IOException {
        if (handle instanceof PathPeerFileHandle pfh) {
            return Files.deleteIfExists(pfh.path());
        }
        return false;
    }

    @Override
    public void reconcile(String rootPath) throws IOException {
        // No-op or rescan verification
    }

    private static final class PathPeerFileHandle implements PeerFileHandle {
        private final Path path;
        private final Path root;

        public PathPeerFileHandle(Path path, Path root) {
            this.path = path;
            this.root = root;
        }

        public Path path() {
            return path;
        }

        @Override
        public ObjectIdentity getObjectId() {
            String rel = root.relativize(path).toString().replace('\\', '/');
            return new ObjectIdentity("obj_" + rel.hashCode());
        }

        @Override
        public String getDisplayName() {
            return path.getFileName().toString();
        }

        @Override
        public long getSizeBytes() {
            try {
                return Files.isDirectory(path) ? 0 : Files.size(path);
            } catch (IOException e) {
                return 0;
            }
        }

        @Override
        public long getLastModifiedUtcMs() {
            try {
                return Files.getLastModifiedTime(path).toMillis();
            } catch (IOException e) {
                return 0;
            }
        }

        @Override
        public boolean isDirectory() {
            return Files.isDirectory(path);
        }

        @Override
        public InputStream openInputStream() throws IOException {
            return Files.newInputStream(path);
        }

        @Override
        public OutputStream openOutputStream() throws IOException {
            return Files.newOutputStream(path);
        }
    }
}
