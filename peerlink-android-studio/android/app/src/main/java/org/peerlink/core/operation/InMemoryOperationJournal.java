package org.peerlink.core.operation;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.stream.Collectors;

/**
 * Thread-safe in-memory OperationJournal conforming to the authoritative OperationJournal contract.
 */
public class InMemoryOperationJournal implements OperationJournal {

    private final ConcurrentMap<String, OperationRecord> records = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, String> idempotencyIndex = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, JournalStage> stages = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, List<String>> notes = new ConcurrentHashMap<>();

    @Override
    public synchronized void recordOperation(OperationRecord record) {
        Objects.requireNonNull(record, "record must not be null");
        String opId = record.getOperationId();
        String idemKey = record.getIdempotencyKey();

        if (idemKey != null && !idemKey.isBlank()) {
            String existingOpId = idempotencyIndex.putIfAbsent(idemKey, opId);
            if (existingOpId != null && !existingOpId.equals(opId)) {
                throw new DuplicateOperationException(idemKey, existingOpId);
            }
        }

        records.put(opId, record);
        stages.put(opId, JournalStage.INTENT);
    }

    @Override
    public synchronized void updateState(String operationId, OperationState newState) {
        Objects.requireNonNull(operationId, "operationId must not be null");
        Objects.requireNonNull(newState, "newState must not be null");

        OperationRecord existing = records.get(operationId);
        if (existing == null) {
            throw new IllegalArgumentException("Cannot update state for unknown operation: " + operationId);
        }

        if (existing.getState().isTerminal() && !newState.isTerminal()) {
            throw new IllegalStateTransitionException(operationId, existing.getState(), newState);
        }

        records.put(operationId, existing.withState(newState));
    }

    @Override
    public synchronized void recordJournalStage(String operationId, JournalStage stage) {
        Objects.requireNonNull(operationId, "operationId must not be null");
        Objects.requireNonNull(stage, "stage must not be null");
        stages.put(operationId, stage);
    }

    @Override
    public Optional<OperationRecord> getOperation(String operationId) {
        return Optional.ofNullable(records.get(operationId));
    }

    @Override
    public List<OperationRecord> listIncompleteOperations() {
        return records.values().stream()
                .filter(r -> !r.getState().isTerminal())
                .collect(Collectors.toList());
    }

    @Override
    public List<OperationRecord> listInterruptedOperations() {
        return records.values().stream()
                .filter(r -> r.getState() == OperationState.EXECUTING)
                .collect(Collectors.toList());
    }

    @Override
    public List<OperationRecord> listUnknownOutcomeOperations() {
        return records.values().stream()
                .filter(r -> r.getState() == OperationState.OUTCOME_UNKNOWN)
                .collect(Collectors.toList());
    }

    @Override
    public Optional<String> findOperationByIdempotencyKey(String idempotencyKey) {
        if (idempotencyKey == null) return Optional.empty();
        return Optional.ofNullable(idempotencyIndex.get(idempotencyKey));
    }

    @Override
    public synchronized void appendNote(String operationId, String note) {
        Objects.requireNonNull(operationId, "operationId must not be null");
        if (note != null) {
            notes.computeIfAbsent(operationId, k -> new ArrayList<>()).add(note);
        }
    }

    @Override
    public synchronized void markInterruptedOperationsUnknown(String reason) {
        for (OperationRecord record : listInterruptedOperations()) {
            records.put(record.getOperationId(), record.withState(OperationState.OUTCOME_UNKNOWN));
            appendNote(record.getOperationId(), "Interrupted: " + reason);
        }
    }

    public JournalStage getStage(String operationId) {
        return stages.getOrDefault(operationId, JournalStage.INTENT);
    }

    public record OperationRecoveryMetadata(
            JournalStage stage,
            String stagingPath,
            String destinationPath,
            String expectedSha256
    ) {}

    private final ConcurrentMap<String, OperationRecoveryMetadata> metadata = new ConcurrentHashMap<>();

    public void setOperationMetadata(String operationId, JournalStage stage, String stagingPath, String destinationPath, String expectedSha256) {
        metadata.put(operationId, new OperationRecoveryMetadata(stage, stagingPath, destinationPath, expectedSha256));
        if (stage != null) {
            stages.put(operationId, stage);
        }
    }

    public Optional<OperationRecoveryMetadata> getOperationMetadata(String operationId) {
        return Optional.ofNullable(metadata.get(operationId));
    }

    public void clear() {
        records.clear();
        idempotencyIndex.clear();
        stages.clear();
        notes.clear();
        metadata.clear();
    }
}
