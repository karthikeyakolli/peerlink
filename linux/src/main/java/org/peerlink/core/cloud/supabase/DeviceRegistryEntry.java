package org.peerlink.core.cloud.supabase;

import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

/**
 * Model representing a registered PeerLink device in the Supabase control plane.
 */
public final class DeviceRegistryEntry {

    private final String deviceId;
    private final String userId;
    private final String peerId;
    private final String publicKey;
    private final String deviceName;
    private final String deviceType;
    private final boolean isRevoked;
    private final String registeredAt;
    private final String lastSeenAt;

    public DeviceRegistryEntry(String deviceId, String userId, String peerId, String publicKey,
                               String deviceName, String deviceType, boolean isRevoked,
                               String registeredAt, String lastSeenAt) {
        this.deviceId = deviceId;
        this.userId = userId;
        this.peerId = Objects.requireNonNull(peerId, "peerId must not be null");
        this.publicKey = Objects.requireNonNull(publicKey, "publicKey must not be null");
        this.deviceName = deviceName != null ? deviceName : "PeerLink Node";
        this.deviceType = deviceType != null ? deviceType : "DESKTOP";
        this.isRevoked = isRevoked;
        this.registeredAt = registeredAt;
        this.lastSeenAt = lastSeenAt;
    }

    public String getDeviceId() { return deviceId; }
    public String getUserId() { return userId; }
    public String getPeerId() { return peerId; }
    public String getPublicKey() { return publicKey; }
    public String getDeviceName() { return deviceName; }
    public String getDeviceType() { return deviceType; }
    public boolean isRevoked() { return isRevoked; }
    public String getRegisteredAt() { return registeredAt; }
    public String getLastSeenAt() { return lastSeenAt; }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        if (deviceId != null) map.put("device_id", deviceId);
        if (userId != null) map.put("user_id", userId);
        map.put("peer_id", peerId);
        map.put("public_key", publicKey);
        map.put("device_name", deviceName);
        map.put("device_type", deviceType);
        map.put("is_revoked", isRevoked);
        return map;
    }

    public static DeviceRegistryEntry fromMap(Map<String, Object> map) {
        String devId = (String) map.get("device_id");
        String uid = (String) map.get("user_id");
        String pid = (String) map.get("peer_id");
        String pk = (String) map.get("public_key");
        String name = (String) map.get("device_name");
        String type = (String) map.get("device_type");
        Boolean revoked = (Boolean) map.get("is_revoked");
        String regAt = (String) map.get("registered_at");
        String seenAt = (String) map.get("last_seen_at");

        return new DeviceRegistryEntry(
                devId, uid, pid, pk, name, type,
                revoked != null && revoked,
                regAt, seenAt
        );
    }
}
