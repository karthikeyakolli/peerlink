package org.peerlink.core.security;

/**
 * Android Keystore hardware-backed security abstraction.
 * Android targets implement this contract using AndroidKeyStore provider,
 * backed by hardware TEE (Trusted Execution Environment) or StrongBox Keymaster.
 */
public interface AndroidKeyStoreAdapter extends SecureKeyStore {
    boolean isInsideSecureHardware(String keyId);
}
