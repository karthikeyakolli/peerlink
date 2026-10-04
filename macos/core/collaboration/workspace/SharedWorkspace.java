package org.peerlink.core.collaboration.workspace;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;

import java.io.Serializable;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Shared Space (Workspace) aggregate.
 *
 * Invariants:
 * - Changes to membership, roles, or revocations increment the policyEpoch.
 * - In-flight or cached operations presenting an older policyEpoch are invalidated.
 * - Owner cannot be removed.
 */
public final class SharedWorkspace implements Serializable {
    private static final long serialVersionUID = 1L;

    private final String workspaceId;
    private final String name;
    private final String ownerPeerId;
    private volatile long policyEpoch;

    private final Map<String, WorkspaceMember> members = new ConcurrentHashMap<>();
    private final Set<String> revokedPeers = ConcurrentHashMap.newKeySet();
    private final Map<ObjectIdentity, FileBranchLineage> fileLineages = new ConcurrentHashMap<>();

    public SharedWorkspace(String workspaceId, String name, String ownerPeerId) {
        this.workspaceId = Objects.requireNonNull(workspaceId, "workspaceId is required");
        this.name = Objects.requireNonNull(name, "name is required");
        this.ownerPeerId = Objects.requireNonNull(ownerPeerId, "ownerPeerId is required");
        this.policyEpoch = 1;

        // Owner is added as first member
        members.put(ownerPeerId, new WorkspaceMember(ownerPeerId, WorkspaceRole.OWNER, System.currentTimeMillis(), ownerPeerId, false));
    }

    public synchronized void inviteMember(String actorPeerId, String targetPeerId, WorkspaceRole role) {
        verifyCanAdmin(actorPeerId);
        if (role == WorkspaceRole.OWNER) {
            throw new IllegalArgumentException("Cannot invite another peer as OWNER");
        }
        if (revokedPeers.contains(targetPeerId)) {
            throw new IllegalStateException("Peer " + targetPeerId + " has been revoked from this workspace");
        }
        members.put(targetPeerId, new WorkspaceMember(targetPeerId, role, System.currentTimeMillis(), actorPeerId, false));
        policyEpoch++;
    }

    public synchronized void removeMember(String actorPeerId, String targetPeerId) {
        verifyCanAdmin(actorPeerId);
        if (targetPeerId.equals(ownerPeerId)) {
            throw new IllegalStateException("Cannot remove workspace owner");
        }
        WorkspaceMember removed = members.remove(targetPeerId);
        if (removed != null) {
            policyEpoch++;
        }
    }

    public synchronized void revokeMember(String actorPeerId, String targetPeerId, String reason) {
        verifyCanAdmin(actorPeerId);
        if (targetPeerId.equals(ownerPeerId)) {
            throw new IllegalStateException("Cannot revoke workspace owner");
        }
        members.remove(targetPeerId);
        revokedPeers.add(targetPeerId);
        policyEpoch++;
    }

    public synchronized void changeRole(String actorPeerId, String targetPeerId, WorkspaceRole newRole) {
        verifyCanAdmin(actorPeerId);
        if (targetPeerId.equals(ownerPeerId)) {
            throw new IllegalStateException("Cannot change role of workspace owner");
        }
        WorkspaceMember member = members.get(targetPeerId);
        if (member == null) {
            throw new NoSuchElementException("Member not found: " + targetPeerId);
        }
        members.put(targetPeerId, member.withRole(newRole));
        policyEpoch++;
    }

    public boolean authorizeAction(String peerId, WorkspaceAction action, long presentedEpoch) {
        // Invariant: Epoch must match current policy epoch
        if (presentedEpoch != this.policyEpoch) {
            return false;
        }

        if (revokedPeers.contains(peerId)) {
            return false;
        }

        WorkspaceMember member = members.get(peerId);
        if (member == null || member.revoked()) {
            return false;
        }

        WorkspaceRole role = member.role();
        return switch (action) {
            case INVITE_MEMBER, REMOVE_MEMBER, REVOKE_MEMBER, CHANGE_ROLE -> role.canAdmin();
            case WRITE_FILE -> role.canWrite();
            case DELETE_FILE -> role.canDelete();
            case READ_PAYLOAD -> role.canReadPayload();
            case VIEW_METADATA -> role.canViewMetadata();
        };
    }

    public FileBranchLineage recordFileModification(
            String actorPeerId,
            ObjectIdentity objectId,
            String relativePath,
            ContentHash contentHash,
            long parentSeq,
            long presentedEpoch
    ) {
        if (!authorizeAction(actorPeerId, WorkspaceAction.WRITE_FILE, presentedEpoch)) {
            throw new SecurityException("Actor " + actorPeerId + " unauthorized to write in workspace " + workspaceId);
        }
        long newSeq = parentSeq + 1;
        FileBranchLineage lineage = new FileBranchLineage(
                objectId, relativePath, newSeq, contentHash, actorPeerId, parentSeq, System.currentTimeMillis()
        );
        fileLineages.put(objectId, lineage);
        return lineage;
    }

    private void verifyCanAdmin(String actorPeerId) {
        WorkspaceMember actor = members.get(actorPeerId);
        if (actor == null || !actor.role().canAdmin()) {
            throw new SecurityException("Peer " + actorPeerId + " lacks admin privileges in workspace " + workspaceId);
        }
    }

    public String getWorkspaceId() { return workspaceId; }
    public String getName() { return name; }
    public String getOwnerPeerId() { return ownerPeerId; }
    public long getPolicyEpoch() { return policyEpoch; }
    public Map<String, WorkspaceMember> getMembers() { return Collections.unmodifiableMap(members); }
    public Set<String> getRevokedPeers() { return Collections.unmodifiableSet(revokedPeers); }
    public Optional<FileBranchLineage> getFileLineage(ObjectIdentity id) { return Optional.ofNullable(fileLineages.get(id)); }
}