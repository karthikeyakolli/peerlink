package org.peerlink.core.compatibility;

public record CompatibilityIssue(
        CompatibilityCategory category,
        CompatibilityResult result,
        String code,
        String description,
        String userActionNeeded
) {}
