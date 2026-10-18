package org.peerlink.desktop.transport;

import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.transfer.FileManifestBuilder;
import org.peerlink.core.transport.PeerSession;
import org.peerlink.core.transport.TransportConnection;
import org.peerlink.desktop.runtime.DesktopNodeDaemon;
import org.peerlink.desktop.runtime.NodeConfiguration;
import org.peerlink.protocol.v1.*;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;

/**
 * End-to-end integration test for Phase 03:
 * Proves that an actual production DesktopNodeDaemon sends real files across
 * an authenticated PeerSession to an independent receiving DesktopNodeDaemon,
 * verifying chunk streaming, SHA-256 integrity, safe staging, and final atomic commit.
 */
public class RealSendWorkflowIntegrationTest {

    @TempDir
    Path tempDir;

    private DesktopNodeDaemon aliceDaemon;
    private DesktopNodeDaemon bobDaemon;
    private ManagedChannel aliceIpcChannel;
    private ManagedChannel bobIpcChannel;

    private DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceBlockingStub aliceStub;
    private DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceStub aliceAsyncStub;

    private String aliceToken;
    private String bobToken;

    @BeforeEach
    void setUp() throws IOException, SQLException {
        Path aliceDir = tempDir.resolve("alice_node");
        Path bobDir = tempDir.resolve("bob_node");
        Files.createDirectories(aliceDir);
        Files.createDirectories(bobDir);

        aliceToken = "test_alice_token_12345678901234567890";
        bobToken = "test_bob_token_12345678901234567890";

        // Ephemeral ports: ipcPort 0 and p2pPort 0
        NodeConfiguration aliceConfig = new NodeConfiguration(aliceDir, 0, aliceToken, 0);
        NodeConfiguration bobConfig = new NodeConfiguration(bobDir, 0, bobToken, 0);

        bobDaemon = new DesktopNodeDaemon(bobConfig);
        bobDaemon.start();

        aliceDaemon = new DesktopNodeDaemon(aliceConfig);
        aliceDaemon.start();

        // Mutually trust identities (cryptographic pairing)
        bobDaemon.getTrustStore().addTrustedPeer(aliceDaemon.getIdentityManager().getPeerIdentity());
        aliceDaemon.getTrustStore().addTrustedPeer(bobDaemon.getIdentityManager().getPeerIdentity());
    }

    @AfterEach
    void tearDown() {
        if (aliceIpcChannel != null) {
            aliceIpcChannel.shutdownNow();
        }
        if (bobIpcChannel != null) {
            bobIpcChannel.shutdownNow();
        }
        if (aliceDaemon != null) {
            aliceDaemon.stop();
        }
        if (bobDaemon != null) {
            bobDaemon.stop();
        }
    }

    @Test
    void testGenuineSendWorkflowAcrossNodesWithChunkIntegrityAndCommit() throws Exception {
        int bobP2pPort = bobDaemon.getTcpTransport().getListeningPort();
        assertTrue(bobP2pPort > 0, "Bob P2P port must be listening");

        // Alice connects to Bob over TCP transport and handshakes
        TransportConnection connection = aliceDaemon.getTcpTransport()
                .connectAsync(new InetSocketAddress("127.0.0.1", bobP2pPort))
                .get(5, TimeUnit.SECONDS);

        PeerSession aliceSession = aliceDaemon.getSessionManager()
                .initiateSessionAsync(connection)
                .get(5, TimeUnit.SECONDS);

        assertNotNull(aliceSession);
        assertEquals(SessionState.SESSION_STATE_ESTABLISHED, aliceSession.getState());
        assertEquals(bobDaemon.getPeerId(), aliceSession.getRemotePeer().getPeerId().getValue());

        // Wait for Bob's session manager to register Alice's inbound session
        PeerSession bobSession = null;
        for (int i = 0; i < 50; i++) {
            var opt = bobDaemon.getSessionManager().getSessionByPeerId(aliceDaemon.getPeerId());
            if (opt.isPresent()) {
                bobSession = opt.get();
                break;
            }
            Thread.sleep(50);
        }
        assertNotNull(bobSession, "Bob must register session for Alice");

        // Create multi-chunk test file (150 KB) to ensure bounded chunk streaming
        Path sourceFile = tempDir.resolve("alice_source.dat");
        byte[] payloadData = new byte[150 * 1024];
        for (int i = 0; i < payloadData.length; i++) {
            payloadData[i] = (byte) ((i * 31) & 0xFF);
        }
        Files.write(sourceFile, payloadData);
        String expectedSha256 = FileManifestBuilder.calculateSha256Hex(sourceFile);

        // Authenticate Alice IPC client
        AuthenticateIpcResponse authResp = aliceDaemon.getIpcService().authenticateDirect(
                aliceToken, 9999, "0.1.0");
        assertTrue(authResp.getAuthenticated());
        String sessionToken = authResp.getSessionToken();

        // Listen for progress events via CountDownLatch
        CountDownLatch completedLatch = new CountDownLatch(1);
        AtomicReference<TransferProgress> finalProgress = new AtomicReference<>();
        List<TransferProgress> progressUpdates = new ArrayList<>();

        // Initiate send via Alice's Local Node IPC
        InitiateSendRequest sendReq = InitiateSendRequest.newBuilder()
                .setSessionToken(sessionToken)
                .setTargetPeerId(PeerId.newBuilder().setValue(bobDaemon.getPeerId()).build())
                .addSourcePaths(sourceFile.toAbsolutePath().toString())
                .setDuplicatePolicy(DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX)
                .build();

        CountDownLatch responseLatch = new CountDownLatch(1);
        AtomicReference<InitiateSendResponse> sendRespRef = new AtomicReference<>();

        aliceDaemon.getIpcService().initiateSend(sendReq, new io.grpc.stub.StreamObserver<>() {
            @Override
            public void onNext(InitiateSendResponse value) {
                sendRespRef.set(value);
            }

            @Override
            public void onError(Throwable t) {
                responseLatch.countDown();
            }

            @Override
            public void onCompleted() {
                responseLatch.countDown();
            }
        });

        assertTrue(responseLatch.await(5, TimeUnit.SECONDS), "InitiateSend must respond promptly");
        InitiateSendResponse sendResp = sendRespRef.get();
        assertNotNull(sendResp);
        assertTrue(sendResp.getAccepted(), "Send request must be accepted: " + sendResp.getErrorMessage());
        assertFalse(sendResp.getTransferId().isBlank());
        String transferId = sendResp.getTransferId();

        // Await transfer completion
        Path bobReceivedDir = bobDaemon.getConfiguration().getDataDirectory().resolve("received");
        Path receivedFile = bobReceivedDir.resolve("alice_source.dat");

        boolean fileAppeared = false;
        for (int i = 0; i < 100; i++) {
            if (Files.exists(receivedFile) && Files.size(receivedFile) == payloadData.length) {
                fileAppeared = true;
                break;
            }
            Thread.sleep(100);
        }

        assertTrue(fileAppeared, "Received file must be committed to Bob's received directory");

        // Verify SHA-256 integrity of received file
        String actualSha256 = FileManifestBuilder.calculateSha256Hex(receivedFile);
        assertEquals(expectedSha256, actualSha256, "Full-file SHA-256 on receiver must exactly match sender");

        // Verify Bob's staging directory has no leftover staging files for this transfer
        Path bobStaging = bobDaemon.getConfiguration().getDataDirectory().resolve("staging").resolve(transferId);
        assertFalse(Files.exists(bobStaging), "Staging directory for transfer must be cleaned up after commit");
    }

    @Test
    void testUntrustedPeerIsRejectedAndCannotTransmit() throws Exception {
        int bobP2pPort = bobDaemon.getTcpTransport().getListeningPort();

        // Create third untrusted peer Eve
        Path eveDir = tempDir.resolve("eve_node");
        Files.createDirectories(eveDir);
        NodeConfiguration eveConfig = new NodeConfiguration(eveDir, 0, "token_eve", 0);
        DesktopNodeDaemon eveDaemon = new DesktopNodeDaemon(eveConfig);
        eveDaemon.start();

        try {
            // Eve connects to Bob
            TransportConnection eveConn = eveDaemon.getTcpTransport()
                    .connectAsync(new InetSocketAddress("127.0.0.1", bobP2pPort))
                    .get(5, TimeUnit.SECONDS);

            // Eve's handshake must fail because Eve is not in Bob's TrustStore
            assertThrows(Exception.class, () -> {
                eveDaemon.getSessionManager().initiateSessionAsync(eveConn).get(5, TimeUnit.SECONDS);
            }, "Handshake from untrusted peer must be rejected");

            // Bob must have no active sessions for Eve
            assertTrue(bobDaemon.getSessionManager().getActiveSessions().isEmpty(),
                    "Bob must not establish session with untrusted peer");
        } finally {
            eveDaemon.stop();
        }
    }

    @Test
    void testMidTransferCancellationCleansUpStaging() throws Exception {
        int bobP2pPort = bobDaemon.getTcpTransport().getListeningPort();

        TransportConnection connection = aliceDaemon.getTcpTransport()
                .connectAsync(new InetSocketAddress("127.0.0.1", bobP2pPort))
                .get(5, TimeUnit.SECONDS);

        PeerSession aliceSession = aliceDaemon.getSessionManager()
                .initiateSessionAsync(connection)
                .get(5, TimeUnit.SECONDS);

        assertNotNull(aliceSession);

        // Wait for Bob's session manager to register Alice's inbound session
        for (int i = 0; i < 50; i++) {
            if (bobDaemon.getSessionManager().getSessionByPeerId(aliceDaemon.getPeerId()).isPresent()) {
                break;
            }
            Thread.sleep(50);
        }

        // Throttle transfer to ensure we can cancel mid-flight
        aliceDaemon.getTransferEngine().setBandwidthLimit(50 * 1024); // 50 KB/s

        Path sourceFile = tempDir.resolve("alice_large_cancel.dat");
        byte[] payloadData = new byte[300 * 1024]; // 300 KB
        Files.write(sourceFile, payloadData);

        AuthenticateIpcResponse authResp = aliceDaemon.getIpcService().authenticateDirect(
                aliceToken, 9999, "0.1.0");
        String sessionToken = authResp.getSessionToken();

        InitiateSendRequest sendReq = InitiateSendRequest.newBuilder()
                .setSessionToken(sessionToken)
                .setTargetPeerId(PeerId.newBuilder().setValue(bobDaemon.getPeerId()).build())
                .addSourcePaths(sourceFile.toAbsolutePath().toString())
                .setDuplicatePolicy(DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX)
                .build();

        CountDownLatch responseLatch = new CountDownLatch(1);
        AtomicReference<InitiateSendResponse> sendRespRef = new AtomicReference<>();

        aliceDaemon.getIpcService().initiateSend(sendReq, new io.grpc.stub.StreamObserver<>() {
            @Override
            public void onNext(InitiateSendResponse value) {
                sendRespRef.set(value);
            }
            @Override public void onError(Throwable t) { responseLatch.countDown(); }
            @Override public void onCompleted() { responseLatch.countDown(); }
        });

        assertTrue(responseLatch.await(5, TimeUnit.SECONDS));
        String transferId = sendRespRef.get().getTransferId();

        // Allow transfer to begin and stage at least partially
        Thread.sleep(200);

        // Cancel transfer via Alice's Local Node IPC
        aliceDaemon.getIpcService().cancelTransfer(
                CancelTransferRequest.newBuilder()
                        .setSessionToken(sessionToken)
                        .setTransferId(transferId)
                        .setReason("User cancelled transfer mid-flight")
                        .build(),
                new io.grpc.stub.StreamObserver<>() {
                    @Override public void onNext(CancelTransferResponse value) {}
                    @Override public void onError(Throwable t) {}
                    @Override public void onCompleted() {}
                }
        );

        // Give receiver time to process cancellation wire message
        Thread.sleep(500);

        // Verify Bob's received directory did NOT commit the cancelled file
        Path bobReceivedDir = bobDaemon.getConfiguration().getDataDirectory().resolve("received");
        Path uncommittedFile = bobReceivedDir.resolve("alice_large_cancel.dat");
        assertFalse(Files.exists(uncommittedFile), "Cancelled transfer must not be committed to destination");

        // Verify Bob's staging directory is cleaned up
        Path bobStaging = bobDaemon.getConfiguration().getDataDirectory().resolve("staging").resolve(transferId);
        assertFalse(Files.exists(bobStaging), "Cancelled transfer staging directory must be cleaned up");
    }
}
