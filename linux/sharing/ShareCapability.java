package org.peerlink.core.sharing;

import org.peerlink.protocol.v1.SharePermission;
import org.peerlink.protocol.v1.ShareType;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Opaque capability token issued to a holder (peer or guest).
 * Cryptographically signed with the share's authSecret (HMAC-SHA256).
 * Encoded as Base64-URL; opaque to intermediaries.
 * A share link is a capability, NOT a pointer to cloud file storage.
 */
public record ShareCapability(
        String tokenId,
        String shareId,
        ShareType shareType,
        Set<SharePermission> permissions,
        long issuedAtUtcMs,
        long expiresAtUtcMs,
        String boundPeerId,
        boolean isGuestToken,
        String operationId,
        String hmacSignatureHex
) {
    private static final String HMAC_SHA256 = "HmacSHA256";

    public ShareCapability {
        if (tokenId == null || tokenId.isBlank()) throw new IllegalArgumentException("tokenId cannot be blank");
        if (shareId == null || shareId.isBlank()) throw new IllegalArgumentException("shareId cannot be blank");
        permissions = permissions == null ? Set.of() : Collections.unmodifiableSet(new HashSet<>(permissions));
        boundPeerId = boundPeerId == null ? "" : boundPeerId;
        operationId = operationId == null ? "" : operationId;
    }

    public boolean isExpired(long nowUtcMs) {
        return expiresAtUtcMs > 0 && nowUtcMs > expiresAtUtcMs;
    }

    public boolean hasPermission(SharePermission p) {
        return permissions.contains(SharePermission.SHARE_PERMISSION_DOWNLOAD) || permissions.contains(p);
    }

    public boolean isBoundToGuest() { return isGuestToken; }
    public boolean isOneTime() { return !operationId.isBlank(); }

    public static ShareCapability issue(
            String shareId, ShareType shareType, Set<SharePermission> permissions,
            long issuedAtUtcMs, long expiresAtUtcMs, String boundPeerId, String authSecret) {
        return issueInternal(shareId, shareType, permissions, issuedAtUtcMs, expiresAtUtcMs,
                boundPeerId, false, "", authSecret);
    }

    public static ShareCapability issueOneTime(
            String shareId, ShareType shareType, Set<SharePermission> permissions,
            long issuedAtUtcMs, long expiresAtUtcMs, String boundPeerId, String operationId, String authSecret) {
        return issueInternal(shareId, shareType, permissions, issuedAtUtcMs, expiresAtUtcMs,
                boundPeerId, false, operationId, authSecret);
    }

    public static ShareCapability issueGuest(
            String shareId, Set<SharePermission> permissions,
            long issuedAtUtcMs, long expiresAtUtcMs, String authSecret) {
        return issueInternal(shareId, ShareType.SHARE_TYPE_GUEST, permissions, issuedAtUtcMs,
                expiresAtUtcMs, "", true, "", authSecret);
    }

    private static ShareCapability issueInternal(
            String shareId, ShareType shareType, Set<SharePermission> permissions,
            long issuedAtUtcMs, long expiresAtUtcMs, String boundPeerId,
            boolean isGuest, String operationId, String authSecret) {
        String tokenId = "cap_" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        String payload = buildPayload(tokenId, shareId, shareType, permissions, expiresAtUtcMs, boundPeerId, isGuest, operationId);
        String sig = hmacSha256(payload, authSecret);
        return new ShareCapability(tokenId, shareId, shareType, permissions, issuedAtUtcMs, expiresAtUtcMs, boundPeerId, isGuest, operationId, sig);
    }

    public String toToken() {
        String permsStr = permissions.stream().map(Enum::name).sorted().collect(Collectors.joining(","));
        String raw = String.join("|", tokenId, shareId, shareType.name(), permsStr,
                String.valueOf(issuedAtUtcMs), String.valueOf(expiresAtUtcMs),
                boundPeerId, String.valueOf(isGuestToken), operationId, hmacSignatureHex);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    public static Optional<ShareCapability> fromToken(String token) {
        if (token == null || token.isBlank()) return Optional.empty();
        try {
            String raw = new String(Base64.getUrlDecoder().decode(token), StandardCharsets.UTF_8);
            String[] p = raw.split("\\|", -1);
            if (p.length != 10) return Optional.empty();
            Set<SharePermission> perms = new HashSet<>();
            if (!p[3].isBlank()) {
                for (String s : p[3].split(",")) {
                    try { perms.add(SharePermission.valueOf(s)); } catch (IllegalArgumentException ignored) {}
                }
            }
            return Optional.of(new ShareCapability(p[0], p[1], ShareType.valueOf(p[2]), perms,
                    Long.parseLong(p[4]), Long.parseLong(p[5]), p[6], Boolean.parseBoolean(p[7]), p[8], p[9]));
        } catch (Exception e) { return Optional.empty(); }
    }

    public boolean verifySignature(String authSecret) {
        if (hmacSignatureHex == null || hmacSignatureHex.isBlank() || authSecret == null) return false;
        String payload = buildPayload(tokenId, shareId, shareType, permissions, expiresAtUtcMs, boundPeerId, isGuestToken, operationId);
        return constantTimeEquals(hmacSha256(payload, authSecret), hmacSignatureHex);
    }

    private static String buildPayload(String tokenId, String shareId, ShareType shareType,
            Set<SharePermission> permissions, long expiresAt, String boundPeerId, boolean isGuest, String operationId) {
        String permsStr = permissions.stream().map(Enum::name).sorted().collect(Collectors.joining(","));
        return tokenId + ":" + shareId + ":" + shareType.name() + ":" + permsStr + ":" + expiresAt + ":" + boundPeerId + ":" + isGuest + ":" + operationId;
    }

    private static String hmacSha256(String data, String key) {
        try {
            Mac mac = Mac.getInstance(HMAC_SHA256);
            mac.init(new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), HMAC_SHA256));
            byte[] raw = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(raw.length * 2);
            for (byte b : raw) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new IllegalStateException("HMAC-SHA256 failed", e);
        }
    }

    private static boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null || a.length() != b.length()) return false;
        int result = 0;
        for (int i = 0; i < a.length(); i++) result |= a.charAt(i) ^ b.charAt(i);
        return result == 0;
    }
}