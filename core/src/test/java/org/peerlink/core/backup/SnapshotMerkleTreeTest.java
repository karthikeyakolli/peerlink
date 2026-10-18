package org.peerlink.core.backup;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;

import java.nio.charset.StandardCharsets;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Section E: Snapshot Merkle Tree Verification Tests")
class SnapshotMerkleTreeTest {

    private HistoricalVersion createItem(String path, String content, long seq) {
        byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
        ContentHash hash = ContentHash.computeSha256(bytes);
        return new HistoricalVersion(
                ObjectIdentity.generate(),
                path,
                hash,
                bytes.length,
                seq,
                System.currentTimeMillis(),
                false,
                hash.getHexString(),
                false,
                false
        );
    }

    @Test
    @DisplayName("Empty tree produces deterministic RFC-compliant root hash")
    void testEmptyTreeRootHash() {
        SnapshotMerkleTree tree = SnapshotMerkleTree.build(List.of());
        assertEquals(SnapshotMerkleTree.EMPTY_ROOT_HASH, tree.getRootHash());
        assertEquals(0, tree.getLeafCount());
        assertTrue(tree.generateProof("any/file.txt").isEmpty());
    }

    @Test
    @DisplayName("Canonical sorting ensures deterministic Merkle root regardless of insertion order")
    void testDeterministicRootAcrossShuffledInput() {
        HistoricalVersion itemA = createItem("docs/architecture.md", "Arch Specs", 1);
        HistoricalVersion itemB = createItem("src/main.rs", "fn main() {}", 1);
        HistoricalVersion itemC = createItem("assets/logo.png", "PNG_DATA", 1);

        SnapshotMerkleTree treeOrder1 = SnapshotMerkleTree.build(List.of(itemA, itemB, itemC));
        SnapshotMerkleTree treeOrder2 = SnapshotMerkleTree.build(List.of(itemC, itemA, itemB));
        SnapshotMerkleTree treeOrder3 = SnapshotMerkleTree.build(List.of(itemB, itemC, itemA));

        assertEquals(treeOrder1.getRootHash(), treeOrder2.getRootHash(), "Root hash must be identical regardless of input order");
        assertEquals(treeOrder1.getRootHash(), treeOrder3.getRootHash(), "Root hash must be identical regardless of input order");
    }

    @Test
    @DisplayName("Odd-node counts (1, 3, 5 leaves) build valid balanced trees and proofs")
    void testOddNodeHandling() {
        for (int count : List.of(1, 3, 5, 7, 9)) {
            List<HistoricalVersion> items = new ArrayList<>();
            for (int i = 0; i < count; i++) {
                items.add(createItem("file_" + i + ".txt", "Content " + i, 1));
            }

            SnapshotMerkleTree tree = SnapshotMerkleTree.build(items);
            assertNotNull(tree.getRootHash());
            assertEquals(count, tree.getLeafCount());

            // Every leaf must have a verifiable inclusion proof
            for (HistoricalVersion item : items) {
                List<SnapshotMerkleTree.ProofNode> proof = tree.generateProof(item.getRelativePath());
                assertTrue(SnapshotMerkleTree.verifyProof(item, proof, tree.getRootHash()),
                        "Inclusion proof must verify for " + item.getRelativePath() + " in " + count + "-node tree");
            }
        }
    }

    @Test
    @DisplayName("Proof tampering or sibling modification is strictly detected")
    void testProofTamperingDetected() {
        HistoricalVersion itemA = createItem("a.txt", "A", 1);
        HistoricalVersion itemB = createItem("b.txt", "B", 1);
        HistoricalVersion itemC = createItem("c.txt", "C", 1);
        HistoricalVersion itemD = createItem("d.txt", "D", 1);

        SnapshotMerkleTree tree = SnapshotMerkleTree.build(List.of(itemA, itemB, itemC, itemD));
        List<SnapshotMerkleTree.ProofNode> proofA = tree.generateProof("a.txt");
        assertFalse(proofA.isEmpty());

        // Tamper with proof sibling hash
        List<SnapshotMerkleTree.ProofNode> tamperedProof = new ArrayList<>();
        tamperedProof.add(new SnapshotMerkleTree.ProofNode("0000000000000000000000000000000000000000000000000000000000000000", proofA.get(0).isRightSibling()));
        for (int i = 1; i < proofA.size(); i++) {
            tamperedProof.add(proofA.get(i));
        }

        assertFalse(SnapshotMerkleTree.verifyProof(itemA, tamperedProof, tree.getRootHash()),
                "Tampered proof sibling must fail verification");
    }

    @Test
    @DisplayName("Altered leaf content or sequence number breaks Merkle membership verification")
    void testAlteredLeafDetected() {
        HistoricalVersion original = createItem("secret.key", "ORIGINAL_KEY", 1);
        HistoricalVersion sibling = createItem("notes.txt", "Meeting Notes", 1);

        SnapshotMerkleTree tree = SnapshotMerkleTree.build(List.of(original, sibling));
        List<SnapshotMerkleTree.ProofNode> proof = tree.generateProof("secret.key");

        // Attacker creates altered item with same path but modified sequence
        HistoricalVersion alteredSeq = new HistoricalVersion(
                original.getObjectId(), original.getRelativePath(), original.getContentHash(),
                original.getSizeBytes(), 999 /* altered sequence */, original.getCapturedAtUtcMs(),
                false, original.getStorageHash(), false, false
        );

        assertFalse(SnapshotMerkleTree.verifyProof(alteredSeq, proof, tree.getRootHash()),
                "Altered sequence must fail Merkle verification");

        // Attacker creates altered item with same path but modified content
        byte[] maliciousBytes = "MALICIOUS_KEY".getBytes(StandardCharsets.UTF_8);
        ContentHash maliciousHash = ContentHash.computeSha256(maliciousBytes);
        HistoricalVersion alteredContent = new HistoricalVersion(
                original.getObjectId(), original.getRelativePath(), maliciousHash,
                maliciousBytes.length, original.getVersionSequence(), original.getCapturedAtUtcMs(),
                false, maliciousHash.getHexString(), false, false
        );

        assertFalse(SnapshotMerkleTree.verifyProof(alteredContent, proof, tree.getRootHash()),
                "Altered content must fail Merkle verification");
    }

    @Test
    @DisplayName("BackupManifest computes and stores authentic Merkle root hash")
    void testBackupManifestComputesMerkleRoot() {
        HistoricalVersion itemA = createItem("reports/q3.pdf", "PDF", 1);
        HistoricalVersion itemB = createItem("reports/q4.pdf", "PDF", 1);

        BackupManifest manifest = new BackupManifest(
                "bkp_test_01",
                "job_01",
                BackupType.FULL,
                System.currentTimeMillis(),
                null,
                Map.of(itemA.getObjectId(), itemA, itemB.getObjectId(), itemB),
                false
        );

        assertNotNull(manifest.getMerkleRootHash());
        assertFalse(manifest.getMerkleRootHash().isBlank());
        SnapshotMerkleTree expectedTree = SnapshotMerkleTree.build(List.of(itemA, itemB));
        assertEquals(expectedTree.getRootHash(), manifest.getMerkleRootHash(),
                "Manifest merkleRootHash must match independently computed Merkle tree root");
    }
}
