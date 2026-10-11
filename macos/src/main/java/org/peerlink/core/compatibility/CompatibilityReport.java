package org.peerlink.core.compatibility;

import java.util.List;

public record CompatibilityReport(
        CompatibilityResult overallResult,
        List<CompatibilityIssue> issues,
        boolean requiresUserDecision
) {
    public CompatibilityReport {
        issues = List.copyOf(issues);
    }
}