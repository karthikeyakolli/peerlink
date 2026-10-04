package org.peerlink.core.sharing;

public final class ShareApprovalState {
    private final String shareId;
    private volatile boolean pendingOwnerApproval = false;
    private volatile boolean ownerApproved = false;
    private volatile boolean ownerDenied = false;
    private volatile String denialReason = "";
    private volatile long approvalTimestampUtcMs = 0L;

    public ShareApprovalState(String shareId) { this.shareId = shareId; }

    public void setPendingApproval(boolean pending) { this.pendingOwnerApproval = pending; }

    public void approve() {
        this.ownerApproved = true;
        this.ownerDenied = false;
        this.pendingOwnerApproval = false;
        this.approvalTimestampUtcMs = System.currentTimeMillis();
    }

    public void deny(String reason) {
        this.ownerDenied = true;
        this.ownerApproved = false;
        this.pendingOwnerApproval = false;
        this.denialReason = reason != null ? reason : "";
        this.approvalTimestampUtcMs = System.currentTimeMillis();
    }

    public String getShareId() { return shareId; }
    public boolean isPendingOwnerApproval() { return pendingOwnerApproval; }
    public boolean isOwnerApproved() { return ownerApproved; }
    public boolean isOwnerDenied() { return ownerDenied; }
    public String getDenialReason() { return denialReason; }
    public long getApprovalTimestampUtcMs() { return approvalTimestampUtcMs; }
}