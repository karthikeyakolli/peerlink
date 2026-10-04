package org.peerlink.core.collaboration.workspace;

/**
 * Hierarchical roles for Shared Spaces.
 * - OWNER: Full control; can transfer ownership; cannot be removed.
 * - ADMIN: Manages membership and workspace settings; cannot demote owner.
 * - EDITOR: Read, write, update, delete files.
 * - CONTRIBUTOR: Read, write new files and update own files; cannot delete others files.
 * - VIEWER: Read and download file payloads and metadata; no write.
 * - OBSERVER: View manifests and metadata only; cannot download file payloads.
 */
public enum WorkspaceRole {
    OWNER,
    ADMIN,
    EDITOR,
    CONTRIBUTOR,
    VIEWER,
    OBSERVER;

    public boolean canAdmin() {
        return this == OWNER || this == ADMIN;
    }

    public boolean canInvite() {
        return this == OWNER || this == ADMIN;
    }

    public boolean canWrite() {
        return this == OWNER || this == ADMIN || this == EDITOR || this == CONTRIBUTOR;
    }

    public boolean canDelete() {
        return this == OWNER || this == ADMIN || this == EDITOR;
    }

    public boolean canReadPayload() {
        return this != OBSERVER;
    }

    public boolean canViewMetadata() {
        return true;
    }
}