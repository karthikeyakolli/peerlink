package org.peerlink.core.transfer;

import org.peerlink.core.transport.PeerSession;
import org.peerlink.core.transport.SessionPayloadHandler;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Multiplexes bidirectional TransferWireMessage payloads over an authenticated PeerSession.
 * Routes asynchronous responses (offers, chunk acks, receipts) back to waiting sender futures,
 * and routes inbound requests (offers, chunks, commit signals) to the registered receiver handler.
 */
public class TransferSessionCoordinator implements SessionPayloadHandler {

    private static final Logger log = LoggerFactory.getLogger(TransferSessionCoordinator.class);

    private final PeerSession session;
    private final Map<String, CompletableFuture<TransferResponse>> pendingOffers = new ConcurrentHashMap<>();
    private final Map<String, CompletableFuture<TransferChunkAck>> pendingChunkAcks = new ConcurrentHashMap<>();
    private final Map<String, CompletableFuture<TransferCompletedReceipt>> pendingReceipts = new ConcurrentHashMap<>();
    private final Map<String, CompletableFuture<TransferResumeState>> pendingResumeStates = new ConcurrentHashMap<>();
    private final Map<String, CompletableFuture<TransferPauseResponse>> pendingPauseResponses = new ConcurrentHashMap<>();
    private volatile TransferSessionReceiver receiver;

    public TransferSessionCoordinator(PeerSession session) {
        this.session = session;
        this.session.setPayloadHandler(this);
    }

    public void registerReceiver(TransferSessionReceiver receiver) {
        this.receiver = receiver;
    }

    public CompletableFuture<TransferResponse> registerPendingOffer(String transferId) {
        CompletableFuture<TransferResponse> future = new CompletableFuture<>();
        pendingOffers.put(transferId, future);
        return future;
    }

    public CompletableFuture<TransferChunkAck> registerPendingChunkAck(String transferId, int itemIndex, long chunkIndex) {
        CompletableFuture<TransferChunkAck> future = new CompletableFuture<>();
        String key = chunkAckKey(transferId, itemIndex, chunkIndex);
        pendingChunkAcks.put(key, future);
        return future;
    }

    public CompletableFuture<TransferCompletedReceipt> registerPendingReceipt(String transferId) {
        CompletableFuture<TransferCompletedReceipt> future = new CompletableFuture<>();
        pendingReceipts.put(transferId, future);
        return future;
    }

    public CompletableFuture<TransferResumeState> registerPendingResumeState(String transferId) {
        CompletableFuture<TransferResumeState> future = new CompletableFuture<>();
        pendingResumeStates.put(transferId, future);
        return future;
    }

    public CompletableFuture<TransferPauseResponse> registerPendingPauseResponse(String transferId) {
        CompletableFuture<TransferPauseResponse> future = new CompletableFuture<>();
        pendingPauseResponses.put(transferId, future);
        return future;
    }

    public void failPendingRequests(Throwable throwable) {
        for (CompletableFuture<TransferResponse> f : pendingOffers.values()) {
            f.completeExceptionally(throwable);
        }
        pendingOffers.clear();

        for (CompletableFuture<TransferChunkAck> f : pendingChunkAcks.values()) {
            f.completeExceptionally(throwable);
        }
        pendingChunkAcks.clear();

        for (CompletableFuture<TransferCompletedReceipt> f : pendingReceipts.values()) {
            f.completeExceptionally(throwable);
        }
        pendingReceipts.clear();

        for (CompletableFuture<TransferResumeState> f : pendingResumeStates.values()) {
            f.completeExceptionally(throwable);
        }
        pendingResumeStates.clear();

        for (CompletableFuture<TransferPauseResponse> f : pendingPauseResponses.values()) {
            f.completeExceptionally(throwable);
        }
        pendingPauseResponses.clear();
    }

    @Override
    public void handlePayload(PeerSession s, byte[] payload) {
        try {
            TransferWireMessage wireMsg = TransferWireMessage.parseFrom(payload);
            switch (wireMsg.getPayloadCase()) {
                case RESPONSE -> {
                    TransferResponse resp = wireMsg.getResponse();
                    CompletableFuture<TransferResponse> f = pendingOffers.remove(resp.getTransferId());
                    if (f != null) {
                        f.complete(resp);
                    } else {
                        log.debug("Unmatched TransferResponse received: {}", resp.getTransferId());
                    }
                }
                case ACK -> {
                    TransferChunkAck ack = wireMsg.getAck();
                    String key = chunkAckKey(ack.getTransferId(), ack.getItemIndex(), ack.getChunkIndex());
                    CompletableFuture<TransferChunkAck> f = pendingChunkAcks.remove(key);
                    if (f != null) {
                        f.complete(ack);
                    } else {
                        log.debug("Unmatched TransferChunkAck received: {}", key);
                    }
                }
                case RECEIPT -> {
                    TransferCompletedReceipt receipt = wireMsg.getReceipt();
                    CompletableFuture<TransferCompletedReceipt> f = pendingReceipts.remove(receipt.getTransferId());
                    if (f != null) {
                        f.complete(receipt);
                    } else {
                        log.debug("Unmatched TransferCompletedReceipt received: {}", receipt.getTransferId());
                    }
                }
                case RESUME_STATE -> {
                    TransferResumeState resumeState = wireMsg.getResumeState();
                    CompletableFuture<TransferResumeState> f = pendingResumeStates.remove(resumeState.getTransferId());
                    if (f != null) {
                        f.complete(resumeState);
                    } else {
                        log.debug("Unmatched TransferResumeState received: {}", resumeState.getTransferId());
                    }
                }
                case PAUSE_RESPONSE -> {
                    TransferPauseResponse pr = wireMsg.getPauseResponse();
                    CompletableFuture<TransferPauseResponse> f = pendingPauseResponses.remove(pr.getTransferId());
                    if (f != null) {
                        f.complete(pr);
                    } else {
                        log.debug("Unmatched TransferPauseResponse received: {}", pr.getTransferId());
                    }
                }
                case OFFER -> {
                    if (receiver != null) {
                        receiver.handleOffer(session, wireMsg.getOffer());
                    } else {
                        log.warn("TransferOffer received on session {} but no receiver registered", session.getSessionId().getValue());
                    }
                }
                case CHUNK -> {
                    if (receiver != null) {
                        receiver.handleChunk(session, wireMsg.getChunk());
                    } else {
                        log.warn("TransferChunk received on session {} but no receiver registered", session.getSessionId().getValue());
                    }
                }
                case COMMIT -> {
                    if (receiver != null) {
                        receiver.handleCommit(session, wireMsg.getCommit());
                    } else {
                        log.warn("TransferCommitSignal received on session {} but no receiver registered", session.getSessionId().getValue());
                    }
                }
                case RESUME_OFFER -> {
                    if (receiver != null) {
                        receiver.handleResumeOffer(session, wireMsg.getResumeOffer());
                    } else {
                        log.warn("TransferResumeOffer received on session {} but no receiver registered", session.getSessionId().getValue());
                    }
                }
                case PAUSE -> {
                    if (receiver != null) {
                        receiver.handlePause(session, wireMsg.getPause());
                    } else {
                        log.warn("TransferPauseRequest received on session {} but no receiver registered", session.getSessionId().getValue());
                    }
                }
                case CANCEL -> {
                    if (receiver != null) {
                        receiver.handleCancel(session, wireMsg.getCancel());
                    }
                }
                default -> log.debug("Unhandled TransferWireMessage case: {}", wireMsg.getPayloadCase());
            }
        } catch (Exception e) {
            log.error("Failed to parse or dispatch TransferWireMessage on session {}: {}",
                    session.getSessionId().getValue(), e.getMessage(), e);
        }
    }

    private static String chunkAckKey(String transferId, int itemIndex, long chunkIndex) {
        return transferId + ":" + itemIndex + ":" + chunkIndex;
    }
}
