package org.peerlink.core.sync;

/**
 * Tracks the content version of a sync object independently from its metadata version.
 *
 * <p>A content version change means the file bytes changed.
 * A metadata version change means name, path, timestamps, or permissions changed
 * without byte-level content change.
 *
 * <p>Versions are monotonically increasing per peer. They are NOT timestamps.
 * Timestamps are hints, not conflict authority.
 */
public record ContentVersion(String peerId, long sequence) implements Comparable<ContentVersion> {
    public ContentVersion {
        if (peerId == null || peerId.isBlank()) throw new IllegalArgumentException("peerId cannot be blank");
        if (sequence < 0) throw new IllegalArgumentException("sequence cannot be negative");
    }
    public static ContentVersion initial(String peerId) { return new ContentVersion(peerId, 1L); }
    public ContentVersion next() { return new ContentVersion(peerId, sequence + 1); }
    @Override public int compareTo(ContentVersion o) { return Long.compare(this.sequence, o.sequence); }
    @Override public String toString() { return peerId + "@cv" + sequence; }
}