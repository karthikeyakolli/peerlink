package org.peerlink.core.chaos;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Collects and records detailed scenario results, traces, and metrics for Phase 24 Chaos Reporting.
 */
public final class ChaosTraceCollector {

    public record ScenarioRecord(
            String scenarioId,
            String scenarioTitle,
            String environment,
            String operationId,
            String traceId,
            String expectedBehavior,
            String actualBehavior,
            String finalFilesystemState,
            String databaseState,
            String recoveryResult,
            String integrityHashResult,
            boolean passed
    ) {}

    private final List<ScenarioRecord> records = Collections.synchronizedList(new ArrayList<>());

    public void record(
            String scenarioId,
            String scenarioTitle,
            String environment,
            String operationId,
            String traceId,
            String expectedBehavior,
            String actualBehavior,
            String finalFilesystemState,
            String databaseState,
            String recoveryResult,
            String integrityHashResult,
            boolean passed
    ) {
        records.add(new ScenarioRecord(
                scenarioId,
                scenarioTitle,
                environment,
                operationId,
                traceId,
                expectedBehavior,
                actualBehavior,
                finalFilesystemState,
                databaseState,
                recoveryResult,
                integrityHashResult,
                passed
        ));
    }

    public List<ScenarioRecord> getRecords() {
        return Collections.unmodifiableList(records);
    }

    public int totalScenarios() {
        return records.size();
    }

    public long passedScenarios() {
        return records.stream().filter(ScenarioRecord::passed).count();
    }

    public long failedScenarios() {
        return records.stream().filter(r -> !r.passed()).count();
    }
}
