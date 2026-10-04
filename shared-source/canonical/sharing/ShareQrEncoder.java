package org.peerlink.core.sharing;

/**
 * Encodes a ShareCapability token as a QR-renderable PeerLink URI.
 * Format: peerlink://share?cap=<base64url-token>
 * No file content is embedded. A QR code is an opaque capability, not cloud storage.
 */
public final class ShareQrEncoder {
    private static final String SCHEME = "peerlink://share?cap=";
    private ShareQrEncoder() {}

    public static String encodeCapabilityUri(ShareCapability capability) {
        return SCHEME + capability.toToken();
    }

    public static String decodeCapabilityToken(String uri) {
        if (uri == null || !uri.startsWith(SCHEME)) {
            throw new IllegalArgumentException("Not a valid PeerLink share URI: " + uri);
        }
        return uri.substring(SCHEME.length());
    }

    public static String describeCap(ShareCapability cap) {
        return String.format("PeerLink Share [%s] type=%s permissions=%s expires=%s guest=%s",
                cap.shareId(), cap.shareType().name(), cap.permissions(),
                cap.expiresAtUtcMs() == 0 ? "never" : String.valueOf(cap.expiresAtUtcMs()),
                cap.isBoundToGuest());
    }
}