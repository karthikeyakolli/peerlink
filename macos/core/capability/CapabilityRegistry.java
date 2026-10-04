package org.peerlink.core.capability;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/**
 * Registry of supported and negotiated capabilities for the local node or remote peers.
 */
public final class CapabilityRegistry {

    private final Set<String> capabilities = new HashSet<>();

    public CapabilityRegistry() {}

    public CapabilityRegistry(Set<String> initialCapabilities) {
        if (initialCapabilities != null) {
            this.capabilities.addAll(initialCapabilities);
        }
    }

    public synchronized void registerCapability(String capability) {
        capabilities.add(capability);
    }

    public synchronized void unregisterCapability(String capability) {
        capabilities.remove(capability);
    }

    public synchronized boolean hasCapability(String capability) {
        return capabilities.contains(capability);
    }

    public synchronized Set<String> getAllCapabilities() {
        return Collections.unmodifiableSet(new HashSet<>(capabilities));
    }
}
