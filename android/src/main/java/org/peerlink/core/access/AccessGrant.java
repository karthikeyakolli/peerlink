package org.peerlink.core.access;

import org.peerlink.protocol.v1.AccessScope;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Explicit authorization grant issued to a remote peer to access a designated share.
 * Contains cryptographic HMAC authentication so tokens cannot be forged or tampered with.
 */
public record AccessGrant(
        String grantId,
        String shareId,
        String requesterPeerId,
        Set<AccessScope> scopes,
        long issuedAtUtcMs,
        long expiresAtUtcMs,
        String signatureHex
) {
    private static final String HMAC_SHA256 = "HmacSHA256";

    public AccessGrant {
        scopes = scopes == null ? Set.of() : Collections.unmodifiableSet(new HashSet<>(scopes));
    }

    public boolean isExpired(long nowUtcMs) {
        return expiresAtUtcMs > 0 && nowUtcMs > expiresAtUtcMs;
    }

    public boolean hasScope(AccessScope scope) {
        return scopes.contains(AccessScope.ACCESS_SCOPE_FULL) || scopes.contains(scope);
    }

    /**
     * Creates and signs an AccessGrant.
     */
    public static AccessGrant issue(
            String grantId,
            String shareId,
            String requesterPeerId,
            Set<AccessScope> scopes,
            long issuedAtUtcMs,
            long expiresAtUtcMs,
            String authSecret
    ) {
        String payload = buildSigningPayload(grantId, shareId, requesterPeerId, scopes, expiresAtUtcMs);
        String signature = computeHmacSha256(payload, authSecret);
        return new AccessGrant(grantId, shareId, requesterPeerId, scopes, issuedAtUtcMs, expiresAtUtcMs, signature);
    }

    /**
     * Serializes grant into a portable opaque authorization token string.
     */
    public String toToken() {
        String scopeStr = scopes.stream().map(Enum::name).sorted().collect(Collectors.joining(","));
        String raw = String.join("|",
                grantId,
                shareId,
                requesterPeerId,
                scopeStr,
                String.valueOf(issuedAtUtcMs),
                String.valueOf(expiresAtUtcMs),
                signatureHex
        );
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Parses an authorization token string.
     */
    public static Optional<AccessGrant> parseToken(String token) {
        if (token == null || token.isBlank()) {
            return Optional.empty();
        }
        try {
            byte[] decoded = Base64.getUrlDecoder().decode(token);
            String raw = new String(decoded, StandardCharsets.UTF_8);
            String[] parts = raw.split("\\|", -1);
            if (parts.length != 7) {
                return Optional.empty();
            }
            String grantId = parts[0];
            String shareId = parts[1];
            String requesterPeerId = parts[2];
            Set<AccessScope> scopes = new HashSet<>();
            if (!parts[3].isBlank()) {
                for (String s : parts[3].split(",")) {
                    try {
                        scopes.add(AccessScope.valueOf(s));
                    } catch (IllegalArgumentException ignored) {}
                }
            }
            long issuedAt = Long.parseLong(parts[4]);
            long expiresAt = Long.parseLong(parts[5]);
            String signature = parts[6];
            return Optional.of(new AccessGrant(grantId, shareId, requesterPeerId, scopes, issuedAt, expiresAt, signature));
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    /**
     * Validates this grant against the share's secret and verifies signature integrity.
     */
    public boolean verifySignature(String authSecret) {
        if (signatureHex == null || signatureHex.isBlank() || authSecret == null) {
            return false;
        }
        String payload = buildSigningPayload(grantId, shareId, requesterPeerId, scopes, expiresAtUtcMs);
        String expected = computeHmacSha256(payload, authSecret);
        return constantTimeEquals(expected, signatureHex);
    }

    private static String buildSigningPayload(String grantId, String shareId, String peerId, Set<AccessScope> scopes, long expiresAt) {
        String sortedScopes = scopes.stream().map(Enum::name).sorted().collect(Collectors.joining(","));
        return grantId + ":" + shareId + ":" + peerId + ":" + sortedScopes + ":" + expiresAt;
    }

    private static String computeHmacSha256(String data, String key) {
        try {
            Mac mac = Mac.getInstance(HMAC_SHA256);
            mac.init(new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), HMAC_SHA256));
            byte[] rawHmac = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(rawHmac.length * 2);
            for (byte b : rawHmac) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new IllegalStateException("Failed to calculate HMAC-SHA256", e);
        }
    }

    private static boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) return false;
        if (a.length() != b.length()) return false;
        int result = 0;
        for (int i = 0; i < a.length(); i++) {
            result |= a.charAt(i) ^ b.charAt(i);
        }
        return result == 0;
    }
}
