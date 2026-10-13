package org.peerlink.core.sync;

import java.util.Objects;

/**
 * Explicit mass-change and mass-deletion policy.
 *
 * <p>Makes safety thresholds and confirmation decisions explicit in the engine
 * rather than hiding safety decisions in UI logic.
 */
public final class MassChangePolicy {

    public enum ConfirmationMode {
        REQUIRE_EXPLICIT_CONFIRMATION, // Default: pause session until explicit user/admin approval
        FAIL_CLOSED,                   // Abort and fail session immediately if burst threshold tripped
        AUTO_APPROVE                   // For automated batch migrations / tests with prior opt-in
    }

    private final int deletionThreshold;
    private final int changeThreshold;
    private final double extensionChangeRatio;
    private final ConfirmationMode confirmationMode;

    public MassChangePolicy() {
        this(MassChangeProtector.DEFAULT_DELETION_THRESHOLD,
             MassChangeProtector.DEFAULT_CHANGE_THRESHOLD,
             MassChangeProtector.DEFAULT_EXTENSION_CHANGE_RATIO,
             ConfirmationMode.REQUIRE_EXPLICIT_CONFIRMATION);
    }

    public MassChangePolicy(int deletionThreshold, int changeThreshold,
                            double extensionChangeRatio, ConfirmationMode confirmationMode) {
        this.deletionThreshold = deletionThreshold;
        this.changeThreshold = changeThreshold;
        this.extensionChangeRatio = extensionChangeRatio;
        this.confirmationMode = Objects.requireNonNull(confirmationMode, "confirmationMode");
    }

    public int getDeletionThreshold() { return deletionThreshold; }
    public int getChangeThreshold() { return changeThreshold; }
    public double getExtensionChangeRatio() { return extensionChangeRatio; }
    public ConfirmationMode getConfirmationMode() { return confirmationMode; }

    public MassChangeProtector createProtector() {
        return new MassChangeProtector(deletionThreshold, changeThreshold, extensionChangeRatio);
    }
}
