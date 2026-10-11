package org.peerlink.core.platform;

import org.peerlink.core.platform.windows.WindowsPlatformAdapter;

import java.nio.file.Path;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

/**
 * Platform integration service providing high-level OS integration.
 * Ensures all native interactions are capability-checked and exception-isolated from core logic.
 */
public class PlatformIntegrationService {

    private final NativePlatformAdapter adapter;

    public PlatformIntegrationService() {
        this(resolveDefaultAdapter());
    }

    public PlatformIntegrationService(NativePlatformAdapter adapter) {
        this.adapter = Objects.requireNonNull(adapter, "adapter must not be null");
    }

    public static NativePlatformAdapter resolveDefaultAdapter() {
        return new WindowsPlatformAdapter();
    }

    public NativePlatformAdapter getAdapter() {
        return adapter;
    }

    public PlatformType getPlatformType() {
        return adapter.getPlatformType();
    }

    public boolean supportsFeature(PlatformFeature feature) {
        return adapter.supportsFeature(feature);
    }

    public boolean revealInFileManager(Path path) {
        if (!adapter.supportsFeature(PlatformFeature.FILE_REVEAL_AND_OPEN)) {
            return false;
        }
        return adapter.revealInFileManager(path);
    }

    public boolean openFile(Path path) {
        if (!adapter.supportsFeature(PlatformFeature.FILE_REVEAL_AND_OPEN)) {
            return false;
        }
        return adapter.openFileWithDefaultApp(path);
    }

    public boolean sendNotification(PlatformNotification notification) {
        if (!adapter.supportsFeature(PlatformFeature.SYSTEM_NOTIFICATIONS)) {
            return false;
        }
        return adapter.postNotification(notification);
    }

    public boolean share(List<Path> paths) {
        if (!adapter.supportsFeature(PlatformFeature.SYSTEM_SHARE_SHEET) &&
            !adapter.supportsFeature(PlatformFeature.FINDER_SHARE_EXTENSION)) {
            return false;
        }
        return adapter.invokeSystemShare(paths);
    }

    public CredentialStorage getCredentialStorage() {
        return adapter.getCredentialStorage();
    }

    public FirewallDiagnosticsResult checkFirewall(int port, String transportProtocol) {
        if (!adapter.supportsFeature(PlatformFeature.FIREWALL_DIAGNOSTICS)) {
            return new FirewallDiagnosticsResult(
                    FirewallDiagnosticsResult.Status.NOT_APPLICABLE,
                    true,
                    port,
                    transportProtocol,
                    List.of("Firewall diagnostics not applicable on " + adapter.getPlatformType()),
                    null
            );
        }
        return adapter.diagnoseFirewall(port, transportProtocol);
    }

    /**
     * Headless fallback adapter when running on unknown or minimal environments.
     */
    public static class FallbackPlatformAdapter implements NativePlatformAdapter {
        private final CredentialStorage fallbackStorage = new FallbackCredentialStorage();

        @Override
        public PlatformType getPlatformType() {
            return PlatformType.UNKNOWN;
        }

        @Override
        public java.util.Set<PlatformFeature> getSupportedFeatures() {
            return java.util.Collections.emptySet();
        }

        @Override
        public boolean revealInFileManager(Path path) {
            return false;
        }

        @Override
        public boolean openFileWithDefaultApp(Path path) {
            return false;
        }

        @Override
        public boolean postNotification(PlatformNotification notification) {
            return false;
        }

        @Override
        public boolean cancelNotification(String notificationId) {
            return false;
        }

        @Override
        public boolean invokeSystemShare(List<Path> paths) {
            return false;
        }

        @Override
        public boolean registerFileManagerContextMenu() {
            return false;
        }

        @Override
        public boolean unregisterFileManagerContextMenu() {
            return false;
        }

        @Override
        public boolean registerFileAssociations() {
            return false;
        }

        @Override
        public boolean unregisterFileAssociations() {
            return false;
        }

        @Override
        public CredentialStorage getCredentialStorage() {
            return fallbackStorage;
        }

        @Override
        public FirewallDiagnosticsResult diagnoseFirewall(int port, String transportProtocol) {
            return new FirewallDiagnosticsResult(
                    FirewallDiagnosticsResult.Status.NOT_APPLICABLE,
                    true,
                    port,
                    transportProtocol,
                    List.of("Headless fallback environment"),
                    null
            );
        }

        @Override
        public boolean checkPermission(String permission) {
            return true;
        }

        @Override
        public boolean requestPermission(String permission) {
            return true;
        }
    }

    public static class FallbackCredentialStorage implements CredentialStorage {
        private final java.util.Map<String, String> map = new java.util.concurrent.ConcurrentHashMap<>();

        @Override
        public void storeSecret(String service, String account, String secret) {
            map.put(service + "/" + account, secret);
        }

        @Override
        public Optional<String> getSecret(String service, String account) {
            return Optional.ofNullable(map.get(service + "/" + account));
        }

        @Override
        public boolean deleteSecret(String service, String account) {
            return map.remove(service + "/" + account) != null;
        }

        @Override
        public boolean hasSecret(String service, String account) {
            return map.containsKey(service + "/" + account);
        }
    }
}
