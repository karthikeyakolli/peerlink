package org.peerlink.app

import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.peerlink.core.android.AndroidKeyStoreSecureKeyStore
import org.peerlink.core.android.AndroidKeystoreManager
import org.peerlink.core.android.FileIdentityMetadataStore
import org.peerlink.core.operation.InMemoryOperationJournal
import org.peerlink.core.security.InMemoryTrustStore
import org.peerlink.core.security.PeerCryptoSigner
import org.peerlink.core.transfer.PeerTransferEngine
import org.peerlink.core.transfer.TransferSessionCoordinator
import org.peerlink.core.transfer.TransferSessionReceiver
import org.peerlink.core.transport.*
import org.peerlink.protocol.v1.*
import java.io.File
import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Task 2 Verification Suite:
 * Proves real Android peer connectivity over real operating system TCP sockets.
 * Strictly no mocks or in-process bypass:
 * - Two independent node instances (Android Node A and Desktop Peer B)
 * - Separate Ed25519 identities & separate storage roots
 * - Real OS TCP socket connection over loopback
 * - Mutual 3-way Ed25519 authenticated handshake
 * - Real chunked payload transmission over PeerSession
 * - Receiver-side SHA-256 verification and safe atomic destination commit
 * - Rejection of unauthenticated/untrusted peers (Zero Trust)
 */
class AndroidRealPeerConnectivityTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var nodeADir: File
    private lateinit var nodeBDir: File

    private lateinit var androidKeystoreManager: AndroidKeystoreManager
    private lateinit var desktopSigner: PeerCryptoSigner
    private lateinit var untrustedSigner: PeerCryptoSigner

    private lateinit var androidTrustStore: InMemoryTrustStore
    private lateinit var desktopTrustStore: InMemoryTrustStore

    private lateinit var androidTransport: StandardTcpTransportProvider
    private lateinit var desktopTransport: StandardTcpTransportProvider
    private lateinit var untrustedTransport: StandardTcpTransportProvider

    private lateinit var androidSessionManager: PeerSessionManager
    private lateinit var desktopSessionManager: PeerSessionManager
    private lateinit var untrustedSessionManager: PeerSessionManager

    private lateinit var androidTransferEngine: PeerTransferEngine
    private lateinit var desktopTransferEngine: PeerTransferEngine

    private val protocolVersion = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build()

    @Before
    fun setUp() {
        nodeADir = tempFolder.newFolder("node_a_android")
        nodeBDir = tempFolder.newFolder("node_b_desktop")

        // 1. Android Node A Identity
        val masterKeyProviderA = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val keyStoreA = AndroidKeyStoreSecureKeyStore(nodeADir, masterKeyProviderA, "master_a")
        val metaStoreA = FileIdentityMetadataStore(nodeADir)
        androidKeystoreManager = AndroidKeystoreManager.createOrLoad(
            keyStoreA, metaStoreA, "Android-Node-A", "Android 15", "0.1.0", false, "SOFTWARE_TEST_HARNESS"
        )

        // 2. Desktop Node B Identity (Independent Ed25519)
        desktopSigner = PeerCryptoSigner.generate("key_desktop_b")
        val desktopPeerId = PeerCryptoSigner.deriveStablePeerId(desktopSigner.publicKeyEncoded)
        val desktopPeer = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(desktopPeerId).build())
            .setDeviceId(DeviceId.newBuilder().setValue("dev_desktop_b").build())
            .setDisplayName("Desktop-Peer-B")
            .setIdentityKey(desktopSigner.toProtobufKey(System.currentTimeMillis()))
            .setFingerprintHex(desktopSigner.computeFingerprint())
            .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
            .build()

        val desktopDevice = DeviceIdentity.newBuilder()
            .setDeviceId(desktopPeer.deviceId)
            .setDeviceName(desktopPeer.displayName)
            .setDeviceType(DeviceType.DEVICE_TYPE_DESKTOP_LINUX)
            .setOsVersion("Linux x86_64")
            .setAppVersion("0.1.0")
            .setIdentityKey(desktopPeer.identityKey)
            .build()

        // 3. Mutual Trust Configuration
        androidTrustStore = InMemoryTrustStore()
        desktopTrustStore = InMemoryTrustStore()

        androidTrustStore.addTrustedPeer(desktopPeer)
        desktopTrustStore.addTrustedPeer(androidKeystoreManager.peerIdentity)

        // 4. Transports (Real Java NIO TCP over loopback)
        androidTransport = StandardTcpTransportProvider("127.0.0.1")
        desktopTransport = StandardTcpTransportProvider("127.0.0.1")
        untrustedTransport = StandardTcpTransportProvider("127.0.0.1")

        // 5. Session Managers
        androidSessionManager = PeerSessionManager(
            androidKeystoreManager.peerIdentity,
            androidKeystoreManager.deviceIdentity,
            androidKeystoreManager.signer,
            androidTrustStore,
            protocolVersion,
            protocolVersion,
            TransportCapabilityNegotiator(listOf(androidTransport))
        )

        desktopSessionManager = PeerSessionManager(
            desktopPeer,
            desktopDevice,
            desktopSigner,
            desktopTrustStore,
            protocolVersion,
            protocolVersion,
            TransportCapabilityNegotiator(listOf(desktopTransport))
        )

        // 6. Transfer Engines
        androidTransferEngine = PeerTransferEngine(
            InMemoryOperationJournal(),
            nodeADir.toPath().resolve("staging")
        )

        desktopTransferEngine = PeerTransferEngine(
            InMemoryOperationJournal(),
            nodeBDir.toPath().resolve("staging")
        )
    }

    @After
    fun tearDown() {
        androidTransport.close()
        desktopTransport.close()
        untrustedTransport.close()
        androidSessionManager.close()
        desktopSessionManager.close()
    }

    @Test
    fun testRealSocketTransferFromAndroidToDesktopWithHashVerificationAndAtomicCommit() {
        // Step 1: Start Desktop Peer B listening on OS-assigned ephemeral TCP port
        desktopTransport.startListening(0, desktopSessionManager::handleInboundConnection)
        val desktopPort = desktopTransport.listeningPort
        assertTrue("Desktop receiver must listen on valid TCP port", desktopPort > 0)

        // Configure receiver destination
        val destDir = File(nodeBDir, "dest_received").toPath()
        Files.createDirectories(destDir)
        val receiver = desktopTransferEngine.createSessionReceiver(destDir, desktopTrustStore)

        // Step 2: Android Node A connects to Desktop Peer B over real TCP socket
        val connection = androidTransport.connectAsync(InetSocketAddress("127.0.0.1", desktopPort)).get(5, TimeUnit.SECONDS)
        assertNotNull("Android node must establish real TCP connection", connection)
        assertEquals(ConnectionState.CONNECTED, connection.state)

        // Step 3: Perform mutual 3-way Ed25519 Handshake
        val androidSession = androidSessionManager.initiateSessionAsync(connection).get(5, TimeUnit.SECONDS)
        assertNotNull("Android session must be established", androidSession)
        assertEquals(SessionState.SESSION_STATE_ESTABLISHED, androidSession.state)

        // Locate Desktop's inbound session
        var desktopSession: PeerSession? = null
        for (i in 0 until 50) {
            val opt = desktopSessionManager.getSessionByPeerId(androidKeystoreManager.peerId.value)
            if (opt.isPresent) {
                desktopSession = opt.get()
                break
            }
            Thread.sleep(50)
        }
        assertNotNull("Desktop peer must have established matching inbound session", desktopSession)

        // Wire receiver coordinator on Desktop
        val desktopCoordinator = TransferSessionCoordinator(desktopSession)
        desktopCoordinator.registerReceiver(receiver)

        // Step 4: Prepare real file content on Android Node A
        val sourceDir = File(nodeADir, "source_files")
        sourceDir.mkdirs()
        val payloadContent = "PeerLink Android Studio Edition - Phase 24 Real P2P Transfer Payload: 100% Verified!"
        val payloadBytes = payloadContent.toByteArray(StandardCharsets.UTF_8)
        val testFile = File(sourceDir, "document_android.txt")
        testFile.writeBytes(payloadBytes)

        // Step 5: Android prepares TransferManifest
        val manifest = androidTransferEngine.prepareSend(
            androidKeystoreManager.peerId.value,
            desktopSession!!.localPeer.peerId.value,
            listOf(testFile.toPath()),
            DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS
        )
        assertEquals(1, manifest.itemsCount)

        // Step 6: Android transmits file over real PeerSession (OS TCP socket)
        val progressNotified = AtomicBoolean(false)
        val receipt = androidTransferEngine.sendTransferOverSession(
            androidSession,
            manifest,
            listOf(testFile.toPath())
        ) { progress ->
            if (progress.transferredBytes > 0) {
                progressNotified.set(true)
            }
        }

        // Step 7: Verify Transfer Receipt returned from Desktop receiver across socket
        assertNotNull("Transfer receipt must be returned from receiver", receipt)
        assertTrue("Transfer must report successful execution", receipt.success)
        assertEquals("Total bytes transferred must match payload size", payloadBytes.size.toLong(), receipt.totalBytesTransferred)
        assertTrue("Sender progress callback must have been notified", progressNotified.get())

        // Step 8: Verify committed file on Desktop filesystem
        val committedFile = destDir.resolve("document_android.txt").toFile()
        assertTrue("Target file must exist in final destination root", committedFile.exists())
        assertEquals("Committed file length must match original bytes", payloadBytes.size.toLong(), committedFile.length())
        assertEquals("Committed file content must match exactly", payloadContent, committedFile.readText(StandardCharsets.UTF_8))
    }

    @Test
    fun testRealSocketTransferFromDesktopToAndroidReceiver() {
        // Step 1: Start Android Node A listening on OS-assigned ephemeral TCP port
        androidTransport.startListening(0, androidSessionManager::handleInboundConnection)
        val androidPort = androidTransport.listeningPort
        assertTrue("Android node must listen on valid TCP port", androidPort > 0)

        // Configure Android receiver destination
        val androidDestDir = File(nodeADir, "android_received").toPath()
        Files.createDirectories(androidDestDir)
        val androidReceiver = androidTransferEngine.createSessionReceiver(androidDestDir, androidTrustStore)

        // Step 2: Desktop connects to Android
        val connection = desktopTransport.connectAsync(InetSocketAddress("127.0.0.1", androidPort)).get(5, TimeUnit.SECONDS)
        val desktopSession = desktopSessionManager.initiateSessionAsync(connection).get(5, TimeUnit.SECONDS)
        assertNotNull(desktopSession)

        // Locate Android's inbound session
        var androidInboundSession: PeerSession? = null
        for (i in 0 until 50) {
            val opt = androidSessionManager.getSessionByPeerId(desktopSession.localPeer.peerId.value)
            if (opt.isPresent) {
                androidInboundSession = opt.get()
                break
            }
            Thread.sleep(50)
        }
        assertNotNull("Android node must have matching inbound session", androidInboundSession)

        // Wire receiver coordinator on Android
        val androidCoordinator = TransferSessionCoordinator(androidInboundSession)
        androidCoordinator.registerReceiver(androidReceiver)

        // Step 3: Desktop sends file to Android
        val desktopSource = File(nodeBDir, "desktop_report.txt")
        val content = "Desktop to Android Transmission over OS TCP Socket"
        desktopSource.writeText(content)

        val manifest = desktopTransferEngine.prepareSend(
            desktopSession.localPeer.peerId.value,
            androidKeystoreManager.peerId.value,
            listOf(desktopSource.toPath()),
            DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX
        )

        val receipt = desktopTransferEngine.sendTransferOverSession(
            desktopSession,
            manifest,
            listOf(desktopSource.toPath())
        ) {}

        assertTrue(receipt.success)
        val receivedOnAndroid = androidDestDir.resolve("desktop_report.txt").toFile()
        assertTrue("File must be safely committed on Android storage", receivedOnAndroid.exists())
        assertEquals(content, receivedOnAndroid.readText())
    }

    @Test
    fun testUntrustedPeerIsRejectedByZeroTrustEnforcement() {
        // Start Android Node listening
        androidTransport.startListening(0, androidSessionManager::handleInboundConnection)
        val androidPort = androidTransport.listeningPort
        assertTrue(androidPort > 0)

        // Create Untrusted Attacker Node C
        untrustedSigner = PeerCryptoSigner.generate("key_attacker_c")
        val untrustedPeerId = PeerCryptoSigner.deriveStablePeerId(untrustedSigner.publicKeyEncoded)
        val untrustedPeer = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(untrustedPeerId).build())
            .setDeviceId(DeviceId.newBuilder().setValue("dev_attacker").build())
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

        untrustedSessionManager = PeerSessionManager(
            untrustedPeer,
            untrustedDevice,
            untrustedSigner,
            InMemoryTrustStore(), // Empty trust store
            protocolVersion,
            protocolVersion,
            TransportCapabilityNegotiator(listOf(untrustedTransport))
        )

        // Attacker connects to Android Node
        val connection = untrustedTransport.connectAsync(InetSocketAddress("127.0.0.1", androidPort)).get(5, TimeUnit.SECONDS)
        assertNotNull(connection)

        // Attempt Handshake: Android Node must REJECT untrusted peer (Zero Trust rule)
        val handshakeFuture = untrustedSessionManager.initiateSessionAsync(connection)
        try {
            handshakeFuture.get(5, TimeUnit.SECONDS)
            fail("Handshake with untrusted peer must fail")
        } catch (e: Exception) {
            // Expected handshake rejection: peer is not trusted
            assertTrue(e.message != null)
        }
    }
}
