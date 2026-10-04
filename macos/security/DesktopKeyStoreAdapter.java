package org.peerlink.core.security;

/**
 * Desktop OS credential/key-store adapter interface.
 * Desktop targets integrate with OS-level credential vaults (e.g. Windows DPAPI / Credential Manager,
 * macOS Keychain, Linux Secret Service).
 */
public interface DesktopKeyStoreAdapter extends SecureKeyStore {
    String getStorageMechanismName();
}
