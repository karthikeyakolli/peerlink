package org.peerlink.core.android;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import org.peerlink.core.operation.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.Closeable;
import java.time.Instant;
import java.util.*;

/**
 * Android SQLite-backed authoritative Operation Journal adhering to Phase 05/25 contracts.
 *
 * <p>Enforces:
 * <ul>
 *   <li>WAL (Write-Ahead Logging) mode and foreign keys enabled.</li>
 *   <li>Idempotency key uniqueness across submissions.</li>
 *   <li>Terminal state transition protection (COMMITTED, FAILED, CANCELLED, OUTCOME_UNKNOWN, RECOVERY_REQUIRED).</li>
 *   <li>Durable persistence surviving process termination and system reboot.</li>
 *   <li>Detailed recovery metadata (staging, destination, expected hash, stage, notes).</li>
 * </ul>
 */
public class AndroidSqliteOperationJournal extends SQLiteOpenHelper implements OperationJournal, Closeable {
    private static final Logger log = LoggerFactory.getLogger(AndroidSqliteOperationJournal.class);

    public static final String DATABASE_NAME = "peerlink_operations.db";
    public static final int DATABASE_VERSION = 1;

    public record OperationRecoveryMetadata(
            String operationId,
            String stagingPath,
            String destinationPath,
            String expectedSha256,
            long totalBytes,
            long transferredBytes,
            JournalStage stage,
            String notes
    ) {}

    public AndroidSqliteOperationJournal(Context context) {
        this(context, DATABASE_NAME);
    }

    public AndroidSqliteOperationJournal(Context context, String databaseName) {
        super(context, databaseName, null, DATABASE_VERSION);
    }

    @Override
    public void onConfigure(SQLiteDatabase db) {
        super.onConfigure(db);
        db.enableWriteAheadLogging();
        db.setForeignKeyConstraintsEnabled(true);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        log.info("Initializing Android SQLite Operation Journal database tables");
        db.execSQL("""
            CREATE TABLE IF NOT EXISTS operations (
                operation_id      TEXT    PRIMARY KEY,
                intent            TEXT    NOT NULL,
                actor_peer_id     TEXT    NOT NULL,
                target_object_ids TEXT    NOT NULL DEFAULT '',
                state             TEXT    NOT NULL,
                journal_stage     TEXT    NOT NULL DEFAULT 'INTENT',
                idempotency_key   TEXT    NOT NULL,
                created_at        INTEGER NOT NULL,
                updated_at        INTEGER NOT NULL,
                interrupted_at    INTEGER,
                notes             TEXT    NOT NULL DEFAULT '',
                staging_path      TEXT,
                destination_path  TEXT,
                expected_sha256   TEXT,
                total_bytes       INTEGER NOT NULL DEFAULT 0,
                transferred_bytes INTEGER NOT NULL DEFAULT 0
            );
        """);

        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS idx_operations_idempotency ON operations(idempotency_key);");
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_operations_state ON operations(state);");

        db.execSQL("""
            CREATE TABLE IF NOT EXISTS operation_targets (
                operation_id TEXT    NOT NULL,
                object_id    TEXT    NOT NULL,
                target_order INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (operation_id, object_id),
                FOREIGN KEY (operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE
            );
        """);

        db.execSQL("""
            CREATE TABLE IF NOT EXISTS recovery_journal (
                recovery_id     TEXT    PRIMARY KEY,
                operation_id    TEXT    NOT NULL,
                decision        TEXT    NOT NULL,
                evidence_hash   TEXT,
                filesystem_path TEXT,
                reconciled_at   INTEGER NOT NULL,
                explanation     TEXT    NOT NULL DEFAULT ''
            );
        """);
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        log.info("Upgrading Android SQLite Operation Journal from v{} to v{}", oldVersion, newVersion);
    }

    @Override
    public synchronized void recordOperation(OperationRecord record) {
        Objects.requireNonNull(record, "record must not be null");

        // Idempotency check: verify if key exists for a different operation_id
        Optional<String> existing = findOperationByIdempotencyKey(record.getIdempotencyKey());
        if (existing.isPresent() && !existing.get().equals(record.getOperationId())) {
            throw new DuplicateOperationException(record.getIdempotencyKey(), existing.get());
        }

        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put("operation_id", record.getOperationId());
        values.put("intent", record.getIntent().name());
        values.put("actor_peer_id", record.getActorPeerId());
        values.put("target_object_ids", String.join(",", record.getTargetObjectIds()));
        values.put("state", record.getState().name());
        values.put("journal_stage", JournalStage.INTENT.name());
        values.put("idempotency_key", record.getIdempotencyKey());
        values.put("created_at", record.getCreatedAtUtcMs());
        values.put("updated_at", record.getUpdatedAtUtcMs());
        values.put("notes", "");

        long row = db.insertWithOnConflict("operations", null, values, SQLiteDatabase.CONFLICT_IGNORE);
        if (row == -1 && !existing.isPresent()) {
            // Already exists with same operation_id (idempotent no-op)
            log.debug("Operation {} already recorded", record.getOperationId());
        }

        int order = 0;
        for (String targetObj : record.getTargetObjectIds()) {
            ContentValues targetVal = new ContentValues();
            targetVal.put("operation_id", record.getOperationId());
            targetVal.put("object_id", targetObj);
            targetVal.put("target_order", order++);
            db.insertWithOnConflict("operation_targets", null, targetVal, SQLiteDatabase.CONFLICT_IGNORE);
        }
    }

    @Override
    public synchronized void updateState(String operationId, OperationState newState) {
        Objects.requireNonNull(operationId, "operationId must not be null");
        Objects.requireNonNull(newState, "newState must not be null");

        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put("state", newState.name());
        values.put("updated_at", System.currentTimeMillis());

        int rows;
        if (newState == OperationState.OUTCOME_UNKNOWN || newState == OperationState.RECOVERY_REQUIRED) {
            // Unconditional update permitted for crash handling
            rows = db.update("operations", values, "operation_id = ?", new String[]{operationId});
        } else {
            // Guard against transition from terminal states
            String terminalList = "('COMMITTED', 'FAILED', 'CANCELLED', 'OUTCOME_UNKNOWN', 'RECOVERY_REQUIRED')";
            rows = db.update("operations", values, "operation_id = ? AND state NOT IN " + terminalList,
                    new String[]{operationId});
        }

        if (rows == 0) {
            Optional<OperationRecord> existing = getOperation(operationId);
            if (existing.isEmpty()) {
                log.warn("updateState: operation not found [{}]", operationId);
            } else {
                throw new IllegalStateTransitionException(operationId, existing.get().getState(), newState);
            }
        }
    }

    @Override
    public synchronized void recordJournalStage(String operationId, JournalStage stage) {
        Objects.requireNonNull(operationId, "operationId must not be null");
        Objects.requireNonNull(stage, "stage must not be null");

        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put("journal_stage", stage.name());
        values.put("updated_at", System.currentTimeMillis());
        db.update("operations", values, "operation_id = ?", new String[]{operationId});
    }

    @Override
    public synchronized Optional<OperationRecord> getOperation(String operationId) {
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor cursor = db.query("operations", null, "operation_id = ?",
                new String[]{operationId}, null, null, null)) {
            if (cursor.moveToFirst()) {
                return Optional.of(mapCursorToRecord(cursor));
            }
        }
        return Optional.empty();
    }

    @Override
    public synchronized List<OperationRecord> listIncompleteOperations() {
        String terminalList = "('COMMITTED', 'FAILED', 'CANCELLED', 'OUTCOME_UNKNOWN', 'RECOVERY_REQUIRED')";
        return queryOperations("state NOT IN " + terminalList, null);
    }

    @Override
    public synchronized List<OperationRecord> listInterruptedOperations() {
        return queryOperations("state = ?", new String[]{"EXECUTING"});
    }

    @Override
    public synchronized List<OperationRecord> listUnknownOutcomeOperations() {
        return queryOperations("state = ?", new String[]{"OUTCOME_UNKNOWN"});
    }

    @Override
    public synchronized Optional<String> findOperationByIdempotencyKey(String idempotencyKey) {
        if (idempotencyKey == null) return Optional.empty();
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor cursor = db.query("operations", new String[]{"operation_id"}, "idempotency_key = ?",
                new String[]{idempotencyKey}, null, null, null, "1")) {
            if (cursor.moveToFirst()) {
                return Optional.of(cursor.getString(0));
            }
        }
        return Optional.empty();
    }

    @Override
    public synchronized void appendNote(String operationId, String note) {
        Objects.requireNonNull(operationId, "operationId must not be null");
        if (note == null || note.isBlank()) return;

        String timestamp = Instant.now().toString();
        String entry = "[" + timestamp + "] " + note;

        SQLiteDatabase db = getWritableDatabase();
        db.execSQL("""
            UPDATE operations
            SET notes = CASE WHEN notes = '' THEN ? ELSE notes || char(10) || ? END,
                updated_at = ?
            WHERE operation_id = ?
        """, new Object[]{entry, entry, System.currentTimeMillis(), operationId});
    }

    @Override
    public synchronized void markInterruptedOperationsUnknown(String reason) {
        long now = System.currentTimeMillis();
        String note = "Process restart: " + reason;
        String entry = "[" + Instant.ofEpochMilli(now) + "] " + note;

        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            db.execSQL("""
                UPDATE operations
                SET state = 'OUTCOME_UNKNOWN',
                    interrupted_at = ?,
                    updated_at = ?,
                    notes = CASE WHEN notes = '' THEN ? ELSE notes || char(10) || ? END
                WHERE state = 'EXECUTING'
            """, new Object[]{now, now, entry, entry});
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    // --- Extended metadata and recovery operations ---

    public synchronized void setOperationMetadata(String operationId, String stagingPath, String destinationPath,
                                                  String expectedSha256, long totalBytes) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        if (stagingPath != null) values.put("staging_path", stagingPath);
        if (destinationPath != null) values.put("destination_path", destinationPath);
        if (expectedSha256 != null) values.put("expected_sha256", expectedSha256);
        if (totalBytes >= 0) values.put("total_bytes", totalBytes);
        values.put("updated_at", System.currentTimeMillis());
        db.update("operations", values, "operation_id = ?", new String[]{operationId});
    }

    public synchronized void updateTransferredBytes(String operationId, long transferredBytes) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put("transferred_bytes", transferredBytes);
        values.put("updated_at", System.currentTimeMillis());
        db.update("operations", values, "operation_id = ?", new String[]{operationId});
    }

    public synchronized Optional<OperationRecoveryMetadata> getOperationMetadata(String operationId) {
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor cursor = db.query("operations",
                new String[]{"operation_id", "staging_path", "destination_path", "expected_sha256", "total_bytes", "transferred_bytes", "journal_stage", "notes"},
                "operation_id = ?", new String[]{operationId}, null, null, null)) {
            if (cursor.moveToFirst()) {
                String opId = cursor.getString(0);
                String staging = cursor.getString(1);
                String dest = cursor.getString(2);
                String expectedHash = cursor.getString(3);
                long total = cursor.getLong(4);
                long xfer = cursor.getLong(5);
                String stageStr = cursor.getString(6);
                JournalStage stage = JournalStage.valueOf(stageStr != null ? stageStr : "INTENT");
                String notes = cursor.getString(7);
                return Optional.of(new OperationRecoveryMetadata(opId, staging, dest, expectedHash, total, xfer, stage, notes));
            }
        }
        return Optional.empty();
    }

    public synchronized void recordRecoveryEntry(String recoveryId, String operationId, String decision,
                                                 String evidenceHash, String filesystemPath,
                                                 long reconciledAt, String explanation) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put("recovery_id", recoveryId);
        values.put("operation_id", operationId);
        values.put("decision", decision);
        values.put("evidence_hash", evidenceHash);
        values.put("filesystem_path", filesystemPath);
        values.put("reconciled_at", reconciledAt);
        values.put("explanation", explanation != null ? explanation : "");
        db.insertWithOnConflict("recovery_journal", null, values, SQLiteDatabase.CONFLICT_REPLACE);
    }

    public synchronized List<Map<String, Object>> listRecoveryEntries(String operationId) {
        List<Map<String, Object>> results = new ArrayList<>();
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor cursor = db.query("recovery_journal", null, "operation_id = ?",
                new String[]{operationId}, null, null, "reconciled_at ASC")) {
            while (cursor.moveToNext()) {
                Map<String, Object> map = new HashMap<>();
                map.put("recovery_id", cursor.getString(cursor.getColumnIndexOrThrow("recovery_id")));
                map.put("operation_id", cursor.getString(cursor.getColumnIndexOrThrow("operation_id")));
                map.put("decision", cursor.getString(cursor.getColumnIndexOrThrow("decision")));
                map.put("evidence_hash", cursor.getString(cursor.getColumnIndexOrThrow("evidence_hash")));
                map.put("filesystem_path", cursor.getString(cursor.getColumnIndexOrThrow("filesystem_path")));
                map.put("reconciled_at", cursor.getLong(cursor.getColumnIndexOrThrow("reconciled_at")));
                map.put("explanation", cursor.getString(cursor.getColumnIndexOrThrow("explanation")));
                results.add(map);
            }
        }
        return results;
    }

    private List<OperationRecord> queryOperations(String selection, String[] selectionArgs) {
        List<OperationRecord> list = new ArrayList<>();
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor cursor = db.query("operations", null, selection, selectionArgs, null, null, "created_at ASC")) {
            while (cursor.moveToNext()) {
                list.add(mapCursorToRecord(cursor));
            }
        }
        return list;
    }

    private OperationRecord mapCursorToRecord(Cursor cursor) {
        String operationId = cursor.getString(cursor.getColumnIndexOrThrow("operation_id"));
        String intentStr = cursor.getString(cursor.getColumnIndexOrThrow("intent"));
        String actorPeerId = cursor.getString(cursor.getColumnIndexOrThrow("actor_peer_id"));
        String targetsStr = cursor.getString(cursor.getColumnIndexOrThrow("target_object_ids"));
        String stateStr = cursor.getString(cursor.getColumnIndexOrThrow("state"));
        String idempKey = cursor.getString(cursor.getColumnIndexOrThrow("idempotency_key"));
        long createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("created_at"));
        long updatedAt = cursor.getLong(cursor.getColumnIndexOrThrow("updated_at"));

        List<String> targetList = (targetsStr == null || targetsStr.isBlank())
                ? Collections.emptyList()
                : Arrays.asList(targetsStr.split(","));

        return new OperationRecord(
                operationId,
                OperationIntent.valueOf(intentStr),
                actorPeerId,
                targetList,
                OperationState.valueOf(stateStr),
                idempKey,
                createdAt,
                updatedAt
        );
    }
}
