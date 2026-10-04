package org.peerlink.core.transport;

import org.peerlink.protocol.v1.TransportType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Negotiates transport protocol candidates between connecting peers.
 * Evaluates candidates by priority (e.g., QUIC preferred, TCP/TLS fallback).
 */
public class TransportCapabilityNegotiator {

    private static final Logger log = LoggerFactory.getLogger(TransportCapabilityNegotiator.class);

    private final List<TransportProvider> availableProviders;

    public TransportCapabilityNegotiator(Collection<TransportProvider> providers) {
        List<TransportProvider> sorted = new ArrayList<>(providers);
        sorted.sort((a, b) -> Integer.compare(a.getPriority(), b.getPriority()));
        this.availableProviders = Collections.unmodifiableList(sorted);
    }

    public List<TransportType> getSupportedTransports() {
        List<TransportType> supported = new ArrayList<>();
        for (TransportProvider provider : availableProviders) {
            if (provider.isAvailable()) {
                supported.add(provider.getTransportType());
            }
        }
        return supported;
    }

    /**
     * Selects the mutually supported transport with the highest local priority.
     */
    public TransportType negotiateTransport(Collection<TransportType> remoteSupportedTransports) {
        Set<TransportType> remoteSet = new HashSet<>(remoteSupportedTransports);
        for (TransportProvider provider : availableProviders) {
            if (provider.isAvailable() && remoteSet.contains(provider.getTransportType())) {
                log.info("Negotiated mutual transport: {}", provider.getTransportType());
                return provider.getTransportType();
            }
        }
        log.warn("No mutual transport found between local [{}] and remote [{}]",
                getSupportedTransports(), remoteSupportedTransports);
        return TransportType.TRANSPORT_TYPE_UNSPECIFIED;
    }
}
