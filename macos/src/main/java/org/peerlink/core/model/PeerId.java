package org.peerlink.core.model;

import java.io.Serializable;
import java.util.Objects;

/**
 * Portable strongly-typed identifier for a PeerLink peer identity.
 */
public final class PeerId implements Serializable {
    private static final long serialVersionUID = 1L;
    private final String value;

    public PeerId(String value) {
        this.value = Objects.requireNonNull(value, "value cannot be null");
    }

    public String getValue() {
        return value;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        PeerId peerId = (PeerId) o;
        return value.equals(peerId.value);
    }

    @Override
    public int hashCode() {
        return value.hashCode();
    }

    @Override
    public String toString() {
        return value;
    }
}
