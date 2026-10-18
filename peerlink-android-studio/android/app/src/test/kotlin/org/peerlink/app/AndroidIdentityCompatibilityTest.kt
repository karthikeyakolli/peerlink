package org.peerlink.app

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.peerlink.core.android.AndroidKeyStoreSecureKeyStore
import org.peerlink.core.android.AndroidKeystoreManager
import org.peerlink.core.android.FileIdentityMetadataStore
import org.peerlink.core.identity.DeviceIdentityManager
import org.peerlink.core.identity.IdentityCorruptionException
import org.peerlink.core.security.InMemoryTrustStore
import org.peerlink.core.security.KeyStorageException
import org.peerlink.core.security.PeerCryptoSigner
import org.peerlink.protocol.v1.DeviceType
import org.peerlink.protocol.v1.KeyType
import org.peerlink.protocol.v1.PeerId
import org.peerlink.protocol.v1.PeerIdentity
import org.peerlink.protocol.v1.TrustLevel
import java.io.DataInputStream
import java.io.File
import java.nio.charset.StandardCharsets
import java.nio.file.Files

/**
 * Task 1 Verification Suite:
 * Proves that Android cryptographic identity conforms strictly to the frozen PeerLink Ed25519 contracts,
 * is fully interoperable with desktop nodes, enforces corruption invariants without silent regeneration,
 * and truthfully reports Keystore hardware backing.
 */
class AndroidIdentityCompatibilityTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    @Test
    fun testEd25519ContractComplianceAndDerivationRuleV1() {
        val rootDir = tempFolder.newFolder("node_identity_v1")
        val masterKeyProvider = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val keyStore = AndroidKeyStoreSecureKeyStore(rootDir, masterKeyProvider, "test_master")
        val metaStore = FileIdentityMetadataStore(rootDir)

        val manager = AndroidKeystoreManager.createOrLoad(
            keyStore,
            metaStore,
            "Pixel 9 Pro",
            "Android 15",
            "0.1.0",
            false,
            "SOFTWARE_TEST_HARNESS"
        )

        // 1. Verify KeyType is ED25519 (never EC secp256r1)
        val cryptoKey = manager.peerIdentity.identityKey
        assertEquals("Android identity KeyType must be KEY_TYPE_ED25519",
            KeyType.KEY_TYPE_ED25519, cryptoKey.keyType)

        // 2. Verify Peer ID derivation matches V1 deterministic rule: "peer_" + 16 hex chars
        val peerId = manager.peerId.value
        assertTrue("PeerId must start with 'peer_'", peerId.startsWith("peer_"))
        assertEquals("PeerId must be 'peer_' + 16 hex chars (total 21 chars)", 21, peerId.length)

        // 3. Verify fingerprint format: "SHA256:" + 16 hex chars
        val fingerprint = manager.fingerprintHex
        assertTrue("Fingerprint must start with 'SHA256:'", fingerprint.startsWith("SHA256:"))
        assertEquals("Fingerprint must be 23 characters long", 23, fingerprint.length)

        // 4. Verify public key bytes can be parsed by standard PeerCryptoSigner
        val pubKeyBytes = cryptoKey.publicKeyBytes.toByteArray()
        val derivedFingerprint = PeerCryptoSigner.computeFingerprint(pubKeyBytes)
        assertEquals("Fingerprint must deterministically derive from public key", fingerprint, derivedFingerprint)
    }

    @Test
    fun testCrossPlatformHandshakeSigningAndVerification() {
        val rootDir = tempFolder.newFolder("node_handshake")
        val masterKeyProvider = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val keyStore = AndroidKeyStoreSecureKeyStore(rootDir, masterKeyProvider, "test_master")
        val metaStore = FileIdentityMetadataStore(rootDir)

        // Node A: Android Node
        val androidNode = AndroidKeystoreManager.createOrLoad(
            keyStore,
            metaStore,
            "Android-Node",
            "Android 15",
            "0.1.0",
            false,
            "SOFTWARE_TEST_HARNESS"
        )

        // Node B: Desktop Peer (independent Ed25519 keypair)
        val desktopSigner = PeerCryptoSigner.generate("desktop_key_001")
        val desktopPeerId = PeerCryptoSigner.deriveStablePeerId(desktopSigner.publicKeyEncoded)

        val connectionId = "conn_test_999"
        val sessionId = "sess_test_123"
        val nonce = PeerCryptoSigner.generateNonce(16)
        val now = System.currentTimeMillis()

        // 1. Android signs challenge -> Desktop verifies
        val androidSig = androidNode.signChallenge(connectionId, sessionId, nonce, now)
        val desktopVerificationResult = PeerCryptoSigner.verifyChallenge(
            androidNode.peerIdentity.identityKey.publicKeyBytes.toByteArray(),
            androidNode.peerId.value,
            connectionId,
            sessionId,
            nonce,
            now,
            androidSig
        )
        assertTrue("Desktop peer must successfully verify Android node's Ed25519 signature", desktopVerificationResult)

        // 2. Desktop signs challenge -> Android verifies
        val desktopSig = desktopSigner.signChallenge(desktopPeerId, connectionId, sessionId, nonce, now)
        val androidVerificationResult = androidNode.verifyPeerChallenge(
            desktopSigner.publicKeyEncoded,
            desktopPeerId,
            connectionId,
            sessionId,
            nonce,
            now,
            desktopSig
        )
        assertTrue("Android node must successfully verify Desktop peer's Ed25519 signature", androidVerificationResult)

        // 3. Tampered payload must fail verification
        val tamperedVerification = PeerCryptoSigner.verifyChallenge(
            androidNode.peerIdentity.identityKey.publicKeyBytes.toByteArray(),
            androidNode.peerId.value,
            connectionId,
            sessionId,
            nonce,
            now + 1000, // tampered timestamp
            androidSig
        )
        assertFalse("Verification of tampered challenge payload must fail", tamperedVerification)
    }

    @Test
    fun testIdentityPersistenceAcrossRestarts() {
        val rootDir = tempFolder.newFolder("node_persistence")
        val fixedMasterSeed = ByteArray(32) { (it + 42).toByte() }
        val masterKeyProvider = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider(fixedMasterSeed)

        val peerIdRun1: String
        val fingerprintRun1: String
        val pubKeyRun1: ByteArray

        // --- Run 1: First startup provisions identity ---
        run {
            val keyStore1 = AndroidKeyStoreSecureKeyStore(rootDir, masterKeyProvider, "master_alias")
            val metaStore1 = FileIdentityMetadataStore(rootDir)
            val manager1 = AndroidKeystoreManager.createOrLoad(
                keyStore1,
                metaStore1,
                "Galaxy S24",
                "Android 14",
                "0.1.0",
                false,
                "SOFTWARE_TEST_HARNESS"
            )
            peerIdRun1 = manager1.peerId.value
            fingerprintRun1 = manager1.fingerprintHex
            pubKeyRun1 = manager1.peerIdentity.identityKey.publicKeyBytes.toByteArray()
        }

        // --- Run 2: Second startup reloads persisted identity ---
        run {
            val keyStore2 = AndroidKeyStoreSecureKeyStore(rootDir, masterKeyProvider, "master_alias")
            val metaStore2 = FileIdentityMetadataStore(rootDir)
            val manager2 = AndroidKeystoreManager.createOrLoad(
                keyStore2,
                metaStore2,
                "Galaxy S24",
                "Android 14",
                "0.1.0",
                false,
                "SOFTWARE_TEST_HARNESS"
            )

            assertEquals("Peer ID must be identical across restarts", peerIdRun1, manager2.peerId.value)
            assertEquals("Fingerprint must be identical across restarts", fingerprintRun1, manager2.fingerprintHex)
            assertArrayEquals("Public key bytes must be identical across restarts",
                pubKeyRun1, manager2.peerIdentity.identityKey.publicKeyBytes.toByteArray())

            // Verify signing still works identically
            val testPayload = "test_persistence_payload".toByteArray(StandardCharsets.UTF_8)
            val sig = manager2.signData(testPayload)
            assertTrue("Reloaded identity must successfully verify self-generated signature",
                manager2.verifySignature(pubKeyRun1, testPayload, sig))
        }
    }

    @Test
    fun testCorruptedMetadataRefusesSilentRegeneration() {
        val rootDir = tempFolder.newFolder("node_corrupt_meta")
        val masterKeyProvider = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val keyStore = AndroidKeyStoreSecureKeyStore(rootDir, masterKeyProvider, "master_alias")
        val metaStore = FileIdentityMetadataStore(rootDir)

        // 1. Provision valid node
        val manager = AndroidKeystoreManager.createOrLoad(
            keyStore, metaStore, "Device", "Android", "0.1.0", false, "TEST"
        )
        assertNotNull(manager)

        // 2. Corrupt metadata file by truncating mandatory fields
        val metaFile = File(rootDir, "device_identity_meta.properties")
        assertTrue(metaFile.exists())
        metaFile.writeText("corrupted=garbage_data\n")

        // 3. Attempting to reload MUST throw IdentityCorruptionException, NOT silently regenerate
        try {
            AndroidKeystoreManager.createOrLoad(
                keyStore, metaStore, "Device", "Android", "0.1.0", false, "TEST"
            )
            fail("Expected IdentityCorruptionException when metadata is corrupt")
        } catch (e: IdentityCorruptionException) {
            assertTrue("Exception must state mandatory fields missing", e.message!!.contains("missing mandatory fields"))
        }
    }

    @Test
    fun testCorruptedPrivateKeyCiphertextRefusesSilentRegeneration() {
        val rootDir = tempFolder.newFolder("node_corrupt_key")
        val masterKeyProvider = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val keyStore = AndroidKeyStoreSecureKeyStore(rootDir, masterKeyProvider, "master_alias")
        val metaStore = FileIdentityMetadataStore(rootDir)

        // 1. Provision valid node
        val manager = AndroidKeystoreManager.createOrLoad(
            keyStore, metaStore, "Device", "Android", "0.1.0", false, "TEST"
        )
        val keyId = manager.signer.keyId

        // 2. Corrupt the encrypted private key file on disk
        val keysDir = File(rootDir, "keys")
        val keyFile = File(keysDir, "$keyId.enc")
        assertTrue(keyFile.exists())
        val originalBytes = keyFile.readBytes()
        // Corrupt ciphertext byte
        originalBytes[originalBytes.size - 5] = (originalBytes[originalBytes.size - 5].toInt() xor 0xFF).toByte()
        keyFile.writeBytes(originalBytes)

        // 3. Attempting to reload MUST throw KeyStorageException / IdentityCorruptionException
        try {
            AndroidKeystoreManager.createOrLoad(
                keyStore, metaStore, "Device", "Android", "0.1.0", false, "TEST"
            )
            fail("Expected KeyStorageException when private key ciphertext is corrupted")
        } catch (e: KeyStorageException) {
            // Expected
            assertTrue(e.message!!.contains("Failed to decrypt private key"))
        }
    }

    @Test
    fun testTruthfulSecurityLevelReporting() {
        val manager = AndroidKeystoreManager.createInMemoryTestManager("Test Node")

        // In test harness:
        assertFalse("Test harness must report not hardware protected", manager.isHardwareProtectedAtRest)
        assertFalse("Ed25519 signing is always executed in software", manager.isDirectHardwareSigning)
        assertEquals("SOFTWARE_IN_MEMORY_TEST", manager.securityLevelDescription)
    }

    @Test
    fun testFullFingerprintAndSafetyNumberDeterminism() {
        val signerA = PeerCryptoSigner.generate("key_a")
        val signerB = PeerCryptoSigner.generate("key_b")

        // 1. Verify Full Fingerprint format: "SHA256:" + 64 hex characters (total 71 chars)
        val fullFingerprintA = signerA.fullFingerprintHex
        assertTrue("Full fingerprint must start with 'SHA256:'", fullFingerprintA.startsWith("SHA256:"))
        assertEquals("Full fingerprint must be 71 characters (SHA256: + 64 hex chars)", 71, fullFingerprintA.length)

        // 2. Short display fingerprint must be a strict prefix of full fingerprint
        val shortFingerprintA = signerA.fingerprintHex
        assertTrue("Short fingerprint must be a strict prefix of full fingerprint", fullFingerprintA.startsWith(shortFingerprintA))

        // 3. Safety Number derivation symmetry: independent of initiator/responder order
        val safetyNumberAB = PeerCryptoSigner.computeSafetyNumber(signerA.publicKeyEncoded, signerB.publicKeyEncoded)
        val safetyNumberBA = PeerCryptoSigner.computeSafetyNumber(signerB.publicKeyEncoded, signerA.publicKeyEncoded)

        assertNotNull("Safety number must not be null", safetyNumberAB)
        assertEquals("Safety number must be symmetric regardless of who initiates pairing", safetyNumberAB, safetyNumberBA)
        // Format: 6 blocks of 5 digits separated by spaces = "XXXXX XXXXX XXXXX XXXXX XXXXX XXXXX" (35 chars)
        assertEquals("Safety number must format as 6 blocks of 5 digits", 35, safetyNumberAB.length)
        val blocks = safetyNumberAB.split(" ")
        assertEquals(6, blocks.size)
        blocks.forEach { block ->
            assertEquals(5, block.length)
            assertTrue("Block must consist solely of numeric digits", block.all { it.isDigit() })
        }

        // 4. Differing keys must produce different safety numbers
        val signerC = PeerCryptoSigner.generate("key_c")
        val safetyNumberAC = PeerCryptoSigner.computeSafetyNumber(signerA.publicKeyEncoded, signerC.publicKeyEncoded)
        assertNotEquals("Different peer keys must yield completely distinct safety numbers", safetyNumberAB, safetyNumberAC)
    }

    @Test
    fun testCollisionResistanceAndIdentityDisambiguation() {
        val trustStore = InMemoryTrustStore()
        val signerA = PeerCryptoSigner.generate("key_legit")
        val legitPeerId = PeerCryptoSigner.deriveStablePeerId(signerA.publicKeyEncoded)

        val legitPeer = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(legitPeerId).build())
            .setDisplayName("Legitimate Peer")
            .setIdentityKey(signerA.toProtobufKey(System.currentTimeMillis()))
            .setFingerprintHex(signerA.fingerprintHex)
            .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
            .build()

        trustStore.addTrustedPeer(legitPeer)
        assertTrue(trustStore.isTrusted(legitPeerId))

        // Attacker creates a different keypair and attempts to masquerade under the same Peer ID
        val signerAttacker = PeerCryptoSigner.generate("key_attacker")
        val attackerClonedPeer = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(legitPeerId).build()) // Same Peer ID
            .setDisplayName("Attacker Masquerading")
            .setIdentityKey(signerAttacker.toProtobufKey(System.currentTimeMillis())) // Different Public Key
            .setFingerprintHex(signerAttacker.fingerprintHex)
            .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
            .build()

        // TrustStore MUST detect cloned public key and throw SecurityException
        try {
            trustStore.addTrustedPeer(attackerClonedPeer)
            fail("Expected SecurityException when a conflicting public key claims an existing Peer ID")
        } catch (e: SecurityException) {
            assertTrue("Must report cloned identity detected", e.message!!.contains("Cloned identity detected"))
        }
    }

    @Test
    fun testAesGcmNonceUniquenessAcrossMultipleWrapIterations() {
        val rootDir = tempFolder.newFolder("nonce_test")
        val masterKeyProvider = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val keyStore = AndroidKeyStoreSecureKeyStore(rootDir, masterKeyProvider, "test_alias")

        val ivSet = HashSet<String>()
        val dummyPrivateKey = ByteArray(32) { 0x42 }

        // Test 200 wrap iterations (verifying random 96-bit IV per encryption)
        val iterations = 200
        for (i in 0 until iterations) {
            val keyId = "test_key_$i"
            keyStore.storePrivateKey(keyId, dummyPrivateKey)

            val encFile = File(rootDir, "keys/$keyId.enc")
            assertTrue("Encrypted key file must exist", encFile.exists())

            // Read the 12-byte IV from the header
            DataInputStream(encFile.inputStream()).use { dis ->
                val magic = dis.readInt()
                assertEquals(0x50454552, magic)
                val version = dis.readInt()
                assertEquals(1, version)
                val storedKeyId = dis.readUTF()
                assertEquals(keyId, storedKeyId)
                val ivLen = dis.readInt()
                assertEquals(12, ivLen) // 96 bits
                val ivBytes = ByteArray(ivLen)
                dis.readFully(ivBytes)
                val ivHex = ivBytes.joinToString("") { "%02x".format(it) }

                assertFalse("IV must never be reused across encryptions (collision at iteration $i)", ivSet.contains(ivHex))
                ivSet.add(ivHex)
            }
        }
        assertEquals(iterations, ivSet.size)
    }

    @Test
    fun testMasterKeyCorruptionAndLockRejection() {
        val rootDir = tempFolder.newFolder("master_corrupt")
        // Master Key Provider A
        val masterProviderA = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider(ByteArray(32) { 0x01 })
        val keyStoreA = AndroidKeyStoreSecureKeyStore(rootDir, masterProviderA, "alias_a")

        val keyId = "secret_identity_key"
        val originalSecret = "TopSecretEd25519PrivateKeyMaterial".toByteArray(StandardCharsets.UTF_8)
        keyStoreA.storePrivateKey(keyId, originalSecret)

        // Attempt retrieval with WRONG Master Key (simulating corrupted keystore or hardware key failure)
        val masterProviderB = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider(ByteArray(32) { 0x02 })
        val keyStoreB = AndroidKeyStoreSecureKeyStore(rootDir, masterProviderB, "alias_a")

        try {
            keyStoreB.getPrivateKey(keyId)
            fail("Expected KeyStorageException when master key cannot decrypt ciphertext (GCM tag mismatch)")
        } catch (e: KeyStorageException) {
            assertTrue("Error must indicate decryption failure or corruption",
                e.message!!.contains("Failed to decrypt private key"))
        }

        // Verify key file still exists and was NOT silently overwritten or wiped
        val keyFile = File(rootDir, "keys/$keyId.enc")
        assertTrue("Ciphertext file must remain intact after failed decryption attempt", keyFile.exists())
    }

    @Test
    fun testThreeWayVerificationDistinction() {
        val signerA = PeerCryptoSigner.generate("key_alpha")
        val signerB = PeerCryptoSigner.generate("key_beta")

        // 1. Full SHA-256 Identity Fingerprint (Single key / Node identity)
        val fullFpA = signerA.fullFingerprintHex
        val fullFpB = signerB.fullFingerprintHex
        assertTrue("Full fingerprint format must start with 'SHA256:'", fullFpA.startsWith("SHA256:"))
        assertEquals("Full fingerprint must be 71 characters (SHA256: + 64 hex chars)", 71, fullFpA.length)
        assertNotEquals("Distinct keys must yield distinct full fingerprints", fullFpA, fullFpB)

        // 2. Pairwise Verification Number (Stable across sessions between two paired nodes)
        val safetyNumberAB = PeerCryptoSigner.computeSafetyNumber(signerA.publicKeyEncoded, signerB.publicKeyEncoded)
        val safetyNumberBA = PeerCryptoSigner.computeSafetyNumber(signerB.publicKeyEncoded, signerA.publicKeyEncoded)
        assertEquals("Pairwise safety number must be strictly symmetric", safetyNumberAB, safetyNumberBA)
        assertEquals(35, safetyNumberAB.length) // 6 blocks of 5 digits separated by spaces
        val blocks = safetyNumberAB.split(" ")
        assertEquals(6, blocks.size)
        blocks.forEach { assertTrue(it.all { c -> c.isDigit() }) }

        // 3. Ephemeral Session Authentication Code (Specific to a single connection attempt)
        val sessionId = "session_xyz_789"
        val nonceA = byteArrayOf(0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08)
        val nonceB = byteArrayOf(0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80.toByte())
        val now = 1700000000000L

        val sessionCodeAB = PeerCryptoSigner.computeSessionAuthCode(
            sessionId, nonceA, nonceB, signerA.publicKeyEncoded, signerB.publicKeyEncoded, now
        )
        val sessionCodeBA = PeerCryptoSigner.computeSessionAuthCode(
            sessionId, nonceA, nonceB, signerB.publicKeyEncoded, signerA.publicKeyEncoded, now
        )
        assertEquals("Session code must be symmetric between initiator and responder", sessionCodeAB, sessionCodeBA)
        assertEquals("Session code must format as 6 decimal digits", 6, sessionCodeAB.length)
        assertTrue(sessionCodeAB.all { it.isDigit() })

        // A different session ID or timestamp MUST produce a completely different session code
        val differentSessionCode = PeerCryptoSigner.computeSessionAuthCode(
            "session_other", nonceA, nonceB, signerA.publicKeyEncoded, signerB.publicKeyEncoded, now
        )
        assertNotEquals("Different session ID must alter session auth code", sessionCodeAB, differentSessionCode)
    }

    @Test
    fun testSubstitutedKeyAndTamperedChallengeRejection() {
        val legitimateSigner = PeerCryptoSigner.generate("key_legit")
        val attackerSigner = PeerCryptoSigner.generate("key_attacker")

        val peerId = "peer_legit"
        val connectionId = "conn_123"
        val sessionId = "sess_456"
        val nonce = byteArrayOf(0xAA.toByte(), 0xBB.toByte(), 0xCC.toByte(), 0xDD.toByte())
        val timestamp = 1700000000000L

        // Legitimate signer signs challenge
        val legitimateSignature = legitimateSigner.signChallenge(peerId, connectionId, sessionId, nonce, timestamp)

        // 1. Verify with correct public key succeeds
        val valid = PeerCryptoSigner.verifyChallenge(
            legitimateSigner.publicKeyEncoded, peerId, connectionId, sessionId, nonce, timestamp, legitimateSignature
        )
        assertTrue("Challenge verification with legitimate key must succeed", valid)

        // 2. Verify with substituted attacker public key MUST fail
        val invalidKey = PeerCryptoSigner.verifyChallenge(
            attackerSigner.publicKeyEncoded, peerId, connectionId, sessionId, nonce, timestamp, legitimateSignature
        )
        assertFalse("Challenge verification with substituted key MUST fail", invalidKey)

        // 3. Verify with tampered nonce MUST fail
        val tamperedNonce = byteArrayOf(0x00, 0xBB.toByte(), 0xCC.toByte(), 0xDD.toByte())
        val invalidNonce = PeerCryptoSigner.verifyChallenge(
            legitimateSigner.publicKeyEncoded, peerId, connectionId, sessionId, tamperedNonce, timestamp, legitimateSignature
        )
        assertFalse("Challenge verification with tampered nonce MUST fail", invalidNonce)

        // 4. Verify with tampered timestamp MUST fail
        val invalidTimestamp = PeerCryptoSigner.verifyChallenge(
            legitimateSigner.publicKeyEncoded, peerId, connectionId, sessionId, nonce, timestamp + 1000, legitimateSignature
        )
        assertFalse("Challenge verification with tampered timestamp MUST fail", invalidTimestamp)
    }

    @Test
    fun testTruthfulSecurityLevelHardwareInspection() {
        val manager = AndroidKeystoreManager.createInMemoryTestManager("Test Android Node")

        // Invariant: direct hardware signing is truthfully false (Android KeyStore does not do direct Ed25519)
        assertFalse("isDirectHardwareSigning must truthfully return false", manager.isDirectHardwareSigning)

        // Test in-memory manager has software security description
        assertEquals("SOFTWARE_IN_MEMORY_TEST", manager.securityLevelDescription)
        assertFalse("In-memory test manager is not hardware protected", manager.isHardwareProtectedAtRest)
    }
}
