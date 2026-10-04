package org.peerlink.core.filesystem;

import org.peerlink.core.model.ObjectIdentity;

import java.io.IOException;
import java.util.List;
import java.util.Optional;

/**
 * Filesystem abstraction.
 * Physical paths/URIs are separated from logical object identities.
 * File watcher events are hints; reconciliation provides truth.
 */
public interface PeerFileProvider {
    Optional<PeerFileHandle> resolve(ObjectIdentity objectId) throws IOException;
    Optional<PeerFileHandle> resolveByPhysicalPath(String physicalPathOrUri) throws IOException;
    List<PeerFileHandle> listChildren(PeerFileHandle directory) throws IOException;
    boolean delete(PeerFileHandle handle) throws IOException;
    void reconcile(String rootPath) throws IOException;
}
