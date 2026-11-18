package org.peerlink.core.transfer;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.operation.InMemoryOperationJournal;
import org.peerlink.core.security.InMemoryTrustStore;
import org.peerlink.core.security.PeerCryptoSigner;
import org.peerlink.core.transport.*;
import org.peerlink.protocol.v1.*;

import java.net.InetSocketAddress;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Verifies real-time transfer reliability hardening:
 * 1. Zero-byte files transfer and commit cleanly over real StandardTcpTransportProvider sessions.
 * 2. Transport disconnect immediately fails pending coordinator futures without hanging.
 */
public class TransferReliabilityHardeningTest {

    private static PeerIdentity makePeer(String peerId, String devId, String name, PeerCryptoSigner signer, long now) {
        return PeerIdentity.newBuilder()
                .setPeerId(PeerId.newBuilder().setValue(peerId).build())
                .setDeviceId(DeviceId.newBuilder().setValue(devId).build())
                .setDisplayName(name)
                .setIdentityKey(signer.toProtobufKey(now))
                .setFingerprintHex(signer.computeFingerprint())
                .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
                .setPairedAtUtcMs(now)
                .build();
    }

    private static DeviceIdentity makeDevice(String devId, String name, PeerCryptoSigner signer, long now) {
        return DeviceIdentity.newBuilder()
                .setDeviceId(DeviceId.newBuilder().setValue(devId).build())
                .setDeviceName(name)
                .setDeviceType(DeviceType.DEVICE_TYPE_DESKTOP_WINDOWS)
                .setOsVersion("Windows 11")
                .setAppVersion("1.0.0")
                .setIdentityKey(signer.toProtobufKey(now))
                .build();
    }

    @Test
    void zeroByteFileTransfersAndCommitsOverRealTcpSession(@TempDir Path tempDir) throws Exception {
        Path srcDir = tempDir.resolve("src");
        Path dstDir = tempDir.resolve("dst");
        Path stgSender = tempDir.resolve("stg_sender");
        Path stgReceiver = tempDir.resolve("stg_receiver");
        Files.createDirectories(srcDir);
        Files.createDirectories(dstDir);

        Path emptyFile = srcDir.resolve("empty_marker.txt");
        Files.write(emptyFile, new byte[0]);

        long now = System.currentTimeMillis();
        PeerCryptoSigner signerA = PeerCryptoSigner.generate("key_zero_a");
        PeerCryptoSigner signerB = PeerCryptoSigner.generate("key_zero_b");

        PeerIdentity idA = makePeer("peer_zero_a", "dev_zero_a", "Phone A", signerA, now);
        PeerIdentity idB = makePeer("peer_zero_b", "dev_zero_b", "Windows PC B", signerB, now);
        DeviceIdentity devA = makeDevice("dev_zero_a", "Phone A", signerA, now);
        DeviceIdentity devB = makeDevice("dev_zero_b", "Windows PC B", signerB, now);

        InMemoryTrustStore trustA = new InMemoryTrustStore();
        InMemoryTrustStore trustB = new InMemoryTrustStore();
        trustA.addTrustedPeer(idB.getPeerId().getValue(), idB.getFingerprintHex(), signerB.getPublicKeyEncoded());
        trustB.addTrustedPeer(idA.getPeerId().getValue(), idA.getFingerprintHex(), signerA.getPublicKeyEncoded());

        ProtocolVersion proto = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build();

        StandardTcpTransportProvider tcpA = new StandardTcpTransportProvider("127.0.0.1");
        StandardTcpTransportProvider tcpB = new StandardTcpTransportProvider("127.0.0.1");

        PeerSessionManager mgrA = new PeerSessionManager(idA, devA, signerA, trustA, proto, proto, new TransportCapabilityNegotiator(List.of(tcpA)));
        PeerSessionManager mgrB = new PeerSessionManager(idB, devB, signerB, trustB, proto, proto, new TransportCapabilityNegotiator(List.of(tcpB)));

        PeerTransferEngine engineA = new PeerTransferEngine(new InMemoryOperationJournal(), stgSender);
        PeerTransferEngine engineB = new PeerTransferEngine(new InMemoryOperationJournal(), stgReceiver);

        mgrB.addSessionLifecycleListener(session -> {
            TransferSessionCoordinator coord = new TransferSessionCoordinator(session);
            TransferSessionReceiver receiver = new TransferSessionReceiver(
                    engineB, dstDir, trustB, TransferSessionReceiver.ReceiverConsentMode.AUTO_ACCEPT_PAIRED_TRUSTED);
            coord.registerReceiver(receiver);
        });

        try {
            tcpB.startListening(0, mgrB::handleInboundConnection);
            int port = tcpB.getListeningPort();

            TransportConnection conn = tcpA.connectAsync(new InetSocketAddress("127.0.0.1", port)).get(5, TimeUnit.SECONDS);
            PeerSession sessionA = mgrA.initiateSessionAsync(conn).get(5, TimeUnit.SECONDS);

            TransferManifest manifest = engineA.prepareSend(
                    "peer_zero_a", "peer_zero_b", List.of(emptyFile),
                    DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX);

            TransferCompletedReceipt receipt = engineA.sendTransferOverSession(
                    sessionA, manifest, List.of(emptyFile), p -> {});

            assertNotNull(receipt);
            assertTrue(receipt.getSuccess(), "0-byte file transfer must succeed: " + receipt.getErrorMessage());
            Path receivedFile = dstDir.resolve("empty_marker.txt");
            assertTrue(Files.exists(receivedFile), "0-byte file must exist at destination");
            assertEquals(0L, Files.size(receivedFile));
        } finally {
            mgrA.close();
            mgrB.close();
            tcpA.close();
            tcpB.close();
        }
    }

    @Test
    void transportCloseImmediatelyFailsPendingCoordinatorRequests() throws Exception {
        long now = System.currentTimeMillis();
        PeerCryptoSigner signerA = PeerCryptoSigner.generate("key_drop_a");
        PeerCryptoSigner signerB = PeerCryptoSigner.generate("key_drop_b");

        PeerIdentity idA = makePeer("peer_drop_a", "dev_drop_a", "Phone Drop", signerA, now);
        PeerIdentity idB = makePeer("peer_drop_b", "dev_drop_b", "PC Drop", signerB, now);
        DeviceIdentity devA = makeDevice("dev_drop_a", "Phone Drop", signerA, now);
        DeviceIdentity devB = makeDevice("dev_drop_b", "PC Drop", signerB, now);

        InMemoryTrustStore trustA = new InMemoryTrustStore();
        InMemoryTrustStore trustB = new InMemoryTrustStore();
        trustA.addTrustedPeer(idB.getPeerId().getValue(), idB.getFingerprintHex(), signerB.getPublicKeyEncoded());
        trustB.addTrustedPeer(idA.getPeerId().getValue(), idA.getFingerprintHex(), signerA.getPublicKeyEncoded());

        ProtocolVersion proto = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build();
        StandardTcpTransportProvider tcpA = new StandardTcpTransportProvider("127.0.0.1");
        StandardTcpTransportProvider tcpB = new StandardTcpTransportProvider("127.0.0.1");

        PeerSessionManager mgrA = new PeerSessionManager(idA, devA, signerA, trustA, proto, proto, new TransportCapabilityNegotiator(List.of(tcpA)));
        PeerSessionManager mgrB = new PeerSessionManager(idB, devB, signerB, trustB, proto, proto, new TransportCapabilityNegotiator(List.of(tcpB)));

        try {
            tcpB.startListening(0, mgrB::handleInboundConnection);
            TransportConnection conn = tcpA.connectAsync(new InetSocketAddress("127.0.0.1", tcpB.getListeningPort())).get(5, TimeUnit.SECONDS);
            PeerSession sessionA = mgrA.initiateSessionAsync(conn).get(5, TimeUnit.SECONDS);

            TransferSessionCoordinator coord = new TransferSessionCoordinator(sessionA);
            CompletableFuture<TransferChunkAck> pendingAck = coord.registerPendingChunkAck("xfer_drop", 0, 0);

            // Simulate sudden network drop
            conn.close();

            // Must fail fast (well under 2 seconds, NOT hang for 15s chunk timeout)
            assertThrows(ExecutionException.class, () -> pendingAck.get(2, TimeUnit.SECONDS));
        } finally {
            mgrA.close();
            mgrB.close();
            tcpA.close();
            tcpB.close();
        }
    }

    @Test
    void multiMegabytePipelinedTransferCommitsIntactOverRealTcp(@TempDir Path tempDir) throws Exception {
        Path srcDir = tempDir.resolve("src_pipe");
        Path dstDir = tempDir.resolve("dst_pipe");
        Path stgSender = tempDir.resolve("stg_pipe_s");
        Path stgReceiver = tempDir.resolve("stg_pipe_r");
        Files.createDirectories(srcDir);
        Files.createDirectories(dstDir);

        // 2.5 MB deterministic payload -> spans >10 chunks so the 6-chunk sliding window exercises full pipelining
        byte[] payload = new byte[2_500_000];
        for (int i = 0; i < payload.length; i++) {
            payload[i] = (byte) ((i * 31 + 17) & 0xFF);
        }
        Path bigFile = srcDir.resolve("video_clip.bin");
        Files.write(bigFile, payload);

        long now = System.currentTimeMillis();
        PeerCryptoSigner signerA = PeerCryptoSigner.generate("key_pipe_a");
        PeerCryptoSigner signerB = PeerCryptoSigner.generate("key_pipe_b");

        PeerIdentity idA = makePeer("peer_pipe_a", "dev_pipe_a", "Phone Pipe", signerA, now);
        PeerIdentity idB = makePeer("peer_pipe_b", "dev_pipe_b", "Windows Pipe", signerB, now);
        DeviceIdentity devA = makeDevice("dev_pipe_a", "Phone Pipe", signerA, now);
        DeviceIdentity devB = makeDevice("dev_pipe_b", "Windows Pipe", signerB, now);

        InMemoryTrustStore trustA = new InMemoryTrustStore();
        InMemoryTrustStore trustB = new InMemoryTrustStore();
        trustA.addTrustedPeer(idB.getPeerId().getValue(), idB.getFingerprintHex(), signerB.getPublicKeyEncoded());
        trustB.addTrustedPeer(idA.getPeerId().getValue(), idA.getFingerprintHex(), signerA.getPublicKeyEncoded());

        ProtocolVersion proto = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build();
        StandardTcpTransportProvider tcpA = new StandardTcpTransportProvider("127.0.0.1");
        StandardTcpTransportProvider tcpB = new StandardTcpTransportProvider("127.0.0.1");

        PeerSessionManager mgrA = new PeerSessionManager(idA, devA, signerA, trustA, proto, proto, new TransportCapabilityNegotiator(List.of(tcpA)));
        PeerSessionManager mgrB = new PeerSessionManager(idB, devB, signerB, trustB, proto, proto, new TransportCapabilityNegotiator(List.of(tcpB)));

        PeerTransferEngine engineA = new PeerTransferEngine(new InMemoryOperationJournal(), stgSender);
        PeerTransferEngine engineB = new PeerTransferEngine(new InMemoryOperationJournal(), stgReceiver);

        mgrB.addSessionLifecycleListener(session -> {
            TransferSessionCoordinator coord = new TransferSessionCoordinator(session);
            TransferSessionReceiver receiver = new TransferSessionReceiver(
                    engineB, dstDir, trustB, TransferSessionReceiver.ReceiverConsentMode.AUTO_ACCEPT_PAIRED_TRUSTED);
            coord.registerReceiver(receiver);
        });

        try {
            tcpB.startListening(0, mgrB::handleInboundConnection);
            TransportConnection conn = tcpA.connectAsync(new InetSocketAddress("127.0.0.1", tcpB.getListeningPort())).get(5, TimeUnit.SECONDS);
            PeerSession sessionA = mgrA.initiateSessionAsync(conn).get(5, TimeUnit.SECONDS);

            TransferManifest manifest = engineA.prepareSend(
                    "peer_pipe_a", "peer_pipe_b", List.of(bigFile),
                    DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX);

            TransferCompletedReceipt receipt = engineA.sendTransferOverSession(
                    sessionA, manifest, List.of(bigFile), p -> {});

            assertNotNull(receipt);
            assertTrue(receipt.getSuccess(), "Pipelined 2.5MB transfer must succeed: " + receipt.getErrorMessage());
            Path received = dstDir.resolve("video_clip.bin");
            assertTrue(Files.exists(received));
            assertArrayEquals(payload, Files.readAllBytes(received));
        } finally {
            mgrA.close();
            mgrB.close();
            tcpA.close();
            tcpB.close();
        }
    }
}
