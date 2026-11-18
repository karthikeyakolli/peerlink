package org.peerlink.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.peerlink.app.keystore.AndroidKeyStoreProvider
import org.peerlink.core.android.AndroidKeyStoreSecureKeyStore
import org.peerlink.core.android.AndroidKeystoreManager
import org.peerlink.core.android.FileIdentityMetadataStore
import org.peerlink.core.security.KeyStorageException
import java.io.File
import java.util.HexFormat

/**
 * Android Instrumented Test for Android KeyStore, hardware backing inspection,
 * and AES-256-GCM wrapped Ed25519 identity persistence.
 *
 * Runs on real Android OS / emulator runtime via connectedDebugAndroidTest.
 */
@RunWith(AndroidJUnit4::class)
class AndroidKeystoreInstrumentedTest {

    private val alias = "peerlink_test_master_key"
    private lateinit var testDir: File

    @Before
    fun setUp() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        testDir = File(context.filesDir, "keystore_test_" + System.currentTimeMillis()).apply { mkdirs() }
    }

    @Test
    fun testAndroidKeyStoreMasterKeyGenerationAndInspection() {
        val provider = AndroidKeyStoreProvider()
        val masterKey = provider.getOrCreateMasterKey(alias)
        assertNotNull("Master key must not be null", masterKey)
        assertEquals("AES", masterKey.algorithm)

        // Truthful security level inspection on this device/emulator
        val secLevel = provider.getSecurityLevel(alias)
        val isHw = provider.isMasterKeyHardwareBacked(alias)
        println("Android KeyStore Master Key Security Level: $secLevel, isHardwareBacked: $isHw")
        assertNotNull(secLevel)
        assertTrue(secLevel.contains("SOFTWARE", ignoreCase = true) || secLevel.contains("TEE", ignoreCase = true) || secLevel.contains("STRONGBOX", ignoreCase = true))

        // Key persistence across re-instantiation
        val provider2 = AndroidKeyStoreProvider()
        val masterKey2 = provider2.getOrCreateMasterKey(alias)
        assertEquals(masterKey.algorithm, masterKey2.algorithm)
    }

    @Test
    fun testWrappedIdentityPersistenceAcrossManagerInstances() {
        val provider = AndroidKeyStoreProvider()
        val secureStore1 = AndroidKeyStoreSecureKeyStore(testDir, provider, alias)
        val metaStore1 = FileIdentityMetadataStore(testDir)

        val manager1 = AndroidKeystoreManager.createOrLoad(
            secureStore1,
            metaStore1,
            "Pixel Test Node",
            "Android Test",
            "1.0.0",
            provider.isMasterKeyHardwareBacked(alias),
            provider.getSecurityLevel(alias)
        )

        val peerId1 = manager1.peerId.value
        val pubKey1 = HexFormat.of().formatHex(manager1.signer.publicKeyEncoded)
        assertNotNull(peerId1)
        assertNotNull(pubKey1)
        assertEquals(88, pubKey1.length) // X.509 SubjectPublicKeyInfo encoded Ed25519 (44 bytes = 88 hex chars)

        // Simulate process restart: create completely new store and manager instances
        val provider2 = AndroidKeyStoreProvider()
        val secureStore2 = AndroidKeyStoreSecureKeyStore(testDir, provider2, alias)
        val metaStore2 = FileIdentityMetadataStore(testDir)

        val manager2 = AndroidKeystoreManager.createOrLoad(
            secureStore2,
            metaStore2,
            "Pixel Test Node",
            "Android Test",
            "1.0.0",
            provider2.isMasterKeyHardwareBacked(alias),
            provider2.getSecurityLevel(alias)
        )

        val pubKey2 = HexFormat.of().formatHex(manager2.signer.publicKeyEncoded)
        assertEquals("Peer ID must be stably persisted across restarts", peerId1, manager2.peerId.value)
        assertEquals("Public key must be stably persisted across restarts", pubKey1, pubKey2)
    }

    @Test
    fun testCorruptedCiphertextRejectionWithoutSilentRegeneration() {
        val provider = AndroidKeyStoreProvider()
        val secureStore = AndroidKeyStoreSecureKeyStore(testDir, provider, alias)

        val rawSeed = ByteArray(32) { 0x42 }
        val keyId = "test_key_001"
        secureStore.storePrivateKey(keyId, rawSeed)
        assertNotNull(secureStore.getPrivateKey(keyId))

        // Corrupt the encrypted private key file directly on disk
        val encFile = File(testDir, "keys/$keyId.enc")
        assertTrue(encFile.exists())
        val bytes = encFile.readBytes()
        bytes[bytes.size - 1] = (bytes[bytes.size - 1].toInt() xor 0xFF).toByte() // corrupt GCM auth tag
        encFile.writeBytes(bytes)

        // Loading must fail and throw KeyStorageException, NOT silently regenerate
        try {
            secureStore.getPrivateKey(keyId)
            fail("Expected KeyStorageException due to corrupted ciphertext / GCM auth tag mismatch")
        } catch (e: KeyStorageException) {
            println("Successfully caught expected KeyStorageException on ciphertext tampering: ${e.message}")
        }
    }
}
