package org.peerlink.core.model;

import java.io.Serializable;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.Objects;

/**
 * Immutable content hash encapsulation.
 * Critical invariant: Content hash is verification metadata, not logical object identity.
 */
public final class ContentHash implements Serializable {
    private static final long serialVersionUID = 1L;

    public enum Algorithm {
        SHA256("SHA-256"),
        BLAKE3("BLAKE3");

        private final String standardName;

        Algorithm(String standardName) {
            this.standardName = standardName;
        }

        public String getStandardName() {
            return standardName;
        }
    }

    private final Algorithm algorithm;
    private final byte[] hashBytes;
    private final String hexString;

    public ContentHash(Algorithm algorithm, byte[] hashBytes) {
        this.algorithm = Objects.requireNonNull(algorithm, "Algorithm cannot be null");
        this.hashBytes = Objects.requireNonNull(hashBytes, "Hash bytes cannot be null").clone();
        this.hexString = HexFormat.of().formatHex(this.hashBytes);
    }

    public static ContentHash computeSha256(byte[] data) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(data);
            return new ContentHash(Algorithm.SHA256, hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 algorithm unavailable in JRE", e);
        }
    }

    public static ContentHash fromHex(Algorithm algorithm, String hex) {
        byte[] bytes = HexFormat.of().parseHex(hex);
        return new ContentHash(algorithm, bytes);
    }

    public boolean matches(byte[] data) {
        ContentHash computed = computeSha256(data);
        return Arrays.equals(this.hashBytes, computed.hashBytes);
    }

    public Algorithm getAlgorithm() {
        return algorithm;
    }

    public byte[] getHashBytes() {
        return hashBytes.clone();
    }

    public String getHexString() {
        return hexString;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof ContentHash that)) return false;
        return algorithm == that.algorithm && Arrays.equals(hashBytes, that.hashBytes);
    }

    @Override
    public int hashCode() {
        int result = Objects.hash(algorithm);
        result = 31 * result + Arrays.hashCode(hashBytes);
        return result;
    }

    @Override
    public String toString() {
        return algorithm.name() + ":" + hexString;
    }
}
