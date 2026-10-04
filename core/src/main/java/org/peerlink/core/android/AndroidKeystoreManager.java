package org.peerlink.core.android;

import com.google.protobuf.ByteString;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.security.*;
import java.util.Objects;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/**
 * Manages device identity keys backed by Android Keystore (hardware TEE/StrongBox)
 * or fallback secure key provider when running in test harnesses.
 */
public class AndroidKeystoreManager {
    private static final Logger log = LoggerFactory.getLogger(AndroidKeystoreManager.class);
    private static final String DEFAULT_ALIAS = "peerlink_node_identity";

    public interface KeystoreProvider {
        KeyPair getOrCreateIdentityKeyPair(String alias) throws GeneralSecurityException;
        byte[] sign(String alias, byte[] data) throws GeneralSecurityException;
        boolean verify(PublicKey publicKey, byte[] data, byte[] signature) throws GeneralSecurityException;
        boolean isHardwareBacked(String alias);
    }

    private final KeystoreProvider provider;
    private final String alias;
    private KeyPair identityKeyPair;
    private PeerIdentity peerIdentity;

    public AndroidKeystoreManager(KeystoreProvider provider) {
        this(provider, DEFAULT_ALIAS);
    }

    public AndroidKeystoreManager(KeystoreProvider provider, String alias) {
        this.provider = Objects.requireNonNull(provider, "provider must not be null");
        this.alias = Objects.requireNonNull(alias, "alias must not be null");
        initialize();
    }

    private void initialize() {
        try {
            this.identityKeyPair = provider.getOrCreateIdentityKeyPair(alias);
            byte[] pubBytes = identityKeyPair.getPublic().getEncoded();
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(pubBytes);
            StringBuilder sb = new StringBuilder("android-peer-");
            for (int i = 0; i < 8; i++) {
                sb.append(String.format("%02x", hash[i]));
            }
            String peerIdStr = sb.toString();
            long now = System.currentTimeMillis();

            CryptographicKey key = CryptographicKey.newBuilder()
                    .setKeyId("key-" + UUID.randomUUID())
                    .setKeyType(KeyType.KEY_TYPE_ED25519)
                    .setPublicKeyBytes(ByteString.copyFrom(pubBytes))
                    .setCreatedAtUtcMs(now)
                    .build();

            this.peerIdentity = PeerIdentity.newBuilder()
                    .setPeerId(PeerId.newBuilder().setValue(peerIdStr).build())
                    .setDisplayName("Android Device")
                    .setIdentityKey(key)
                    .setPairedAtUtcMs(now)
                    .build();

            log.info("Initialized Android Keystore Identity. PeerId: {}, Hardware-backed: {}",
                    peerIdStr, provider.isHardwareBacked(alias));
        } catch (Exception e) {
            throw new IllegalStateException("Failed to initialize Android Keystore identity for alias: " + alias, e);
        }
    }

    public PeerIdentity getPeerIdentity() {
        return peerIdentity;
    }

    public PeerId getPeerId() {
        return peerIdentity.getPeerId();
    }

    public boolean isHardwareBacked() {
        return provider.isHardwareBacked(alias);
    }

    public KeystoreProvider getKeystoreProvider() {
        return provider;
    }

    public byte[] signData(byte[] data) throws GeneralSecurityException {
        return provider.sign(alias, data);
    }

    public boolean verifySignature(PublicKey publicKey, byte[] data, byte[] signature) throws GeneralSecurityException {
        return provider.verify(publicKey, data, signature);
    }

    /**
     * Default software provider implementing pure in-memory cryptographic isolation
     * for unit/integration testing on JVM or emulators where KeyStore service is mocked.
     */
    public static class SoftwareKeystoreProvider implements KeystoreProvider {
        private final ConcurrentMap<String, KeyPair> keyStore = new ConcurrentHashMap<>();
        private final boolean simulateHardware;

        public SoftwareKeystoreProvider() {
            this(false);
        }

        public SoftwareKeystoreProvider(boolean simulateHardware) {
            this.simulateHardware = simulateHardware;
        }

        @Override
        public KeyPair getOrCreateIdentityKeyPair(String alias) throws GeneralSecurityException {
            return keyStore.computeIfAbsent(alias, k -> {
                try {
                    KeyPairGenerator kpg = KeyPairGenerator.getInstance("EC");
                    kpg.initialize(256);
                    return kpg.generateKeyPair();
                } catch (NoSuchAlgorithmException e) {
                    throw new RuntimeException("EC key generation failed", e);
                }
            });
        }

        @Override
        public byte[] sign(String alias, byte[] data) throws GeneralSecurityException {
            KeyPair kp = keyStore.get(alias);
            if (kp == null) {
                throw new KeyStoreException("Key alias not found: " + alias);
            }
            Signature sig = Signature.getInstance("SHA256withECDSA");
            sig.initSign(kp.getPrivate());
            sig.update(data);
            return sig.sign();
        }

        @Override
        public boolean verify(PublicKey publicKey, byte[] data, byte[] signature) throws GeneralSecurityException {
            Signature sig = Signature.getInstance("SHA256withECDSA");
            sig.initVerify(publicKey);
            sig.update(data);
            return sig.verify(signature);
        }

        @Override
        public boolean isHardwareBacked(String alias) {
            return simulateHardware;
        }
    }
}
