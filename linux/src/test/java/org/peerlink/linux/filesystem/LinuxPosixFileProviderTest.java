package org.peerlink.linux.filesystem;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.filesystem.DestinationSafety;
import org.peerlink.core.filesystem.PeerFileHandle;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

class LinuxPosixFileProviderTest {

    @TempDir
    Path tempDir;

    private LinuxPosixFileProvider provider;

    @BeforeEach
    void setUp() {
        provider = new LinuxPosixFileProvider(tempDir);
    }

    @Test
    void testResolveValidFileAndReadContent() throws IOException {
        Path validFile = tempDir.resolve("sample-doc.tar.gz");
        Files.writeString(validFile, "Linux payload data");

        Optional<PeerFileHandle> handleOpt = provider.resolveByPhysicalPath(validFile.toString());
        assertTrue(handleOpt.isPresent());

        PeerFileHandle handle = handleOpt.get();
        assertEquals(validFile.toAbsolutePath().normalize().toString(), handle.getDisplayName());
        assertFalse(handle.isDirectory());
        assertEquals("Linux payload data".getBytes(StandardCharsets.UTF_8).length, handle.getSizeBytes());

        try (InputStream in = handle.openInputStream()) {
            String content = new String(in.readAllBytes(), StandardCharsets.UTF_8);
            assertEquals("Linux payload data", content);
        }
    }

    @Test
    void testRejectsNulByteInPath() {
        String badPath = "file\0with_nul.txt";
        assertThrows(IllegalArgumentException.class, () -> {
            LinuxPosixFileProvider.validatePosixPathSafety(badPath);
        });

        Optional<PeerFileHandle> handle = assertDoesNotThrow(() ->
                provider.resolveByPhysicalPath(tempDir.resolve("bad\0file").toString()));
        assertFalse(handle.isPresent());
    }

    @Test
    void testRejectsPathTraversalSequences() {
        String traversal = "../../../etc/shadow";
        DestinationSafety safety = provider.validateDestinationSafety("trans-1", traversal);
        assertFalse(safety.isSafe());

        Optional<PeerFileHandle> handle = assertDoesNotThrow(() ->
                provider.resolveByPhysicalPath(tempDir.resolve(traversal).toString()));
        assertFalse(handle.isPresent());
    }

    @Test
    void testListChildren() throws IOException {
        Path subDir = tempDir.resolve("workspace");
        Files.createDirectories(subDir);
        Files.writeString(subDir.resolve("a.txt"), "A");
        Files.writeString(subDir.resolve("b.txt"), "B");

        Optional<PeerFileHandle> dirHandleOpt = provider.resolveByPhysicalPath(subDir.toString());
        assertTrue(dirHandleOpt.isPresent());
        assertTrue(dirHandleOpt.get().isDirectory());

        List<PeerFileHandle> children = provider.listChildren(dirHandleOpt.get());
        assertEquals(2, children.size());
    }
}
