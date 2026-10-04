package org.peerlink.core.security;

import org.peerlink.protocol.v1.PeerIdentity;
import org.peerlink.protocol.v1.RevocationRecord;
import org.peerlink.protocol.v1.TrustLevel;

import java.io.IOException;
import java.util.Collection;
import java.util.Optional;

/**
 * Trust store interface for PeerLink cryptographic trust management.
 * Invariant: Discovery does NOT establish trust.
 * Trusted peer status requires explicit cryptographic pairing and verification.
 */
public interface TrustStore {

    boolean isTrusted(String peerId);

    boolean isRevoked(String peerId);

    TrustLevel getTrustLevel(String peerId);

    void addTrustedPeer(PeerIdentity peer);

    // Convenience method for simple pairing
    void addTrustedPeer(String peerId, String fingerprint, byte[] publicKey);

    void revokeTrust(String peerId);

    void revokeTrust(String peerId, String reason, byte[] signature);

    Optional<String> getFingerprint(String peerId);

    Optional<PeerIdentity> getPeer(String peerId);

    Collection<PeerIdentity> getAllPeers();

    Collection<RevocationRecord> getRevocations();

    byte[] exportTrustSnapshot(PeerCryptoSigner signer) throws IOException;

    void importTrustSnapshot(byte[] snapshotBytes, byte[] expectedSignerPublicKey) throws IOException;
}
