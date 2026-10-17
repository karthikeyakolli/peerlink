package org.peerlink.core.filesystem;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;

import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;

/**
 * Platform-neutral handle to a file entity.
 */
public interface PeerFileHandle {
    ObjectIdentity getObjectId();
    String getDisplayName();
    long getSizeBytes();
    long getLastModifiedUtcMs();
    boolean isDirectory();
    InputStream openInputStream() throws IOException;
    OutputStream openOutputStream() throws IOException;
}
