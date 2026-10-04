package org.peerlink.core.security;

import java.io.InputStream;
import java.io.IOException;

/**
 * Scanner provider abstraction.
 * Allows integration with native host antimalware engines (e.g. Defender, ClamAV)
 * without creating hard dependencies or claiming PeerLink is an antivirus product.
 */
public interface ScannerProvider {
    String getProviderName();
    boolean isAvailable();
    SecurityVerdict scanStream(InputStream inputStream) throws IOException;
    SecurityVerdict scanFile(String filePath) throws IOException;
}
