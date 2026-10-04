package org.peerlink.core.cloud.supabase;

import java.util.Map;
import java.util.Objects;

/**
 * Encapsulates a Supabase Auth session with JWT access token and refresh token.
 */
public final class SupabaseAuthSession {

    private final String accessToken;
    private final String refreshToken;
    private final String tokenType;
    private final long expiresInSeconds;
    private final long expiresAtMillis;
    private final String userId;
    private final String email;

    public SupabaseAuthSession(String accessToken, String refreshToken, String tokenType,
                               long expiresInSeconds, long expiresAtMillis,
                               String userId, String email) {
        this.accessToken = Objects.requireNonNull(accessToken, "accessToken must not be null");
        this.refreshToken = refreshToken;
        this.tokenType = tokenType != null ? tokenType : "bearer";
        this.expiresInSeconds = expiresInSeconds;
        this.expiresAtMillis = expiresAtMillis;
        this.userId = userId;
        this.email = email;
    }

    public String getAccessToken() { return accessToken; }
    public String getRefreshToken() { return refreshToken; }
    public String getTokenType() { return tokenType; }
    public long getExpiresInSeconds() { return expiresInSeconds; }
    public long getExpiresAtMillis() { return expiresAtMillis; }
    public String getUserId() { return userId; }
    public String getEmail() { return email; }

    public boolean isExpired() {
        return System.currentTimeMillis() >= expiresAtMillis;
    }

    /**
     * Checks if the session needs refresh within a buffer period (default 60 seconds).
     */
    public boolean needsRefresh(long bufferSeconds) {
        return System.currentTimeMillis() + (bufferSeconds * 1000) >= expiresAtMillis;
    }

    @SuppressWarnings("unchecked")
    public static SupabaseAuthSession fromJson(Map<String, Object> json) {
        String access = (String) json.get("access_token");
        String refresh = (String) json.get("refresh_token");
        String tokenType = (String) json.get("token_type");
        Number exp = (Number) json.get("expires_in");
        long expiresIn = exp != null ? exp.longValue() : 3600;
        long expiresAt = System.currentTimeMillis() + (expiresIn * 1000);

        String uid = null;
        String email = null;
        Object userObj = json.get("user");
        if (userObj instanceof Map) {
            Map<String, Object> userMap = (Map<String, Object>) userObj;
            uid = (String) userMap.get("id");
            email = (String) userMap.get("email");
        }

        return new SupabaseAuthSession(access, refresh, tokenType, expiresIn, expiresAt, uid, email);
    }
}
