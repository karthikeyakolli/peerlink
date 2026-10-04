package org.peerlink.core.sync;

import java.util.ArrayList;
import java.util.List;

/**
 * Detects suspicious burst changes and pauses sync pending user/policy decision.
 *
 * <p>Design:
 * <ul>
 *   <li>A burst is suspicious when the number of changes exceeds configured thresholds.</li>
 *   <li>Specific patterns (mass deletion, mass extension rename) trigger separate checks.</li>
 *   <li>When triggered: sync is PAUSED, current versions are preserved, reason is recorded.</li>
 *   <li>User or policy must explicitly approve or reject before sync resumes.</li>
 *   <li>File locking is advisory only — mass-change protection does NOT rely on locks.</li>
 * </ul>
 */
public final class MassChangeProtector {

    public static final int DEFAULT_DELETION_THRESHOLD = 50;
    public static final int DEFAULT_CHANGE_THRESHOLD = 200;
    public static final double DEFAULT_EXTENSION_CHANGE_RATIO = 0.5; // >50% of objects changed extension

    private final int deletionThreshold;
    private final int changeThreshold;
    private final double extensionChangeRatio;

    public MassChangeProtector() {
        this(DEFAULT_DELETION_THRESHOLD, DEFAULT_CHANGE_THRESHOLD, DEFAULT_EXTENSION_CHANGE_RATIO);
    }

    public MassChangeProtector(int deletionThreshold, int changeThreshold, double extensionChangeRatio) {
        this.deletionThreshold = deletionThreshold;
        this.changeThreshold = changeThreshold;
        this.extensionChangeRatio = extensionChangeRatio;
    }

    public record Assessment(boolean triggered, List<String> reasons) {
        public boolean isSafe() { return !triggered; }
    }

    /**
     * Evaluate a batch of detected changes for suspicious patterns.
     *
     * @param changes     the full list of detected changes
     * @param totalTracked total number of tracked objects before this batch
     * @return an assessment with triggered flag and list of reasons
     */
    public Assessment assess(List<DetectedChange> changes, int totalTracked) {
        return assess(changes, totalTracked, null);
    }

    /**
     * Evaluate a batch of detected changes for suspicious patterns.
     * When manifest is provided, pure directory deletions are excluded from the file deletion threshold.
     *
     * @param changes      the full list of detected changes
     * @param totalTracked total number of tracked objects before this batch
     * @param manifest     optional manifest to resolve directory vs file objects
     * @return an assessment with triggered flag and list of reasons
     */
    public Assessment assess(List<DetectedChange> changes, int totalTracked, SyncManifest manifest) {
        List<String> reasons = new ArrayList<>();

        long deletions;
        if (manifest != null) {
            deletions = changes.stream()
                    .filter(c -> c.changeType() == ChangeType.DELETED)
                    .filter(c -> {
                        if (c.objectId() == null) return true;
                        return manifest.findById(c.objectId())
                                .map(obj -> !obj.isDirectory())
                                .orElse(true);
                    })
                    .count();
        } else {
            deletions = changes.stream().filter(c -> c.changeType() == ChangeType.DELETED).count();
        }
        long totalChanges = changes.size();

        if (deletions >= deletionThreshold) {
            reasons.add(String.format(
                    "Mass deletion detected: %d deletions (threshold: %d)", deletions, deletionThreshold));
        }

        if (totalChanges >= changeThreshold) {
            reasons.add(String.format(
                    "Burst change detected: %d changes (threshold: %d)", totalChanges, changeThreshold));
        }

        // Mass extension change: count objects where path extension changed
        if (totalTracked > 0) {
            long extensionChanges = changes.stream()
                    .filter(c -> c.changeType() == ChangeType.CONTENT_MODIFIED || c.changeType() == ChangeType.METADATA_CHANGED)
                    .filter(c -> extensionChanged(c.relativePath()))
                    .count();
            double ratio = (double) extensionChanges / totalTracked;
            if (ratio >= extensionChangeRatio && extensionChanges > 10) {
                reasons.add(String.format(
                        "Mass extension change detected: %.0f%% of objects (%.0f%% threshold)",
                        ratio * 100, extensionChangeRatio * 100));
            }
        }

        return new Assessment(!reasons.isEmpty(), reasons);
    }

    private static boolean extensionChanged(String path) {
        // Simple heuristic: path contains extension-change marker like .enc, .locked, .crypted
        if (path == null) return false;
        String lower = path.toLowerCase();
        return lower.endsWith(".enc") || lower.endsWith(".locked") || lower.endsWith(".crypted")
                || lower.endsWith(".encrypted") || lower.endsWith(".renamed");
    }
}