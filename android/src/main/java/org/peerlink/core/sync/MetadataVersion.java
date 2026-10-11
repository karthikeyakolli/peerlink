package org.peerlink.core.sync;

/**
 * Tracks the metadata version of a sync object (name, path, permissions, timestamps).
 * Separate from ContentVersion so renames/moves can be tracked independently of edits.
 */
public record MetadataVersion(String peerId, long sequence) implements Comparable<MetadataVersion> {
    public MetadataVersion {
        if (peerId == null || peerId.isBlank()) throw new IllegalArgumentException("peerId cannot be blank");
        if (sequence < 0) throw new IllegalArgumentException("sequence cannot be negative");
    }
    public static MetadataVersion initial(String peerId) { return new MetadataVersion(peerId, 1L); }
    public MetadataVersion next() { return new MetadataVersion(peerId, sequence + 1); }
    @Override public int compareTo(MetadataVersion o) { return Long.compare(this.sequence, o.sequence); }
    @Override public String toString() { return peerId + "@mv" + sequence; }
}