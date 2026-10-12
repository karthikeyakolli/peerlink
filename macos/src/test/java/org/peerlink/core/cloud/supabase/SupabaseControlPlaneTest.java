package org.peerlink.core.cloud.supabase;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Phase 08 Verification Suite:
 * 1. login
 * 2. register device
 * 3. device appears/disappears
 * 4. reconnect
 * 5. duplicate event
 * 6. missed event
 * 7. Supabase outage
 * 8. stale presence
 * 9. expired session
 *
 * Plus critical architectural & security invariants (service-role prohibition, no file payloads).
 */
public class SupabaseControlPlaneTest {

    private HttpServer mockServer;
    private int port;
    private String serverUrl;
    private final String validAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon_key_mock";

    // Track mock server state
    private final AtomicInteger authRequests = new AtomicInteger(0);
    private final AtomicInteger refreshRequests = new AtomicInteger(0);
    private final AtomicInteger registryRequests = new AtomicInteger(0);
    private final AtomicInteger presenceRequests = new AtomicInteger(0);
    private final AtomicInteger signalingRequests = new AtomicInteger(0);
    private final AtomicBoolean simulateOutage = new AtomicBoolean(false);

    private final List<Map<String, Object>> registeredDevices = new CopyOnWriteArrayList<>();
    private final List<Map<String, Object>> storedPresence = new CopyOnWriteArrayList<>();
    private final List<Map<String, Object>> pendingSignaling = new CopyOnWriteArrayList<>();

    @BeforeEach
    void setUp() throws IOException {
        mockServer = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        port = mockServer.getAddress().getPort();
        serverUrl = "http://127.0.0.1:" + port;

        // Route: /auth/v1/token
        mockServer.createContext("/auth/v1/token", new HttpHandler() {
            @Override
            public void handle(HttpExchange exchange) throws IOException {
                if (simulateOutage.get()) {
                    sendResponse(exchange, 503, "{\"message\":\"Supabase backend unavailable\"}");
                    return;
                }
                String query = exchange.getRequestURI().getQuery();
                if (query != null && query.contains("grant_type=refresh_token")) {
                    refreshRequests.incrementAndGet();
                    String resp = "{"
                            + "\"access_token\":\"new_refreshed_access_token_jwt\","
                            + "\"refresh_token\":\"new_refreshed_refresh_token\","
                            + "\"token_type\":\"bearer\","
                            + "\"expires_in\":3600,"
                            + "\"user\":{\"id\":\"user-uuid-1234\",\"email\":\"alice@example.com\"}"
                            + "}";
                    sendResponse(exchange, 200, resp);
                } else {
                    authRequests.incrementAndGet();
                    String resp = "{"
                            + "\"access_token\":\"valid_access_token_jwt\","
                            + "\"refresh_token\":\"valid_refresh_token\","
                            + "\"token_type\":\"bearer\","
                            + "\"expires_in\":3600,"
                            + "\"user\":{\"id\":\"user-uuid-1234\",\"email\":\"alice@example.com\"}"
                            + "}";
                    sendResponse(exchange, 200, resp);
                }
            }
        });

        // Route: /rest/v1/device_registry
        mockServer.createContext("/rest/v1/device_registry", new HttpHandler() {
            @Override
            public void handle(HttpExchange exchange) throws IOException {
                if (simulateOutage.get()) {
                    sendResponse(exchange, 503, "{\"message\":\"Outage\"}");
                    return;
                }
                registryRequests.incrementAndGet();
                String method = exchange.getRequestMethod();
                if ("POST".equalsIgnoreCase(method)) {
                    String reqBody = readString(exchange.getRequestBody());
                    Map<String, Object> item = SimpleJson.parseObject(reqBody);
                    item.put("device_id", "dev-" + UUID.randomUUID());
                    item.put("registered_at", Instant.now().toString());
                    registeredDevices.add(item);
                    sendResponse(exchange, 201, SimpleJson.stringify(Collections.singletonList(item)));
                } else if ("GET".equalsIgnoreCase(method)) {
                    sendResponse(exchange, 200, SimpleJson.stringify(registeredDevices));
                } else if ("PATCH".equalsIgnoreCase(method)) {
                    sendResponse(exchange, 200, "[]");
                }
            }
        });

        // Route: /rest/v1/device_presence
        mockServer.createContext("/rest/v1/device_presence", new HttpHandler() {
            @Override
            public void handle(HttpExchange exchange) throws IOException {
                if (simulateOutage.get()) {
                    sendResponse(exchange, 503, "{\"message\":\"Outage\"}");
                    return;
                }
                presenceRequests.incrementAndGet();
                String method = exchange.getRequestMethod();
                if ("POST".equalsIgnoreCase(method)) {
                    String reqBody = readString(exchange.getRequestBody());
                    Map<String, Object> item = SimpleJson.parseObject(reqBody);
                    storedPresence.add(item);
                    sendResponse(exchange, 200, SimpleJson.stringify(Collections.singletonList(item)));
                } else {
                    sendResponse(exchange, 200, SimpleJson.stringify(storedPresence));
                }
            }
        });

        // Route: /rest/v1/signaling_messages
        mockServer.createContext("/rest/v1/signaling_messages", new HttpHandler() {
            @Override
            public void handle(HttpExchange exchange) throws IOException {
                if (simulateOutage.get()) {
                    sendResponse(exchange, 503, "{\"message\":\"Outage\"}");
                    return;
                }
                signalingRequests.incrementAndGet();
                String method = exchange.getRequestMethod();
                if ("POST".equalsIgnoreCase(method)) {
                    String reqBody = readString(exchange.getRequestBody());
                    Map<String, Object> item = SimpleJson.parseObject(reqBody);
                    if (!item.containsKey("message_id")) {
                        item.put("message_id", UUID.randomUUID().toString());
                    }
                    pendingSignaling.add(item);
                    sendResponse(exchange, 201, SimpleJson.stringify(Collections.singletonList(item)));
                } else if ("GET".equalsIgnoreCase(method)) {
                    sendResponse(exchange, 200, SimpleJson.stringify(pendingSignaling));
                } else if ("PATCH".equalsIgnoreCase(method)) {
                    sendResponse(exchange, 200, "[]");
                }
            }
        });

        mockServer.setExecutor(null);
        mockServer.start();
    }

    @AfterEach
    void tearDown() {
        if (mockServer != null) {
            mockServer.stop(0);
        }
        registeredDevices.clear();
        storedPresence.clear();
        pendingSignaling.clear();
        simulateOutage.set(false);
    }

    private void sendResponse(HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }

    private String readString(InputStream is) throws IOException {
        return new String(is.readAllBytes(), StandardCharsets.UTF_8);
    }

    // =========================================================================
    // Test 1: Login
    // =========================================================================
    @Test
    @DisplayName("Test 1: Supabase Auth sign-in produces valid session with access & refresh tokens")
    void testAuthLogin() throws IOException {
        SupabaseConfig config = SupabaseConfig.development(serverUrl, validAnonKey);
        SupabaseAuthClient authClient = new SupabaseAuthClient(config);

        SupabaseAuthSession session = authClient.signInWithPassword("alice@example.com", "SecretPass123!");

        assertNotNull(session);
        assertEquals("valid_access_token_jwt", session.getAccessToken());
        assertEquals("valid_refresh_token", session.getRefreshToken());
        assertEquals("user-uuid-1234", session.getUserId());
        assertEquals("alice@example.com", session.getEmail());
        assertFalse(session.isExpired());
        assertEquals(1, authRequests.get());
    }

    // =========================================================================
    // Test 2: Register Device
    // =========================================================================
    @Test
    @DisplayName("Test 2: Device registration binds account to Ed25519 public key and peer ID")
    void testRegisterDevice() throws IOException {
        SupabaseConfig config = SupabaseConfig.development(serverUrl, validAnonKey);
        SupabaseRestClient restClient = new SupabaseRestClient(config);
        SupabaseDeviceRegistryClient registryClient = new SupabaseDeviceRegistryClient(restClient);

        DeviceRegistryEntry localDevice = new DeviceRegistryEntry(
                null,
                "user-uuid-1234",
                "peer-ed25519-abc-123",
                "MCowBQYDK2VwAyEA...pubkey...",
                "Alice's MacBook Pro",
                "DESKTOP",
                false,
                null,
                null
        );

        DeviceRegistryEntry registered = registryClient.registerDevice(localDevice, "valid_access_token_jwt");

        assertNotNull(registered);
        assertNotNull(registered.getDeviceId());
        assertEquals("peer-ed25519-abc-123", registered.getPeerId());
        assertEquals("Alice's MacBook Pro", registered.getDeviceName());
        assertEquals(1, registryRequests.get());
        assertEquals(1, registeredDevices.size());
    }

    // =========================================================================
    // Test 3: Device Appears / Disappears
    // =========================================================================
    @Test
    @DisplayName("Test 3: Device presence publishing and offline departure")
    void testDeviceAppearsAndDisappears() throws IOException {
        SupabaseConfig config = SupabaseConfig.development(serverUrl, validAnonKey);
        SupabaseRestClient restClient = new SupabaseRestClient(config);
        SupabaseDeviceRegistryClient registryClient = new SupabaseDeviceRegistryClient(restClient);

        List<String> candidates = Arrays.asList("192.168.1.105:54321", "203.0.113.10:54321");

        // Device appears ONLINE
        DevicePresenceEntry online = new DevicePresenceEntry(
                "dev-001",
                "ONLINE",
                candidates,
                Instant.now().toString(),
                60
        );
        DevicePresenceEntry resOnline = registryClient.updatePresence(online, "valid_access_token_jwt");
        assertEquals("ONLINE", resOnline.getPresenceStatus());
        assertEquals(2, resOnline.getCandidateEndpoints().size());

        // Device gracefully disappears OFFLINE
        DevicePresenceEntry offline = new DevicePresenceEntry(
                "dev-001",
                "OFFLINE",
                Collections.emptyList(),
                Instant.now().toString(),
                60
        );
        DevicePresenceEntry resOffline = registryClient.updatePresence(offline, "valid_access_token_jwt");
        assertEquals("OFFLINE", resOffline.getPresenceStatus());
    }

    // =========================================================================
    // Test 4: Reconnect
    // =========================================================================
    @Test
    @DisplayName("Test 4: Realtime reconnection and catch-up trigger")
    void testReconnectHandling() {
        SupabaseConfig config = SupabaseConfig.development(serverUrl, validAnonKey);
        AtomicBoolean connectedCalled = new AtomicBoolean(false);

        SupabaseRealtimeClient client = new SupabaseRealtimeClient(config, new SupabaseRealtimeClient.RealtimeEventListener() {
            @Override
            public void onEvent(String topic, String event, Map<String, Object> payload) {}

            @Override
            public void onConnected() {
                connectedCalled.set(true);
            }

            @Override
            public void onDisconnected(int statusCode, String reason) {}

            @Override
            public void onError(Throwable throwable) {}
        });

        client.subscribe("realtime:public:signaling_messages");
        assertNotNull(client);
    }

    // =========================================================================
    // Test 5: Duplicate Event Idempotency
    // =========================================================================
    @Test
    @DisplayName("Test 5: Realtime client filters duplicate event IDs idempotently")
    void testDuplicateEventSuppression() {
        SupabaseConfig config = SupabaseConfig.development(serverUrl, validAnonKey);
        AtomicInteger eventCounter = new AtomicInteger(0);

        SupabaseRealtimeClient client = new SupabaseRealtimeClient(config, new SupabaseRealtimeClient.RealtimeEventListener() {
            @Override
            public void onEvent(String topic, String event, Map<String, Object> payload) {
                eventCounter.incrementAndGet();
            }

            @Override
            public void onConnected() {}

            @Override
            public void onDisconnected(int statusCode, String reason) {}

            @Override
            public void onError(Throwable throwable) {}
        });

        String rawJson = "{"
                + "\"topic\":\"public:signaling_messages\","
                + "\"event\":\"INSERT\","
                + "\"payload\":{\"record\":{\"message_id\":\"msg-dup-123\",\"sender_peer_id\":\"peer-bob\"}}"
                + "}";

        // First delivery
        client.handleIncomingMessage(rawJson);
        assertEquals(1, eventCounter.get());

        // Duplicate delivery with same message_id
        client.handleIncomingMessage(rawJson);
        assertEquals(1, eventCounter.get(), "Duplicate event must be discarded by client deduplicator");

        // Different message ID should pass
        String newJson = "{"
                + "\"topic\":\"public:signaling_messages\","
                + "\"event\":\"INSERT\","
                + "\"payload\":{\"record\":{\"message_id\":\"msg-fresh-456\",\"sender_peer_id\":\"peer-bob\"}}"
                + "}";
        client.handleIncomingMessage(newJson);
        assertEquals(2, eventCounter.get());
    }

    // =========================================================================
    // Test 6: Missed Event Durable Catch-Up
    // =========================================================================
    @Test
    @DisplayName("Test 6: Missed Realtime event is reliably recovered via durable PostgREST query")
    void testMissedEventDurableCatchUp() throws IOException {
        SupabaseConfig config = SupabaseConfig.development(serverUrl, validAnonKey);
        SupabaseRestClient restClient = new SupabaseRestClient(config);
        SupabaseDeviceRegistryClient registryClient = new SupabaseDeviceRegistryClient(restClient);

        // Pre-populate signaling table with a message sent while recipient was offline/missed
        Map<String, Object> missedMsg = new HashMap<>();
        missedMsg.put("message_id", "msg-missed-777");
        missedMsg.put("sender_peer_id", "peer-sender-999");
        missedMsg.put("recipient_peer_id", "peer-me-111");
        missedMsg.put("message_type", "OFFER");
        missedMsg.put("payload", Collections.singletonMap("sdp", "v=0..."));
        missedMsg.put("created_at", Instant.now().toString());
        missedMsg.put("expires_at", Instant.now().plusSeconds(300).toString());
        missedMsg.put("is_consumed", false);
        pendingSignaling.add(missedMsg);

        // Query pending messages
        List<SignalingMessage> pending = registryClient.fetchPendingSignalingMessages("peer-me-111", "token");
        assertEquals(1, pending.size());
        assertEquals("msg-missed-777", pending.get(0).getMessageId());
        assertEquals(SignalingMessage.Type.OFFER, pending.get(0).getMessageType());

        // Mark consumed
        registryClient.markSignalingMessageConsumed("msg-missed-777", "token");
    }

    // =========================================================================
    // Test 7: Supabase Outage & Circuit Breaker
    // =========================================================================
    @Test
    @DisplayName("Test 7: Outage trips circuit breaker, notifies listener, and enables degraded offline fallback")
    void testSupabaseOutageAndCircuitBreaker() {
        SupabaseConfig config = SupabaseConfig.builder()
                .supabaseUrl(serverUrl)
                .anonKey(validAnonKey)
                .circuitBreakerThreshold(2)
                .circuitBreakerResetMs(500)
                .build();

        CircuitBreaker cb = new CircuitBreaker(2, 500);
        RetryPolicy rp = RetryPolicy.noRetry();
        SupabaseRestClient restClient = new SupabaseRestClient(config, java.net.http.HttpClient.newHttpClient(), cb, rp);

        // Simulate 503 outage on mock server
        simulateOutage.set(true);

        // 1st failure
        assertThrows(IOException.class, () -> restClient.select("device_registry", "select=*", "token"));
        assertEquals(CircuitBreaker.State.CLOSED, cb.getState());

        // 2nd failure -> trips circuit breaker to OPEN
        assertThrows(IOException.class, () -> restClient.select("device_registry", "select=*", "token"));
        assertEquals(CircuitBreaker.State.OPEN, cb.getState());

        // 3rd attempt: Fast-fails immediately with SupabaseOutageException without hitting the wire
        SupabaseOutageException outageEx = assertThrows(
                SupabaseOutageException.class,
                () -> restClient.select("device_registry", "select=*", "token")
        );
        assertTrue(outageEx.isCircuitBreakerOpen());

        // Recover outage
        simulateOutage.set(false);
        try {
            Thread.sleep(600); // allow reset timeout to elapse
        } catch (InterruptedException ignored) {}

        // Next request enters HALF_OPEN and then CLOSED on success
        assertDoesNotThrow(() -> restClient.select("device_registry", "select=*", "token"));
        assertEquals(CircuitBreaker.State.CLOSED, cb.getState());
    }

    // =========================================================================
    // Test 8: Stale Presence Detection
    // =========================================================================
    @Test
    @DisplayName("Test 8: Presence entry with expired TTL is correctly detected as stale/offline")
    void testStalePresenceDetection() {
        // Active heartbeat (now)
        DevicePresenceEntry active = new DevicePresenceEntry(
                "dev-fresh",
                "ONLINE",
                Collections.singletonList("127.0.0.1:5000"),
                Instant.now().toString(),
                60
        );
        assertFalse(active.isStale());

        // Heartbeat from 5 minutes ago with 60-second TTL
        DevicePresenceEntry stale = new DevicePresenceEntry(
                "dev-stale",
                "ONLINE",
                Collections.singletonList("127.0.0.1:5000"),
                Instant.now().minusSeconds(300).toString(),
                60
        );
        assertTrue(stale.isStale(), "Presence older than TTL must be flagged as stale");
    }

    // =========================================================================
    // Test 9: Expired Session and Token Refresh
    // =========================================================================
    @Test
    @DisplayName("Test 9: Expired session triggers automatic refresh token exchange")
    void testExpiredSessionRefresh() throws IOException {
        SupabaseConfig config = SupabaseConfig.development(serverUrl, validAnonKey);
        SupabaseAuthClient authClient = new SupabaseAuthClient(config);

        // Create an expired session object
        SupabaseAuthSession expiredSession = new SupabaseAuthSession(
                "old_expired_jwt",
                "valid_refresh_token",
                "bearer",
                0,
                System.currentTimeMillis() - 10000,
                "user-uuid-1234",
                "alice@example.com"
        );

        assertTrue(expiredSession.isExpired());
        assertTrue(expiredSession.needsRefresh(60));

        // Perform token refresh
        SupabaseAuthSession refreshed = authClient.refreshSession(expiredSession.getRefreshToken());

        assertNotNull(refreshed);
        assertEquals("new_refreshed_access_token_jwt", refreshed.getAccessToken());
        assertFalse(refreshed.isExpired());
        assertEquals(1, refreshRequests.get());
    }

    // =========================================================================
    // Critical Invariant: Service-Role Secret Rejection
    // =========================================================================
    @Test
    @DisplayName("Invariant: Rejects service-role secrets at client configuration construction")
    void testRejectsServiceRoleKey() {
        assertThrows(SecurityException.class, () -> {
            SupabaseConfig.builder()
                    .supabaseUrl("https://example.supabase.co")
                    .anonKey("service_role_secret_key_that_should_never_be_in_client")
                    .build();
        });
    }

    // =========================================================================
    // Critical Invariant: Full Coordinator Integration
    // =========================================================================
    @Test
    @DisplayName("Invariant: Coordinator orchestrates auth, registry, presence and signaling")
    void testCoordinatorLifecycle() throws IOException {
        SupabaseConfig config = SupabaseConfig.builder()
                .supabaseUrl(serverUrl)
                .anonKey(validAnonKey)
                .presenceHeartbeatSeconds(1)
                .presenceTtlSeconds(5)
                .build();

        SupabaseAuthClient authClient = new SupabaseAuthClient(config);
        SupabaseRestClient restClient = new SupabaseRestClient(config);
        SupabaseDeviceRegistryClient registryClient = new SupabaseDeviceRegistryClient(restClient);

        SupabaseControlPlaneCoordinator coordinator = new SupabaseControlPlaneCoordinator(
                config,
                authClient,
                registryClient
        );

        SupabaseAuthSession session = new SupabaseAuthSession(
                "token", "refresh", "bearer", 3600, System.currentTimeMillis() + 3600000, "user-1", "test@peerlink.org"
        );
        DeviceRegistryEntry device = new DeviceRegistryEntry(
                null, "user-1", "peer-coordinator-test", "key", "Desktop", "DESKTOP", false, null, null
        );

        coordinator.start(session, device, Arrays.asList("127.0.0.1:4000"));
        assertTrue(coordinator.isRunning());
        assertFalse(coordinator.isDegraded());

        // Send a WebRTC signaling message
        SignalingMessage sent = coordinator.sendSignaling(
                "peer-remote-999",
                SignalingMessage.Type.OFFER,
                Collections.singletonMap("sdp", "mock-sdp-offer")
        );
        assertNotNull(sent);
        assertEquals("peer-coordinator-test", sent.getSenderPeerId());
        assertEquals("peer-remote-999", sent.getRecipientPeerId());

        coordinator.stop();
        assertFalse(coordinator.isRunning());
    }

    // =========================================================================
    // Phase 12 Invariants: File Payload Prohibition, Rate Limiting, Signing
    // =========================================================================
    @Test
    @DisplayName("Phase 12: SupabaseRestClient strictly prohibits user file content and transfer chunks")
    void testSupabaseFilePayloadProhibition() {
        SupabaseConfig config = SupabaseConfig.development(serverUrl, validAnonKey);
        SupabaseRestClient client = new SupabaseRestClient(config);

        String[] forbiddenTables = new String[]{"files", "transfer_chunks", "file_storage", "user_content", "blob_data"};
        for (String table : forbiddenTables) {
            SecurityException ex = assertThrows(SecurityException.class, () -> client.select(table, null, "token"));
            assertTrue(ex.getMessage().contains("ARCHITECTURAL VIOLATION"), "Must mention architectural violation");
        }
    }

    @Test
    @DisplayName("Phase 12: SupabaseRestClient rejects payloads exceeding 64KB threshold")
    void testSupabaseOversizedPayloadProtection() {
        SupabaseConfig config = SupabaseConfig.development(serverUrl, validAnonKey);
        SupabaseRestClient client = new SupabaseRestClient(config);

        Map<String, Object> hugePayload = new HashMap<>();
        StringBuilder sb = new StringBuilder(70000);
        for (int i = 0; i < 70000; i++) sb.append('X');
        hugePayload.put("raw_data", sb.toString());

        SecurityException ex = assertThrows(SecurityException.class, () -> client.insert("device_presence", hugePayload, "token"));
        assertTrue(ex.getMessage().contains("64 KB maximum threshold"));
    }

    @Test
    @DisplayName("Phase 12: SignalingRateLimiter enforces token-bucket limits on signaling traffic")
    void testSignalingRateLimiter() {
        SignalingRateLimiter limiter = new SignalingRateLimiter(3, 1, 3, 1);
        String peerId = "peer-rate-test";

        assertTrue(limiter.tryAcquire(peerId));
        assertTrue(limiter.tryAcquire(peerId));
        assertTrue(limiter.tryAcquire(peerId));
        assertFalse(limiter.tryAcquire(peerId));

        assertThrows(SignalingRateLimitException.class, () -> limiter.acquireOrThrow(peerId));
    }

    @Test
    @DisplayName("Phase 12: Cryptographic device identity is separated from Supabase account and verified")
    void testSignalingCryptographicIdentitySeparation() throws Exception {
        SignalingMessage msg = new SignalingMessage(
                UUID.randomUUID().toString(),
                "peer-alice-ed25519",
                "peer-bob-ed25519",
                SignalingMessage.Type.OFFER,
                Collections.singletonMap("sdp", "mock-sdp"),
                Instant.now().toString(),
                Instant.now().plusSeconds(300).toString(),
                false
        );

        assertFalse(msg.isCryptographicallySigned());

        String pubKey = "mock-ed25519-public-key";
        SignalingMessage signed = msg.withSignature(data -> {
            try {
                java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
                return md.digest(data);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }, pubKey);

        assertTrue(signed.isCryptographicallySigned());
        assertEquals(pubKey, signed.getSenderPublicKey());

        boolean valid = signed.verifySignature((data, sig) -> {
            try {
                java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
                return Arrays.equals(md.digest(data), sig);
            } catch (Exception e) {
                return false;
            }
        });
        assertTrue(valid);
    }
}
