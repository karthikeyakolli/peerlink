package org.peerlink.core.platform;

/**
 * Capability flags for OS-level integration features.
 * All platform-specific features must be guarded by capability queries.
 */
public enum PlatformFeature {
    // File Manager / Explorer Integrations
    FILE_EXPLORER_CONTEXT_MENU,
    FINDER_SYNC_INTEGRATION,
    FILE_MANAGER_ACTIONS,
    FILE_REVEAL_AND_OPEN,
    FILE_ASSOCIATIONS,

    // Sharing Integrations
    SYSTEM_SHARE_SHEET,
    FINDER_SHARE_EXTENSION,

    // Notifications
    SYSTEM_NOTIFICATIONS,

    // Credentials & Secrets
    OS_KEYCHAIN_CREDENTIALS,
    DPAPI_CREDENTIALS,
    FREEDESKTOP_SECRET_SERVICE,

    // Diagnostics & Permissions
    FIREWALL_DIAGNOSTICS,
    SANDBOX_PERMISSIONS,
    SAF_DOCUMENT_PICKER,
    MEDIA_STORE_INTEGRATION,
    OS_PERMISSION_FLOWS,

    // Desktop/System Services
    DBUS_INTEGRATION,
    XDG_INTEGRATION,
    OPTIONAL_FILE_PROVIDER
}
