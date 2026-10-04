package org.peerlink.core.ai.model;

/**
 * Data privacy classification levels for AI context inputs.
 */
public enum PrivacyLevel {
    /**
     * Non-confidential operational metadata (e.g. extension, file size, connection type).
     */
    NORMAL,

    /**
     * User-identifiable metadata (e.g. full file names, relative paths, peer device names).
     * Requires user authorization and redaction of sensitive identifiers.
     */
    SENSITIVE,

    /**
     * Cryptographic keys, credentials, token secrets, auth headers, private file contents,
     * and clipboard entries. STRICTLY FORBIDDEN from ever being transmitted to external AI providers.
     */
    HIGHLY_SENSITIVE
}
