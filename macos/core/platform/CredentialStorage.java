package org.peerlink.core.platform;

import java.util.Optional;

/**
 * Common abstraction for operating-system credential and secret storage.
 * Implementations wrap OS keychains, DPAPI, or Secret Service without leaking details into core.
 */
public interface CredentialStorage {
    /**
     * Securely store or update a secret associated with a service and account key.
     */
    void storeSecret(String service, String account, String secret);

    /**
     * Retrieve a secret.
     */
    Optional<String> getSecret(String service, String account);

    /**
     * Delete a stored secret.
     */
    boolean deleteSecret(String service, String account);

    /**
     * Check if a secret exists.
     */
    boolean hasSecret(String service, String account);
}
