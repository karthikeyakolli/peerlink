package org.peerlink.desktop.runtime;

import io.grpc.Server;
import io.grpc.ServerBuilder;
import org.peerlink.core.event.NodeEvent;
import org.peerlink.core.event.NodeEventBus;
import org.peerlink.desktop.ipc.DesktopLocalNodeServiceImpl;
import org.peerlink.desktop.ipc.LocalTokenAuthInterceptor;
import org.peerlink.desktop.storage.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.Closeable;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.SQLException;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Main daemon managing the Desktop Local Node runtime.
 * Manages SQLite storage, authenticated gRPC IPC server, and lifecycle (start, stop, restart, health).
 */
public final class DesktopNodeDaemon implements Closeable {
    private static final Logger log = LoggerFactory.getLogger(DesktopNodeDaemon.class);

    private final NodeConfiguration configuration;
    private final String peerId;
    private final NodeEventBus eventBus = new NodeEventBus();

    private Server grpcServer;
    private LocalSqliteStorage sqliteStorage;
    private DesktopLocalNodeServiceImpl ipcService;
    private ResourceLimitsPolicy limitsPolicy;
    private StartupRecoveryManager recoveryManager;
    private ReconciliationFramework reconciliationFramework;
    private StartupRecoveryManager.RecoveryReport lastRecoveryReport;
    private org.peerlink.core.transfer.PeerTransferEngine transferEngine;
    private final AtomicBoolean running = new AtomicBoolean(false);

    public DesktopNodeDaemon(NodeConfiguration configuration) {
        this.configuration = configuration;
        this.peerId = "peer_" + UUID.randomUUID().toString().substring(0, 8);
    }

    public synchronized void start() throws IOException, SQLException {
        if (running.get()) {
            log.warn("Desktop Local Node daemon is already running.");
            return;
        }

        log.info("Starting Desktop Local Node daemon (Peer ID: {})...", peerId);
        eventBus.publish(new NodeEvent.NodeLifecycleChanged(
                eventBus.nextSequence(), Instant.now(), NodeEvent.NodeLifecycleState.STARTING, "Initializing node runtime"));

        // 1. Initialize SQLite Local Storage
        sqliteStorage = new LocalSqliteStorage(configuration.getDatabasePath());
        limitsPolicy = new ResourceLimitsPolicy(eventBus);
        reconciliationFramework = new ReconciliationFramework(sqliteStorage);
        recoveryManager = new StartupRecoveryManager(sqliteStorage, eventBus);

        // 2. Run Startup Recovery
        try {
            lastRecoveryReport = recoveryManager.runRecovery("Node start");
        } catch (StartupRecoveryManager.StartupRecoveryException e) {
            log.error("Fatal startup recovery failure: {}", e.getMessage(), e);
            stop();
            throw new RuntimeException("Node startup aborted due to recovery failure", e);
        }

        // 3. Initialize Transfer Engine
        Path stagingRoot = configuration.getDataDirectory().resolve("staging");
        transferEngine = new org.peerlink.core.transfer.PeerTransferEngine(sqliteStorage, stagingRoot);

        // 4. Start Authenticated Loopback gRPC IPC Server
        LocalTokenAuthInterceptor authInterceptor = new LocalTokenAuthInterceptor(configuration.getIpcAuthToken());
        ipcService = new DesktopLocalNodeServiceImpl(
                configuration.getIpcAuthToken(),
                peerId,
                configuration.getIpcPort(),
                this::restartAsync,
                this::stop,
                transferEngine
        );

        InetSocketAddress bindAddress = new InetSocketAddress(NodeConfiguration.DEFAULT_HOST, configuration.getIpcPort());
        grpcServer = ServerBuilder.forPort(configuration.getIpcPort())
                .addService(ipcService)
                .intercept(authInterceptor)
                .build()
                .start();

        running.set(true);
        eventBus.publish(new NodeEvent.NodeLifecycleChanged(
                eventBus.nextSequence(), Instant.now(), NodeEvent.NodeLifecycleState.RUNNING, "Node is fully operational"));
        log.info("Desktop Local Node IPC server listening on {}:{}", NodeConfiguration.DEFAULT_HOST, configuration.getIpcPort());
    }

    public synchronized void stop() {
        if (!running.get()) {
            return;
        }
        log.info("Shutting down Desktop Local Node daemon...");
        eventBus.publish(new NodeEvent.NodeLifecycleChanged(
                eventBus.nextSequence(), Instant.now(), NodeEvent.NodeLifecycleState.STOPPING, "Node shutdown initiated"));

        if (ipcService != null) {
            ipcService.close();
            ipcService = null;
        }
        if (grpcServer != null) {
            log.info("Shutting down gRPC IPC server...");
            grpcServer.shutdown();
            try {
                if (!grpcServer.awaitTermination(3, java.util.concurrent.TimeUnit.SECONDS)) {
                    grpcServer.shutdownNow();
                }
            } catch (InterruptedException e) {
                grpcServer.shutdownNow();
                Thread.currentThread().interrupt();
            }
            grpcServer = null;
        }
        if (sqliteStorage != null) {
            sqliteStorage.close();
            sqliteStorage = null;
        }

        running.set(false);
        eventBus.publish(new NodeEvent.NodeLifecycleChanged(
                eventBus.nextSequence(), Instant.now(), NodeEvent.NodeLifecycleState.STOPPED, "Node shutdown complete"));
        log.info("Desktop Local Node daemon stopped.");
    }

    public synchronized void restart() throws IOException, SQLException {
        log.info("Restarting Desktop Local Node daemon...");
        stop();
        start();
        log.info("Desktop Local Node daemon restarted successfully.");
    }

    private void restartAsync() {
        new Thread(() -> {
            try {
                restart();
            } catch (Exception e) {
                log.error("Failed to restart daemon: {}", e.getMessage(), e);
            }
        }, "peerlink-node-restart").start();
    }

    public boolean isHealthy() {
        if (!running.get() || grpcServer == null || grpcServer.isShutdown() || sqliteStorage == null) {
            return false;
        }
        try {
            return sqliteStorage.checkIntegrity();
        } catch (SQLException e) {
            log.error("Integrity check failed: {}", e.getMessage());
            return false;
        }
    }

    public String getPeerId() { return peerId; }
    public NodeConfiguration getConfiguration() { return configuration; }
    public boolean isRunning() { return running.get(); }
    public DesktopLocalNodeServiceImpl getIpcService() { return ipcService; }
    public NodeEventBus getEventBus() { return eventBus; }
    public LocalSqliteStorage getSqliteStorage() { return sqliteStorage; }
    public ResourceLimitsPolicy getLimitsPolicy() { return limitsPolicy; }
    public ReconciliationFramework getReconciliationFramework() { return reconciliationFramework; }
    public StartupRecoveryManager.RecoveryReport getLastRecoveryReport() { return lastRecoveryReport; }
    public ObjectIndexRepository getObjectIndex() { return sqliteStorage != null ? sqliteStorage.getObjectIndex() : null; }
    public org.peerlink.core.transfer.PeerTransferEngine getTransferEngine() { return transferEngine; }

    @Override
    public void close() {
        stop();
    }

    public static void main(String[] args) throws Exception {
        Path dataDir = Paths.get(System.getProperty("user.home"), ".peerlink");
        int port = NodeConfiguration.DEFAULT_IPC_PORT;
        String token = null;

        for (int i = 0; i < args.length; i++) {
            if ("--port".equals(args[i]) && i + 1 < args.length) {
                port = Integer.parseInt(args[++i]);
            } else if ("--data-dir".equals(args[i]) && i + 1 < args.length) {
                dataDir = Paths.get(args[++i]);
            } else if ("--token".equals(args[i]) && i + 1 < args.length) {
                token = args[++i];
            }
        }

        NodeConfiguration config = NodeConfiguration.loadOrCreate(dataDir, port, token);
        DesktopNodeDaemon daemon = new DesktopNodeDaemon(config);
        daemon.start();

        Runtime.getRuntime().addShutdownHook(new Thread(daemon::stop));
        log.info("Desktop Node Daemon started. Press Ctrl+C to terminate.");
        Thread.currentThread().join();
    }
}
