package org.peerlink.app

import com.google.protobuf.ByteString
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.peerlink.core.operation.InMemoryOperationJournal
import org.peerlink.core.security.PersistentTrustStore
import org.peerlink.core.transfer.PeerTransferEngine
import org.peerlink.core.transfer.TransferSessionReceiver
import org.peerlink.core.transport.PeerSession
import org.peerlink.core.transport.SessionPayloadHandler
import org.peerlink.core.transport.TransportConnection
import org.peerlink.protocol.v1.*
import java.io.File
import java.nio.file.Files
import java.util.concurrent.CompletableFuture

/**
 * Phase 10A.2: Tests native TrustStore persistence across process restarts,
 * fail-safe authorization behavior on malformed trust records, cloned identity detection,
 * and inbound transfer authorization enforcement across simulated app lifecycles.
 */
class AndroidTrustStorePersistenceAndLifecycleTest {

    private lateinit var tempDir: File
    private lateinit var trustStoreFile: File
    private lateinit var stagingDir: File
    private lateinit var destDir: File
    private lateinit var journal: InMemoryOperationJournal
    private lateinit var transferEngine: PeerTransferEngine

    private class TestSession(private val remote: PeerIdentity) : PeerSession {
        val sentPayloads = mutableListOf<ByteArray>()
        override fun getSessionId(): SessionId = SessionId.newBuilder().setValue("fake-session").build()
        override fun getLocalPeer(): PeerIdentity = PeerIdentity.newBuilder().setDisplayName("Local").build()
        override fun getRemotePeer(): PeerIdentity = remote
        override fun getState(): SessionState = SessionState.SESSION_STATE_ESTABLISHED
        override fun getActiveTransportType(): TransportType = TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS
        override fun getConnection(): TransportConnection? = null
        override fun getDescriptor(): SessionDescriptor = SessionDescriptor.getDefaultInstance()
        override fun sendPayloadAsync(payload: ByteArray): CompletableFuture<Void> {
            sentPayloads.add(payload)
            return CompletableFuture.completedFuture(null)
        }
        override fun setPayloadHandler(handler: SessionPayloadHandler) {}
        override fun sendPingAsync(): CompletableFuture<Long> = CompletableFuture.completedFuture(10L)
        override fun closeAsync(reasonCode: Int, reason: String?): CompletableFuture<Void> = CompletableFuture.completedFuture(null)
        override fun close() {}
    }

    @Before
    fun setUp() {
        tempDir = Files.createTempDirectory("peerlink-trust-test").toFile()
        trustStoreFile = File(tempDir, "security/trust_store.pb")
        stagingDir = File(tempDir, "staging").apply { mkdirs() }
        destDir = File(tempDir, "dest").apply { mkdirs() }
        journal = InMemoryOperationJournal()
        transferEngine = PeerTransferEngine(journal, stagingDir.toPath())
    }

    @After
    fun tearDown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun testTrustPersistenceAcrossProcessRestarts() {
        val peerId = "peer_alice_persistent"
        val fingerprint = "SHA256:11223344556677889900aabbccddeeff"
        val publicKey = ByteArray(32) { 0x42 }

        // Process lifecycle 1: Pair device
        val store1 = PersistentTrustStore(trustStoreFile.toPath())
        assertFalse(store1.isTrusted(peerId))
        store1.addTrustedPeer(peerId, fingerprint, publicKey)
        assertTrue(store1.isTrusted(peerId))
        assertFalse(store1.isRevoked(peerId))

        // Verify backing file exists on disk
        assertTrue("Persistent file should be written", trustStoreFile.exists())

        // Process lifecycle 2: Simulate process death and app restart
        val storeRestarted = PersistentTrustStore(trustStoreFile.toPath())
        assertTrue("Trusted peer status must survive app restart", storeRestarted.isTrusted(peerId))
        assertFalse(storeRestarted.isRevoked(peerId))
        assertEquals(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED, storeRestarted.getTrustLevel(peerId))
    }

    @Test
    fun testRevocationPersistenceAcrossProcessRestarts() {
        val peerId = "peer_bob_revocable"
        val fingerprint = "SHA256:aabbccddeeff11223344556677889900"
        val publicKey = ByteArray(32) { 0x24 }

        // Process lifecycle 1: Pair and then revoke
        val store1 = PersistentTrustStore(trustStoreFile.toPath())
        store1.addTrustedPeer(peerId, fingerprint, publicKey)
        assertTrue(store1.isTrusted(peerId))

        store1.revokeTrust(peerId, "User un-paired device", ByteArray(0))
        assertTrue(store1.isRevoked(peerId))
        assertFalse(store1.isTrusted(peerId))
        assertEquals(TrustLevel.TRUST_LEVEL_REVOKED, store1.getTrustLevel(peerId))

        // Process lifecycle 2: Simulate app restart
        val storeRestarted = PersistentTrustStore(trustStoreFile.toPath())
        assertTrue("Revocation status must survive app restart", storeRestarted.isRevoked(peerId))
        assertFalse("Revoked peer must NOT be trusted after restart", storeRestarted.isTrusted(peerId))
        assertEquals(TrustLevel.TRUST_LEVEL_REVOKED, storeRestarted.getTrustLevel(peerId))
    }

    @Test
    fun testClonedIdentityDetectionThrowsSecurityException() {
        val peerId = "peer_charlie_cloned"
        val fingerprint = "SHA256:ffffffffffffffffffffffffffffffff"
        val keyOriginal = ByteArray(32) { 0x01 }
        val keyCloned = ByteArray(32) { 0x02 }

        val store = PersistentTrustStore(trustStoreFile.toPath())
        store.addTrustedPeer(peerId, fingerprint, keyOriginal)
        assertTrue(store.isTrusted(peerId))

        // Attempting to overwrite peer with conflicting public key must trigger SecurityException
        assertThrows(SecurityException::class.java) {
            store.addTrustedPeer(peerId, fingerprint, keyCloned)
        }

        // Verify original key remains intact after failed attack
        val restarted = PersistentTrustStore(trustStoreFile.toPath())
        assertTrue(restarted.isTrusted(peerId))
    }

    @Test
    fun testMalformedOrCorruptedTrustStoreFileRecovery() {
        // Write corrupted non-protobuf data to the trust store path
        trustStoreFile.parentFile?.mkdirs()
        trustStoreFile.writeBytes(byteArrayOf(0xDE.toByte(), 0xAD.toByte(), 0xBE.toByte(), 0xEF.toByte(), 0x00, 0x11))

        // Initializing with corrupted file must fail closed gracefully without throwing crash
        val store = PersistentTrustStore(trustStoreFile.toPath())
        assertFalse("Corrupted store must fail-closed: unauthenticated peer untrusted", store.isTrusted("peer_xyz"))
        assertFalse(store.isRevoked("peer_xyz"))

        // Rescuing store: Adding a new peer should flush clean atomic file
        val validKey = ByteArray(32) { 0x55 }
        store.addTrustedPeer("peer_rescued", "SHA256:5555", validKey)
        assertTrue(store.isTrusted("peer_rescued"))

        // Subsequent restart must successfully load rescued store
        val storeRecovered = PersistentTrustStore(trustStoreFile.toPath())
        assertTrue(storeRecovered.isTrusted("peer_rescued"))
    }

    @Test
    fun testTransferSessionReceiverEnforcesPersistentTrustAcrossRestarts() {
        val peerId = "peer_trusted_client"
        val key = ByteArray(32) { 0x77 }

        // Lifecycle 1: Pair peer and initialize receiver
        val store1 = PersistentTrustStore(trustStoreFile.toPath())
        store1.addTrustedPeer(peerId, "FP_777", key)

        val receiver1 = TransferSessionReceiver(
            transferEngine,
            destDir.toPath(),
            store1,
            TransferSessionReceiver.ReceiverConsentMode.AUTO_ACCEPT_PAIRED_TRUSTED
        )

        val peerIdentity = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(peerId).build())
            .setDisplayName("Trusted Client")
            .build()
        val session1 = TestSession(peerIdentity)

        val offer = TransferOffer.newBuilder()
            .setManifest(
                TransferManifest.newBuilder()
                    .setTransferId("xfer_persistent_test")
                    .setSenderPeerId(PeerId.newBuilder().setValue(peerId).build())
                    .setReceiverPeerId(PeerId.newBuilder().setValue("peer-me").build())
                    .setChunkSizeBytes(64 * 1024)
                    .setTotalBytes(10)
                    .addItems(TransferItem.newBuilder().setRelativePath("doc.pdf").setFileSizeBytes(10).build())
                    .build()
            )
            .build()

        receiver1.handleOffer(session1, offer)
        assertEquals(1, session1.sentPayloads.size)
        val wire1 = TransferWireMessage.parseFrom(session1.sentPayloads[0])
        assertTrue("Trusted peer offer must be accepted under AUTO_ACCEPT_PAIRED_TRUSTED", wire1.response.accepted)

        // Lifecycle 2: Simulate process restart with fresh receiver and reloaded store
        val storeRestarted = PersistentTrustStore(trustStoreFile.toPath())
        val receiverRestarted = TransferSessionReceiver(
            transferEngine,
            destDir.toPath(),
            storeRestarted,
            TransferSessionReceiver.ReceiverConsentMode.AUTO_ACCEPT_PAIRED_TRUSTED
        )
        val session2 = TestSession(peerIdentity)
        receiverRestarted.handleOffer(session2, offer)
        assertEquals(1, session2.sentPayloads.size)
        val wire2 = TransferWireMessage.parseFrom(session2.sentPayloads[0])
        assertTrue("Trusted peer must remain accepted across process restart", wire2.response.accepted)

        // Lifecycle 3: Revoke peer and verify immediate rejection
        storeRestarted.revokeTrust(peerId)
        val session3 = TestSession(peerIdentity)
        receiverRestarted.handleOffer(session3, offer)
        assertEquals(1, session3.sentPayloads.size)
        val wire3 = TransferWireMessage.parseFrom(session3.sentPayloads[0])
        assertFalse("Revoked peer offer must be rejected", wire3.response.accepted)
        assertTrue(wire3.response.rejectionReason.contains("revoked", ignoreCase = true))
    }
}
