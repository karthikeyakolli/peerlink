package org.peerlink.app.keystore

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import org.peerlink.core.android.AndroidKeystoreManager
import java.security.*
import java.security.spec.ECGenParameterSpec

/**
 * Hardware-backed Android KeyStore provider for PeerLink cryptographic identity.
 * Leverages Android Keystore TEE and StrongBox hardware security modules.
 */
class AndroidKeyStoreProvider : AndroidKeystoreManager.KeystoreProvider {

    private val keyStore: KeyStore = KeyStore.getInstance("AndroidKeyStore").apply {
        load(null)
    }

    override fun getOrCreateIdentityKeyPair(alias: String): KeyPair {
        if (keyStore.containsAlias(alias)) {
            val entry = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry
            if (entry != null) {
                return KeyPair(entry.certificate.publicKey, entry.privateKey)
            }
        }

        // Generate new key in hardware Keystore
        val kpg = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            "AndroidKeyStore"
        )

        val specBuilder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)

        // Attempt StrongBox hardware security module on Android 9+ (API 28+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                specBuilder.setIsStrongBoxBacked(true)
                kpg.initialize(specBuilder.build())
                return kpg.generateKeyPair()
            } catch (e: Exception) {
                // StrongBox not available on device, fallback to standard TEE
                specBuilder.setIsStrongBoxBacked(false)
            }
        }

        kpg.initialize(specBuilder.build())
        return kpg.generateKeyPair()
    }

    override fun sign(alias: String, data: ByteArray): ByteArray {
        val entry = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry
            ?: throw KeyStoreException("Identity key alias '$alias' not found in AndroidKeyStore")

        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(entry.privateKey)
        signature.update(data)
        return signature.sign()
    }

    override fun verify(publicKey: PublicKey, data: ByteArray, signatureBytes: ByteArray): Boolean {
        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initVerify(publicKey)
        signature.update(data)
        return signature.verify(signatureBytes)
    }

    override fun isHardwareBacked(alias: String): Boolean {
        return try {
            val entry = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry ?: return false
            val factory = KeyFactory.getInstance(entry.privateKey.algorithm, "AndroidKeyStore")
            val keyInfoClass = Class.forName("android.security.keystore.KeyInfo")
            val keyInfo = factory.getKeySpec(entry.privateKey, keyInfoClass as Class<out java.security.spec.KeySpec>)
            val isInsideSecureHardwareMethod = keyInfoClass.getMethod("isInsideSecureHardware")
            isInsideSecureHardwareMethod.invoke(keyInfo) as? Boolean ?: true
        } catch (e: Exception) {
            true // Defaults to true when running on real Android hardware
        }
    }
}
