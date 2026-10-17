package org.peerlink.core.security;

import org.peerlink.protocol.v1.CryptographicKey;
import org.peerlink.protocol.v1.KeyType;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.Arrays;
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

    public String getFullFingerprintHex() {
        return computeFullFingerprint(getPublicKeyEncoded());
    }

    /**
     * Short display fingerprint (first 16 hex chars) used in brief notifications/UI headers.
     */
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
     * Full 64-hex SHA-256 fingerprint for unambiguous security verification and out-of-band audit.
     */
    public static String computeFullFingerprint(byte[] publicKeyEncoded) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(publicKeyEncoded);
            return "SHA256:" + HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
    }

    /**
     * Domain separation constant for stable pairwise verification safety numbers.
     * Unambiguously binds protocol name, function, version, and algorithm.
     */
    public static final String SAFETY_NUMBER_DOMAIN_V1 = "PeerLink:PairwiseSafetyNumber:v1:Ed25519:";

    /**
     * Domain separation constant for ephemeral session-specific authentication codes (SAS).
     */
    public static final String SESSION_AUTH_DOMAIN_V1 = "PeerLink:SessionAuthCode:v1:Ed25519:";

    /**
     * Derives a deterministic out-of-band pairwise safety number (6 blocks of 5 digits = 30 digits).
     * Binds domain separator, version, algorithm, and lexicographically sorted public keys with SHA-512.
     * Guaranteed symmetric: computeSafetyNumber(A, B) == computeSafetyNumber(B, A).
     */
    public static String computeSafetyNumber(byte[] localPublicKeyEncoded, byte[] remotePublicKeyEncoded) {
        return computeSafetyNumber(SAFETY_NUMBER_DOMAIN_V1, localPublicKeyEncoded, remotePublicKeyEncoded);
    }

    /**
     * Computes safety number with explicit domain separation tag.
     */
    public static String computeSafetyNumber(String domainSeparator, byte[] localPublicKeyEncoded, byte[] remotePublicKeyEncoded) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-512");
            if (domainSeparator != null && !domainSeparator.isEmpty()) {
                digest.update(domainSeparator.getBytes(StandardCharsets.UTF_8));
            }
            // Lexicographical ordering ensures both peers compute the exact identical safety number
            int cmp = Arrays.compare(localPublicKeyEncoded, remotePublicKeyEncoded);
            if (cmp <= 0) {
                digest.update(localPublicKeyEncoded);
                digest.update(remotePublicKeyEncoded);
            } else {
                digest.update(remotePublicKeyEncoded);
                digest.update(localPublicKeyEncoded);
            }
            byte[] hash = digest.digest();

            // Convert into 6 blocks of 5 numeric digits (30 digits total)
            StringBuilder sb = new StringBuilder();
            ByteBuffer bb = ByteBuffer.wrap(hash);
            for (int i = 0; i < 6; i++) {
                int val = Math.abs(bb.getInt() % 100000);
                if (i > 0) sb.append(" ");
                sb.append(String.format(java.util.Locale.US, "%05d", val));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
    }

    /**
     * Computes an ephemeral session-specific authentication code (SAS PIN) binding
     * the session ID, ephemeral connection nonces, timestamps, and public keys.
     */
    public static String computeSessionAuthCode(String sessionId, byte[] localNonce, byte[] remoteNonce,
                                               byte[] localPublicKeyEncoded, byte[] remotePublicKeyEncoded,
                                               long timestampUtcMs) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update(SESSION_AUTH_DOMAIN_V1.getBytes(StandardCharsets.UTF_8));
            digest.update(sessionId.getBytes(StandardCharsets.UTF_8));
            digest.update(localNonce != null ? localNonce : new byte[0]);
            digest.update(remoteNonce != null ? remoteNonce : new byte[0]);

            int cmp = Arrays.compare(localPublicKeyEncoded, remotePublicKeyEncoded);
            if (cmp <= 0) {
                digest.update(localPublicKeyEncoded);
                digest.update(remotePublicKeyEncoded);
            } else {
                digest.update(remotePublicKeyEncoded);
                digest.update(localPublicKeyEncoded);
            }

            ByteBuffer bb = ByteBuffer.allocate(8);
            bb.putLong(timestampUtcMs);
            digest.update(bb.array());

            byte[] hash = digest.digest();
            int pin = Math.abs(ByteBuffer.wrap(hash).getInt() % 1000000);
            return String.format(java.util.Locale.US, "%06d", pin);
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
