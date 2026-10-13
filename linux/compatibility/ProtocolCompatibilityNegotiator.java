package org.peerlink.core.compatibility;

import org.peerlink.core.capability.CapabilityRegistry;

import java.util.*;

/**
 * Protocol Compatibility Negotiator.
 *
 * Strictly separates PROTOCOL COMPATIBILITY from FILE COMPATIBILITY:
 * - Protocol compatibility: message schemas, protocol versions, capability negotiation, transport requirements.
 * - File compatibility: filenames, path semantics, storage volume limits, metadata/permissions, execution safety.
 */
public final class ProtocolCompatibilityNegotiator {

    public static final int CURRENT_PROTOCOL_VERSION = 1;
    public static final int MIN_SUPPORTED_PROTOCOL_VERSION = 1;
    public static final int MAX_SUPPORTED_PROTOCOL_VERSION = 1;
    public static final String PROTOCOL_SCHEMA_IDENTIFIER = "peerlink.v1";

    public record ProtocolNegotiationResult(
            boolean compatible,
            int negotiatedVersion,
            String schemaIdentifier,
            Set<String> negotiatedCapabilities,
            List<String> incompatibilityReasons
    ) {
        public boolean isCompatible() { return compatible; }
    }

    private final int localMinVersion;
    private final int localMaxVersion;
    private final String schemaIdentifier;
    private final Set<String> requiredCapabilities;
    private final CapabilityRegistry localCapabilities;

    public ProtocolCompatibilityNegotiator(CapabilityRegistry localCapabilities) {
        this(MIN_SUPPORTED_PROTOCOL_VERSION, MAX_SUPPORTED_PROTOCOL_VERSION, PROTOCOL_SCHEMA_IDENTIFIER, localCapabilities, Set.of());
    }

    public ProtocolCompatibilityNegotiator(int localMinVersion, int localMaxVersion, String schemaIdentifier,
                                           CapabilityRegistry localCapabilities, Set<String> requiredCapabilities) {
        this.localMinVersion = localMinVersion;
        this.localMaxVersion = localMaxVersion;
        this.schemaIdentifier = Objects.requireNonNull(schemaIdentifier, "schemaIdentifier cannot be null");
        this.localCapabilities = localCapabilities != null ? localCapabilities : new CapabilityRegistry();
        this.requiredCapabilities = requiredCapabilities != null ? Set.copyOf(requiredCapabilities) : Set.of();
    }

    public ProtocolNegotiationResult negotiate(
            int remoteMinVersion,
            int remoteMaxVersion,
            String remoteSchemaIdentifier,
            Set<String> remoteCapabilities,
            boolean transportEncrypted
    ) {
        List<String> reasons = new ArrayList<>();

        // 1. Version negotiation: find highest mutually supported version
        int negotiatedVersion = -1;
        int commonMin = Math.max(localMinVersion, remoteMinVersion);
        int commonMax = Math.min(localMaxVersion, remoteMaxVersion);

        if (commonMin > commonMax) {
            reasons.add("Protocol version mismatch: local [" + localMinVersion + ".." + localMaxVersion +
                    "] has no overlap with remote [" + remoteMinVersion + ".." + remoteMaxVersion + "]");
        } else {
            negotiatedVersion = commonMax;
        }

        // 2. Schema compatibility
        if (remoteSchemaIdentifier != null && !remoteSchemaIdentifier.isBlank()
                && !schemaIdentifier.equalsIgnoreCase(remoteSchemaIdentifier)) {
            reasons.add("Message schema mismatch: local " + schemaIdentifier + " vs remote " + remoteSchemaIdentifier);
        }

        // 3. Transport security requirements
        if (!transportEncrypted) {
            reasons.add("Transport security requirement violated: unencrypted transport rejected by protocol policy");
        }

        // 4. Capability negotiation: find mutually supported capabilities and ensure required ones are present
        Set<String> negotiatedCaps = new HashSet<>();
        Set<String> localAll = localCapabilities.getAllCapabilities();
        if (remoteCapabilities != null) {
            for (String cap : remoteCapabilities) {
                if (localAll.contains(cap)) {
                    negotiatedCaps.add(cap);
                }
            }
        }

        for (String req : requiredCapabilities) {
            if (!negotiatedCaps.contains(req)) {
                reasons.add("Required protocol capability missing: " + req);
            }
        }

        boolean compatible = reasons.isEmpty();
        return new ProtocolNegotiationResult(compatible, negotiatedVersion, schemaIdentifier,
                Collections.unmodifiableSet(negotiatedCaps), Collections.unmodifiableList(reasons));
    }
}
