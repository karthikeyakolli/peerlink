package org.peerlink.core.security;

import org.peerlink.protocol.v1.PeerIdentity;
import org.peerlink.protocol.v1.RevocationRecord;
import org.peerlink.protocol.v1.TrustStoreSnapshot;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

/**
 * Durable, thread-safe file-backed TrustStore implementation.
 * Persists trust anchors and revocations across node restarts.
 * Uses atomic file replacement (.tmp -> target) to prevent state corruption.
 */
public class PersistentTrustStore extends InMemoryTrustStore {

    private static final Logger log = LoggerFactory.getLogger(PersistentTrustStore.class);

    private final Path storageFile;

    public PersistentTrustStore(Path storageFile) {
        this.storageFile = storageFile;
        loadFromDisk();
    }

    private synchronized void loadFromDisk() {
        if (!Files.exists(storageFile)) {
            log.info("No existing trust store file found at {}; initializing fresh store", storageFile);
            return;
        }

        try {
            byte[] bytes = Files.readAllBytes(storageFile);
            TrustStoreSnapshot snapshot = TrustStoreSnapshot.parseFrom(bytes);

            peers.clear();
            revocations.clear();

            for (PeerIdentity peer : snapshot.getTrustedPeersList()) {
                peers.put(peer.getPeerId().getValue(), peer);
            }
            for (RevocationRecord rev : snapshot.getRevocationsList()) {
                revocations.put(rev.getRevokedPeerId().getValue(), rev);
            }

            log.info("Loaded {} trusted peers and {} revocations from {}",
                    peers.size(), revocations.size(), storageFile);
        } catch (Exception e) {
            log.error("Failed to load trust store from {}: {}", storageFile, e.getMessage());
        }
    }

    public synchronized void flushToDisk() throws IOException {
        if (storageFile.getParent() != null) {
            Files.createDirectories(storageFile.getParent());
        }

        TrustStoreSnapshot snapshot = TrustStoreSnapshot.newBuilder()
                .setVersion(1)
                .setSnapshotTimestampUtcMs(System.currentTimeMillis())
                .addAllTrustedPeers(peers.values())
                .addAllRevocations(revocations.values())
                .build();

        Path tempFile = storageFile.resolveSibling(storageFile.getFileName() + ".tmp");
        Files.write(tempFile, snapshot.toByteArray());
        Files.move(tempFile, storageFile, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
    }

    @Override
    public synchronized void addTrustedPeer(PeerIdentity peer) {
        super.addTrustedPeer(peer);
        try {
            flushToDisk();
        } catch (IOException e) {
            log.error("Failed to persist trust store update: {}", e.getMessage(), e);
        }
    }

    @Override
    public synchronized void revokeTrust(String peerId, String reason, byte[] signature) {
        super.revokeTrust(peerId, reason, signature);
        try {
            flushToDisk();
        } catch (IOException e) {
            log.error("Failed to persist trust store revocation: {}", e.getMessage(), e);
        }
    }
}
