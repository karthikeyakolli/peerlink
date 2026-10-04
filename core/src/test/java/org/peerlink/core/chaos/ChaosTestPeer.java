package org.peerlink.core.chaos;

import org.peerlink.core.operation.JournalStage;
import org.peerlink.core.operation.OperationJournal;
import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;
import org.peerlink.core.security.InMemoryTrustStore;
import org.peerlink.core.security.PeerCryptoSigner;
import org.peerlink.core.transfer.*;
import org.peerlink.protocol.v1.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Programmable test peer simulating both cooperative and adversarial peer nodes.
 */
public final class ChaosTestPeer {

    private final String peerId;
    private final PeerCryptoSigner signer;
    private final InMemoryTrustStore trustStore;
    private final Path rootDir;
    private final Path stagingDir;
    private final Path destinationDir;

    private final InMemoryOperationJournal opJournal;
    private final InMemoryTransferSessionJournal sessionJournal;
    private final StagingDirectoryManager stagingManager;
    private final PeerTransferEngine transferEngine;
    private final FileManifestBuilder manifestBuilder;

    public ChaosTestPeer(String peerId, Path baseDir) throws IOException {
        this.peerId = peerId;
        this.signer = PeerCryptoSigner.generate("key_" + peerId);
        this.trustStore = new InMemoryTrustStore();
        this.rootDir = baseDir.resolve(peerId);
        this.stagingDir = rootDir.resolve("staging");
        this.destinationDir = rootDir.resolve("downloads");

        Files.createDirectories(stagingDir);
        Files.createDirectories(destinationDir);

        this.opJournal = new InMemoryOperationJournal();
        this.sessionJournal = new InMemoryTransferSessionJournal();
        this.stagingManager = new StagingDirectoryManager(stagingDir);
        this.transferEngine = new PeerTransferEngine(
                opJournal,
                sessionJournal,
                stagingManager,
                new TransferPreflight(),
                new DestinationConflictResolver(),
                new BandwidthLimiter(),
                new TransferQueueManager()
        );
        this.manifestBuilder = new FileManifestBuilder();
    }

    public String getPeerId() {
        return peerId;
    }

    public PeerCryptoSigner getSigner() {
        return signer;
    }

    public InMemoryTrustStore getTrustStore() {
        return trustStore;
    }

    public Path getDestinationDir() {
        return destinationDir;
    }

    public Path getStagingDir() {
        return stagingDir;
    }

    public InMemoryOperationJournal getOpJournal() {
        return opJournal;
    }

    public InMemoryTransferSessionJournal getSessionJournal() {
        return sessionJournal;
    }

    public PeerTransferEngine getTransferEngine() {
        return transferEngine;
    }

    public FileManifestBuilder getManifestBuilder() {
        return manifestBuilder;
    }

    public void trustPeer(ChaosTestPeer other) {
        this.trustStore.addTrustedPeer(
                other.getPeerId(),
                other.getSigner().computeFingerprint(),
                other.getSigner().getPublicKeyEncoded()
        );
    }

    public void revokePeer(String otherPeerId) {
        this.trustStore.revokeTrust(otherPeerId);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // In-memory Journal Implementation
    // ──────────────────────────────────────────────────────────────────────────
    public static class InMemoryOperationJournal implements OperationJournal {
        private final Map<String, OperationRecord> operations = new ConcurrentHashMap<>();

        @Override
        public void recordOperation(OperationRecord record) {
            operations.put(record.getOperationId(), record);
        }

        @Override
        public Optional<OperationRecord> getOperation(String operationId) {
            return Optional.ofNullable(operations.get(operationId));
        }

        @Override
        public void updateState(String operationId, OperationState newState) {
            OperationRecord rec = operations.get(operationId);
            if (rec != null) {
                operations.put(operationId, rec.withState(newState));
            }
        }

        @Override
        public void recordJournalStage(String operationId, JournalStage stage) {}

        @Override
        public void appendNote(String operationId, String note) {}

        @Override
        public List<OperationRecord> listIncompleteOperations() {
            return operations.values().stream()
                    .filter(r -> r.getState() != OperationState.COMMITTED &&
                            r.getState() != OperationState.FAILED &&
                            r.getState() != OperationState.CANCELLED &&
                            r.getState() != OperationState.OUTCOME_UNKNOWN)
                    .toList();
        }

        @Override
        public List<OperationRecord> listInterruptedOperations() {
            return operations.values().stream()
                    .filter(r -> r.getState() == OperationState.EXECUTING)
                    .toList();
        }

        @Override
        public List<OperationRecord> listUnknownOutcomeOperations() {
            return operations.values().stream()
                    .filter(r -> r.getState() == OperationState.OUTCOME_UNKNOWN)
                    .toList();
        }

        @Override
        public Optional<String> findOperationByIdempotencyKey(String idempotencyKey) {
            return operations.values().stream()
                    .filter(r -> r.getIdempotencyKey().equals(idempotencyKey))
                    .map(OperationRecord::getOperationId)
                    .findFirst();
        }

        @Override
        public void markInterruptedOperationsUnknown(String reason) {}
    }
}
