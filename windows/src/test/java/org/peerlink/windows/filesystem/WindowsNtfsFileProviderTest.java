package org.peerlink.windows.filesystem;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.filesystem.PeerFileHandle;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

class WindowsNtfsFileProviderTest {

    @TempDir
    Path tempDir;

    private WindowsNtfsFileProvider provider;

    @BeforeEach
    void setUp() {
        provider = new WindowsNtfsFileProvider(tempDir);
    }

    @Test
    void testResolveValidFileAndReadWrite() throws IOException {
        Path validFile = tempDir.resolve("safe-document.txt");
        Files.writeString(validFile, "Hello Windows NTFS");

        Optional<PeerFileHandle> handleOpt = provider.resolveByPhysicalPath(validFile.toString());
        assertTrue(handleOpt.isPresent());

        PeerFileHandle handle = handleOpt.get();
        assertEquals(validFile.toAbsolutePath().normalize().toString(), handle.getDisplayName());
        assertFalse(handle.isDirectory());
        assertEquals("Hello Windows NTFS".getBytes(StandardCharsets.UTF_8).length, handle.getSizeBytes());

        try (InputStream in = handle.openInputStream()) {
            String content = new String(in.readAllBytes(), StandardCharsets.UTF_8);
            assertEquals("Hello Windows NTFS", content);
        }
    }

    @Test
    void testRejectsReservedWin32DeviceNames() {
        String[] reservedNames = {"CON", "con.txt", "PRN", "aux", "NUL.pdf", "COM1", "com9.dat", "LPT1", "lpt5.bin"};
        for (String reserved : reservedNames) {
            Optional<PeerFileHandle> handle = assertDoesNotThrow(() ->
                    provider.resolveByPhysicalPath(tempDir.resolve(reserved).toString()));
            assertFalse(handle.isPresent(), "Expected reserved device name " + reserved + " to be rejected");
        }
    }

    @Test
    void testRejectsAlternateDataStreams() {
        String adsName = "document.txt:hidden_stream";
        try {
            Optional<PeerFileHandle> handle = provider.resolveByPhysicalPath(adsName);
            assertFalse(handle.isPresent(), "Expected ADS stream syntax to be rejected");
        } catch (Exception e) {
            // Windows NIO rejected illegal ADS character
        }
    }

    @Test
    void testRejectsTrailingDotsAndSpaces() {
        String[] badNames = {"filename.txt.", "filename.txt ", "folder."};
        for (String bad : badNames) {
            try {
                Optional<PeerFileHandle> handle = provider.resolveByPhysicalPath(bad);
                assertFalse(handle.isPresent(), "Expected trailing dot or space name " + bad + " to be rejected");
            } catch (Exception e) {
                // Windows NIO rejected trailing dot/space
            }
        }
    }

    @Test
    void testListChildren() throws IOException {
        Path subDir = tempDir.resolve("subfolder");
        Files.createDirectories(subDir);
        Path file1 = subDir.resolve("file1.txt");
        Path file2 = subDir.resolve("file2.txt");
        Files.writeString(file1, "one");
        Files.writeString(file2, "two");

        Optional<PeerFileHandle> dirHandleOpt = provider.resolveByPhysicalPath(subDir.toString());
        assertTrue(dirHandleOpt.isPresent());
        assertTrue(dirHandleOpt.get().isDirectory());

        List<PeerFileHandle> children = provider.listChildren(dirHandleOpt.get());
        assertEquals(2, children.size());
    }
}
