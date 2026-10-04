package org.peerlink.core.net.ice;

import java.io.IOException;
import java.net.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Standard ICE Agent managing candidate gathering, candidate pairing,
 * connectivity check state machine, and path selection per RFC 8445.
 */
public class IceAgent {

    public interface IceListener {
        void onCandidateGathered(IceCandidate candidate);
        void onPathSelected(CandidatePair activePair, ConnectionDiagnostics diagnostics);
        void onPathMigrated(CandidatePair oldPair, CandidatePair newPair);
        void onFailed(String reason);
    }

    private final boolean isControlling;
    private final PathSelector pathSelector;
    private final IceListener listener;

    private final List<IceCandidate> localCandidates = new CopyOnWriteArrayList<>();
    private final List<IceCandidate> remoteCandidates = new CopyOnWriteArrayList<>();
    private final List<CandidatePair> candidatePairs = new CopyOnWriteArrayList<>();

    private final StunClient stunClient = new StunClient();
    private final TurnClient turnClient = new TurnClient();

    private final AtomicBoolean isGathering = new AtomicBoolean(false);
    private final AtomicBoolean isClosed = new AtomicBoolean(false);

    private CandidatePair activePair = null;

    public IceAgent(boolean isControlling, PathSelector.Policy policy, IceListener listener) {
        this.isControlling = isControlling;
        this.pathSelector = new PathSelector(policy != null ? policy : PathSelector.Policy.defaultPolicy());
        this.listener = listener;
    }

    public boolean isControlling() { return isControlling; }
    public List<IceCandidate> getLocalCandidates() { return Collections.unmodifiableList(localCandidates); }
    public List<IceCandidate> getRemoteCandidates() { return Collections.unmodifiableList(remoteCandidates); }
    public List<CandidatePair> getCandidatePairs() { return Collections.unmodifiableList(candidatePairs); }
    public CandidatePair getActivePair() { return activePair; }

    public void addLocalCandidate(IceCandidate candidate) {
        if (!localCandidates.contains(candidate)) {
            localCandidates.add(candidate);
            if (listener != null) listener.onCandidateGathered(candidate);
            recomputeCandidatePairs();
        }
    }

    public void addRemoteCandidate(IceCandidate candidate) {
        if (!remoteCandidates.contains(candidate)) {
            remoteCandidates.add(candidate);
            recomputeCandidatePairs();
        }
    }

    /**
     * Gathers local HOST candidates from active local network interfaces.
     */
    public void gatherHostCandidates(int port, TransportProtocol protocol) {
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces.hasMoreElements()) {
                NetworkInterface nif = interfaces.nextElement();
                if (!nif.isUp() || nif.isLoopback()) continue;

                Enumeration<InetAddress> addresses = nif.getInetAddresses();
                while (addresses.hasMoreElements()) {
                    InetAddress addr = addresses.nextElement();
                    if (addr instanceof Inet4Address) {
                        IceCandidate hostCand = IceCandidate.host(addr.getHostAddress(), port, protocol);
                        addLocalCandidate(hostCand);
                    }
                }
            }
        } catch (Exception e) {
            // Fallback to loopback / localhost for tests
            addLocalCandidate(IceCandidate.host("127.0.0.1", port, protocol));
        }
    }

    /**
     * Gathers server-reflexive (SRFLX) candidate via STUN.
     */
    public IceCandidate gatherSrflxCandidate(DatagramSocket socket, InetSocketAddress stunServer, int timeoutMs) throws IOException {
        IceCandidate srflx = stunClient.discoverReflexiveCandidate(socket, stunServer, timeoutMs);
        addLocalCandidate(srflx);
        return srflx;
    }

    /**
     * Gathers relayed (RELAY) candidate via coturn TURN server.
     */
    public IceCandidate gatherRelayCandidate(DatagramSocket socket, CoturnConfig coturnConfig, int timeoutMs) throws IOException {
        IceCandidate relay = turnClient.allocateRelayCandidate(socket, coturnConfig, timeoutMs);
        addLocalCandidate(relay);
        return relay;
    }

    private synchronized void recomputeCandidatePairs() {
        for (IceCandidate local : localCandidates) {
            for (IceCandidate remote : remoteCandidates) {
                if (local.getProtocol() == remote.getProtocol() && local.getComponentId() == remote.getComponentId()) {
                    CandidatePair pair = new CandidatePair(local, remote, isControlling);
                    if (!candidatePairs.contains(pair)) {
                        candidatePairs.add(pair);
                    }
                }
            }
        }
    }

    /**
     * Executes path selection across candidate pairs and notifies listener.
     */
    public synchronized ConnectionDiagnostics evaluateAndSelectPath() {
        ConnectionDiagnostics diagnostics = pathSelector.selectPath(candidatePairs);
        CandidatePair selected = diagnostics.getSelectedPair();

        if (selected != null && !selected.equals(activePair)) {
            CandidatePair old = activePair;
            activePair = selected;
            if (old != null && listener != null) {
                listener.onPathMigrated(old, selected);
            }
            if (listener != null) {
                listener.onPathSelected(selected, diagnostics);
            }
        } else if (selected == null && listener != null) {
            listener.onFailed(diagnostics.getDirectFailureReason());
        }

        return diagnostics;
    }

    /**
     * Triggers simulated or probe-based check completion on a pair for testing/production.
     */
    public synchronized void recordCheckResult(CandidatePair pair, boolean success, long rttMs) {
        if (pair != null) {
            if (success) {
                pair.recordCheckSuccess(rttMs);
            } else {
                pair.recordCheckFailure();
            }
        }
    }

    public void close() {
        isClosed.set(true);
    }
}
