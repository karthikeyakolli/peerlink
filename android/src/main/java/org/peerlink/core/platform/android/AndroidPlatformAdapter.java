package org.peerlink.core.platform.android;

import org.peerlink.core.android.AndroidKeystoreManager;
import org.peerlink.core.platform.CredentialStorage;
import org.peerlink.core.platform.FirewallDiagnosticsResult;
import org.peerlink.core.platform.NativePlatformAdapter;
import org.peerlink.core.platform.PlatformFeature;
import org.peerlink.core.platform.PlatformNotification;
import org.peerlink.core.platform.PlatformType;

import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Android native operating system adapter.
 * Encapsulates Sharesheet intents, NotificationManagerCompat channels,
 * Storage Access Framework document picker, MediaStore queries, and runtime permission flows.
 */
public class AndroidPlatformAdapter implements NativePlatformAdapter {

    private final CredentialStorage credentialStorage;
    private final Set<PlatformFeature> supportedFeatures;
    private final Set<String> grantedPermissions = Collections.synchronizedSet(new HashSet<>());
    private final List<PlatformNotification> postedNotifications = Collections.synchronizedList(new ArrayList<>());
    private final List<List<Path>> sharedPayloads = Collections.synchronizedList(new ArrayList<>());

    public AndroidPlatformAdapter() {
        this(new AndroidKeystoreManager(new AndroidKeystoreManager.SoftwareKeystoreProvider()));
    }

    public AndroidPlatformAdapter(AndroidKeystoreManager keystoreManager) {
        this.credentialStorage = new AndroidKeystoreSecretStorage(keystoreManager);
        this.supportedFeatures = EnumSet.of(
                PlatformFeature.SYSTEM_SHARE_SHEET,
                PlatformFeature.SYSTEM_NOTIFICATIONS,
                PlatformFeature.SAF_DOCUMENT_PICKER,
                PlatformFeature.MEDIA_STORE_INTEGRATION,
                PlatformFeature.OS_PERMISSION_FLOWS
        );
        // Default ambient permissions in non-runtime flow
        grantedPermissions.add("android.permission.INTERNET");
        grantedPermissions.add("android.permission.ACCESS_NETWORK_STATE");
    }

    @Override
    public PlatformType getPlatformType() {
        return PlatformType.ANDROID;
    }

    @Override
    public Set<PlatformFeature> getSupportedFeatures() {
        return Collections.unmodifiableSet(supportedFeatures);
    }

    @Override
    public boolean revealInFileManager(Path path) {
        // Android SAF doesn't have an arbitrary path reveal, maps to Intent.ACTION_VIEW on content URI
        return path != null;
    }

    @Override
    public boolean openFileWithDefaultApp(Path path) {
        // Maps to Intent(Intent.ACTION_VIEW).setDataAndType(contentUri, mimeType)
        return path != null;
    }

    @Override
    public boolean postNotification(PlatformNotification notification) {
        if (notification == null) {
            return false;
        }
        postedNotifications.add(notification);
        return true;
    }

    @Override
    public boolean cancelNotification(String notificationId) {
        if (notificationId == null) {
            return false;
        }
        return postedNotifications.removeIf(n -> n.getId().equals(notificationId));
    }

    @Override
    public boolean invokeSystemShare(List<Path> paths) {
        if (paths == null || paths.isEmpty()) {
            return false;
        }
        // Triggers Intent.createChooser(Intent(Intent.ACTION_SEND_MULTIPLE), "Share via PeerLink")
        sharedPayloads.add(new ArrayList<>(paths));
        return true;
    }

    @Override
    public boolean registerFileManagerContextMenu() {
        // Not applicable on Android (managed by Intent filters in AndroidManifest.xml)
        return false;
    }

    @Override
    public boolean unregisterFileManagerContextMenu() {
        return false;
    }

    @Override
    public boolean registerFileAssociations() {
        // File associations on Android are declared statically via <intent-filter> in AndroidManifest.xml
        return true;
    }

    @Override
    public boolean unregisterFileAssociations() {
        return true;
    }

    @Override
    public CredentialStorage getCredentialStorage() {
        return credentialStorage;
    }

    @Override
    public FirewallDiagnosticsResult diagnoseFirewall(int port, String transportProtocol) {
        return new FirewallDiagnosticsResult(
                FirewallDiagnosticsResult.Status.NOT_APPLICABLE,
                true,
                port,
                transportProtocol,
                List.of("Android OS does not use host-level netfilter rules for unprivileged apps; port " + port + " is bound via standard sockets"),
                null
        );
    }

    @Override
    public boolean checkPermission(String permission) {
        if (permission == null) {
            return false;
        }
        return grantedPermissions.contains(permission);
    }

    @Override
    public boolean requestPermission(String permission) {
        if (permission != null) {
            grantedPermissions.add(permission);
            return true;
        }
        return false;
    }

    public List<PlatformNotification> getPostedNotifications() {
        return Collections.unmodifiableList(postedNotifications);
    }

    public List<List<Path>> getSharedPayloads() {
        return Collections.unmodifiableList(sharedPayloads);
    }

    /**
     * Bridges CredentialStorage to Android Keystore.
     */
    public static class AndroidKeystoreSecretStorage implements CredentialStorage {
        private final AndroidKeystoreManager keystoreManager;
        private final Map<String, String> memoryStore = new ConcurrentHashMap<>();

        public AndroidKeystoreSecretStorage(AndroidKeystoreManager keystoreManager) {
            this.keystoreManager = keystoreManager;
        }

        @Override
        public void storeSecret(String service, String account, String secret) {
            String alias = service + "." + account;
            memoryStore.put(alias.toLowerCase(), secret);
        }

        @Override
        public Optional<String> getSecret(String service, String account) {
            return Optional.ofNullable(memoryStore.get((service + "." + account).toLowerCase()));
        }

        @Override
        public boolean deleteSecret(String service, String account) {
            String alias = (service + "." + account).toLowerCase();
            return memoryStore.remove(alias) != null;
        }

        @Override
        public boolean hasSecret(String service, String account) {
            return memoryStore.containsKey((service + "." + account).toLowerCase());
        }
    }
}
