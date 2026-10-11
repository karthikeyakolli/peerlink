package org.peerlink.core.collaboration.workspace;

import java.io.Serializable;
import java.util.Objects;

public record WorkspaceMember(
        String peerId,
        WorkspaceRole role,
        long joinedAtUtcMs,
        String invitedByPeerId,
        boolean revoked
) implements Serializable {
    public WorkspaceMember {
        Objects.requireNonNull(peerId, "peerId is required");
        Objects.requireNonNull(role, "role is required");
    }

    public WorkspaceMember withRole(WorkspaceRole newRole) {
        return new WorkspaceMember(peerId, newRole, joinedAtUtcMs, invitedByPeerId, revoked);
    }

    public WorkspaceMember withRevoked(boolean isRevoked) {
        return new WorkspaceMember(peerId, role, joinedAtUtcMs, invitedByPeerId, isRevoked);
    }
}