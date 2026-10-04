package org.peerlink.core.sync;

import java.util.*;

/**
 * Vector clock for causal ordering of sync events.
 *
 * <p>Rules:
 * <ul>
 *   <li>Timestamps are NOT used for causality — only vector clocks.</li>
 *   <li>A dominates B if every component of A >= every component of B and at least one is strictly greater.</li>
 *   <li>Concurrent means neither dominates the other — conflict must be resolved.</li>
 *   <li>Equal means same state — no action needed.</li>
 * </ul>
 */
public final class CausalVersion {

    private final Map<String, Long> clock;

    public CausalVersion() { this.clock = new HashMap<>(); }
    private CausalVersion(Map<String, Long> clock) { this.clock = new HashMap<>(clock); }

    public static CausalVersion empty() { return new CausalVersion(); }

    /** Increment this peer's component. Called on local write. */
    public CausalVersion increment(String peerId) {
        CausalVersion next = new CausalVersion(clock);
        next.clock.put(peerId, clock.getOrDefault(peerId, 0L) + 1);
        return next;
    }

    /** Merge two vector clocks (take the max of each component). Used on sync receive. */
    public CausalVersion merge(CausalVersion other) {
        CausalVersion merged = new CausalVersion(clock);
        for (Map.Entry<String, Long> e : other.clock.entrySet()) {
            merged.clock.merge(e.getKey(), e.getValue(), Math::max);
        }
        return merged;
    }

    public long get(String peerId) { return clock.getOrDefault(peerId, 0L); }

    public enum Relation { DOMINATES, DOMINATED_BY, CONCURRENT, EQUAL }

    /**
     * Returns the causal relation of THIS version relative to OTHER.
     * DOMINATES = this happened after other (causally).
     * DOMINATED_BY = this happened before other.
     * CONCURRENT = both changed independently.
     * EQUAL = identical state.
     */
    public Relation relatedTo(CausalVersion other) {
        Set<String> allPeers = new HashSet<>(this.clock.keySet());
        allPeers.addAll(other.clock.keySet());

        boolean thisGreater = false, otherGreater = false;
        for (String p : allPeers) {
            long a = this.clock.getOrDefault(p, 0L);
            long b = other.clock.getOrDefault(p, 0L);
            if (a > b) thisGreater = true;
            if (b > a) otherGreater = true;
        }
        if (thisGreater && !otherGreater) return Relation.DOMINATES;
        if (otherGreater && !thisGreater) return Relation.DOMINATED_BY;
        if (thisGreater) return Relation.CONCURRENT;
        return Relation.EQUAL;
    }

    public boolean isConcurrentWith(CausalVersion other) { return relatedTo(other) == Relation.CONCURRENT; }

    public Map<String, Long> snapshot() { return Collections.unmodifiableMap(new HashMap<>(clock)); }

    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder("{");
        clock.entrySet().stream().sorted(Map.Entry.comparingByKey())
                .forEach(e -> sb.append(e.getKey()).append(":").append(e.getValue()).append(","));
        if (sb.length() > 1) sb.setLength(sb.length() - 1);
        sb.append("}");
        return sb.toString();
    }

    @Override
    public boolean equals(Object o) {
        if (!(o instanceof CausalVersion c)) return false;
        return clock.equals(c.clock);
    }

    @Override public int hashCode() { return clock.hashCode(); }
}