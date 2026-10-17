package org.peerlink.core.transfer;

import org.peerlink.core.security.TrustStore;
import org.peerlink.core.transport.PeerSession;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Path;

/**
 * Receiver-side protocol handler operating on an authenticated PeerSession.
 * Independently parses, authenticates, validates, and handles incoming transfer messages,
 * ensuring untrusted/revoked peers cannot write to local staging, and writes only to receiver-local storage.
 */
public class TransferSessionReceiver {

    private static final Logger log = LoggerFactory.getLogger(TransferSessionReceiver.class);

    private final PeerTransferEngine engine;
    private final Path localDestinationRoot;
    private final TrustStore trustStore;

    public TransferSessionReceiver(PeerTransferEngine engine, Path localDestinationRoot, TrustStore trustStore) {
        this.engine = engine;
        this.localDestinationRoot = localDestinationRoot;
        this.trustStore = trustStore;
    }

    public void handleOffer(PeerSession session, TransferOffer offer) {
        String transferId = offer.getManifest().getTransferId();
        String remotePeerId = session.getRemotePeer().getPeerId().getValue();

        // 1. Session State Invariant
        if (session.getState() != SessionState.SESSION_STATE_ESTABLISHED) {
            log.warn("Rejected offer {}: Session is not established ({})", transferId, session.getState());
            sendResponse(session, TransferResponse.newBuilder()
                    .setTransferId(transferId)
                    .setAccepted(false)
                    .setRejectionReason("Session not established: " + session.getState())
                    .build());
            return;
        }

        // 2. Authorization / Trust Invariant (Discovery != Trust)
        if (trustStore != null) {
            if (trustStore.isRevoked(remotePeerId)) {
                log.warn("Rejected offer {}: Remote peer {} is revoked", transferId, remotePeerId);
                sendResponse(session, TransferResponse.newBuilder()
                        .setTransferId(transferId)
                        .setAccepted(false)
                        .setRejectionReason("Remote peer is revoked: " + remotePeerId)
                        .build());
                return;
            }

            if (!trustStore.isTrusted(remotePeerId)) {
                log.warn("Rejected offer {}: Remote peer {} is untrusted", transferId, remotePeerId);
                sendResponse(session, TransferResponse.newBuilder()
                        .setTransferId(transferId)
                        .setAccepted(false)
                        .setRejectionReason("Remote peer is not trusted. Explicit pairing required.")
                        .build());
                return;
            }
        }

        // 3. Sender Identity Binding Invariant
        if (!offer.getManifest().getSenderPeerId().getValue().equals(remotePeerId)) {
            log.warn("Rejected offer {}: Sender peer in manifest ({}) does not match authenticated session peer ({})",
                    transferId, offer.getManifest().getSenderPeerId().getValue(), remotePeerId);
            sendResponse(session, TransferResponse.newBuilder()
                    .setTransferId(transferId)
                    .setAccepted(false)
                    .setRejectionReason("Manifest sender identity does not match authenticated session peer")
                    .build());
            return;
        }

        // 4. Delegate to receiver engine for manifest preflight and staging allocation
        TransferResponse response = engine.handleIncomingOffer(offer, localDestinationRoot);
        sendResponse(session, response);
    }

    public void handleChunk(PeerSession session, TransferChunk chunk) {
        if (session.getState() != SessionState.SESSION_STATE_ESTABLISHED) {
            sendChunkAck(session, TransferChunkAck.newBuilder()
                    .setTransferId(chunk.getTransferId())
                    .setItemIndex(chunk.getItemIndex())
                    .setChunkIndex(chunk.getChunkIndex())
                    .setSuccess(false)
                    .setErrorMessage("Session not established: " + session.getState())
                    .build());
            return;
        }

        try {
            TransferChunkAck ack = engine.handleIncomingChunk(chunk);
            sendChunkAck(session, ack);
        } catch (IOException e) {
            log.error("Failed to handle incoming chunk for transfer {}: {}", chunk.getTransferId(), e.getMessage(), e);
            sendChunkAck(session, TransferChunkAck.newBuilder()
                    .setTransferId(chunk.getTransferId())
                    .setItemIndex(chunk.getItemIndex())
                    .setChunkIndex(chunk.getChunkIndex())
                    .setSuccess(false)
                    .setErrorMessage("IO error writing chunk: " + e.getMessage())
                    .build());
        }
    }

    public void handleCommit(PeerSession session, TransferCommitSignal commit) {
        String transferId = commit.getTransferId();
        TransferManifest manifest = engine.getActiveManifest(transferId);

        if (manifest == null) {
            log.error("Commit signal received for unknown or un staged transfer: {}", transferId);
            sendReceipt(session, TransferCompletedReceipt.newBuilder()
                    .setTransferId(transferId)
                    .setSuccess(false)
                    .setErrorMessage("Transfer not found or staging expired")
                    .build());
            return;
        }

        try {
            // Independent receiver-side verification before commit
            TransferVerifyResult verify = engine.verifyReceivedTransfer(transferId, manifest);
            if (!verify.getVerified()) {
                log.error("Transfer {} verification failed on receiver: item={}, expected={}, computed={}",
                        transferId, verify.getItemIndex(), verify.getExpectedSha256(), verify.getComputedSha256());
                sendReceipt(session, TransferCompletedReceipt.newBuilder()
                        .setTransferId(transferId)
                        .setOperationId(manifest.getOperationId())
                        .setSuccess(false)
                        .setErrorMessage("Integrity verification failed for item " + verify.getItemIndex())
                        .build());
                return;
            }

            // Commit verified files to receiver-local destination
            TransferCompletedReceipt receipt = engine.commitReceivedTransfer(transferId, manifest, localDestinationRoot);
            sendReceipt(session, receipt);
        } catch (Exception e) {
            log.error("Failed to commit transfer {} on receiver: {}", transferId, e.getMessage(), e);
            sendReceipt(session, TransferCompletedReceipt.newBuilder()
                    .setTransferId(transferId)
                    .setOperationId(manifest.getOperationId())
                    .setSuccess(false)
                    .setErrorMessage("Commit failure: " + e.getMessage())
                    .build());
        }
    }

    public void handleCancel(PeerSession session, TransferCancelRequest cancel) {
        engine.cancelTransfer(cancel.getTransferId(), cancel.getReason());
    }

    private void sendResponse(PeerSession session, TransferResponse response) {
        TransferWireMessage wireMsg = TransferWireMessage.newBuilder().setResponse(response).build();
        session.sendPayloadAsync(wireMsg.toByteArray());
    }

    private void sendChunkAck(PeerSession session, TransferChunkAck ack) {
        TransferWireMessage wireMsg = TransferWireMessage.newBuilder().setAck(ack).build();
        session.sendPayloadAsync(wireMsg.toByteArray());
    }

    private void sendReceipt(PeerSession session, TransferCompletedReceipt receipt) {
        TransferWireMessage wireMsg = TransferWireMessage.newBuilder().setReceipt(receipt).build();
        session.sendPayloadAsync(wireMsg.toByteArray());
    }
}
