package org.peerlink.core.cloud.supabase;

import java.io.IOException;
import java.util.*;

/**
 * High-level typed client for managing device registration, presence heartbeat,
 * and WebRTC signaling coordination via Supabase PostgREST.
 */
public class SupabaseDeviceRegistryClient {

    private final SupabaseRestClient restClient;

    public SupabaseDeviceRegistryClient(SupabaseRestClient restClient) {
        this.restClient = Objects.requireNonNull(restClient, "restClient must not be null");
    }

    public SupabaseRestClient getRestClient() {
        return restClient;
    }

    // --- Device Registry ---

    public DeviceRegistryEntry registerDevice(DeviceRegistryEntry entry, String authToken) throws IOException {
        List<Map<String, Object>> res = restClient.upsert(
                "device_registry",
                entry.toMap(),
                authToken,
                "peer_id"
        );
        if (res.isEmpty()) {
            throw new IOException("Failed to register device: empty response");
        }
        return DeviceRegistryEntry.fromMap(res.get(0));
    }

    public Optional<DeviceRegistryEntry> findDeviceByPeerId(String peerId, String authToken) throws IOException {
        String query = "peer_id=eq." + peerId + "&is_revoked=eq.false&select=*";
        List<Map<String, Object>> rows = restClient.select("device_registry", query, authToken);
        if (rows.isEmpty()) {
            return Optional.empty();
        }
        return Optional.of(DeviceRegistryEntry.fromMap(rows.get(0)));
    }

    public List<DeviceRegistryEntry> listUserDevices(String authToken) throws IOException {
        String query = "is_revoked=eq.false&select=*";
        List<Map<String, Object>> rows = restClient.select("device_registry", query, authToken);
        List<DeviceRegistryEntry> result = new ArrayList<>(rows.size());
        for (Map<String, Object> row : rows) {
            result.add(DeviceRegistryEntry.fromMap(row));
        }
        return result;
    }

    public void revokeDevice(String deviceId, String authToken) throws IOException {
        Map<String, Object> update = new HashMap<>();
        update.put("is_revoked", true);
        restClient.update("device_registry", "device_id=eq." + deviceId, update, authToken);
    }

    // --- Device Presence ---

    public DevicePresenceEntry updatePresence(DevicePresenceEntry presence, String authToken) throws IOException {
        List<Map<String, Object>> res = restClient.upsert(
                "device_presence",
                presence.toMap(),
                authToken,
                "device_id"
        );
        if (res.isEmpty()) {
            throw new IOException("Failed to update device presence");
        }
        return DevicePresenceEntry.fromMap(res.get(0));
    }

    public Optional<DevicePresenceEntry> queryPresence(String deviceId, String authToken) throws IOException {
        String query = "device_id=eq." + deviceId + "&select=*";
        List<Map<String, Object>> rows = restClient.select("device_presence", query, authToken);
        if (rows.isEmpty()) {
            return Optional.empty();
        }
        return Optional.of(DevicePresenceEntry.fromMap(rows.get(0)));
    }

    public List<DevicePresenceEntry> queryActivePresence(String authToken) throws IOException {
        String query = "select=*";
        List<Map<String, Object>> rows = restClient.select("active_device_presence", query, authToken);
        List<DevicePresenceEntry> list = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            DevicePresenceEntry entry = DevicePresenceEntry.fromMap(row);
            if (!entry.isStale() && !"OFFLINE".equalsIgnoreCase(entry.getPresenceStatus())) {
                list.add(entry);
            }
        }
        return list;
    }

    // --- Signaling Coordination ---

    public SignalingMessage sendSignalingMessage(SignalingMessage msg, String authToken) throws IOException {
        List<Map<String, Object>> res = restClient.insert(
                "signaling_messages",
                msg.toMap(),
                authToken
        );
        if (res.isEmpty()) {
            throw new IOException("Failed to insert signaling message");
        }
        return SignalingMessage.fromMap(res.get(0));
    }

    public List<SignalingMessage> fetchPendingSignalingMessages(String recipientPeerId, String authToken) throws IOException {
        String query = "recipient_peer_id=eq." + recipientPeerId +
                "&is_consumed=eq.false&order=created_at.asc&select=*";
        List<Map<String, Object>> rows = restClient.select("signaling_messages", query, authToken);
        List<SignalingMessage> result = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            SignalingMessage msg = SignalingMessage.fromMap(row);
            if (!msg.isExpired()) {
                result.add(msg);
            }
        }
        return result;
    }

    public void markSignalingMessageConsumed(String messageId, String authToken) throws IOException {
        Map<String, Object> update = new HashMap<>();
        update.put("is_consumed", true);
        restClient.update("signaling_messages", "message_id=eq." + messageId, update, authToken);
    }
}
