package org.peerlink.core.android;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.peerlink.core.filesystem.PeerFileHandle;
import org.peerlink.core.model.ObjectIdentity;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.AccessDeniedException;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

import static org.junit.jupiter.api.Assertions.*;

class AndroidSafStorageTest {

    private MockContentResolverBridge bridge;
    private AndroidStorageAbstraction storage;

    @BeforeEach
    void setUp() {
        bridge = new MockContentResolverBridge();
        storage = new AndroidStorageAbstraction(bridge);
    }

    @Test
    void testResolveAndReadSafDocument() throws IOException {
        String uri = "content://com.android.providers.media.documents/document/1001";
        bridge.putDocument(uri, "document.pdf", "Mock PDF payload".getBytes(StandardCharsets.UTF_8));

        Optional<PeerFileHandle> handleOpt = storage.resolveByPhysicalPath(uri);
        assertTrue(handleOpt.isPresent());

        PeerFileHandle handle = handleOpt.get();
        assertEquals("document.pdf", handle.getDisplayName());
        assertEquals("Mock PDF payload".getBytes(StandardCharsets.UTF_8).length, handle.getSizeBytes());
        assertFalse(handle.isDirectory());

        try (InputStream in = handle.openInputStream()) {
            String content = new String(in.readAllBytes(), StandardCharsets.UTF_8);
            assertEquals("Mock PDF payload", content);
        }
    }

    @Test
    void testStoragePermissionDeniedThrowsAccessDeniedException() {
        String uri = "content://com.android.externalstorage.documents/document/restricted";
        bridge.putDocument(uri, "secret.txt", "restricted".getBytes(StandardCharsets.UTF_8));
        bridge.setReadPermission(uri, false);

        assertThrows(AccessDeniedException.class, () -> {
            storage.resolveByPhysicalPath(uri);
        });
    }

    @Test
    void testNonExistentDocumentReturnsEmpty() throws IOException {
        String missingUri = "content://com.android.providers.media/missing/404";
        Optional<PeerFileHandle> handle = storage.resolveByPhysicalPath(missingUri);
        assertFalse(handle.isPresent());
    }

    @Test
    void testWriteToSafDocument() throws IOException {
        String uri = "content://com.android.providers.downloads.documents/document/new_file";
        bridge.putDocument(uri, "output.txt", new byte[0]);

        Optional<PeerFileHandle> handleOpt = storage.resolveByPhysicalPath(uri);
        assertTrue(handleOpt.isPresent());

        try (OutputStream out = handleOpt.get().openOutputStream()) {
            out.write("Written data".getBytes(StandardCharsets.UTF_8));
        }

        byte[] savedBytes = bridge.getRawBytes(uri);
        assertEquals("Written data", new String(savedBytes, StandardCharsets.UTF_8));
    }

    // --- Mock ContentResolver Bridge ---
    static class MockContentResolverBridge implements AndroidStorageAbstraction.ContentResolverBridge {
        private final Map<String, byte[]> data = new ConcurrentHashMap<>();
        private final Map<String, String> names = new ConcurrentHashMap<>();
        private final Map<String, Boolean> readPermissions = new ConcurrentHashMap<>();
        private final Map<String, Boolean> writePermissions = new ConcurrentHashMap<>();

        void putDocument(String uri, String name, byte[] bytes) {
            data.put(uri, bytes);
            names.put(uri, name);
            readPermissions.put(uri, true);
            writePermissions.put(uri, true);
        }

        void setReadPermission(String uri, boolean allowed) {
            readPermissions.put(uri, allowed);
        }

        byte[] getRawBytes(String uri) {
            return data.get(uri);
        }

        @Override
        public InputStream openInputStream(String uri) throws IOException {
            byte[] bytes = data.get(uri);
            if (bytes == null) throw new FileNotFoundException("URI not found: " + uri);
            return new ByteArrayInputStream(bytes);
        }

        @Override
        public OutputStream openOutputStream(String uri) throws IOException {
            return new ByteArrayOutputStream() {
                @Override
                public void close() throws IOException {
                    super.close();
                    data.put(uri, toByteArray());
                }
            };
        }

        @Override
        public boolean delete(String uri) {
            return data.remove(uri) != null;
        }

        @Override
        public boolean exists(String uri) {
            return data.containsKey(uri);
        }

        @Override
        public long getLength(String uri) {
            byte[] b = data.get(uri);
            return b != null ? b.length : 0;
        }

        @Override
        public String getDisplayName(String uri) {
            return names.getOrDefault(uri, "unknown");
        }

        @Override
        public long getLastModified(String uri) {
            return 123456789L;
        }

        @Override
        public boolean isDirectory(String uri) {
            return false;
        }

        @Override
        public List<String> listChildren(String treeUri) {
            return Collections.emptyList();
        }

        @Override
        public boolean checkReadPermission(String uri) {
            return readPermissions.getOrDefault(uri, true);
        }

        @Override
        public boolean checkWritePermission(String uri) {
            return writePermissions.getOrDefault(uri, true);
        }
    }
}
