package org.peerlink.core.sharing;

public final class AuthorizationDecision {
    private final boolean authorized;
    private final RejectReason rejectReason;
    private final String errorMessage;
    private final ShareCapability capability;
    private final ShareObject share;

    private AuthorizationDecision(boolean authorized, RejectReason rejectReason,
            String errorMessage, ShareCapability capability, ShareObject share) {
        this.authorized = authorized;
        this.rejectReason = rejectReason;
        this.errorMessage = errorMessage;
        this.capability = capability;
        this.share = share;
    }

    public static AuthorizationDecision authorized(ShareCapability capability, ShareObject share) {
        return new AuthorizationDecision(true, RejectReason.NONE, null, capability, share);
    }

    public static AuthorizationDecision reject(RejectReason reason, String message) {
        return new AuthorizationDecision(false, reason, message, null, null);
    }

    public boolean isAuthorized() { return authorized; }
    public RejectReason getRejectReason() { return rejectReason; }
    public String getErrorMessage() { return errorMessage; }
    public ShareCapability getCapability() { return capability; }
    public ShareObject getShare() { return share; }

    @Override
    public String toString() {
        return authorized ? "AUTHORIZED" : ("REJECTED[" + rejectReason + "]: " + errorMessage);
    }
}