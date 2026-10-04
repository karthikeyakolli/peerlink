package org.peerlink.core.access;

import org.peerlink.protocol.v1.AccessScope;

import java.nio.file.Path;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/**
 * Definition of an explicitly shared directory root on the host machine.
 *
 * <p>Invariant: A local peer never exposes the entire filesystem.
 * Only designated ShareDefinitions with explicit allowed peers and scopes can be accessed.
 */
public record ShareDefinition(
        String shareId,
        String displayName,
        Path rootDirectory,
        Set<String> allowedPeerIds,
        Set<AccessScope> allowedScopes,
        long createdAtUtcMs,
        long expiresAtUtcMs,
        String authSecret
) {
    public ShareDefinition {
        if (shareId == null || shareId.isBlank()) {
            throw new IllegalArgumentException("shareId cannot be blank");
        }
        if (rootDirectory == null) {
            throw new IllegalArgumentException("rootDirectory cannot be null");
        }
        if (authSecret == null || authSecret.isBlank()) {
            throw new IllegalArgumentException("authSecret cannot be blank");
        }
        allowedPeerIds = allowedPeerIds == null ? Set.of() : Collections.unmodifiableSet(new HashSet<>(allowedPeerIds));
        allowedScopes = allowedScopes == null ? Set.of() : Collections.unmodifiableSet(new HashSet<>(allowedScopes));
    }

    public boolean isExpired(long nowUtcMs) {
        return expiresAtUtcMs > 0 && nowUtcMs > expiresAtUtcMs;
    }

    public boolean isPeerPermitted(String peerId) {
        if (allowedPeerIds.isEmpty()) {
            return false; // By default, explicit peer authorization is required
        }
        return allowedPeerIds.contains(peerId);
    }

    public boolean allowsScope(AccessScope scope) {
        return allowedScopes.contains(AccessScope.ACCESS_SCOPE_FULL) || allowedScopes.contains(scope);
    }
}
