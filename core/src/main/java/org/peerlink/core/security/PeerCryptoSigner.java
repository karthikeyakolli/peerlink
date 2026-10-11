package org.peerlink.core.security;

import org.peerlink.protocol.v1.CryptographicKey;
import org.peerlink.protocol.v1.KeyType;

import java.nio.charset.StandardCharsets;
import java.security.*;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.HexFormat;

/**
 * Standard cryptographic identity signing and verification using Ed25519.
 * Enforces:
 * - Peer identity is anchored in cryptographic keys, never IP/hostname.
 * - Nonce-based replay protection with time bounds.
 */
public class PeerCryptoSigner {

    private static final String ALGORITHM = "Ed25519";
    private final KeyPair keyPair;
    private final String keyId;

    public PeerCryptoSigner(KeyPair keyPair, String keyId) {
        this.keyPair = keyPair;
        this.keyId = keyId;
    }

    public static PeerCryptoSigner generate(String keyId) {
        try {
            KeyPairGenerator kpg = KeyPairGenerator.getInstance(ALGORITHM);
            return new PeerCryptoSigner(kpg.generateKeyPair(), keyId);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("JVM environment does not support Ed25519", e);
        }
    }

    /**
     * Restores an Ed25519 signer from durable private and public key bytes.
     */
    public static PeerCryptoSigner fromPrivateKeyBytes(String keyId, byte[] privateKeyBytes, byte[] publicKeyBytes) {
        try {
            KeyFactory kf = KeyFactory.getInstance(ALGORITHM);
            PrivateKey priv = kf.generatePrivate(new PKCS8EncodedKeySpec(privateKeyBytes));
            PublicKey pub = kf.generatePublic(new X509EncodedKeySpec(publicKeyBytes));
            return new PeerCryptoSigner(new KeyPair(pub, priv), keyId);
        } catch (Exception e) {
            throw new IllegalArgumentException("Failed to restore Ed25519 keypair from encoded bytes", e);
        }
    }

    /**
     * Stable Peer ID derivation rule (Version 1: SHA-256 of public key).
     * Derivation: "peer_" + first 16 hex chars of SHA-256(publicKeyEncoded).
     */
    public static String deriveStablePeerId(byte[] publicKeyEncoded) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(publicKeyEncoded);
            return "peer_" + HexFormat.of().formatHex(hash).substring(0, 16);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 algorithm missing", e);
        }
    }

    public PublicKey getPublicKey() {
        return keyPair.getPublic();
    }

    public byte[] getPublicKeyEncoded() {
        return keyPair.getPublic().getEncoded();
    }

    public byte[] getPublicKeyBytes() {
        return getPublicKeyEncoded();
    }

    public byte[] getPrivateKeyBytes() {
        return keyPair.getPrivate().getEncoded();
    }

    public String getKeyId() {
        return keyId;
    }

    public String getFingerprintHex() {
        return computeFingerprint();
    }

    public CryptographicKey toProtobufKey(long createdAtUtcMs) {
        return CryptographicKey.newBuilder()
                .setKeyType(KeyType.KEY_TYPE_ED25519)
                .setPublicKeyBytes(com.google.protobuf.ByteString.copyFrom(getPublicKeyEncoded()))
                .setKeyId(keyId)
                .setCreatedAtUtcMs(createdAtUtcMs)
                .build();
    }

    public String computeFingerprint() {
        return computeFingerprint(getPublicKeyEncoded());
    }

    public static String computeFingerprint(byte[] publicKeyEncoded) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(publicKeyEncoded);
            return "SHA256:" + HexFormat.of().formatHex(hash).substring(0, 16);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
    }

    /**
     * Signs challenge data: peerId:connectionId:sessionId:nonceHex:timestamp
     */
    public byte[] signChallenge(String peerId, String connectionId, String sessionId, byte[] nonce, long timestampUtcMs) {
        byte[] payload = formatChallengePayload(peerId, connectionId, sessionId, nonce, timestampUtcMs);
        try {
            Signature sig = Signature.getInstance(ALGORITHM);
            sig.initSign(keyPair.getPrivate());
            sig.update(payload);
            return sig.sign();
        } catch (Exception e) {
            throw new RuntimeException("Failed to sign challenge payload", e);
        }
    }

    /**
     * Verifies signature against a remote peer's public key bytes.
     */
    public static boolean verifyChallenge(byte[] remotePublicKeyEncoded,
                                          String peerId,
                                          String connectionId,
                                          String sessionId,
                                          byte[] nonce,
                                          long timestampUtcMs,
                                          byte[] signature) {
        byte[] payload = formatChallengePayload(peerId, connectionId, sessionId, nonce, timestampUtcMs);
        try {
            KeyFactory kf = KeyFactory.getInstance(ALGORITHM);
            PublicKey pub = kf.generatePublic(new X509EncodedKeySpec(remotePublicKeyEncoded));
            Signature sig = Signature.getInstance(ALGORITHM);
            sig.initVerify(pub);
            sig.update(payload);
            return sig.verify(signature);
        } catch (Exception e) {
            return false;
        }
    }

    public static byte[] generateNonce(int lengthBytes) {
        byte[] nonce = new byte[lengthBytes];
        new SecureRandom().nextBytes(nonce);
        return nonce;
    }

    private static byte[] formatChallengePayload(String peerId, String connectionId, String sessionId, byte[] nonce, long timestampUtcMs) {
        String nonceHex = HexFormat.of().formatHex(nonce);
        String s = peerId + ":" + connectionId + ":" + sessionId + ":" + nonceHex + ":" + timestampUtcMs;
        return s.getBytes(StandardCharsets.UTF_8);
    }
}
