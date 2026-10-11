package org.peerlink.core.cloud.supabase;

import java.time.Instant;
import java.util.*;

/**
 * Model representing device presence, online status, short-lived connectivity candidates,
 * and heartbeat TTL.
 */
public final class DevicePresenceEntry {

    private final String deviceId;
    private final String presenceStatus; // ONLINE, AWAY, BUSY, OFFLINE
    private final List<String> candidateEndpoints; // e.g. ["192.168.1.100:54321", "203.0.113.5:54321"]
    private final String lastHeartbeatAt;
    private final int ttlSeconds;

    public DevicePresenceEntry(String deviceId, String presenceStatus, List<String> candidateEndpoints,
                               String lastHeartbeatAt, int ttlSeconds) {
        this.deviceId = Objects.requireNonNull(deviceId, "deviceId must not be null");
        this.presenceStatus = presenceStatus != null ? presenceStatus : "ONLINE";
        this.candidateEndpoints = candidateEndpoints != null ? Collections.unmodifiableList(new ArrayList<>(candidateEndpoints)) : Collections.emptyList();
        this.lastHeartbeatAt = lastHeartbeatAt != null ? lastHeartbeatAt : Instant.now().toString();
        this.ttlSeconds = ttlSeconds > 0 ? ttlSeconds : 60;
    }

    public String getDeviceId() { return deviceId; }
    public String getPresenceStatus() { return presenceStatus; }
    public List<String> getCandidateEndpoints() { return candidateEndpoints; }
    public String getLastHeartbeatAt() { return lastHeartbeatAt; }
    public int getTtlSeconds() { return ttlSeconds; }

    public boolean isStale() {
        try {
            Instant heartbeat = Instant.parse(lastHeartbeatAt);
            return heartbeat.plusSeconds(ttlSeconds).isBefore(Instant.now());
        } catch (Exception e) {
            return false;
        }
    }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("device_id", deviceId);
        map.put("presence_status", presenceStatus);
        map.put("candidate_endpoints", candidateEndpoints);
        map.put("last_heartbeat_at", lastHeartbeatAt);
        map.put("ttl_seconds", ttlSeconds);
        return map;
    }

    @SuppressWarnings("unchecked")
    public static DevicePresenceEntry fromMap(Map<String, Object> map) {
        String devId = (String) map.get("device_id");
        String status = (String) map.get("presence_status");
        if (status == null) status = (String) map.get("effective_status");
        List<String> candidates = new ArrayList<>();
        Object candObj = map.get("candidate_endpoints");
        if (candObj instanceof List) {
            for (Object item : (List<?>) candObj) {
                if (item != null) candidates.add(item.toString());
            }
        }
        String hb = (String) map.get("last_heartbeat_at");
        Number ttlNum = (Number) map.get("ttl_seconds");
        int ttl = ttlNum != null ? ttlNum.intValue() : 60;

        return new DevicePresenceEntry(devId, status, candidates, hb, ttl);
    }
}
