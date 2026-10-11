package org.peerlink.core.cloud.supabase;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

/**
 * Direct HTTPS client for Supabase GoTrue Auth API.
 * Handles user sign-up, password authentication, session token refresh, and logout.
 */
public class SupabaseAuthClient {

    private final SupabaseConfig config;
    private final HttpClient httpClient;
    private final CircuitBreaker circuitBreaker;
    private final RetryPolicy retryPolicy;

    public SupabaseAuthClient(SupabaseConfig config) {
        this(config, HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(config.getConnectTimeoutMs()))
                .build(),
                new CircuitBreaker(config.getCircuitBreakerThreshold(), config.getCircuitBreakerResetMs()),
                RetryPolicy.defaultPolicy());
    }

    public SupabaseAuthClient(SupabaseConfig config, HttpClient httpClient,
                              CircuitBreaker circuitBreaker, RetryPolicy retryPolicy) {
        this.config = Objects.requireNonNull(config, "config must not be null");
        this.httpClient = Objects.requireNonNull(httpClient, "httpClient must not be null");
        this.circuitBreaker = circuitBreaker;
        this.retryPolicy = retryPolicy != null ? retryPolicy : RetryPolicy.defaultPolicy();
    }

    public CircuitBreaker getCircuitBreaker() {
        return circuitBreaker;
    }

    public SupabaseAuthSession signUp(String email, String password) throws IOException {
        String url = config.getAuthEndpoint() + "/signup";
        Map<String, Object> body = new HashMap<>();
        body.put("email", email);
        body.put("password", password);
        return executeAuthRequest(url, body);
    }

    public SupabaseAuthSession signInWithPassword(String email, String password) throws IOException {
        String url = config.getAuthEndpoint() + "/token?grant_type=password";
        Map<String, Object> body = new HashMap<>();
        body.put("email", email);
        body.put("password", password);
        return executeAuthRequest(url, body);
    }

    public SupabaseAuthSession refreshSession(String refreshToken) throws IOException {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new IllegalArgumentException("Refresh token must not be null or blank");
        }
        String url = config.getAuthEndpoint() + "/token?grant_type=refresh_token";
        Map<String, Object> body = new HashMap<>();
        body.put("refresh_token", refreshToken);
        return executeAuthRequest(url, body);
    }

    public void signOut(String accessToken) throws IOException {
        String url = config.getAuthEndpoint() + "/logout";
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("apikey", config.getAnonKey())
                .header("Authorization", "Bearer " + (accessToken != null ? accessToken : config.getAnonKey()))
                .header("Content-Type", "application/json")
                .timeout(Duration.ofMillis(config.getRequestTimeoutMs()))
                .POST(HttpRequest.BodyPublishers.noBody())
                .build();

        try {
            retryPolicy.execute(() -> {
                HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
                if (response.statusCode() >= 400 && response.statusCode() != 401) {
                    throw new SupabaseOutageException("Logout failed with status " + response.statusCode(), response.statusCode());
                }
                return null;
            }, circuitBreaker);
        } catch (Exception e) {
            if (e instanceof IOException) throw (IOException) e;
            throw new IOException("Failed to sign out", e);
        }
    }

    private SupabaseAuthSession executeAuthRequest(String url, Map<String, Object> bodyMap) throws IOException {
        String jsonPayload = SimpleJson.stringify(bodyMap);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("apikey", config.getAnonKey())
                .header("Content-Type", "application/json")
                .timeout(Duration.ofMillis(config.getRequestTimeoutMs()))
                .POST(HttpRequest.BodyPublishers.ofString(jsonPayload))
                .build();

        try {
            return retryPolicy.execute(() -> {
                HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
                int status = response.statusCode();
                String body = response.body();

                if (status >= 500) {
                    throw new SupabaseOutageException("Supabase Auth service unavailable (HTTP " + status + ")", status);
                }

                Map<String, Object> respMap = SimpleJson.parseObject(body);
                if (status >= 400) {
                    String msg = (String) respMap.get("error_description");
                    if (msg == null) msg = (String) respMap.get("msg");
                    if (msg == null) msg = (String) respMap.get("message");
                    if (msg == null) msg = "Auth error (" + status + ")";
                    throw new IOException("Auth failure: " + msg);
                }

                return SupabaseAuthSession.fromJson(respMap);
            }, circuitBreaker);
        } catch (Exception e) {
            if (e instanceof IOException) throw (IOException) e;
            throw new IOException("Supabase Auth request failed", e);
        }
    }
}
