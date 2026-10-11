package org.peerlink.core.cloud.supabase;

import java.time.Instant;
import java.util.*;

/**
 * Model representing an ephemeral signaling message exchanged through the Supabase control plane.
 * Used for WebRTC offer/answer negotiation, ICE candidates, and P2P connection coordination.
 */
public final class SignalingMessage {

    public enum Type {
        OFFER,
        ANSWER,
        ICE_CANDIDATE,
        RELAY_REQUEST,
        HANGUP,
        PAIRING_INVITE
    }

    private final String messageId;
    private final String senderPeerId;
    private final String recipientPeerId;
    private final Type messageType;
    private final Map<String, Object> payload;
    private final String createdAt;
    private final String expiresAt;
    private final boolean isConsumed;

    public SignalingMessage(String messageId, String senderPeerId, String recipientPeerId,
                            Type messageType, Map<String, Object> payload,
                            String createdAt, String expiresAt, boolean isConsumed) {
        this.messageId = messageId != null ? messageId : UUID.randomUUID().toString();
        this.senderPeerId = Objects.requireNonNull(senderPeerId, "senderPeerId must not be null");
        this.recipientPeerId = Objects.requireNonNull(recipientPeerId, "recipientPeerId must not be null");
        this.messageType = Objects.requireNonNull(messageType, "messageType must not be null");
        this.payload = payload != null ? Collections.unmodifiableMap(new LinkedHashMap<>(payload)) : Collections.emptyMap();
        this.createdAt = createdAt != null ? createdAt : Instant.now().toString();
        this.expiresAt = expiresAt != null ? expiresAt : Instant.now().plusSeconds(300).toString();
        this.isConsumed = isConsumed;
    }

    public String getMessageId() { return messageId; }
    public String getSenderPeerId() { return senderPeerId; }
    public String getRecipientPeerId() { return recipientPeerId; }
    public Type getMessageType() { return messageType; }
    public Map<String, Object> getPayload() { return payload; }
    public String getCreatedAt() { return createdAt; }
    public String getExpiresAt() { return expiresAt; }
    public boolean isConsumed() { return isConsumed; }

    public boolean isExpired() {
        try {
            return Instant.parse(expiresAt).isBefore(Instant.now());
        } catch (Exception e) {
            return false;
        }
    }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new LinkedHashMap<>();
        if (messageId != null) map.put("message_id", messageId);
        map.put("sender_peer_id", senderPeerId);
        map.put("recipient_peer_id", recipientPeerId);
        map.put("message_type", messageType.name());
        map.put("payload", payload);
        map.put("created_at", createdAt);
        map.put("expires_at", expiresAt);
        map.put("is_consumed", isConsumed);
        return map;
    }

    @SuppressWarnings("unchecked")
    public static SignalingMessage fromMap(Map<String, Object> map) {
        String id = (String) map.get("message_id");
        String sender = (String) map.get("sender_peer_id");
        String recipient = (String) map.get("recipient_peer_id");
        String typeStr = (String) map.get("message_type");
        Type type = Type.valueOf(typeStr);
        Map<String, Object> payloadMap = Collections.emptyMap();
        Object p = map.get("payload");
        if (p instanceof Map) {
            payloadMap = (Map<String, Object>) p;
        }
        String created = (String) map.get("created_at");
        String expires = (String) map.get("expires_at");
        Boolean consumed = (Boolean) map.get("is_consumed");

        return new SignalingMessage(
                id, sender, recipient, type, payloadMap, created, expires,
                consumed != null && consumed
        );
    }
}
