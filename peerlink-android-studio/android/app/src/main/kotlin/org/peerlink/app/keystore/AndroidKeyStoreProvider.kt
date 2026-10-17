package org.peerlink.app.keystore

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import org.peerlink.core.android.AndroidKeyStoreSecureKeyStore
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

/**
 * Android KeyStore provider supplying AES-256-GCM master keys for encrypting
 * PeerLink Ed25519 identity key material at rest.
 *
 * Truthful hardware inspection:
 * - Attempts StrongBox hardware security module first on Android 9+ (API 28+).
 * - Falls back to standard TEE if StrongBox is unavailable.
 * - Inspects KeyInfo to report true hardware protection (returns SOFTWARE if running on emulator or non-TEE hardware).
 * - Never claims hardware-backed signing for Ed25519; accurately reports hardware protection at rest.
 */
class AndroidKeyStoreProvider : AndroidKeyStoreSecureKeyStore.MasterKeyProvider {

    private val keyStore: KeyStore = KeyStore.getInstance("AndroidKeyStore").apply {
        load(null)
    }

    override fun getOrCreateMasterKey(alias: String): SecretKey {
        if (keyStore.containsAlias(alias)) {
            val entry = keyStore.getEntry(alias, null) as? KeyStore.SecretKeyEntry
            if (entry != null) {
                return entry.secretKey
            }
        }

        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )

        val specBuilder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)

        // Attempt StrongBox hardware security module on Android 9+ (API 28+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                specBuilder.setIsStrongBoxBacked(true)
                keyGenerator.init(specBuilder.build())
                return keyGenerator.generateKey()
            } catch (e: Exception) {
                // StrongBox not available on device, fallback to standard TEE
                specBuilder.setIsStrongBoxBacked(false)
            }
        }

        keyGenerator.init(specBuilder.build())
        return keyGenerator.generateKey()
    }

    override fun isMasterKeyHardwareBacked(alias: String): Boolean {
        return try {
            val secretKey = getOrCreateMasterKey(alias)
            val factory = SecretKeyFactory.getInstance(secretKey.algorithm, "AndroidKeyStore")
            val keyInfo = factory.getKeySpec(secretKey, KeyInfo::class.java) as KeyInfo
            keyInfo.isInsideSecureHardware
        } catch (e: Exception) {
            false // Truthful: do not assume hardware backing on failure
        }
    }

    override fun getSecurityLevel(alias: String): String {
        return try {
            val secretKey = getOrCreateMasterKey(alias)
            val factory = SecretKeyFactory.getInstance(secretKey.algorithm, "AndroidKeyStore")
            val keyInfo = factory.getKeySpec(secretKey, KeyInfo::class.java) as KeyInfo

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                when (keyInfo.securityLevel) {
                    KeyProperties.SECURITY_LEVEL_STRONGBOX -> "HARDWARE_STRONGBOX"
                    KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> "HARDWARE_TEE"
                    else -> "SOFTWARE"
                }
            } else if (keyInfo.isInsideSecureHardware) {
                "HARDWARE_TEE"
            } else {
                "SOFTWARE"
            }
        } catch (e: Exception) {
            "SOFTWARE"
        }
    }
}
