package org.peerlink.core.collaboration.workspace;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;

import java.io.Serializable;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Objects;

/**
 * Tracks immutable file lineage across collaborative workspace operations.
 */
public final class FileBranchLineage implements Serializable {
    private static final long serialVersionUID = 1L;

    private final ObjectIdentity objectId;
    private final String relativePath;
    private final long versionSequence;
    private final ContentHash contentHash;
    private final String modifierPeerId;
    private final long parentVersionSequence;
    private final String lineageHash;
    private final long timestampUtcMs;

    public FileBranchLineage(
            ObjectIdentity objectId,
            String relativePath,
            long versionSequence,
            ContentHash contentHash,
            String modifierPeerId,
            long parentVersionSequence,
            long timestampUtcMs
    ) {
        this.objectId = Objects.requireNonNull(objectId, "objectId cannot be null");
        this.relativePath = Objects.requireNonNull(relativePath, "relativePath cannot be null");
        this.versionSequence = versionSequence;
        this.contentHash = contentHash;
        this.modifierPeerId = Objects.requireNonNull(modifierPeerId, "modifierPeerId cannot be null");
        this.parentVersionSequence = parentVersionSequence;
        this.timestampUtcMs = timestampUtcMs;
        this.lineageHash = computeLineageHash();
    }

    private String computeLineageHash() {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(objectId.getValue().getBytes(StandardCharsets.UTF_8));
            md.update(relativePath.getBytes(StandardCharsets.UTF_8));
            md.update(String.valueOf(versionSequence).getBytes(StandardCharsets.UTF_8));
            if (contentHash != null) {
                md.update(contentHash.getHexString().getBytes(StandardCharsets.UTF_8));
            }
            md.update(modifierPeerId.getBytes(StandardCharsets.UTF_8));
            md.update(String.valueOf(parentVersionSequence).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(md.digest());
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    public ObjectIdentity getObjectId() { return objectId; }
    public String getRelativePath() { return relativePath; }
    public long getVersionSequence() { return versionSequence; }
    public ContentHash getContentHash() { return contentHash; }
    public String getModifierPeerId() { return modifierPeerId; }
    public long getParentVersionSequence() { return parentVersionSequence; }
    public String getLineageHash() { return lineageHash; }
    public long getTimestampUtcMs() { return timestampUtcMs; }
}