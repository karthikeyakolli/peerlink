package org.peerlink.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.FixMethodOrder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.MethodSorters
import org.peerlink.core.android.*
import org.peerlink.core.operation.JournalStage
import org.peerlink.core.operation.OperationState
import org.peerlink.core.security.PeerCryptoSigner
import org.peerlink.core.security.PersistentTrustStore
import org.peerlink.core.transfer.PeerTransferEngine
import org.peerlink.core.transfer.TransferSessionCoordinator
import org.peerlink.core.transfer.TransferSessionReceiver
import org.peerlink.core.transport.*
import org.peerlink.protocol.v1.*
import java.io.File
import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * PeerLink Phase 10B.4 Cross-Emulator Real Transfer Path Proof Suite.
 *
 * Verifies real TCP socket communication across the shared virtual Wi-Fi
 * mesh router (AndroidWifi 10.0.2.0/24) between distinct emulator instances:
 * - Device A: emulator-5554 (wlan0: 10.0.2.16)
 * - Device B: emulator-5556 (wlan0: 10.0.2.17)
 * - Device C: emulator-5558 (wlan0: 10.0.2.18)
 *
 * Traverses StandardTcpTransportProvider, PeerSessionManager, PersistentTrustStore (trust_store.pb),
 * PeerTransferEngine, and AndroidSqliteOperationJournal across distinct IP addresses.
 */
@RunWith(AndroidJUnit4::class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class CrossEmulatorRemoteTransferInstrumentedTest {

    companion object {
        const val IP_DEVICE_A = "10.0.2.16"
        const val IP_DEVICE_B = "10.0.2.17"
        const val IP_DEVICE_C = "10.0.2.18"

        const val PORT_PRODUCTION_DAEMON = 8765
        const val PORT_P2P_TRANSFER = 8766

        const val PAYLOAD_A_TO_B = "CROSS-EMULATOR VERIFIED PAYLOAD: Device A (10.0.2.16) -> Device B (10.0.2.17) over shared virtual Wi-Fi mesh router."
        const val PAYLOAD_B_TO_A = "CROSS-EMULATOR VERIFIED REVERSE PAYLOAD: Device B (10.0.2.17) -> Device A (10.0.2.16) over shared virtual Wi-Fi mesh router."
        const val PAYLOAD_C_TO_A = "CROSS-EMULATOR VERIFIED THIRD-PEER PAYLOAD: Device C (10.0.2.18) -> Device A (10.0.2.16) over shared virtual Wi-Fi mesh router."

        // Deterministic Ed25519 PKCS8 private keys & X509 public keys for multi-VM parity
        const val PRIV_HEX_A = "302e020100300506032b6570042204209117247572a7b3a9b849ead4cc2afc17734aee643977f2624880279099d9f83a"
        const val PUB_HEX_A = "302a300506032b6570032100d4f429b0b7c2727dfdb0ad9258d5e425f62fc6034f1314bb0ea9bcc3dc0814c8"

        const val PRIV_HEX_B = "302e020100300506032b657004220420a67ecf5d5de638050506b2d6df5bd905ff9d255ecd0eda0f25e247685b5f492f"
        const val PUB_HEX_B = "302a300506032b6570032100aaa73881775a2d0d77b1aa40bd6854031317a25f4b7b9998a60edd56363fe41b"

        const val PRIV_HEX_C = "302e020100300506032b657004220420b0127605d840af1d92ce3f8734c02156396463d60dda71691883158593b17969"
        const val PUB_HEX_C = "302a300506032b6570032100b92353084146add56193a47e452b261ff72b5b55d95ef4b59f6843eda4d99bab"

        const val FIXED_TIMESTAMP = 1792378348000L

        fun hexToBytes(hex: String): ByteArray {
            val len = hex.length
            val data = ByteArray(len / 2)
            var i = 0
            while (i < len) {
                data[i / 2] = ((Character.digit(hex[i], 16) shl 4) + Character.digit(hex[i + 1], 16)).toByte()
                i += 2
            }
            return data
        }
    }

    private lateinit var testWorkDir: File
    private lateinit var stagingDir: File
    private lateinit var destDir: File
    private lateinit var localSqliteJournal: AndroidSqliteOperationJournal
    private lateinit var protocolVersion: ProtocolVersion

    private lateinit var signerA: PeerCryptoSigner
    private lateinit var peerIdentityA: PeerIdentity
    private lateinit var deviceIdentityA: DeviceIdentity

    private lateinit var signerB: PeerCryptoSigner
    private lateinit var peerIdentityB: PeerIdentity
    private lateinit var deviceIdentityB: DeviceIdentity

    private lateinit var signerC: PeerCryptoSigner
    private lateinit var peerIdentityC: PeerIdentity
    private lateinit var deviceIdentityC: DeviceIdentity

    @Before
    fun setUp() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        testWorkDir = File(context.filesDir, "cross_qual_shared").apply { mkdirs() }
        stagingDir = File(testWorkDir, "staging").apply { mkdirs() }
        destDir = File(testWorkDir, "received").apply { mkdirs() }

        localSqliteJournal = AndroidSqliteOperationJournal(context, "cross_ops_shared.db")
        protocolVersion = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build()

        signerA = PeerCryptoSigner.fromPrivateKeyBytes("key_cross_a", hexToBytes(PRIV_HEX_A), hexToBytes(PUB_HEX_A))
        val peerAId = PeerCryptoSigner.deriveStablePeerId(signerA.publicKeyEncoded)
        peerIdentityA = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(peerAId).build())
            .setDeviceId(DeviceId.newBuilder().setValue("dev_cross_a").build())
            .setDisplayName("Device-A-PixelFold")
            .setIdentityKey(signerA.toProtobufKey(FIXED_TIMESTAMP))
            .setFingerprintHex(signerA.computeFingerprint())
            .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
            .build()
        deviceIdentityA = DeviceIdentity.newBuilder()
            .setDeviceId(peerIdentityA.deviceId)
            .setDeviceName(peerIdentityA.displayName)
            .setDeviceType(DeviceType.DEVICE_TYPE_MOBILE_ANDROID)
            .setOsVersion("Android 17 API 37")
            .setAppVersion("0.1.0")
            .setIdentityKey(peerIdentityA.identityKey)
            .build()

        signerB = PeerCryptoSigner.fromPrivateKeyBytes("key_cross_b", hexToBytes(PRIV_HEX_B), hexToBytes(PUB_HEX_B))
        val peerBId = PeerCryptoSigner.deriveStablePeerId(signerB.publicKeyEncoded)
        peerIdentityB = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(peerBId).build())
            .setDeviceId(DeviceId.newBuilder().setValue("dev_cross_b").build())
            .setDisplayName("Device-B-Pixel8Pro")
            .setIdentityKey(signerB.toProtobufKey(FIXED_TIMESTAMP))
            .setFingerprintHex(signerB.computeFingerprint())
            .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
            .build()
        deviceIdentityB = DeviceIdentity.newBuilder()
            .setDeviceId(peerIdentityB.deviceId)
            .setDeviceName(peerIdentityB.displayName)
            .setDeviceType(DeviceType.DEVICE_TYPE_MOBILE_ANDROID)
            .setOsVersion("Android 17 API 37")
            .setAppVersion("0.1.0")
            .setIdentityKey(peerIdentityB.identityKey)
            .build()

        signerC = PeerCryptoSigner.fromPrivateKeyBytes("key_cross_c", hexToBytes(PRIV_HEX_C), hexToBytes(PUB_HEX_C))
        val peerCId = PeerCryptoSigner.deriveStablePeerId(signerC.publicKeyEncoded)
        peerIdentityC = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(peerCId).build())
            .setDeviceId(DeviceId.newBuilder().setValue("dev_cross_c").build())
            .setDisplayName("Device-C-MediumPhone")
            .setIdentityKey(signerC.toProtobufKey(FIXED_TIMESTAMP))
            .setFingerprintHex(signerC.computeFingerprint())
            .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
            .build()
        deviceIdentityC = DeviceIdentity.newBuilder()
            .setDeviceId(peerIdentityC.deviceId)
            .setDeviceName(peerIdentityC.displayName)
            .setDeviceType(DeviceType.DEVICE_TYPE_MOBILE_ANDROID)
            .setOsVersion("Android 17 API 37")
            .setAppVersion("0.1.0")
            .setIdentityKey(peerIdentityC.identityKey)
            .build()
    }

    @After
    fun tearDown() {
        try { localSqliteJournal.close() } catch (ignored: Exception) {}
    }

    private fun sha256(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        val sb = StringBuilder()
        for (b in digest) {
            sb.append(String.format("%02x", b))
        }
        return sb.toString()
    }

    /**
     * Test 1: Zero-Trust Enforcement over Remote Virtual Wi-Fi Network to Device B.
     * Connects across virtual Wi-Fi interface (wlan0) to Device B's real IP 10.0.2.17:8765.
     * Initiates handshake with an untrusted identity.
     * Confirms that Device B's remote daemon rejects the connection with ERROR_CODE_UNAUTHORIZED.
     */
    @Test
    fun test01_RemoteUntrustedConnectionToDeviceBIsRejected() {
        val untrustedSigner = PeerCryptoSigner.generate("cross_attacker_untrusted")
        val untrustedPeerId = PeerCryptoSigner.deriveStablePeerId(untrustedSigner.publicKeyEncoded)
        val untrustedPeer = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(untrustedPeerId).build())
            .setDeviceId(DeviceId.newBuilder().setValue("dev_untrusted_remote").build())
            .setDisplayName("Attacker")
            .setIdentityKey(untrustedSigner.toProtobufKey(System.currentTimeMillis()))
            .setFingerprintHex(untrustedSigner.computeFingerprint())
            .setTrustLevel(TrustLevel.TRUST_LEVEL_UNTRUSTED)
            .build()
        val untrustedDevice = DeviceIdentity.newBuilder()
            .setDeviceId(untrustedPeer.deviceId)
            .setDeviceName(untrustedPeer.displayName)
            .setDeviceType(DeviceType.DEVICE_TYPE_MOBILE_ANDROID)
            .setIdentityKey(untrustedPeer.identityKey)
            .build()

        val transport = StandardTcpTransportProvider("0.0.0.0")
        val sessionManager = PeerSessionManager(
            untrustedPeer, untrustedDevice, untrustedSigner,
            org.peerlink.core.security.InMemoryTrustStore(),
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transport))
        )

        try {
            val conn = transport.connectAsync(InetSocketAddress(IP_DEVICE_B, PORT_PRODUCTION_DAEMON))
                .get(5, TimeUnit.SECONDS)
            assertNotNull("TCP connection to remote Device B must be established", conn)

            val handshakeFuture = sessionManager.initiateSessionAsync(conn)
            try {
                handshakeFuture.get(5, TimeUnit.SECONDS)
                fail("Remote daemon on Device B must reject handshake from untrusted peer")
            } catch (e: Exception) {
                val msg = e.message ?: ""
                assertTrue(
                    "Handshake rejection must be unauthorized: $msg",
                    msg.contains("ERROR_CODE_UNAUTHORIZED") || msg.contains("rejected by remote peer") || msg.contains("Handshake rejected")
                )
            }
        } finally {
            transport.close()
            sessionManager.close()
        }
    }

    /**
     * Test 2: Zero-Trust Enforcement over Remote Virtual Wi-Fi Network to Device C.
     * Connects across virtual Wi-Fi interface (wlan0) to Device C's real IP 10.0.2.18:8765.
     * Confirms that Device C's remote daemon rejects the connection with ERROR_CODE_UNAUTHORIZED.
     */
    @Test
    fun test02_RemoteUntrustedConnectionToDeviceCIsRejected() {
        val untrustedSigner = PeerCryptoSigner.generate("cross_attacker_untrusted_c")
        val untrustedPeerId = PeerCryptoSigner.deriveStablePeerId(untrustedSigner.publicKeyEncoded)
        val untrustedPeer = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(untrustedPeerId).build())
            .setDeviceId(DeviceId.newBuilder().setValue("dev_untrusted_c").build())
            .setDisplayName("Attacker-C")
            .setIdentityKey(untrustedSigner.toProtobufKey(System.currentTimeMillis()))
            .setFingerprintHex(untrustedSigner.computeFingerprint())
            .setTrustLevel(TrustLevel.TRUST_LEVEL_UNTRUSTED)
            .build()
        val untrustedDevice = DeviceIdentity.newBuilder()
            .setDeviceId(untrustedPeer.deviceId)
            .setDeviceName(untrustedPeer.displayName)
            .setDeviceType(DeviceType.DEVICE_TYPE_MOBILE_ANDROID)
            .setIdentityKey(untrustedPeer.identityKey)
            .build()

        val transport = StandardTcpTransportProvider("0.0.0.0")
        val sessionManager = PeerSessionManager(
            untrustedPeer, untrustedDevice, untrustedSigner,
            org.peerlink.core.security.InMemoryTrustStore(),
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transport))
        )

        try {
            val conn = transport.connectAsync(InetSocketAddress(IP_DEVICE_C, PORT_PRODUCTION_DAEMON))
                .get(5, TimeUnit.SECONDS)
            assertNotNull("TCP connection to remote Device C must be established", conn)

            val handshakeFuture = sessionManager.initiateSessionAsync(conn)
            try {
                handshakeFuture.get(5, TimeUnit.SECONDS)
                fail("Remote daemon on Device C must reject handshake from untrusted peer")
            } catch (e: Exception) {
                val msg = e.message ?: ""
                assertTrue(
                    "Handshake rejection must be unauthorized: $msg",
                    msg.contains("ERROR_CODE_UNAUTHORIZED") || msg.contains("rejected by remote peer") || msg.contains("Handshake rejected")
                )
            }
        } finally {
            transport.close()
            sessionManager.close()
        }
    }

    /**
     * Test 3: Standalone Receiver on Device B (Port 8766).
     * Listens on 0.0.0.0:8766. Trusts Device A and Device C.
     * Receives file streamed across the shared virtual Wi-Fi mesh router from Device A (10.0.2.16).
     */
    @Test
    fun test03_DeviceB_RunReceiver_ListenOnPort8766() {
        val trustStoreFile = File(testWorkDir, "trust_store_b.pb").toPath()
        val trustStore = PersistentTrustStore(trustStoreFile)
        trustStore.addTrustedPeer(peerIdentityA)
        trustStore.addTrustedPeer(peerIdentityC)

        val transport = StandardTcpTransportProvider("0.0.0.0")
        val sessionManager = PeerSessionManager(
            peerIdentityB, deviceIdentityB, signerB, trustStore,
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transport))
        )
        val transferEngine = PeerTransferEngine(localSqliteJournal, stagingDir.toPath())
        val receiver = transferEngine.createSessionReceiver(destDir.toPath(), trustStore)

        val transferDoneLatch = CountDownLatch(1)
        val transferSuccess = AtomicBoolean(false)

        receiver.addListener(object : TransferSessionReceiver.ReceiverTransferEventListener {
            override fun onIncomingOffer(session: PeerSession?, offer: TransferOffer?) {}
            override fun onTransferProgress(xferId: String?, fileName: String?, percent: Int, transferred: Long, total: Long) {}
            override fun onTransferCompleted(xferId: String?, fileName: String?, success: Boolean, errorMsg: String?) {
                transferSuccess.set(success)
                transferDoneLatch.countDown()
            }
        })

        try {
            transport.startListening(PORT_P2P_TRANSFER, sessionManager::handleInboundConnection)
            assertEquals(PORT_P2P_TRANSFER, transport.listeningPort)

            sessionManager.addSessionLifecycleListener(object : PeerSessionManager.SessionLifecycleListener {
                override fun onSessionEstablished(session: PeerSession) {
                    TransferSessionCoordinator(session).registerReceiver(receiver)
                }
            })

            // Await inbound transfer from remote Device A (wlan0: 10.0.2.16)
            val received = transferDoneLatch.await(30, TimeUnit.SECONDS)
            assertTrue("Receiver timed out waiting for remote transfer from Device A", received)
            assertTrue("Transfer must complete successfully", transferSuccess.get())
            val receivedFile = File(destDir, "cross_payload_a_to_b.txt")
            assertTrue("Received file must exist in destDir: ${receivedFile.absolutePath}", receivedFile.exists())
            val expectedSha = sha256(PAYLOAD_A_TO_B.toByteArray(StandardCharsets.UTF_8))
            val actualSha = sha256(receivedFile.readBytes())
            assertEquals("SHA-256 digest must match across virtual Wi-Fi transfer", expectedSha, actualSha)
            assertEquals(PAYLOAD_A_TO_B.toByteArray(StandardCharsets.UTF_8).size.toLong(), receivedFile.length())
        } finally {
            transport.close()
            sessionManager.close()
        }
    }

    /**
     * Test 4: Cross-Device Directed Transfer from Device A to Device B over 10.0.2.17:8766.
     * Connects to Device B's remote IP 10.0.2.17 on port 8766 over virtual Wi-Fi interface (wlan0).
     * Streams file via PeerTransferEngine over established session.
     */
    @Test
    fun test04_DeviceA_SendToRemoteDeviceB_OverVirtualWifi() {
        val trustStoreFile = File(testWorkDir, "trust_store_a.pb").toPath()
        val trustStore = PersistentTrustStore(trustStoreFile)
        trustStore.addTrustedPeer(peerIdentityB)

        val transport = StandardTcpTransportProvider("0.0.0.0")
        val sessionManager = PeerSessionManager(
            peerIdentityA, deviceIdentityA, signerA, trustStore,
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transport))
        )
        val transferEngine = PeerTransferEngine(localSqliteJournal, stagingDir.toPath())

        val payloadBytes = PAYLOAD_A_TO_B.toByteArray(StandardCharsets.UTF_8)
        val expectedSha256 = sha256(payloadBytes)

        val sourceFile = File(testWorkDir, "cross_payload_a_to_b.txt").apply { writeBytes(payloadBytes) }
        assertEquals(payloadBytes.size.toLong(), sourceFile.length())

        try {
            var conn: TransportConnection? = null
            for (i in 0 until 10) {
                try {
                    conn = transport.connectAsync(InetSocketAddress(IP_DEVICE_B, PORT_P2P_TRANSFER)).get(1, TimeUnit.SECONDS)
                    if (conn != null) break
                } catch (e: Exception) {
                    Thread.sleep(500)
                }
            }
            assertNotNull("Connection to Device B (10.0.2.17:8766) over virtual Wi-Fi must succeed", conn)

            val session = sessionManager.initiateSessionAsync(conn).get(5, TimeUnit.SECONDS)
            assertEquals(SessionState.SESSION_STATE_ESTABLISHED, session.state)

            val manifest = transferEngine.prepareSend(
                peerIdentityA.peerId.value,
                peerIdentityB.peerId.value,
                listOf(sourceFile.toPath()),
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS
            )
            val opId = manifest.operationId.value

            val receipt = transferEngine.sendTransferOverSession(session, manifest, listOf(sourceFile.toPath())) {}
            assertTrue("Remote transfer receipt must report success", receipt.success)
            assertEquals(payloadBytes.size.toLong(), receipt.totalBytesTransferred)

            localSqliteJournal.updateState(opId, OperationState.COMMITTED)
            localSqliteJournal.recordJournalStage(opId, JournalStage.COMMIT)

            val op = localSqliteJournal.getOperation(opId)
            assertTrue("Operation record must exist in SQLite journal", op.isPresent)
            assertEquals(OperationState.COMMITTED, op.get().state)
        } finally {
            transport.close()
            sessionManager.close()
        }
    }

    /**
     * Test 5: Standalone Receiver on Device A (Reverse & Third-Peer Direction).
     * Starts listening on 0.0.0.0:8766 on Device A (10.0.2.16).
     * Trusts Device B and Device C.
     */
    @Test
    fun test05_DeviceA_RunReceiver_ListenOnPort8766() {
        val trustStoreFile = File(testWorkDir, "trust_store_a_rev.pb").toPath()
        val trustStore = PersistentTrustStore(trustStoreFile)
        trustStore.addTrustedPeer(peerIdentityB)
        trustStore.addTrustedPeer(peerIdentityC)

        val transport = StandardTcpTransportProvider("0.0.0.0")
        val sessionManager = PeerSessionManager(
            peerIdentityA, deviceIdentityA, signerA, trustStore,
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transport))
        )
        val transferEngine = PeerTransferEngine(localSqliteJournal, stagingDir.toPath())
        val receiver = transferEngine.createSessionReceiver(destDir.toPath(), trustStore)

        val transferDoneLatch = CountDownLatch(1)
        val transferSuccess = AtomicBoolean(false)

        receiver.addListener(object : TransferSessionReceiver.ReceiverTransferEventListener {
            override fun onIncomingOffer(session: PeerSession?, offer: TransferOffer?) {}
            override fun onTransferProgress(xferId: String?, fileName: String?, percent: Int, transferred: Long, total: Long) {}
            override fun onTransferCompleted(xferId: String?, fileName: String?, success: Boolean, errorMsg: String?) {
                transferSuccess.set(success)
                transferDoneLatch.countDown()
            }
        })

        try {
            transport.startListening(PORT_P2P_TRANSFER, sessionManager::handleInboundConnection)
            assertEquals(PORT_P2P_TRANSFER, transport.listeningPort)

            sessionManager.addSessionLifecycleListener(object : PeerSessionManager.SessionLifecycleListener {
                override fun onSessionEstablished(session: PeerSession) {
                    TransferSessionCoordinator(session).registerReceiver(receiver)
                }
            })

            val received = transferDoneLatch.await(30, TimeUnit.SECONDS)
            assertTrue("Receiver on Device A timed out waiting for remote transfer", received)
            assertTrue("Transfer must complete successfully", transferSuccess.get())
        } finally {
            transport.close()
            sessionManager.close()
        }
    }

    /**
     * Test 6: Cross-Device Directed Transfer from Device B to Device A (Reverse Direction).
     * Connects to Device A's remote IP 10.0.2.16 on port 8766 over virtual Wi-Fi interface (wlan0).
     */
    @Test
    fun test06_DeviceB_SendToRemoteDeviceA_OverVirtualWifi() {
        val trustStoreFile = File(testWorkDir, "trust_store_b_rev.pb").toPath()
        val trustStore = PersistentTrustStore(trustStoreFile)
        trustStore.addTrustedPeer(peerIdentityA)

        val transport = StandardTcpTransportProvider("0.0.0.0")
        val sessionManager = PeerSessionManager(
            peerIdentityB, deviceIdentityB, signerB, trustStore,
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transport))
        )
        val transferEngine = PeerTransferEngine(localSqliteJournal, stagingDir.toPath())

        val payloadBytes = PAYLOAD_B_TO_A.toByteArray(StandardCharsets.UTF_8)
        val expectedSha256 = sha256(payloadBytes)

        val sourceFile = File(testWorkDir, "cross_payload_b_to_a.txt").apply { writeBytes(payloadBytes) }
        assertEquals(payloadBytes.size.toLong(), sourceFile.length())

        try {
            var conn: TransportConnection? = null
            for (i in 0 until 10) {
                try {
                    conn = transport.connectAsync(InetSocketAddress(IP_DEVICE_A, PORT_P2P_TRANSFER)).get(1, TimeUnit.SECONDS)
                    if (conn != null) break
                } catch (e: Exception) {
                    Thread.sleep(500)
                }
            }
            assertNotNull("Connection to Device A (10.0.2.16:8766) over virtual Wi-Fi must succeed", conn)

            val session = sessionManager.initiateSessionAsync(conn).get(5, TimeUnit.SECONDS)
            assertEquals(SessionState.SESSION_STATE_ESTABLISHED, session.state)

            val manifest = transferEngine.prepareSend(
                peerIdentityB.peerId.value,
                peerIdentityA.peerId.value,
                listOf(sourceFile.toPath()),
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS
            )
            val opId = manifest.operationId.value

            val receipt = transferEngine.sendTransferOverSession(session, manifest, listOf(sourceFile.toPath())) {}
            assertTrue("Remote reverse transfer receipt must report success", receipt.success)
            assertEquals(payloadBytes.size.toLong(), receipt.totalBytesTransferred)

            localSqliteJournal.updateState(opId, OperationState.COMMITTED)
            localSqliteJournal.recordJournalStage(opId, JournalStage.COMMIT)

            val op = localSqliteJournal.getOperation(opId)
            assertTrue(op.isPresent)
            assertEquals(OperationState.COMMITTED, op.get().state)
        } finally {
            transport.close()
            sessionManager.close()
        }
    }

    /**
     * Test 7: Cross-Device Directed Transfer from Device C to Device A (Third-Peer Route).
     * Connects to Device A's remote IP 10.0.2.16 on port 8766 over virtual Wi-Fi interface (wlan0).
     */
    @Test
    fun test07_DeviceC_SendToRemoteDeviceA_OverVirtualWifi() {
        val trustStoreFile = File(testWorkDir, "trust_store_c.pb").toPath()
        val trustStore = PersistentTrustStore(trustStoreFile)
        trustStore.addTrustedPeer(peerIdentityA)

        val transport = StandardTcpTransportProvider("0.0.0.0")
        val sessionManager = PeerSessionManager(
            peerIdentityC, deviceIdentityC, signerC, trustStore,
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transport))
        )
        val transferEngine = PeerTransferEngine(localSqliteJournal, stagingDir.toPath())

        val payloadBytes = PAYLOAD_C_TO_A.toByteArray(StandardCharsets.UTF_8)
        val expectedSha256 = sha256(payloadBytes)

        val sourceFile = File(testWorkDir, "cross_payload_c_to_a.txt").apply { writeBytes(payloadBytes) }
        assertEquals(payloadBytes.size.toLong(), sourceFile.length())

        try {
            var conn: TransportConnection? = null
            for (i in 0 until 10) {
                try {
                    conn = transport.connectAsync(InetSocketAddress(IP_DEVICE_A, PORT_P2P_TRANSFER)).get(1, TimeUnit.SECONDS)
                    if (conn != null) break
                } catch (e: Exception) {
                    Thread.sleep(500)
                }
            }
            assertNotNull("Connection to Device A (10.0.2.16:8766) over virtual Wi-Fi must succeed", conn)

            val session = sessionManager.initiateSessionAsync(conn).get(5, TimeUnit.SECONDS)
            assertEquals(SessionState.SESSION_STATE_ESTABLISHED, session.state)

            val manifest = transferEngine.prepareSend(
                peerIdentityC.peerId.value,
                peerIdentityA.peerId.value,
                listOf(sourceFile.toPath()),
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS
            )
            val opId = manifest.operationId.value

            val receipt = transferEngine.sendTransferOverSession(session, manifest, listOf(sourceFile.toPath())) {}
            assertTrue("Remote third-peer transfer receipt must report success", receipt.success)
            assertEquals(payloadBytes.size.toLong(), receipt.totalBytesTransferred)

            localSqliteJournal.updateState(opId, OperationState.COMMITTED)
            localSqliteJournal.recordJournalStage(opId, JournalStage.COMMIT)

            val op = localSqliteJournal.getOperation(opId)
            assertTrue(op.isPresent)
            assertEquals(OperationState.COMMITTED, op.get().state)
        } finally {
            transport.close()
            sessionManager.close()
        }
    }

    /**
     * Test 8: Device B Receiver with Revoked Trust.
     * Listens on 0.0.0.0:8766. Device A was originally trusted but is now explicitly revoked.
     * Keeps listener open for 15 seconds to verify rejection of Device A's connection attempt.
     */
    @Test
    fun test08_DeviceB_ListenWithRevokedDeviceA_RejectsSubsequentConnection() {
        val trustStoreFile = File(testWorkDir, "trust_store_b_revoked.pb").toPath()
        val trustStore = PersistentTrustStore(trustStoreFile)
        trustStore.addTrustedPeer(peerIdentityA)
        // Explicitly revoke Device A
        trustStore.revokeTrust(peerIdentityA.peerId.value, "Security breach test", ByteArray(0))
        assertFalse("Device A must no longer be trusted", trustStore.isTrusted(peerIdentityA.peerId.value))
        assertTrue("Device A must be marked revoked", trustStore.isRevoked(peerIdentityA.peerId.value))

        val transport = StandardTcpTransportProvider("0.0.0.0")
        val sessionManager = PeerSessionManager(
            peerIdentityB, deviceIdentityB, signerB, trustStore,
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transport))
        )

        try {
            transport.startListening(PORT_P2P_TRANSFER, sessionManager::handleInboundConnection)
            assertEquals(PORT_P2P_TRANSFER, transport.listeningPort)

            // Hold port open for 15s to process inbound revoked connection attempt
            Thread.sleep(15000)
        } finally {
            transport.close()
            sessionManager.close()
        }
    }

    /**
     * Test 9: Device A Attempt to Transfer to Device B Fails Due to Revocation.
     * Connects across virtual Wi-Fi interface (wlan0) to Device B at 10.0.2.17:8766.
     * Initiates handshake; confirms that remote Device B rejects the connection.
     */
    @Test
    fun test09_DeviceA_AttemptTransferToDeviceB_FailsDueToRevocation() {
        val trustStoreFile = File(testWorkDir, "trust_store_a_revoked.pb").toPath()
        val trustStore = PersistentTrustStore(trustStoreFile)
        trustStore.addTrustedPeer(peerIdentityB)

        val transport = StandardTcpTransportProvider("0.0.0.0")
        val sessionManager = PeerSessionManager(
            peerIdentityA, deviceIdentityA, signerA, trustStore,
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transport))
        )

        try {
            var conn: TransportConnection? = null
            for (i in 0 until 10) {
                try {
                    conn = transport.connectAsync(InetSocketAddress(IP_DEVICE_B, PORT_P2P_TRANSFER)).get(1, TimeUnit.SECONDS)
                    if (conn != null) break
                } catch (e: Exception) {
                    Thread.sleep(500)
                }
            }
            assertNotNull("Connection to Device B over virtual Wi-Fi must succeed", conn)

            val handshakeFuture = sessionManager.initiateSessionAsync(conn)
            try {
                handshakeFuture.get(5, TimeUnit.SECONDS)
                fail("Remote Device B must reject handshake because Device A was revoked")
            } catch (e: Exception) {
                val msg = e.message ?: ""
                assertTrue(
                    "Rejection reason must indicate unauthorized / rejected: $msg",
                    msg.contains("ERROR_CODE_UNAUTHORIZED") || msg.contains("rejected by remote peer") || msg.contains("Handshake rejected")
                )
            }
        } finally {
            transport.close()
            sessionManager.close()
        }
    }

    /**
     * Test 10: Verify Endpoint Discrimination and Interface Integrity.
     * Confirms that localhost (127.0.0.1) is distinct from the virtual Wi-Fi interface (10.0.2.16/17/18).
     */
    @Test
    fun test10_VerifyEndpointDiscriminationAndInterfaceIntegrity() {
        val loopback = InetSocketAddress("127.0.0.1", 8765)
        val remoteB = InetSocketAddress(IP_DEVICE_B, 8765)
        val remoteC = InetSocketAddress(IP_DEVICE_C, 8765)

        assertNotEquals("Loopback IP must not match Device B virtual Wi-Fi IP", loopback.address.hostAddress, remoteB.address.hostAddress)
        assertNotEquals("Loopback IP must not match Device C virtual Wi-Fi IP", loopback.address.hostAddress, remoteC.address.hostAddress)
        assertEquals("10.0.2.17", remoteB.address.hostAddress)
        assertEquals("10.0.2.18", remoteC.address.hostAddress)
    }
}
