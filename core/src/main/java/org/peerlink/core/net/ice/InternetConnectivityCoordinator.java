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

    private volatile String targetPeerId;

    public void setTargetPeerId(String peerId) {
        this.targetPeerId = peerId;
    }

    public String getTargetPeerId() {
        return targetPeerId;
    }

    public void handleIncomingSignalingCandidate(String senderPeerId, Map<String, Object> candidateMap) {
        try {
            IceCandidate candidate = IceCandidate.fromMap(candidateMap);
            iceAgent.addRemoteCandidate(candidate);
        } catch (Exception ignored) {}
    }

    public void handleIncomingSignalingMessage(SignalingMessage msg) {
        if (msg == null) return;
        if (msg.getMessageType() == SignalingMessage.Type.ICE_CANDIDATE) {
            handleIncomingSignalingCandidate(msg.getSenderPeerId(), msg.getPayload());
        }
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

    public TurnRelayedTransportConnection createRelayedTransportConnection(CandidatePair pair,
                                                                            java.nio.channels.SocketChannel socketChannel,
                                                                            java.util.function.Consumer<byte[]> dataSender) {
        Objects.requireNonNull(pair, "pair must not be null");
        if (!pair.isRelayed()) {
            throw new IllegalArgumentException("Cannot create relayed connection for non-relayed pair: " + pair);
        }
        IceCandidate relayCand = pair.getLocalCandidate().isRelayed() ? pair.getLocalCandidate() : pair.getRemoteCandidate();
        InetSocketAddress relayAddr = new InetSocketAddress(relayCand.getIp(), relayCand.getPort());
        InetSocketAddress localAddr = new InetSocketAddress(pair.getLocalCandidate().getIp(), pair.getLocalCandidate().getPort());
        InetSocketAddress remoteAddr = new InetSocketAddress(pair.getRemoteCandidate().getIp(), pair.getRemoteCandidate().getPort());

        org.peerlink.protocol.v1.ConnectionId connId = org.peerlink.protocol.v1.ConnectionId.newBuilder()
                .setValue("conn_turn_" + UUID.randomUUID().toString().replace("-", ""))
                .build();

        return new TurnRelayedTransportConnection(
                connId,
                localAddr,
                remoteAddr,
                relayAddr,
                relayCand.getProtocol(),
                TurnRelayedTransportConnection.DEFAULT_CHANNEL_NUMBER,
                socketChannel,
                dataSender
        );
    }

    private void publishCandidateThroughSignaling(IceCandidate candidate) {
        if (supabaseCoordinator != null && supabaseCoordinator.isRunning() && targetPeerId != null) {
            try {
                Map<String, Object> payload = candidate.toMap();
                supabaseCoordinator.sendSignaling(targetPeerId, SignalingMessage.Type.ICE_CANDIDATE, payload);
            } catch (Exception ignored) {}
        }
    }
}
