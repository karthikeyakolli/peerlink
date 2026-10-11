package org.peerlink.core.cloud.supabase;

import java.util.Objects;

/**
 * Immutable configuration for the Supabase Control Plane.
 *
 * SECURITY INVARIANT:
 * Client nodes (Desktop & Android) must ONLY possess the public anon key.
 * Service role keys are strictly forbidden and rejected at construction.
 */
public final class SupabaseConfig {

    private final String supabaseUrl;
    private final String anonKey;
    private final SupabaseEnvironment environment;
    private final int connectTimeoutMs;
    private final int requestTimeoutMs;
    private final int circuitBreakerThreshold;
    private final long circuitBreakerResetMs;
    private final int presenceHeartbeatSeconds;
    private final int presenceTtlSeconds;

    private SupabaseConfig(Builder builder) {
        this.supabaseUrl = sanitizeUrl(Objects.requireNonNull(builder.supabaseUrl, "supabaseUrl must not be null"));
        this.anonKey = Objects.requireNonNull(builder.anonKey, "anonKey must not be null");
        this.environment = Objects.requireNonNull(builder.environment, "environment must not be null");
        this.connectTimeoutMs = builder.connectTimeoutMs;
        this.requestTimeoutMs = builder.requestTimeoutMs;
        this.circuitBreakerThreshold = builder.circuitBreakerThreshold;
        this.circuitBreakerResetMs = builder.circuitBreakerResetMs;
        this.presenceHeartbeatSeconds = builder.presenceHeartbeatSeconds;
        this.presenceTtlSeconds = builder.presenceTtlSeconds;

        validateSecurityConstraints();
    }

    private String sanitizeUrl(String url) {
        String trimmed = url.trim();
        if (trimmed.endsWith("/")) {
            return trimmed.substring(0, trimmed.length() - 1);
        }
        return trimmed;
    }

    private void validateSecurityConstraints() {
        // Guard against accidental leak or usage of service_role keys
        String lowerKey = anonKey.toLowerCase();
        if (lowerKey.contains("service_role") || lowerKey.contains("secret")) {
            throw new SecurityException("CRITICAL SECURITY ERROR: service-role secrets must NEVER be configured on client nodes!");
        }
        if (!supabaseUrl.startsWith("http://") && !supabaseUrl.startsWith("https://")) {
            throw new IllegalArgumentException("Supabase URL must start with http:// or https://: " + supabaseUrl);
        }
        if (environment == SupabaseEnvironment.PRODUCTION && !supabaseUrl.startsWith("https://")) {
            throw new SecurityException("Production Supabase URL must use TLS (https://)");
        }
    }

    public String getSupabaseUrl() { return supabaseUrl; }
    public String getAnonKey() { return anonKey; }
    public SupabaseEnvironment getEnvironment() { return environment; }
    public int getConnectTimeoutMs() { return connectTimeoutMs; }
    public int getRequestTimeoutMs() { return requestTimeoutMs; }
    public int getCircuitBreakerThreshold() { return circuitBreakerThreshold; }
    public long getCircuitBreakerResetMs() { return circuitBreakerResetMs; }
    public int getPresenceHeartbeatSeconds() { return presenceHeartbeatSeconds; }
    public int getPresenceTtlSeconds() { return presenceTtlSeconds; }

    public String getRestEndpoint() {
        return supabaseUrl + "/rest/v1";
    }

    public String getAuthEndpoint() {
        return supabaseUrl + "/auth/v1";
    }

    public String getRealtimeEndpoint() {
        String wsUrl = supabaseUrl.replaceFirst("^http", "ws");
        return wsUrl + "/realtime/v1/websocket?apikey=" + anonKey + "&vsn=1.0.0";
    }

    public static Builder builder() {
        return new Builder();
    }

    public static SupabaseConfig development(String supabaseUrl, String anonKey) {
        return builder()
                .supabaseUrl(supabaseUrl)
                .anonKey(anonKey)
                .environment(SupabaseEnvironment.DEVELOPMENT)
                .build();
    }

    public static final class Builder {
        private String supabaseUrl;
        private String anonKey;
        private SupabaseEnvironment environment = SupabaseEnvironment.DEVELOPMENT;
        private int connectTimeoutMs = 5000;
        private int requestTimeoutMs = 10000;
        private int circuitBreakerThreshold = 3;
        private long circuitBreakerResetMs = 15000;
        private int presenceHeartbeatSeconds = 20;
        private int presenceTtlSeconds = 60;

        public Builder supabaseUrl(String supabaseUrl) {
            this.supabaseUrl = supabaseUrl;
            return this;
        }

        public Builder anonKey(String anonKey) {
            this.anonKey = anonKey;
            return this;
        }

        public Builder environment(SupabaseEnvironment environment) {
            this.environment = environment;
            return this;
        }

        public Builder connectTimeoutMs(int connectTimeoutMs) {
            this.connectTimeoutMs = connectTimeoutMs;
            return this;
        }

        public Builder requestTimeoutMs(int requestTimeoutMs) {
            this.requestTimeoutMs = requestTimeoutMs;
            return this;
        }

        public Builder circuitBreakerThreshold(int threshold) {
            this.circuitBreakerThreshold = threshold;
            return this;
        }

        public Builder circuitBreakerResetMs(long resetMs) {
            this.circuitBreakerResetMs = resetMs;
            return this;
        }

        public Builder presenceHeartbeatSeconds(int seconds) {
            this.presenceHeartbeatSeconds = seconds;
            return this;
        }

        public Builder presenceTtlSeconds(int seconds) {
            this.presenceTtlSeconds = seconds;
            return this;
        }

        public SupabaseConfig build() {
            return new SupabaseConfig(this);
        }
    }
}
