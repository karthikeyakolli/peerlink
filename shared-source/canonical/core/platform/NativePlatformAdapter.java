package org.peerlink.core.platform;

import java.nio.file.Path;
import java.util.List;
import java.util.Set;

/**
 * Common PeerLink capability interface for OS-level native integration.
 * Concrete adapters implement this interface without modifying or contaminating core domain logic.
 */
public interface NativePlatformAdapter {

    /**
     * Identifies the current OS platform.
     */
    PlatformType getPlatformType();

    /**
     * Returns the set of capabilities supported by this platform adapter.
     */
    Set<PlatformFeature> getSupportedFeatures();

    /**
     * Checks if a specific platform feature is supported.
     */
    default boolean supportsFeature(PlatformFeature feature) {
        return getSupportedFeatures().contains(feature);
    }

    /**
     * Opens native file manager and selects/highlights the target file or directory.
     */
    boolean revealInFileManager(Path path);

    /**
     * Opens target file with the OS default application.
     */
    boolean openFileWithDefaultApp(Path path);

    /**
     * Posts a notification to the OS notification center / daemon.
     */
    boolean postNotification(PlatformNotification notification);

    /**
     * Dismisses or cancels an active notification.
     */
    boolean cancelNotification(String notificationId);

    /**
     * Triggers the OS share sheet or native share flow with the specified file paths.
     */
    boolean invokeSystemShare(List<Path> paths);

    /**
     * Registers application context menu integration in the native file manager
     * (e.g. "Send with PeerLink" in File Explorer, Finder Quick Action, or XDG desktop action).
     */
    boolean registerFileManagerContextMenu();

    /**
     * Unregisters application context menu integration.
     */
    boolean unregisterFileManagerContextMenu();

    /**
     * Registers OS file associations (e.g. .peerlink and .plpkg).
     */
    boolean registerFileAssociations();

    /**
     * Unregisters OS file associations.
     */
    boolean unregisterFileAssociations();

    /**
     * Returns the credential storage adapter for this platform.
     */
    CredentialStorage getCredentialStorage();

    /**
     * Performs network firewall diagnostics for PeerLink transport ports.
     */
    FirewallDiagnosticsResult diagnoseFirewall(int port, String transportProtocol);

    /**
     * Checks if an OS permission or sandbox entitlement is granted.
     */
    boolean checkPermission(String permission);

    /**
     * Requests an OS permission or security bookmark.
     */
    boolean requestPermission(String permission);
}
