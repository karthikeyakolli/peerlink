package org.peerlink.core.transfer;

import org.peerlink.core.security.TrustStore;
import org.peerlink.core.transport.PeerSession;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Path;

/**
 * Receiver-side protocol handler operating on an authenticated PeerSession.
 * Independently parses, authenticates, validates, and handles incoming transfer messages,
 * ensuring untrusted/revoked peers cannot write to local staging, and writes only to receiver-local storage.
 */
public class TransferSessionReceiver {

    private static final Logger log = LoggerFactory.getLogger(TransferSessionReceiver.class);

    public enum ReceiverConsentMode {
        AUTO_ACCEPT_PAIRED_TRUSTED,
        MANUAL_PROMPT_ALL,
        REJECT_ALL
    }

    public interface ReceiverTransferEventListener {
        void onIncomingOffer(PeerSession session, TransferOffer offer);
        void onTransferProgress(String transferId, String fileName, int percent, long transferredBytes, long totalBytes);
        void onTransferCompleted(String transferId, String fileName, boolean success, String errorMessage);
    }

    private final PeerTransferEngine engine;
    private final Path localDestinationRoot;
    private final TrustStore trustStore;
    private volatile ReceiverConsentMode consentMode = ReceiverConsentMode.AUTO_ACCEPT_PAIRED_TRUSTED;
    private final java.util.List<ReceiverTransferEventListener> listeners = new java.util.concurrent.CopyOnWriteArrayList<>();
    private final java.util.concurrent.ConcurrentMap<String, java.util.concurrent.CompletableFuture<Boolean>> pendingConsent = new java.util.concurrent.ConcurrentHashMap<>();
    private final java.util.concurrent.ConcurrentMap<String, java.util.concurrent.atomic.AtomicLong> bytesTransferredMap = new java.util.concurrent.ConcurrentHashMap<>();

    public TransferSessionReceiver(PeerTransferEngine engine, Path localDestinationRoot, TrustStore trustStore) {
        this(engine, localDestinationRoot, trustStore, ReceiverConsentMode.AUTO_ACCEPT_PAIRED_TRUSTED);
    }

    public TransferSessionReceiver(PeerTransferEngine engine, Path localDestinationRoot, TrustStore trustStore, ReceiverConsentMode consentMode) {
        this.engine = engine;
        this.localDestinationRoot = localDestinationRoot;
        this.trustStore = trustStore;
        this.consentMode = consentMode != null ? consentMode : ReceiverConsentMode.AUTO_ACCEPT_PAIRED_TRUSTED;
    }

    public void addListener(ReceiverTransferEventListener listener) {
        if (listener != null) {
            listeners.add(listener);
        }
    }

    public void removeListener(ReceiverTransferEventListener listener) {
        if (listener != null) {
            listeners.remove(listener);
        }
    }

    public void setConsentMode(ReceiverConsentMode mode) {
        this.consentMode = mode != null ? mode : ReceiverConsentMode.AUTO_ACCEPT_PAIRED_TRUSTED;
    }

    public ReceiverConsentMode getConsentMode() {
        return consentMode;
    }

    public boolean respondConsent(String transferId, boolean accept) {
        java.util.concurrent.CompletableFuture<Boolean> f = pendingConsent.remove(transferId);
        if (f != null) {
            f.complete(accept);
            return true;
        }
        return false;
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

        // 4. Enforce Receiver Consent Policy
        if (consentMode == ReceiverConsentMode.REJECT_ALL) {
            log.warn("Rejected offer {}: ReceiverConsentMode is REJECT_ALL", transferId);
            sendResponse(session, TransferResponse.newBuilder()
                    .setTransferId(transferId)
                    .setAccepted(false)
                    .setRejectionReason("Receiver does not accept transfers")
                    .build());
            return;
        }

        if (consentMode == ReceiverConsentMode.MANUAL_PROMPT_ALL) {
            java.util.concurrent.CompletableFuture<Boolean> consentFuture = new java.util.concurrent.CompletableFuture<>();
            pendingConsent.put(transferId, consentFuture);
            for (ReceiverTransferEventListener l : listeners) {
                try {
                    l.onIncomingOffer(session, offer);
                } catch (Exception ignored) {}
            }
            boolean accepted = false;
            try {
                accepted = consentFuture.get(30, java.util.concurrent.TimeUnit.SECONDS);
            } catch (Exception e) {
                log.warn("Transfer consent decision timed out or was interrupted for {}: {}", transferId, e.getMessage());
                accepted = false;
            } finally {
                pendingConsent.remove(transferId);
            }

            if (!accepted) {
                log.warn("Rejected offer {}: User declined consent or prompt timed out", transferId);
                sendResponse(session, TransferResponse.newBuilder()
                        .setTransferId(transferId)
                        .setAccepted(false)
                        .setRejectionReason("Transfer offer rejected by receiver user")
                        .build());
                return;
            }
        } else {
            // AUTO_ACCEPT_PAIRED_TRUSTED
            for (ReceiverTransferEventListener l : listeners) {
                try {
                    l.onIncomingOffer(session, offer);
                } catch (Exception ignored) {}
            }
        }

        // 5. Delegate to receiver engine for manifest preflight and staging allocation
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

        TransferChunkAck ack;
        try {
            ack = engine.handleIncomingChunk(chunk);
            if (ack.getSuccess()) {
                java.util.concurrent.atomic.AtomicLong counter = bytesTransferredMap.computeIfAbsent(
                        chunk.getTransferId(), k -> new java.util.concurrent.atomic.AtomicLong(0));
                long transferred = counter.addAndGet(chunk.getData().size());
                TransferManifest m = engine.getActiveManifest(chunk.getTransferId());
                long total = (m != null && m.getTotalBytes() > 0) ? m.getTotalBytes() : transferred;
                int percent = (int) Math.min(100, Math.max(0, (transferred * 100) / total));
                String fileName = (m != null && m.getItemsCount() > chunk.getItemIndex())
                        ? m.getItems(chunk.getItemIndex()).getRelativePath() : "file";
                for (ReceiverTransferEventListener l : listeners) {
                    try {
                        l.onTransferProgress(chunk.getTransferId(), fileName, percent, transferred, total);
                    } catch (Exception ignored) {}
                }
            }
        } catch (java.io.IOException e) {
            log.error("IOException handling chunk for transfer [{}]: {}", chunk.getTransferId(), e.getMessage());
            ack = TransferChunkAck.newBuilder()
                    .setTransferId(chunk.getTransferId())
                    .setItemIndex(chunk.getItemIndex())
                    .setChunkIndex(chunk.getChunkIndex())
                    .setSuccess(false)
                    .setErrorMessage("I/O error processing chunk: " + e.getMessage())
                    .build();
        }
        sendChunkAck(session, ack);
    }

    public void handleCommit(PeerSession session, TransferCommitSignal commit) {
        String transferId = commit.getTransferId();
        TransferManifest manifest = engine.getActiveManifest(transferId);
        bytesTransferredMap.remove(transferId);
        String fileName = (manifest != null && manifest.getItemsCount() > 0)
                ? manifest.getItems(0).getRelativePath() : "file";

        if (manifest == null) {
            log.error("Commit signal received for unknown or un staged transfer: {}", transferId);
            TransferCompletedReceipt receipt = TransferCompletedReceipt.newBuilder()
                    .setTransferId(transferId)
                    .setSuccess(false)
                    .setErrorMessage("Transfer not found or staging expired")
                    .build();
            sendReceipt(session, receipt);
            for (ReceiverTransferEventListener l : listeners) {
                try {
                    l.onTransferCompleted(transferId, fileName, false, receipt.getErrorMessage());
                } catch (Exception ignored) {}
            }
            return;
        }

        try {
            // Independent receiver-side verification before commit
            TransferVerifyResult verify = engine.verifyReceivedTransfer(transferId, manifest);
            if (!verify.getVerified()) {
                log.error("Transfer {} verification failed on receiver: item={}, expected={}, computed={}",
                        transferId, verify.getItemIndex(), verify.getExpectedSha256(), verify.getComputedSha256());
                TransferCompletedReceipt receipt = TransferCompletedReceipt.newBuilder()
                        .setTransferId(transferId)
                        .setOperationId(manifest.getOperationId())
                        .setSuccess(false)
                        .setErrorMessage("Integrity verification failed for item " + verify.getItemIndex())
                        .build();
                sendReceipt(session, receipt);
                for (ReceiverTransferEventListener l : listeners) {
                    try {
                        l.onTransferCompleted(transferId, fileName, false, receipt.getErrorMessage());
                    } catch (Exception ignored) {}
                }
                return;
            }

            // Commit verified files to receiver-local destination
            TransferCompletedReceipt receipt = engine.commitReceivedTransfer(transferId, manifest, localDestinationRoot);
            sendReceipt(session, receipt);
            for (ReceiverTransferEventListener l : listeners) {
                try {
                    l.onTransferCompleted(transferId, fileName, receipt.getSuccess(), receipt.getErrorMessage());
                } catch (Exception ignored) {}
            }
        } catch (Exception e) {
            log.error("Failed to commit transfer {} on receiver: {}", transferId, e.getMessage(), e);
            TransferCompletedReceipt receipt = TransferCompletedReceipt.newBuilder()
                    .setTransferId(transferId)
                    .setOperationId(manifest.getOperationId())
                    .setSuccess(false)
                    .setErrorMessage("Commit failure: " + e.getMessage())
                    .build();
            sendReceipt(session, receipt);
            for (ReceiverTransferEventListener l : listeners) {
                try {
                    l.onTransferCompleted(transferId, fileName, false, receipt.getErrorMessage());
                } catch (Exception ignored) {}
            }
        }
    }

    public void handleCancel(PeerSession session, TransferCancelRequest cancel) {
        engine.cancelTransfer(cancel.getTransferId(), cancel.getReason());
    }

    public void handleResumeOffer(PeerSession session, TransferResumeOffer resumeOffer) {
        String transferId = resumeOffer.getTransferId();
        String remotePeerId = session.getRemotePeer().getPeerId().getValue();

        if (session.getState() != SessionState.SESSION_STATE_ESTABLISHED) {
            log.warn("Rejected resume offer {}: Session is not established ({})", transferId, session.getState());
            sendResumeState(session, TransferResumeState.newBuilder()
                    .setTransferId(transferId)
                    .setCanResume(false)
                    .setMessage("Session not established: " + session.getState())
                    .build());
            return;
        }

        if (trustStore != null) {
            if (trustStore.isRevoked(remotePeerId)) {
                log.warn("Rejected resume offer {}: Remote peer {} is revoked", transferId, remotePeerId);
                sendResumeState(session, TransferResumeState.newBuilder()
                        .setTransferId(transferId)
                        .setCanResume(false)
                        .setMessage("Remote peer is revoked: " + remotePeerId)
                        .build());
                return;
            }
            if (!trustStore.isTrusted(remotePeerId)) {
                log.warn("Rejected resume offer {}: Remote peer {} is untrusted", transferId, remotePeerId);
                sendResumeState(session, TransferResumeState.newBuilder()
                        .setTransferId(transferId)
                        .setCanResume(false)
                        .setMessage("Remote peer is untrusted")
                        .build());
                return;
            }
        }

        if (consentMode == ReceiverConsentMode.REJECT_ALL) {
            sendResumeState(session, TransferResumeState.newBuilder()
                    .setTransferId(transferId)
                    .setCanResume(false)
                    .setMessage("Receiver does not accept transfers")
                    .build());
            return;
        }

        TransferResumeState state = engine.handleResumeOffer(resumeOffer, localDestinationRoot);
        sendResumeState(session, state);
    }

    public void handlePause(PeerSession session, TransferPauseRequest pause) {
        engine.pauseTransfer(pause.getTransferId(), pause.getReason());
        TransferPauseResponse resp = TransferPauseResponse.newBuilder()
                .setTransferId(pause.getTransferId())
                .setAcknowledged(true)
                .build();
        TransferWireMessage wire = TransferWireMessage.newBuilder().setPauseResponse(resp).build();
        session.sendPayloadAsync(wire.toByteArray());
    }

    private void sendResumeState(PeerSession session, TransferResumeState state) {
        TransferWireMessage wireMsg = TransferWireMessage.newBuilder().setResumeState(state).build();
        session.sendPayloadAsync(wireMsg.toByteArray());
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
