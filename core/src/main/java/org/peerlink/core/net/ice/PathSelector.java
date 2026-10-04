package org.peerlink.core.net.ice;

import java.util.*;

/**
 * Intelligent Path Selector with:
 * - Direct-path prioritization
 * - Relay fallback
 * - Direct-only policy enforcement
 * - Hysteresis algorithm to eliminate direct/relay path flapping
 * - Dynamic path migration
 */
public class PathSelector {

    public static final class Policy {
        private final boolean directOnly;
        private final boolean preferQuic;
        private final int hysteresisMinSuccessiveProbes;
        private final double hysteresisImprovementMargin; // e.g. 0.20 for 20% better RTT
        private final int failureToleranceThreshold;

        public Policy(boolean directOnly, boolean preferQuic,
                      int hysteresisMinSuccessiveProbes, double hysteresisImprovementMargin,
                      int failureToleranceThreshold) {
            this.directOnly = directOnly;
            this.preferQuic = preferQuic;
            this.hysteresisMinSuccessiveProbes = Math.max(1, hysteresisMinSuccessiveProbes);
            this.hysteresisImprovementMargin = Math.max(0.0, hysteresisImprovementMargin);
            this.failureToleranceThreshold = Math.max(1, failureToleranceThreshold);
        }

        public static Policy defaultPolicy() {
            return new Policy(false, true, 3, 0.20, 3);
        }

        public static Policy directOnly() {
            return new Policy(true, true, 3, 0.20, 3);
        }

        public boolean isDirectOnly() { return directOnly; }
        public boolean isPreferQuic() { return preferQuic; }
        public int getHysteresisMinSuccessiveProbes() { return hysteresisMinSuccessiveProbes; }
        public double getHysteresisImprovementMargin() { return hysteresisImprovementMargin; }
        public int getFailureToleranceThreshold() { return failureToleranceThreshold; }
    }

    private final Policy policy;
    private CandidatePair activePair = null;
    private final List<String> diagnosticEvents = new ArrayList<>();

    public PathSelector() {
        this(Policy.defaultPolicy());
    }

    public PathSelector(Policy policy) {
        this.policy = Objects.requireNonNull(policy, "policy must not be null");
    }

    public Policy getPolicy() {
        return policy;
    }

    public CandidatePair getActivePair() {
        return activePair;
    }

    public synchronized ConnectionDiagnostics selectPath(List<CandidatePair> candidatePairs) {
        if (candidatePairs == null || candidatePairs.isEmpty()) {
            return new ConnectionDiagnostics(
                    ConnectionDiagnostics.Outcome.ALL_FAILED,
                    null,
                    "No candidate pairs available",
                    null,
                    ConnectionQuality.unknown(),
                    diagnosticEvents
            );
        }

        // Sort pairs by RFC 8445 priority (direct highest, lowest RTT)
        List<CandidatePair> sorted = new ArrayList<>(candidatePairs);
        Collections.sort(sorted);

        // 1. Check for working direct paths (HOST, SRFLX, PRFLX)
        CandidatePair bestDirect = null;
        for (CandidatePair pair : sorted) {
            if (pair.isDirect() && pair.getState() == CandidatePair.State.SUCCEEDED) {
                if (bestDirect == null || pair.getRoundTripTimeMs() < bestDirect.getRoundTripTimeMs()) {
                    bestDirect = pair;
                }
            }
        }

        if (bestDirect != null) {
            boolean shouldSwitch = evaluateHysteresis(bestDirect);
            if (shouldSwitch) {
                this.activePair = bestDirect;
                diagnosticEvents.add("Selected direct path: " + bestDirect);
                ConnectionQuality quality = new ConnectionQuality(
                        bestDirect.getRoundTripTimeMs(),
                        0.0,
                        2,
                        50_000_000
                );
                return new ConnectionDiagnostics(
                        ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED,
                        bestDirect,
                        null,
                        null,
                        quality,
                        diagnosticEvents
                );
            } else if (activePair != null) {
                // Keep active pair due to hysteresis
                return new ConnectionDiagnostics(
                        activePair.isDirect() ? ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED : ConnectionDiagnostics.Outcome.RELAY_USED,
                        activePair,
                        null,
                        "Hysteresis suppressed switch to prevent flapping",
                        new ConnectionQuality(activePair.getRoundTripTimeMs(), 0.0, 2, 20_000_000),
                        diagnosticEvents
                );
            }
        }

        // 2. Direct paths failed or not ready
        String directFailure = bestDirect == null ?
                "All direct host and STUN reflexive candidate pairs failed connectivity checks or timed out" : null;

        // Check Direct-Only Policy
        if (policy.isDirectOnly()) {
            diagnosticEvents.add("Direct-only policy is active: Relay paths rejected");
            return new ConnectionDiagnostics(
                    ConnectionDiagnostics.Outcome.DIRECT_FAILED,
                    null,
                    directFailure != null ? directFailure : "Direct connection required but failed",
                    "Direct-only policy prohibited relay fallback",
                    ConnectionQuality.unknown(),
                    diagnosticEvents
            );
        }

        // 3. Fallback to working relay path (RELAY / coturn)
        CandidatePair bestRelay = null;
        for (CandidatePair pair : sorted) {
            if (pair.isRelayed() && pair.getState() == CandidatePair.State.SUCCEEDED) {
                if (bestRelay == null || pair.getRoundTripTimeMs() < bestRelay.getRoundTripTimeMs()) {
                    bestRelay = pair;
                }
            }
        }

        if (bestRelay != null) {
            this.activePair = bestRelay;
            diagnosticEvents.add("Falling back to relayed path: " + bestRelay);
            String whyRelay = directFailure != null ? directFailure : "Direct probes dropped by firewall/symmetric NAT";
            ConnectionQuality quality = new ConnectionQuality(
                    bestRelay.getRoundTripTimeMs(),
                    0.02,
                    15,
                    10_000_000
            );
            return new ConnectionDiagnostics(
                    ConnectionDiagnostics.Outcome.RELAY_USED,
                    bestRelay,
                    directFailure,
                    whyRelay,
                    quality,
                    diagnosticEvents
            );
        }

        // 4. All failed
        diagnosticEvents.add("All direct and relay candidate pairs failed");
        return new ConnectionDiagnostics(
                ConnectionDiagnostics.Outcome.ALL_FAILED,
                null,
                "Both direct (LAN/STUN) and relayed (TURN) candidate pairs exhausted without success",
                "Relay allocation or peer permission failed",
                ConnectionQuality.unknown(),
                diagnosticEvents
        );
    }

    /**
     * Hysteresis algorithm:
     * Prevents rapid back-and-forth flapping between direct and relay paths.
     */
    private boolean evaluateHysteresis(CandidatePair candidate) {
        if (activePair == null) {
            return true; // No current path, select immediately
        }

        if (activePair.equals(candidate)) {
            return true; // Already active
        }

        // If currently on RELAY and new candidate is DIRECT:
        // Require at least `hysteresisMinSuccessiveProbes` successful checks
        if (activePair.isRelayed() && candidate.isDirect()) {
            if (candidate.getConsecutiveSuccesses() < policy.getHysteresisMinSuccessiveProbes()) {
                diagnosticEvents.add("Hysteresis: direct path probationary (" +
                        candidate.getConsecutiveSuccesses() + "/" + policy.getHysteresisMinSuccessiveProbes() + " probes)");
                return false;
            }
            diagnosticEvents.add("Hysteresis: direct path verified stable after " +
                    candidate.getConsecutiveSuccesses() + " probes. Migrating from relay to direct!");
            return true;
        }

        // If both are direct, only migrate if candidate offers significant RTT improvement margin
        if (activePair.isDirect() && candidate.isDirect()) {
            long currentRtt = activePair.getRoundTripTimeMs();
            long newRtt = candidate.getRoundTripTimeMs();
            if (currentRtt > 0 && newRtt > 0) {
                double improvement = (double) (currentRtt - newRtt) / currentRtt;
                if (improvement < policy.getHysteresisImprovementMargin()) {
                    return false; // Insufficient improvement to justify path migration
                }
            }
            return true;
        }

        // If currently on DIRECT and considering RELAY:
        // Only degrade to relay if active direct path has experienced >= `failureToleranceThreshold` consecutive failures
        if (activePair.isDirect() && candidate.isRelayed()) {
            if (activePair.getConsecutiveFailures() < policy.getFailureToleranceThreshold()) {
                diagnosticEvents.add("Hysteresis: tolerating transient direct failure (" +
                        activePair.getConsecutiveFailures() + "/" + policy.getFailureToleranceThreshold() + ")");
                return false;
            }
            return true;
        }

        return true;
    }

    public synchronized void migratePath(CandidatePair newPair) {
        Objects.requireNonNull(newPair, "newPair must not be null");
        diagnosticEvents.add("Migrating active path from " + activePair + " to " + newPair);
        this.activePair = newPair;
    }
}
