package org.peerlink.core.cloud.supabase;

import java.io.IOException;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.BiFunction;
import java.util.function.Consumer;
import java.util.function.Function;

/**
 * Main coordinator for PeerLink's Supabase Control Plane integration.
 * Orchestrates:
 * 1. Authentication lifecycle & automatic token refresh.
 * 2. Cryptographic Device Registration (binding user account to Ed25519 identity).
 * 3. Heartbeat presence announcements & short-lived connectivity candidate publication.
 * 4. Ephemeral signaling message delivery & consumption (WebRTC negotiation).
 * 5. Outage resilience and durable catch-up reconciliation.
 *
 * CRITICAL ARCHITECTURAL INVARIANT:
 * No user file contents or transfer chunks ever touch Supabase. Supabase is strictly control plane.
 */
public class SupabaseControlPlaneCoordinator {

    private final SupabaseConfig config;
    private final SupabaseAuthClient authClient;
    private final SupabaseDeviceRegistryClient registryClient;
    private final CircuitBreaker circuitBreaker;

    private final AtomicBoolean isRunning = new AtomicBoolean(false);
    private final AtomicBoolean isDegraded = new AtomicBoolean(false);

    private SupabaseAuthSession currentSession;
    private DeviceRegistryEntry localDevice;
    private List<String> currentCandidateEndpoints = Collections.emptyList();

    private ScheduledExecutorService backgroundExecutor;
    private ScheduledFuture<?> presenceHeartbeatTask;
    private ScheduledFuture<?> tokenRefreshTask;
    private ScheduledFuture<?> durableCatchUpTask;

    private Consumer<SignalingMessage> signalingListener;
    private Consumer<Boolean> outageListener;
    private Consumer<DevicePresenceEntry> presenceListener;

    private final SignalingRateLimiter rateLimiter = new SignalingRateLimiter();
    private Function<byte[], byte[]> cryptographicSigner;
    private BiFunction<byte[], byte[], Boolean> cryptographicVerifier;

    public SupabaseControlPlaneCoordinator(SupabaseConfig config,
                                           SupabaseAuthClient authClient,
                                           SupabaseDeviceRegistryClient registryClient) {
        this.config = Objects.requireNonNull(config, "config must not be null");
        this.authClient = Objects.requireNonNull(authClient, "authClient must not be null");
        this.registryClient = Objects.requireNonNull(registryClient, "registryClient must not be null");
        this.circuitBreaker = authClient.getCircuitBreaker();

        if (this.circuitBreaker != null) {
            this.circuitBreaker.setStateChangeListener(state -> {
                boolean degraded = (state == CircuitBreaker.State.OPEN);
                boolean changed = isDegraded.compareAndSet(!degraded, degraded);
                if (changed && outageListener != null) {
                    outageListener.accept(degraded);
                }
            });
        }
    }

    public SignalingRateLimiter getRateLimiter() {
        return rateLimiter;
    }

    public void setCryptographicSigner(Function<byte[], byte[]> signer) {
        this.cryptographicSigner = signer;
    }

    public void setCryptographicVerifier(BiFunction<byte[], byte[], Boolean> verifier) {
        this.cryptographicVerifier = verifier;
    }

    public synchronized void start(SupabaseAuthSession session, DeviceRegistryEntry device, List<String> candidateEndpoints) throws IOException {
        if (isRunning.get()) return;
        this.currentSession = Objects.requireNonNull(session, "session must not be null");
        this.localDevice = Objects.requireNonNull(device, "device must not be null");
        this.currentCandidateEndpoints = candidateEndpoints != null ? new ArrayList<>(candidateEndpoints) : Collections.emptyList();
        this.isRunning.set(true);

        this.backgroundExecutor = Executors.newScheduledThreadPool(2, r -> {
            Thread t = new Thread(r, "peerlink-supabase-coordinator");
            t.setDaemon(true);
            return t;
        });

        // 1. Register device with Supabase
        registerLocalDevice();

        // 2. Publish initial presence
        publishPresence("ONLINE");

        // 3. Schedule heartbeat presence task
        int heartbeatInterval = config.getPresenceHeartbeatSeconds();
        this.presenceHeartbeatTask = backgroundExecutor.scheduleAtFixedRate(
                this::runPresenceHeartbeat,
                heartbeatInterval,
                heartbeatInterval,
                TimeUnit.SECONDS
        );

        // 4. Schedule token auto-refresh check (every 60 seconds)
        this.tokenRefreshTask = backgroundExecutor.scheduleAtFixedRate(
                this::checkAndRefreshToken,
                60,
                60,
                TimeUnit.SECONDS
        );

        // 5. Schedule periodic durable catch-up query (every 10 seconds)
        this.durableCatchUpTask = backgroundExecutor.scheduleAtFixedRate(
                this::performDurableCatchUp,
                5,
                10,
                TimeUnit.SECONDS
        );
    }

    public synchronized void stop() {
        if (!isRunning.get()) return;
        isRunning.set(false);

        // Mark presence as OFFLINE before shutting down if possible
        try {
            publishPresence("OFFLINE");
        } catch (Exception ignored) {}

        if (presenceHeartbeatTask != null) presenceHeartbeatTask.cancel(true);
        if (tokenRefreshTask != null) tokenRefreshTask.cancel(true);
        if (durableCatchUpTask != null) durableCatchUpTask.cancel(true);

        if (backgroundExecutor != null) {
            backgroundExecutor.shutdownNow();
        }
    }

    public boolean isRunning() {
        return isRunning.get();
    }

    public boolean isDegraded() {
        return isDegraded.get();
    }

    public SupabaseAuthSession getCurrentSession() {
        return currentSession;
    }

    public void setSignalingListener(Consumer<SignalingMessage> listener) {
        this.signalingListener = listener;
    }

    public void setOutageListener(Consumer<Boolean> listener) {
        this.outageListener = listener;
    }

    public void setPresenceListener(Consumer<DevicePresenceEntry> listener) {
        this.presenceListener = listener;
    }

    public synchronized void updateCandidateEndpoints(List<String> newEndpoints) {
        this.currentCandidateEndpoints = new ArrayList<>(newEndpoints);
        runPresenceHeartbeat();
    }

    public SignalingMessage sendSignaling(String recipientPeerId, SignalingMessage.Type type, Map<String, Object> payload) throws IOException {
        rateLimiter.acquireOrThrow(recipientPeerId);
        ensureActiveSession();
        SignalingMessage msg = new SignalingMessage(
                UUID.randomUUID().toString(),
                localDevice.getPeerId(),
                recipientPeerId,
                type,
                payload,
                Instant.now().toString(),
                Instant.now().plusSeconds(300).toString(),
                false
        );

        if (cryptographicSigner != null && localDevice.getPublicKey() != null) {
            msg = msg.withSignature(cryptographicSigner, localDevice.getPublicKey());
        }

        try {
            return registryClient.sendSignalingMessage(msg, currentSession.getAccessToken());
        } catch (SupabaseOutageException e) {
            handleOutage(e);
            throw e;
        }
    }

    public void performDurableCatchUp() {
        if (!isRunning.get() || currentSession == null || localDevice == null) return;

        try {
            ensureActiveSession();
            List<SignalingMessage> pending = registryClient.fetchPendingSignalingMessages(
                    localDevice.getPeerId(),
                    currentSession.getAccessToken()
            );

            for (SignalingMessage msg : pending) {
                // 1. Check expiration
                if (msg.isExpired()) {
                    registryClient.markSignalingMessageConsumed(msg.getMessageId(), currentSession.getAccessToken());
                    continue;
                }

                // 2. Check recipient authorization
                if (!localDevice.getPeerId().equals(msg.getRecipientPeerId())) {
                    registryClient.markSignalingMessageConsumed(msg.getMessageId(), currentSession.getAccessToken());
                    continue;
                }

                // 3. Cryptographic signature verification if configured
                if (cryptographicVerifier != null && msg.isCryptographicallySigned()) {
                    boolean valid = msg.verifySignature(cryptographicVerifier);
                    if (!valid) {
                        // Drop tampered / forged message
                        registryClient.markSignalingMessageConsumed(msg.getMessageId(), currentSession.getAccessToken());
                        continue;
                    }
                }

                if (signalingListener != null) {
                    signalingListener.accept(msg);
                }
                registryClient.markSignalingMessageConsumed(msg.getMessageId(), currentSession.getAccessToken());
            }

            if (isDegraded.compareAndSet(true, false)) {
                if (outageListener != null) outageListener.accept(false);
            }
        } catch (Exception e) {
            handleOutage(e);
        }
    }

    public synchronized void checkAndRefreshToken() {
        if (currentSession == null) return;
        // Refresh if within 5 minutes of expiration
        if (currentSession.needsRefresh(300)) {
            try {
                this.currentSession = authClient.refreshSession(currentSession.getRefreshToken());
            } catch (Exception e) {
                handleOutage(e);
            }
        }
    }

    private void registerLocalDevice() throws IOException {
        try {
            this.localDevice = registryClient.registerDevice(localDevice, currentSession.getAccessToken());
        } catch (SupabaseOutageException e) {
            handleOutage(e);
            throw e;
        }
    }

    private void runPresenceHeartbeat() {
        if (!isRunning.get()) return;
        try {
            publishPresence("ONLINE");
        } catch (Exception e) {
            handleOutage(e);
        }
    }

    private void publishPresence(String status) throws IOException {
        if (currentSession == null || localDevice == null || localDevice.getDeviceId() == null) return;

        DevicePresenceEntry presence = new DevicePresenceEntry(
                localDevice.getDeviceId(),
                status,
                currentCandidateEndpoints,
                Instant.now().toString(),
                config.getPresenceTtlSeconds()
        );

        registryClient.updatePresence(presence, currentSession.getAccessToken());
    }

    private void ensureActiveSession() throws IOException {
        if (currentSession != null && currentSession.isExpired()) {
            checkAndRefreshToken();
            if (currentSession.isExpired()) {
                throw new IOException("Supabase Auth session has expired and could not be refreshed");
            }
        }
    }

    private void handleOutage(Throwable t) {
        boolean degraded = true;
        if (isDegraded.compareAndSet(false, degraded)) {
            if (outageListener != null) {
                outageListener.accept(true);
            }
        }
    }
}
