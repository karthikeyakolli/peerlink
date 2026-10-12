package org.peerlink.core.cloud.supabase;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.*;
import java.util.function.BiFunction;
import java.util.function.Function;

/**
 * Model representing an ephemeral signaling message exchanged through the Supabase control plane.
 * Used for WebRTC offer/answer negotiation, ICE candidates, and P2P connection coordination.
 *
 * CRITICAL SECURITY INVARIANT:
 * Ephemeral signaling messages carry cryptographic device signatures so that
 * account identity (Supabase GoTrue) is strictly separated from device identity.
 * Compromise of a Supabase account cannot forge device cryptographic identity.
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
    private final String senderPublicKey;
    private final String signature;

    public SignalingMessage(String messageId, String senderPeerId, String recipientPeerId,
                            Type messageType, Map<String, Object> payload,
                            String createdAt, String expiresAt, boolean isConsumed) {
        this(messageId, senderPeerId, recipientPeerId, messageType, payload, createdAt, expiresAt, isConsumed, null, null);
    }

    public SignalingMessage(String messageId, String senderPeerId, String recipientPeerId,
                            Type messageType, Map<String, Object> payload,
                            String createdAt, String expiresAt, boolean isConsumed,
                            String senderPublicKey, String signature) {
        this.messageId = messageId != null ? messageId : UUID.randomUUID().toString();
        this.senderPeerId = Objects.requireNonNull(senderPeerId, "senderPeerId must not be null");
        this.recipientPeerId = Objects.requireNonNull(recipientPeerId, "recipientPeerId must not be null");
        this.messageType = Objects.requireNonNull(messageType, "messageType must not be null");
        this.payload = payload != null ? Collections.unmodifiableMap(new LinkedHashMap<>(payload)) : Collections.emptyMap();
        this.createdAt = createdAt != null ? createdAt : Instant.now().toString();
        this.expiresAt = expiresAt != null ? expiresAt : Instant.now().plusSeconds(300).toString();
        this.isConsumed = isConsumed;
        this.senderPublicKey = senderPublicKey;
        this.signature = signature;
    }

    public String getMessageId() { return messageId; }
    public String getSenderPeerId() { return senderPeerId; }
    public String getRecipientPeerId() { return recipientPeerId; }
    public Type getMessageType() { return messageType; }
    public Map<String, Object> getPayload() { return payload; }
    public String getCreatedAt() { return createdAt; }
    public String getExpiresAt() { return expiresAt; }
    public boolean isConsumed() { return isConsumed; }
    public String getSenderPublicKey() { return senderPublicKey; }
    public String getSignature() { return signature; }

    public boolean isCryptographicallySigned() {
        return signature != null && !signature.isBlank() &&
               senderPublicKey != null && !senderPublicKey.isBlank();
    }

    public boolean isExpired() {
        try {
            return Instant.parse(expiresAt).isBefore(Instant.now());
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Computes the deterministic canonical byte representation for cryptographic signing.
     */
    public byte[] getCanonicalSigningBytes() {
        String canonical = senderPeerId + "|" + recipientPeerId + "|" + messageType.name() + "|" +
                createdAt + "|" + expiresAt + "|" + SimpleJson.stringify(payload);
        return canonical.getBytes(StandardCharsets.UTF_8);
    }

    /**
     * Produces a cryptographically signed copy of this signaling message.
     */
    public SignalingMessage withSignature(Function<byte[], byte[]> signer, String senderPublicKey) {
        Objects.requireNonNull(signer, "signer must not be null");
        byte[] sigBytes = signer.apply(getCanonicalSigningBytes());
        String sigBase64 = Base64.getEncoder().encodeToString(sigBytes);
        return new SignalingMessage(
                messageId, senderPeerId, recipientPeerId, messageType, payload,
                createdAt, expiresAt, isConsumed, senderPublicKey, sigBase64
        );
    }

    /**
     * Verifies the cryptographic signature against the provided verifier function.
     * @param verifier BiFunction taking (canonicalBytes, signatureBytes) and returning boolean
     */
    public boolean verifySignature(BiFunction<byte[], byte[], Boolean> verifier) {
        if (!isCryptographicallySigned()) return false;
        try {
            byte[] sigBytes = Base64.getDecoder().decode(signature);
            return verifier.apply(getCanonicalSigningBytes(), sigBytes);
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
        if (senderPublicKey != null) map.put("sender_public_key", senderPublicKey);
        if (signature != null) map.put("signature", signature);
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
        String pubKey = (String) map.get("sender_public_key");
        String sig = (String) map.get("signature");

        return new SignalingMessage(
                id, sender, recipient, type, payloadMap, created, expires,
                consumed != null && consumed,
                pubKey, sig
        );
    }
}
