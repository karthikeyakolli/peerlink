package org.peerlink.core.workspace;

import org.peerlink.core.model.PeerId;
import java.io.File;
import java.util.Objects;

public final class WorkspaceScope {
    private final String workspaceId;
    private final PeerId owner;
    private final File rootDirectory;

    public WorkspaceScope(String workspaceId, PeerId owner, File rootDirectory) {
        this.workspaceId = Objects.requireNonNull(workspaceId);
        this.owner = Objects.requireNonNull(owner);
        this.rootDirectory = Objects.requireNonNull(rootDirectory);
    }

    public String getWorkspaceId() { return workspaceId; }
    public PeerId getOwner() { return owner; }
    public File getRootDirectory() { return rootDirectory; }
}
