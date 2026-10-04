package org.peerlink.core.cloud.supabase;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.nio.ByteBuffer;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * WebSocket Realtime client for Supabase using Phoenix Channels protocol.
 * INVARIANT:
 * - Realtime is strictly an ephemeral notification trigger.
 * - Delivery is NOT guaranteed; durable state is always queried upon reconnect or timeout.
 * - Duplicate events are filtered via bounded LRU deduplication.
 */
public class SupabaseRealtimeClient {

    public interface RealtimeEventListener {
        void onEvent(String topic, String event, Map<String, Object> payload);
        void onConnected();
        void onDisconnected(int statusCode, String reason);
        void onError(Throwable throwable);
    }

    private final SupabaseConfig config;
    private final HttpClient httpClient;
    private final RealtimeEventListener listener;
    private final AtomicBoolean isRunning = new AtomicBoolean(false);
    private final AtomicLong messageRefCounter = new AtomicLong(0);

    private final Set<String> subscribedTopics = ConcurrentHashMap.newKeySet();
    private final Set<String> processedMessageIds = Collections.synchronizedSet(Collections.newSetFromMap(
            new LinkedHashMap<String, Boolean>(100, 0.75f, true) {
                @Override
                protected boolean removeEldestEntry(Map.Entry<String, Boolean> eldest) {
                    return size() > 2000;
                }
            }
    ));

    private WebSocket webSocket;
    private ScheduledExecutorService scheduler;
    private ScheduledFuture<?> heartbeatTask;
    private String authToken;

    public SupabaseRealtimeClient(SupabaseConfig config, RealtimeEventListener listener) {
        this(config, HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(config.getConnectTimeoutMs()))
                .build(), listener);
    }

    public SupabaseRealtimeClient(SupabaseConfig config, HttpClient httpClient, RealtimeEventListener listener) {
        this.config = Objects.requireNonNull(config, "config must not be null");
        this.httpClient = Objects.requireNonNull(httpClient, "httpClient must not be null");
        this.listener = listener;
    }

    public synchronized void start(String authToken) throws IOException {
        if (isRunning.get()) return;
        this.authToken = authToken;
        isRunning.set(true);

        this.scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "peerlink-supabase-realtime");
            t.setDaemon(true);
            return t;
        });

        connect();
    }

    public synchronized void stop() {
        isRunning.set(false);
        if (heartbeatTask != null) {
            heartbeatTask.cancel(true);
        }
        if (scheduler != null) {
            scheduler.shutdownNow();
        }
        if (webSocket != null) {
            try {
                webSocket.sendClose(WebSocket.NORMAL_CLOSURE, "Client shutdown");
            } catch (Exception ignored) {}
            webSocket = null;
        }
    }

    public boolean isConnected() {
        return webSocket != null && isRunning.get();
    }

    public void subscribe(String topic) {
        subscribedTopics.add(topic);
        if (webSocket != null) {
            sendJoinTopic(topic);
        }
    }

    public void unsubscribe(String topic) {
        subscribedTopics.remove(topic);
        if (webSocket != null) {
            sendLeaveTopic(topic);
        }
    }

    public boolean isDuplicateEvent(String eventId) {
        if (eventId == null || eventId.isBlank()) return false;
        synchronized (processedMessageIds) {
            if (processedMessageIds.contains(eventId)) {
                return true;
            }
            processedMessageIds.add(eventId);
            return false;
        }
    }

    private synchronized void connect() {
        if (!isRunning.get()) return;

        try {
            String wsUri = config.getRealtimeEndpoint();
            CompletableFuture<WebSocket> future = httpClient.newWebSocketBuilder()
                    .connectTimeout(Duration.ofMillis(config.getConnectTimeoutMs()))
                    .header("apikey", config.getAnonKey())
                    .buildAsync(URI.create(wsUri), new WebSocketListenerImpl());

            this.webSocket = future.get(config.getConnectTimeoutMs(), TimeUnit.MILLISECONDS);

            // Re-subscribe to all pending topics
            for (String topic : subscribedTopics) {
                sendJoinTopic(topic);
            }

            // Start heartbeat task (every 25 seconds)
            heartbeatTask = scheduler.scheduleAtFixedRate(this::sendHeartbeat, 25, 25, TimeUnit.SECONDS);

            if (listener != null) {
                listener.onConnected();
            }
        } catch (Exception e) {
            if (listener != null) {
                listener.onError(e);
            }
            scheduleReconnect();
        }
    }

    private void scheduleReconnect() {
        if (!isRunning.get()) return;
        scheduler.schedule(() -> {
            if (isRunning.get()) {
                connect();
            }
        }, 5, TimeUnit.SECONDS);
    }

    private void sendHeartbeat() {
        if (webSocket == null) return;
        long ref = messageRefCounter.incrementAndGet();
        Map<String, Object> heartbeat = new HashMap<>();
        heartbeat.put("topic", "phoenix");
        heartbeat.put("event", "heartbeat");
        heartbeat.put("payload", Collections.emptyMap());
        heartbeat.put("ref", String.valueOf(ref));

        sendTextMessage(SimpleJson.stringify(heartbeat));
    }

    private void sendJoinTopic(String topic) {
        if (webSocket == null) return;
        long ref = messageRefCounter.incrementAndGet();
        Map<String, Object> joinMsg = new HashMap<>();
        joinMsg.put("topic", topic);
        joinMsg.put("event", "phx_join");
        Map<String, Object> payload = new HashMap<>();
        if (authToken != null) {
            payload.put("user_token", authToken);
        }
        joinMsg.put("payload", payload);
        joinMsg.put("ref", String.valueOf(ref));

        sendTextMessage(SimpleJson.stringify(joinMsg));
    }

    private void sendLeaveTopic(String topic) {
        if (webSocket == null) return;
        long ref = messageRefCounter.incrementAndGet();
        Map<String, Object> leaveMsg = new HashMap<>();
        leaveMsg.put("topic", topic);
        leaveMsg.put("event", "phx_leave");
        leaveMsg.put("payload", Collections.emptyMap());
        leaveMsg.put("ref", String.valueOf(ref));

        sendTextMessage(SimpleJson.stringify(leaveMsg));
    }

    private void sendTextMessage(String text) {
        if (webSocket != null) {
            try {
                webSocket.sendText(text, true);
            } catch (Exception e) {
                if (listener != null) listener.onError(e);
            }
        }
    }

    // Process incoming message payload
    @SuppressWarnings("unchecked")
    public void handleIncomingMessage(String rawJson) {
        try {
            Map<String, Object> msg = SimpleJson.parseObject(rawJson);
            String topic = (String) msg.get("topic");
            String event = (String) msg.get("event");
            Map<String, Object> payload = Collections.emptyMap();
            Object p = msg.get("payload");
            if (p instanceof Map) {
                payload = (Map<String, Object>) p;
            }

            // Extract potential deduplication ID (e.g. record id or message_id)
            String dedupId = null;
            Object recordObj = payload.get("record");
            if (recordObj instanceof Map) {
                Map<String, Object> rec = (Map<String, Object>) recordObj;
                dedupId = (String) rec.get("message_id");
                if (dedupId == null) dedupId = (String) rec.get("id");
            } else if (payload.containsKey("id")) {
                dedupId = String.valueOf(payload.get("id"));
            }

            if (dedupId != null && isDuplicateEvent(dedupId)) {
                // Drop duplicate event
                return;
            }

            if (listener != null) {
                listener.onEvent(topic, event, payload);
            }
        } catch (Exception e) {
            if (listener != null) {
                listener.onError(e);
            }
        }
    }

    private class WebSocketListenerImpl implements WebSocket.Listener {
        private final StringBuilder buffer = new StringBuilder();

        @Override
        public void onOpen(WebSocket ws) {
            ws.request(1);
        }

        @Override
        public CompletionStage<?> onText(WebSocket ws, CharSequence data, boolean last) {
            buffer.append(data);
            if (last) {
                String completeMessage = buffer.toString();
                buffer.setLength(0);
                handleIncomingMessage(completeMessage);
            }
            ws.request(1);
            return null;
        }

        @Override
        public CompletionStage<?> onClose(WebSocket ws, int statusCode, String reason) {
            webSocket = null;
            if (listener != null) {
                listener.onDisconnected(statusCode, reason);
            }
            scheduleReconnect();
            return null;
        }

        @Override
        public void onError(WebSocket ws, Throwable error) {
            webSocket = null;
            if (listener != null) {
                listener.onError(error);
            }
            scheduleReconnect();
        }
    }
}
