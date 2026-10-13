package org.peerlink.core.collaboration.workspace;

import org.peerlink.core.model.PeerId;

import java.io.File;
import java.nio.file.Path;
import java.util.Objects;

/**
 * Encapsulates the local filesystem boundary of a Shared Workspace.
 * Invariant: Operations within a workspace MUST NOT escape the rootDirectory.
 */
public final class WorkspaceScope {
    private final String workspaceId;
    private final PeerId owner;
    private final File rootDirectory;
    private final Path normalizedRoot;

    public WorkspaceScope(String workspaceId, PeerId owner, File rootDirectory) {
        this.workspaceId = Objects.requireNonNull(workspaceId, "workspaceId cannot be null");
        this.owner = Objects.requireNonNull(owner, "owner cannot be null");
        this.rootDirectory = Objects.requireNonNull(rootDirectory, "rootDirectory cannot be null");
        this.normalizedRoot = rootDirectory.toPath().toAbsolutePath().normalize();
    }

    public String getWorkspaceId() { return workspaceId; }
    public PeerId getOwner() { return owner; }
    public File getRootDirectory() { return rootDirectory; }
    public Path getNormalizedRoot() { return normalizedRoot; }

    /**
     * Checks if a candidate path is within the workspace boundary.
     */
    public boolean isPathWithinScope(Path candidatePath) {
        if (candidatePath == null) return false;
        Path normalizedCandidate = candidatePath.toAbsolutePath().normalize();
        return normalizedCandidate.startsWith(normalizedRoot);
    }

    /**
     * Resolves a relative path within the workspace root, preventing traversal escape.
     */
    public Path resolvePathWithinScope(String relativePath) {
        if (relativePath == null || relativePath.isBlank()) {
            throw new IllegalArgumentException("Relative path cannot be null or blank");
        }
        if (relativePath.contains("\0")) {
            throw new SecurityException("Null byte detected in workspace path: " + relativePath);
        }
        if (relativePath.contains("..") || relativePath.startsWith("/") || relativePath.startsWith("\\")
                || (relativePath.length() >= 2 && Character.isLetter(relativePath.charAt(0)) && relativePath.charAt(1) == ':')) {
            throw new SecurityException("Path traversal or illegal prefix in workspace path: " + relativePath);
        }

        Path resolved = normalizedRoot.resolve(relativePath).normalize();
        if (!isPathWithinScope(resolved)) {
            throw new SecurityException("Resolved path escapes workspace scope boundary: " + resolved);
        }
        return resolved;
    }
}
