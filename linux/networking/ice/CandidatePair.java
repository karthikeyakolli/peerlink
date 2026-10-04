package org.peerlink.core.net.ice;

import java.util.Objects;

/**
 * An ICE Candidate Pair formed by pairing a local candidate with a remote candidate.
 * Follows RFC 8445 Section 6.1.2.
 */
public final class CandidatePair implements Comparable<CandidatePair> {

    public enum State {
        FROZEN,
        WAITING,
        IN_PROGRESS,
        SUCCEEDED,
        FAILED
    }

    private final IceCandidate localCandidate;
    private final IceCandidate remoteCandidate;
    private final long pairPriority;
    private State state = State.FROZEN;
    private long roundTripTimeMs = -1;
    private int consecutiveSuccesses = 0;
    private int consecutiveFailures = 0;
    private long lastCheckedTime = 0;

    public CandidatePair(IceCandidate localCandidate, IceCandidate remoteCandidate, boolean isControlling) {
        this.localCandidate = Objects.requireNonNull(localCandidate, "localCandidate must not be null");
        this.remoteCandidate = Objects.requireNonNull(remoteCandidate, "remoteCandidate must not be null");
        this.pairPriority = computePairPriority(localCandidate.getPriority(), remoteCandidate.getPriority(), isControlling);
    }

    /**
     * RFC 8445 Section 6.1.2.3:
     * pair_priority = (2^32 * min(G, D)) + (2 * max(G, D)) + (G > D ? 1 : 0)
     */
    public static long computePairPriority(long localPriority, long remotePriority, boolean isControlling) {
        long g = isControlling ? localPriority : remotePriority;
        long d = isControlling ? remotePriority : localPriority;
        long min = Math.min(g, d);
        long max = Math.max(g, d);
        return (min << 32) + (2 * max) + (g > d ? 1 : 0);
    }

    public IceCandidate getLocalCandidate() { return localCandidate; }
    public IceCandidate getRemoteCandidate() { return remoteCandidate; }
    public long getPairPriority() { return pairPriority; }
    public State getState() { return state; }
    public long getRoundTripTimeMs() { return roundTripTimeMs; }
    public int getConsecutiveSuccesses() { return consecutiveSuccesses; }
    public int getConsecutiveFailures() { return consecutiveFailures; }
    public long getLastCheckedTime() { return lastCheckedTime; }

    public boolean isDirect() {
        return localCandidate.isDirect() && remoteCandidate.isDirect();
    }

    public boolean isRelayed() {
        return localCandidate.isRelayed() || remoteCandidate.isRelayed();
    }

    public void setState(State state) {
        this.state = state;
    }

    public void recordCheckSuccess(long rttMs) {
        this.state = State.SUCCEEDED;
        this.roundTripTimeMs = Math.max(0, rttMs);
        this.consecutiveSuccesses++;
        this.consecutiveFailures = 0;
        this.lastCheckedTime = System.currentTimeMillis();
    }

    public void recordCheckFailure() {
        this.state = State.FAILED;
        this.consecutiveFailures++;
        this.consecutiveSuccesses = 0;
        this.lastCheckedTime = System.currentTimeMillis();
    }

    @Override
    public int compareTo(CandidatePair other) {
        // Higher pair priority first
        int cmp = Long.compare(other.pairPriority, this.pairPriority);
        if (cmp != 0) return cmp;
        // If priority is equal, prefer direct over relayed
        if (this.isDirect() && !other.isDirect()) return -1;
        if (!this.isDirect() && other.isDirect()) return 1;
        // Lowest RTT if already measured
        if (this.roundTripTimeMs > 0 && other.roundTripTimeMs > 0) {
            return Long.compare(this.roundTripTimeMs, other.roundTripTimeMs);
        }
        return 0;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof CandidatePair)) return false;
        CandidatePair that = (CandidatePair) o;
        return Objects.equals(localCandidate, that.localCandidate) &&
                Objects.equals(remoteCandidate, that.remoteCandidate);
    }

    @Override
    public int hashCode() {
        return Objects.hash(localCandidate, remoteCandidate);
    }

    @Override
    public String toString() {
        return "Pair[" + localCandidate.getType() + ":" + localCandidate.getIp() + ":" + localCandidate.getPort() +
                " <-> " + remoteCandidate.getType() + ":" + remoteCandidate.getIp() + ":" + remoteCandidate.getPort() +
                ", state=" + state + ", rtt=" + roundTripTimeMs + "ms, prio=" + pairPriority + "]";
    }
}
