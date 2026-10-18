package org.peerlink.core.backup;

import org.peerlink.core.model.ContentHash;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.*;

/**
 * High-Integrity Cryptographic Merkle Tree for Snapshot Manifests.
 *
 * Implements RFC 6962-inspired domain separation:
 * - Leaf nodes: prefixed with 0x00
 * - Internal nodes: prefixed with 0x01
 *
 * Guarantees:
 * - Second-preimage resistance via domain separation.
 * - Deterministic canonical leaf ordering by relative path.
 * - Logarithmic inclusion proofs (audit / membership verification).
 * - Full restore-time validation preventing corrupted or altered manifest restoration.
 */
public final class SnapshotMerkleTree {

    public static final byte DOMAIN_LEAF = 0x00;
    public static final byte DOMAIN_INTERNAL = 0x01;
    public static final String EMPTY_ROOT_HASH = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"; // SHA-256("")

    public record ProofNode(String siblingHash, boolean isRightSibling) {}

    private final List<HistoricalVersion> sortedLeaves;
    private final Map<String, Integer> pathIndex;
    private final String rootHash;
    private final List<List<String>> treeLevels;

    private SnapshotMerkleTree(List<HistoricalVersion> sortedLeaves,
                               Map<String, Integer> pathIndex,
                               String rootHash,
                               List<List<String>> treeLevels) {
        this.sortedLeaves = sortedLeaves;
        this.pathIndex = pathIndex;
        this.rootHash = rootHash;
        this.treeLevels = treeLevels;
    }

    /**
     * Builds a deterministic Merkle tree from a collection of historical version snapshot items.
     */
    public static SnapshotMerkleTree build(Collection<HistoricalVersion> items) {
        if (items == null || items.isEmpty()) {
            return new SnapshotMerkleTree(List.of(), Map.of(), EMPTY_ROOT_HASH, List.of());
        }

        // 1. Sort items canonically by relative path
        List<HistoricalVersion> sorted = new ArrayList<>(items);
        sorted.sort(Comparator.comparing(HistoricalVersion::getRelativePath));

        Map<String, Integer> index = new HashMap<>();
        List<String> leafHashes = new ArrayList<>(sorted.size());

        for (int i = 0; i < sorted.size(); i++) {
            HistoricalVersion item = sorted.get(i);
            index.put(item.getRelativePath(), i);
            leafHashes.add(computeLeafHash(item));
        }

        // 2. Build tree levels bottom-up
        List<List<String>> levels = new ArrayList<>();
        levels.add(leafHashes);

        List<String> currentLevel = leafHashes;
        while (currentLevel.size() > 1) {
            List<String> nextLevel = new ArrayList<>();
            for (int i = 0; i < currentLevel.size(); i += 2) {
                String left = currentLevel.get(i);
                String right = (i + 1 < currentLevel.size()) ? currentLevel.get(i + 1) : left; // Duplicate odd node
                nextLevel.add(computeInternalHash(left, right));
            }
            levels.add(nextLevel);
            currentLevel = nextLevel;
        }

        String computedRoot = currentLevel.get(0);
        return new SnapshotMerkleTree(List.copyOf(sorted), Map.copyOf(index), computedRoot, levels);
    }

    /**
     * Computes the leaf hash using RFC 6962 domain separation (0x00 prefix).
     */
    public static String computeLeafHash(HistoricalVersion item) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(DOMAIN_LEAF);

            // Canonical encoding of leaf components
            byte[] pathBytes = item.getRelativePath().getBytes(StandardCharsets.UTF_8);
            md.update(ByteBuffer.allocate(4).putInt(pathBytes.length).array());
            md.update(pathBytes);

            String hashStr = item.getContentHash() != null ? item.getContentHash().getHexString() : "tombstone";
            byte[] hashBytes = hashStr.getBytes(StandardCharsets.UTF_8);
            md.update(ByteBuffer.allocate(4).putInt(hashBytes.length).array());
            md.update(hashBytes);

            md.update(ByteBuffer.allocate(8).putLong(item.getSizeBytes()).array());
            md.update(ByteBuffer.allocate(8).putLong(item.getVersionSequence()).array());
            md.update((byte) (item.isDeleted() ? 1 : 0));
            md.update((byte) (item.isEncrypted() ? 1 : 0));

            return HexFormat.of().formatHex(md.digest());
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    /**
     * Computes internal node hash using RFC 6962 domain separation (0x01 prefix).
     */
    public static String computeInternalHash(String leftHex, String rightHex) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(DOMAIN_INTERNAL);
            md.update(HexFormat.of().parseHex(leftHex));
            md.update(HexFormat.of().parseHex(rightHex));
            return HexFormat.of().formatHex(md.digest());
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    /**
     * Returns the root hash of the snapshot Merkle tree.
     */
    public String getRootHash() {
        return rootHash;
    }

    /**
     * Returns canonical count of leaves in this snapshot tree.
     */
    public int getLeafCount() {
        return sortedLeaves.size();
    }

    /**
     * Generates a cryptographic inclusion proof (Merkle path) for the given item.
     */
    public List<ProofNode> generateProof(String relativePath) {
        Integer leafIndex = pathIndex.get(relativePath);
        if (leafIndex == null || treeLevels.isEmpty()) {
            return List.of();
        }

        List<ProofNode> proof = new ArrayList<>();
        int currentIndex = leafIndex;

        for (int level = 0; level < treeLevels.size() - 1; level++) {
            List<String> currentLevel = treeLevels.get(level);
            boolean isRight = (currentIndex % 2 == 1);
            int siblingIndex = isRight ? currentIndex - 1 : currentIndex + 1;

            if (siblingIndex < currentLevel.size()) {
                proof.add(new ProofNode(currentLevel.get(siblingIndex), !isRight));
            } else {
                // Odd node paired with itself
                proof.add(new ProofNode(currentLevel.get(currentIndex), !isRight));
            }

            currentIndex /= 2;
        }

        return List.copyOf(proof);
    }

    /**
     * Verifies an inclusion proof for a file against an authoritative Merkle root hash.
     */
    public static boolean verifyProof(HistoricalVersion item, List<ProofNode> proof, String expectedRootHash) {
        if (item == null || expectedRootHash == null) return false;
        if (proof == null || proof.isEmpty()) {
            // Single leaf tree or empty tree
            String leaf = computeLeafHash(item);
            return leaf.equalsIgnoreCase(expectedRootHash);
        }

        String currentHash = computeLeafHash(item);
        for (ProofNode node : proof) {
            if (node.isRightSibling()) {
                currentHash = computeInternalHash(currentHash, node.siblingHash());
            } else {
                currentHash = computeInternalHash(node.siblingHash(), currentHash);
            }
        }

        return currentHash.equalsIgnoreCase(expectedRootHash);
    }
}
