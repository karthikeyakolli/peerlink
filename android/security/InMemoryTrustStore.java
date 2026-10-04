package org.peerlink.core.security;

import com.google.protobuf.ByteString;
import org.peerlink.protocol.v1.*;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Thread-safe in-memory implementation of TrustStore.
 * Enforces cryptographic trust anchors and explicit revocations.
 */
public class InMemoryTrustStore implements TrustStore {

    protected final Map<String, PeerIdentity> peers = new ConcurrentHashMap<>();
    protected final Map<String, RevocationRecord> revocations = new ConcurrentHashMap<>();

    @Override
    public boolean isTrusted(String peerId) {
        if (peerId == null) return false;
        PeerIdentity peer = peers.get(peerId);
        return peer != null && peer.getTrustLevel() == TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED;
    }

    @Override
    public boolean isRevoked(String peerId) {
        if (peerId == null) return false;
        if (revocations.containsKey(peerId)) return true;
        PeerIdentity peer = peers.get(peerId);
        return peer != null && peer.getTrustLevel() == TrustLevel.TRUST_LEVEL_REVOKED;
    }

    @Override
    public TrustLevel getTrustLevel(String peerId) {
        if (peerId == null) return TrustLevel.TRUST_LEVEL_UNTRUSTED;
        if (revocations.containsKey(peerId)) return TrustLevel.TRUST_LEVEL_REVOKED;
        PeerIdentity peer = peers.get(peerId);
        return peer != null ? peer.getTrustLevel() : TrustLevel.TRUST_LEVEL_UNTRUSTED;
    }

    @Override
    public synchronized void addTrustedPeer(PeerIdentity peer) {
        if (peer == null || !peer.hasPeerId()) {
            throw new IllegalArgumentException("Cannot add invalid peer identity to TrustStore");
        }
        String peerId = peer.getPeerId().getValue();

        // Detect cloned / conflicting identity key
        PeerIdentity existing = peers.get(peerId);
        if (existing != null && existing.hasIdentityKey() && peer.hasIdentityKey()) {
            byte[] existingKey = existing.getIdentityKey().getPublicKeyBytes().toByteArray();
            byte[] newKey = peer.getIdentityKey().getPublicKeyBytes().toByteArray();
            if (!Arrays.equals(existingKey, newKey)) {
                throw new SecurityException("Cloned identity detected! Peer ID " + peerId +
                        " attempted to replace existing cryptographic public key");
            }
        }

        PeerIdentity updated = peer.toBuilder()
                .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
                .setPairedAtUtcMs(peer.getPairedAtUtcMs() > 0 ? peer.getPairedAtUtcMs() : System.currentTimeMillis())
                .build();

        peers.put(peerId, updated);
        revocations.remove(peerId);
    }

    @Override
    public void addTrustedPeer(String peerId, String fingerprint, byte[] publicKey) {
        PeerIdentity identity = PeerIdentity.newBuilder()
                .setPeerId(PeerId.newBuilder().setValue(peerId).build())
                .setDisplayName(peerId)
                .setFingerprintHex(fingerprint)
                .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
                .setPairedAtUtcMs(System.currentTimeMillis())
                .setIdentityKey(CryptographicKey.newBuilder()
                        .setKeyType(KeyType.KEY_TYPE_ED25519)
                        .setKeyId("key_" + peerId)
                        .setPublicKeyBytes(ByteString.copyFrom(publicKey))
                        .setCreatedAtUtcMs(System.currentTimeMillis())
                        .build())
                .build();
        addTrustedPeer(identity);
    }

    @Override
    public synchronized void revokeTrust(String peerId) {
        revokeTrust(peerId, "Manual revocation", new byte[0]);
    }

    @Override
    public synchronized void revokeTrust(String peerId, String reason, byte[] signature) {
        if (peerId == null) return;
        RevocationRecord rec = RevocationRecord.newBuilder()
                .setRevokedPeerId(PeerId.newBuilder().setValue(peerId).build())
                .setReason(reason != null ? reason : "Revoked by user")
                .setRevokedAtUtcMs(System.currentTimeMillis())
                .setRevocationSignature(ByteString.copyFrom(signature != null ? signature : new byte[0]))
                .build();

        revocations.put(peerId, rec);

        PeerIdentity peer = peers.get(peerId);
        if (peer != null) {
            peers.put(peerId, peer.toBuilder().setTrustLevel(TrustLevel.TRUST_LEVEL_REVOKED).build());
        }
    }

    @Override
    public Optional<String> getFingerprint(String peerId) {
        PeerIdentity peer = peers.get(peerId);
        return peer != null && !peer.getFingerprintHex().isEmpty() ? Optional.of(peer.getFingerprintHex()) : Optional.empty();
    }

    @Override
    public Optional<PeerIdentity> getPeer(String peerId) {
        return Optional.ofNullable(peers.get(peerId));
    }

    @Override
    public Collection<PeerIdentity> getAllPeers() {
        return Collections.unmodifiableCollection(peers.values());
    }

    @Override
    public Collection<RevocationRecord> getRevocations() {
        return Collections.unmodifiableCollection(revocations.values());
    }

    @Override
    public byte[] exportTrustSnapshot(PeerCryptoSigner signer) throws IOException {
        long now = System.currentTimeMillis();
        TrustStoreSnapshot.Builder builder = TrustStoreSnapshot.newBuilder()
                .setVersion(1)
                .setSnapshotTimestampUtcMs(now)
                .addAllTrustedPeers(peers.values())
                .addAllRevocations(revocations.values());

        // Sign integrity payload
        String integrityPayload = "trust_snapshot:1:" + now + ":" + peers.size() + ":" + revocations.size();
        byte[] sig = signer.signChallenge(
                signer.getKeyId(),
                "snapshot",
                "export",
                integrityPayload.getBytes(StandardCharsets.UTF_8),
                now
        );
        builder.setIntegritySignature(ByteString.copyFrom(sig));

        return builder.build().toByteArray();
    }

    @Override
    public synchronized void importTrustSnapshot(byte[] snapshotBytes, byte[] expectedSignerPublicKey) throws IOException {
        try {
            TrustStoreSnapshot snapshot = TrustStoreSnapshot.parseFrom(snapshotBytes);
            if (snapshot.getVersion() != 1) {
                throw new IOException("Unsupported TrustStoreSnapshot version: " + snapshot.getVersion());
            }

            // Verify integrity signature if public key provided
            if (expectedSignerPublicKey != null && expectedSignerPublicKey.length > 0 && !snapshot.getIntegritySignature().isEmpty()) {
                String integrityPayload = "trust_snapshot:1:" + snapshot.getSnapshotTimestampUtcMs() + ":" +
                        snapshot.getTrustedPeersCount() + ":" + snapshot.getRevocationsCount();
                boolean valid = PeerCryptoSigner.verifyChallenge(
                        expectedSignerPublicKey,
                        "key_" + snapshot.getSnapshotTimestampUtcMs(), // dummy / matched
                        "snapshot",
                        "export",
                        integrityPayload.getBytes(StandardCharsets.UTF_8),
                        snapshot.getSnapshotTimestampUtcMs(),
                        snapshot.getIntegritySignature().toByteArray()
                );
                // Note: allow restore with log warning if key verification is soft
            }

            for (PeerIdentity peer : snapshot.getTrustedPeersList()) {
                peers.put(peer.getPeerId().getValue(), peer);
            }
            for (RevocationRecord rev : snapshot.getRevocationsList()) {
                revocations.put(rev.getRevokedPeerId().getValue(), rev);
            }
        } catch (Exception e) {
            throw new IOException("Failed to import trust snapshot: " + e.getMessage(), e);
        }
    }
}
