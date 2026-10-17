package org.peerlink.core.identity;

import java.util.Map;
import java.util.Optional;

/**
 * Storage abstraction for persisting and reading device cryptographic identity metadata.
 * Invariant: Actual private key bytes are managed exclusively by SecureKeyStore;
 * non-sensitive identity metadata (peer ID, device ID, public key, fingerprint) lives here.
 */
public interface IdentityMetadataStore {

    /**
     * Loads persisted identity metadata attributes.
     * Expected keys: peer_id, device_id, device_name, device_type, key_id, public_key_hex,
     * fingerprint, created_at_ms, derivation_version.
     */
    Optional<Map<String, String>> loadIdentityMetadata();

    /**
     * Persists identity metadata attributes atomically.
     */
    void saveIdentityMetadata(Map<String, String> metadata);

    /**
     * Checks if an identity record already exists in storage.
     */
    boolean hasIdentityMetadata();
}
