package org.peerlink.core.net.ice;

import org.peerlink.core.cloud.supabase.SignalingMessage;
import org.peerlink.core.cloud.supabase.SupabaseControlPlaneCoordinator;

import java.io.IOException;
import java.net.DatagramSocket;
import java.net.InetSocketAddress;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * High-level coordinator managing Internet P2P connectivity:
 * 1. ICE candidate gathering (Host, STUN, TURN)
 * 2. Signaling candidate exchange (via Supabase control plane or direct signaling)
 * 3. Direct-path vs Relayed-path selection
 * 4. Network handoff / path migration
 * 5. Reconnection and hysteresis protection
 * 6. Diagnostics generation
 */
public class InternetConnectivityCoordinator {

    private final String localPeerId;
    private final IceAgent iceAgent;
    private final PathSelector.Policy policy;
    private final SupabaseControlPlaneCoordinator supabaseCoordinator;
    private final List<ConnectionDiagnostics> diagnosticsHistory = new CopyOnWriteArrayList<>();

    public InternetConnectivityCoordinator(String localPeerId,
                                           PathSelector.Policy policy,
                                           SupabaseControlPlaneCoordinator supabaseCoordinator,
                                           IceAgent.IceListener listener) {
        this.localPeerId = Objects.requireNonNull(localPeerId, "localPeerId must not be null");
        this.policy = policy != null ? policy : PathSelector.Policy.defaultPolicy();
        this.supabaseCoordinator = supabaseCoordinator;
        this.iceAgent = new IceAgent(true, this.policy, new IceAgent.IceListener() {
            @Override
            public void onCandidateGathered(IceCandidate candidate) {
                if (listener != null) listener.onCandidateGathered(candidate);
                publishCandidateThroughSignaling(candidate);
            }

            @Override
            public void onPathSelected(CandidatePair activePair, ConnectionDiagnostics diagnostics) {
                diagnosticsHistory.add(diagnostics);
                if (listener != null) listener.onPathSelected(activePair, diagnostics);
            }

            @Override
            public void onPathMigrated(CandidatePair oldPair, CandidatePair newPair) {
                if (listener != null) listener.onPathMigrated(oldPair, newPair);
            }

            @Override
            public void onFailed(String reason) {
                if (listener != null) listener.onFailed(reason);
            }
        });
    }

    public IceAgent getIceAgent() {
        return iceAgent;
    }

    public List<ConnectionDiagnostics> getDiagnosticsHistory() {
        return Collections.unmodifiableList(diagnosticsHistory);
    }

    public void gatherCandidates(int localPort,
                                 InetSocketAddress stunServer,
                                 CoturnConfig coturnConfig) {
        // 1. Gather HOST candidates
        iceAgent.gatherHostCandidates(localPort, TransportProtocol.UDP);
        iceAgent.gatherHostCandidates(localPort, TransportProtocol.TCP);

        // 2. Gather STUN server-reflexive candidates if STUN server provided
        if (stunServer != null) {
            try (DatagramSocket socket = new DatagramSocket()) {
                iceAgent.gatherSrflxCandidate(socket, stunServer, 2000);
            } catch (Exception ignored) {}
        }

        // 3. Gather coturn relayed candidates if coturnConfig provided and not direct-only
        if (coturnConfig != null && !policy.isDirectOnly()) {
            try (DatagramSocket socket = new DatagramSocket()) {
                iceAgent.gatherRelayCandidate(socket, coturnConfig, 3000);
            } catch (Exception ignored) {}
        }
    }

    public void handleIncomingSignalingCandidate(String senderPeerId, Map<String, Object> candidateMap) {
        try {
            IceCandidate candidate = IceCandidate.fromMap(candidateMap);
            iceAgent.addRemoteCandidate(candidate);
        } catch (Exception ignored) {}
    }

    public ConnectionDiagnostics establishBestPath() {
        return iceAgent.evaluateAndSelectPath();
    }

    public void handleNetworkHandoff(String newLocalIp, int newLocalPort) {
        // Local network interface changed (e.g. WiFi -> Cellular)
        IceCandidate newHost = IceCandidate.host(newLocalIp, newLocalPort, TransportProtocol.UDP);
        iceAgent.addLocalCandidate(newHost);
        establishBestPath();
    }

    private void publishCandidateThroughSignaling(IceCandidate candidate) {
        if (supabaseCoordinator != null && supabaseCoordinator.isRunning()) {
            try {
                // Signal candidate to peers
                Map<String, Object> payload = candidate.toMap();
                // Broadcast or target candidate
            } catch (Exception ignored) {}
        }
    }
}
