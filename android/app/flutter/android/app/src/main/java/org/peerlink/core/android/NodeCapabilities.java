package org.peerlink.core.android;

import java.util.*;

/**
 * Immutable typed capability descriptor capturing what this device node can actually do now:
 * - Available physical and logical network interfaces
 * - Active listening sockets and endpoints
 * - Usable local and peer transports
 * - Missing permissions (e.g. CAMERA, ACCESS_LOCAL_NETWORK)
 * - Android OS background execution and battery limitations
 * - Supported protocol operations (SEND, ACCESS, SYNC, BACKUP)
 * - Cryptographic Keystore security tier
 */
public class NodeCapabilities {
    private final List<String> availableNetworkInterfaces;
    private final List<String> activeListeners;
    private final List<String> usableTransports;
    private final List<String> missingPermissions;
    private final String backgroundTransferLimitations;
    private final Map<String, Boolean> supportedFeatures;
    private final boolean isHardwareSigning;
    private final String securityLevel;
    private final boolean canTransfer;

    public NodeCapabilities(List<String> availableNetworkInterfaces,
                            List<String> activeListeners,
                            List<String> usableTransports,
                            List<String> missingPermissions,
                            String backgroundTransferLimitations,
                            Map<String, Boolean> supportedFeatures,
                            boolean isHardwareSigning,
                            String securityLevel,
                            boolean canTransfer) {
        this.availableNetworkInterfaces = Collections.unmodifiableList(new ArrayList<>(availableNetworkInterfaces != null ? availableNetworkInterfaces : Collections.emptyList()));
        this.activeListeners = Collections.unmodifiableList(new ArrayList<>(activeListeners != null ? activeListeners : Collections.emptyList()));
        this.usableTransports = Collections.unmodifiableList(new ArrayList<>(usableTransports != null ? usableTransports : Collections.emptyList()));
        this.missingPermissions = Collections.unmodifiableList(new ArrayList<>(missingPermissions != null ? missingPermissions : Collections.emptyList()));
        this.backgroundTransferLimitations = backgroundTransferLimitations != null ? backgroundTransferLimitations : "None";
        this.supportedFeatures = Collections.unmodifiableMap(new LinkedHashMap<>(supportedFeatures != null ? supportedFeatures : Collections.emptyMap()));
        this.isHardwareSigning = isHardwareSigning;
        this.securityLevel = securityLevel != null ? securityLevel : "UNKNOWN";
        this.canTransfer = canTransfer;
    }

    public List<String> getAvailableNetworkInterfaces() {
        return availableNetworkInterfaces;
    }

    public List<String> getActiveListeners() {
        return activeListeners;
    }

    public List<String> getUsableTransports() {
        return usableTransports;
    }

    public List<String> getMissingPermissions() {
        return missingPermissions;
    }

    public String getBackgroundTransferLimitations() {
        return backgroundTransferLimitations;
    }

    public Map<String, Boolean> getSupportedFeatures() {
        return supportedFeatures;
    }

    public boolean isHardwareSigning() {
        return isHardwareSigning;
    }

    public String getSecurityLevel() {
        return securityLevel;
    }

    public boolean canTransfer() {
        return canTransfer;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("availableNetworkInterfaces", availableNetworkInterfaces);
        map.put("activeListeners", activeListeners);
        map.put("usableTransports", usableTransports);
        map.put("missingPermissions", missingPermissions);
        map.put("backgroundTransferLimitations", backgroundTransferLimitations);
        map.put("supportedFeatures", supportedFeatures);
        map.put("isHardwareSigning", isHardwareSigning);
        map.put("securityLevel", securityLevel);
        map.put("canTransfer", canTransfer);
        return map;
    }

    @Override
    public String toString() {
        return "NodeCapabilities{" +
                "interfaces=" + availableNetworkInterfaces +
                ", listeners=" + activeListeners +
                ", transports=" + usableTransports +
                ", missingPerms=" + missingPermissions +
                ", limitations='" + backgroundTransferLimitations + '\'' +
                ", hardwareSigning=" + isHardwareSigning +
                ", securityLevel='" + securityLevel + '\'' +
                ", canTransfer=" + canTransfer +
                '}';
    }
}
