package org.peerlink.core.cloud.supabase;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * PostgREST Data API client for querying and modifying durable control-plane tables in Supabase.
 * Invariant: Never used for storing file content or transfer payloads.
 */
public class SupabaseRestClient {

    private final SupabaseConfig config;
    private final HttpClient httpClient;
    private final CircuitBreaker circuitBreaker;
    private final RetryPolicy retryPolicy;

    public SupabaseRestClient(SupabaseConfig config) {
        this(config, HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(config.getConnectTimeoutMs()))
                .build(),
                new CircuitBreaker(config.getCircuitBreakerThreshold(), config.getCircuitBreakerResetMs()),
                RetryPolicy.defaultPolicy());
    }

    public SupabaseRestClient(SupabaseConfig config, HttpClient httpClient,
                              CircuitBreaker circuitBreaker, RetryPolicy retryPolicy) {
        this.config = Objects.requireNonNull(config, "config must not be null");
        this.httpClient = Objects.requireNonNull(httpClient, "httpClient must not be null");
        this.circuitBreaker = circuitBreaker != null ? circuitBreaker
                : new CircuitBreaker(config.getCircuitBreakerThreshold(), config.getCircuitBreakerResetMs());
        this.retryPolicy = retryPolicy != null ? retryPolicy : RetryPolicy.defaultPolicy();
    }

    public CircuitBreaker getCircuitBreaker() {
        return circuitBreaker;
    }

    public List<Map<String, Object>> select(String table, String queryParams, String authToken) throws IOException {
        String url = buildUrl(table, queryParams);
        HttpRequest.Builder builder = createRequestBuilder(url, authToken)
                .GET();

        String responseBody = execute(builder.build());
        return parseListResponse(responseBody);
    }

    public List<Map<String, Object>> insert(String table, Object body, String authToken) throws IOException {
        String url = buildUrl(table, null);
        String json = SimpleJson.stringify(body);

        HttpRequest.Builder builder = createRequestBuilder(url, authToken)
                .header("Prefer", "return=representation")
                .POST(HttpRequest.BodyPublishers.ofString(json));

        String responseBody = execute(builder.build());
        return parseListResponse(responseBody);
    }

    public List<Map<String, Object>> upsert(String table, Object body, String authToken, String onConflict) throws IOException {
        String query = onConflict != null ? "on_conflict=" + onConflict : null;
        String url = buildUrl(table, query);
        String json = SimpleJson.stringify(body);

        HttpRequest.Builder builder = createRequestBuilder(url, authToken)
                .header("Prefer", "return=representation,resolution=merge-duplicates")
                .POST(HttpRequest.BodyPublishers.ofString(json));

        String responseBody = execute(builder.build());
        return parseListResponse(responseBody);
    }

    public List<Map<String, Object>> update(String table, String queryParams, Object body, String authToken) throws IOException {
        String url = buildUrl(table, queryParams);
        String json = SimpleJson.stringify(body);

        HttpRequest.Builder builder = createRequestBuilder(url, authToken)
                .header("Prefer", "return=representation")
                .method("PATCH", HttpRequest.BodyPublishers.ofString(json));

        String responseBody = execute(builder.build());
        return parseListResponse(responseBody);
    }

    public void delete(String table, String queryParams, String authToken) throws IOException {
        String url = buildUrl(table, queryParams);
        HttpRequest.Builder builder = createRequestBuilder(url, authToken)
                .DELETE();

        execute(builder.build());
    }

    private String buildUrl(String table, String queryParams) {
        String base = config.getRestEndpoint() + "/" + table;
        if (queryParams != null && !queryParams.isBlank()) {
            return base + "?" + queryParams;
        }
        return base;
    }

    private HttpRequest.Builder createRequestBuilder(String url, String authToken) {
        String token = (authToken != null && !authToken.isBlank()) ? authToken : config.getAnonKey();
        return HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("apikey", config.getAnonKey())
                .header("Authorization", "Bearer " + token)
                .header("Content-Type", "application/json")
                .timeout(Duration.ofMillis(config.getRequestTimeoutMs()));
    }

    private String execute(HttpRequest request) throws IOException {
        try {
            return retryPolicy.execute(() -> {
                HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
                int status = response.statusCode();
                String body = response.body();

                if (status >= 500) {
                    throw new SupabaseOutageException("Supabase REST service error (HTTP " + status + ")", status);
                }
                if (status >= 400) {
                    throw new IOException("Supabase PostgREST error (HTTP " + status + "): " + body);
                }
                return body != null ? body : "";
            }, circuitBreaker);
        } catch (Exception e) {
            if (e instanceof IOException) throw (IOException) e;
            throw new IOException("Failed to execute PostgREST request", e);
        }
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> parseListResponse(String json) {
        if (json == null || json.isBlank()) return Collections.emptyList();
        Object parsed = SimpleJson.parse(json);
        if (parsed instanceof List) {
            return (List<Map<String, Object>>) parsed;
        } else if (parsed instanceof Map) {
            return Collections.singletonList((Map<String, Object>) parsed);
        }
        return Collections.emptyList();
    }
}
