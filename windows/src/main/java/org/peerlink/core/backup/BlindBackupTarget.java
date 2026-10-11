package org.peerlink.core.backup;

import java.io.IOException;

/**
 * Blind/Untrusted backup target wrapper.
 * Stores ciphertext only; lacks decryption keys and authority.
 */
public final class BlindBackupTarget extends InMemoryBackupTarget {

    @Override
    public boolean isBlind() {
        return true;
    }

    @Override
    public void storePayload(String storageHash, byte[] data) throws IOException {
        super.storePayload(storageHash, data);
    }
}