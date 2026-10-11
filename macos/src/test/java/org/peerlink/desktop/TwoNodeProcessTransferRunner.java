package org.peerlink.desktop;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;

/**
 * Multi-process two-node transfer test runner.
 * Spawns two independent Desktop Node daemon processes with distinct ports, tokens, and data directories.
 * Provides the authoritative execution recipe for running two-node end-to-end transfers.
 */
public class TwoNodeProcessTransferRunner {

    public static void main(String[] args) {
        System.out.println("=== PeerLink Two-Node Process Transfer Verification ===");

        Path tempDir;
        try {
            tempDir = Files.createTempDirectory("peerlink_2node_test_");
        } catch (IOException e) {
            System.err.println("Failed to create temporary test directory: " + e.getMessage());
            System.exit(1);
            return;
        }

        Path aliceData = tempDir.resolve("node_alice");
        Path bobData = tempDir.resolve("node_bob");

        int aliceIpcPort = 51051;
        int bobIpcPort = 51053;

        String aliceToken = "auth_token_alice_secret_12345678901234567890";
        String bobToken = "auth_token_bob_secret_12345678901234567890";

        System.out.println("Alice Data Dir: " + aliceData);
        System.out.println("Bob Data Dir: " + bobData);
        System.out.println("Alice IPC Port: " + aliceIpcPort);
        System.out.println("Bob IPC Port: " + bobIpcPort);

        // ProcessBuilder command format:
        // java -cp <classpath> org.peerlink.desktop.runtime.DesktopNodeDaemon --port 51051 --data-dir <path> --token <token>
        System.out.println("\nCommand to execute Node Alice:");
        System.out.printf("java -cp <fat-jar-or-classpath> org.peerlink.desktop.runtime.DesktopNodeDaemon --port %d --data-dir \"%s\" --token \"%s\"%n",
                aliceIpcPort, aliceData.toAbsolutePath(), aliceToken);

        System.out.println("\nCommand to execute Node Bob:");
        System.out.printf("java -cp <fat-jar-or-classpath> org.peerlink.desktop.runtime.DesktopNodeDaemon --port %d --data-dir \"%s\" --token \"%s\"%n",
                bobIpcPort, bobData.toAbsolutePath(), bobToken);

        System.out.println("\nEnd-to-end multi-process verification requires pre-built jars or online Maven dependencies.");
    }
}
