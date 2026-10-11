package org.peerlink.core.android;

import org.peerlink.core.filesystem.PeerFileHandle;
import org.peerlink.core.filesystem.PeerFileProvider;
import org.peerlink.core.model.ObjectIdentity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
import java.nio.file.AccessDeniedException;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/**
 * Storage Access Framework (SAF), ContentResolver, and MediaStore abstraction
 * implementing PeerLink's portable PeerFileProvider.
 */
public class AndroidStorageAbstraction implements PeerFileProvider {
    private static final Logger log = LoggerFactory.getLogger(AndroidStorageAbstraction.class);

    public interface ContentResolverBridge {
        InputStream openInputStream(String uri) throws IOException;
        OutputStream openOutputStream(String uri) throws IOException;
        boolean delete(String uri) throws IOException;
        boolean exists(String uri);
        long getLength(String uri);
        String getDisplayName(String uri);
        long getLastModified(String uri);
        boolean isDirectory(String uri);
        List<String> listChildren(String treeUri) throws IOException;
        boolean checkReadPermission(String uri);
        boolean checkWritePermission(String uri);
    }

    private final ContentResolverBridge contentResolver;
    private final ConcurrentMap<ObjectIdentity, String> objectToUriMap = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, ObjectIdentity> uriToObjectMap = new ConcurrentHashMap<>();

    public AndroidStorageAbstraction(ContentResolverBridge contentResolver) {
        this.contentResolver = Objects.requireNonNull(contentResolver, "contentResolver must not be null");
    }

    public void registerMapping(ObjectIdentity objectId, String contentUri) {
        objectToUriMap.put(objectId, contentUri);
        uriToObjectMap.put(contentUri, objectId);
    }

    @Override
    public Optional<PeerFileHandle> resolve(ObjectIdentity objectId) throws IOException {
        String uri = objectToUriMap.get(objectId);
        if (uri == null) {
            return Optional.empty();
        }
        return resolveByPhysicalPath(uri);
    }

    @Override
    public Optional<PeerFileHandle> resolveByPhysicalPath(String physicalPathOrUri) throws IOException {
        if (!contentResolver.exists(physicalPathOrUri)) {
            return Optional.empty();
        }

        if (!contentResolver.checkReadPermission(physicalPathOrUri)) {
            throw new AccessDeniedException("Storage permission denied for SAF Uri: " + physicalPathOrUri);
        }

        ObjectIdentity objectId = uriToObjectMap.computeIfAbsent(physicalPathOrUri,
                uri -> new ObjectIdentity("android-obj-" + UUID.nameUUIDFromBytes(uri.getBytes())));

        return Optional.of(new SafPeerFileHandle(objectId, physicalPathOrUri, contentResolver));
    }

    @Override
    public List<PeerFileHandle> listChildren(PeerFileHandle directory) throws IOException {
        if (!(directory instanceof SafPeerFileHandle safDir)) {
            throw new IllegalArgumentException("Expected SafPeerFileHandle, got " + directory.getClass().getName());
        }

        if (!safDir.isDirectory()) {
            return Collections.emptyList();
        }

        List<String> childUris = contentResolver.listChildren(safDir.getPhysicalUri());
        List<PeerFileHandle> results = new ArrayList<>();
        for (String childUri : childUris) {
            Optional<PeerFileHandle> handle = resolveByPhysicalPath(childUri);
            handle.ifPresent(results::add);
        }
        return Collections.unmodifiableList(results);
    }

    @Override
    public boolean delete(PeerFileHandle handle) throws IOException {
        if (!(handle instanceof SafPeerFileHandle safHandle)) {
            throw new IllegalArgumentException("Expected SafPeerFileHandle, got " + handle.getClass().getName());
        }

        if (!contentResolver.checkWritePermission(safHandle.getPhysicalUri())) {
            throw new AccessDeniedException("Write permission denied to delete: " + safHandle.getPhysicalUri());
        }

        boolean success = contentResolver.delete(safHandle.getPhysicalUri());
        if (success) {
            objectToUriMap.remove(handle.getObjectId());
            uriToObjectMap.remove(safHandle.getPhysicalUri());
        }
        return success;
    }

    @Override
    public void reconcile(String rootPath) throws IOException {
        log.info("Reconciling Android SAF root: {}", rootPath);
        // Scans root tree Uri and updates index
        Optional<PeerFileHandle> rootOpt = resolveByPhysicalPath(rootPath);
        if (rootOpt.isPresent() && rootOpt.get().isDirectory()) {
            listChildren(rootOpt.get());
        }
    }

    public static class SafPeerFileHandle implements PeerFileHandle {
        private final ObjectIdentity objectId;
        private final String physicalUri;
        private final ContentResolverBridge bridge;

        public SafPeerFileHandle(ObjectIdentity objectId, String physicalUri, ContentResolverBridge bridge) {
            this.objectId = objectId;
            this.physicalUri = physicalUri;
            this.bridge = bridge;
        }

        public String getPhysicalUri() {
            return physicalUri;
        }

        @Override
        public ObjectIdentity getObjectId() {
            return objectId;
        }

        @Override
        public String getDisplayName() {
            return bridge.getDisplayName(physicalUri);
        }

        @Override
        public long getSizeBytes() {
            return bridge.getLength(physicalUri);
        }

        @Override
        public long getLastModifiedUtcMs() {
            return bridge.getLastModified(physicalUri);
        }

        @Override
        public boolean isDirectory() {
            return bridge.isDirectory(physicalUri);
        }

        @Override
        public InputStream openInputStream() throws IOException {
            if (!bridge.checkReadPermission(physicalUri)) {
                throw new AccessDeniedException("SAF read permission denied for: " + physicalUri);
            }
            return bridge.openInputStream(physicalUri);
        }

        @Override
        public OutputStream openOutputStream() throws IOException {
            if (!bridge.checkWritePermission(physicalUri)) {
                throw new AccessDeniedException("SAF write permission denied for: " + physicalUri);
            }
            return bridge.openOutputStream(physicalUri);
        }
    }
}
