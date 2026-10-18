package org.peerlink.core.model;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

/**
 * Logical object identity representing a PeerLink entity.
 * Critical invariant: Object identity is NOT a filesystem path and NOT a content hash.
 */
public final class ObjectIdentity implements Serializable {
    private static final long serialVersionUID = 1L;

    private final String value;

    public ObjectIdentity(String value) {
        this.value = Objects.requireNonNull(value, "ObjectIdentity value must not be null");
        if (value.isBlank()) {
            throw new IllegalArgumentException("ObjectIdentity value must not be blank");
        }
    }

    public static ObjectIdentity generate() {
        return new ObjectIdentity("obj_" + UUID.randomUUID().toString().replace("-", ""));
    }

    public String getValue() {
        return value;
    }

    public String value() {
        return value;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof ObjectIdentity that)) return false;
        return Objects.equals(value, that.value);
    }

    @Override
    public int hashCode() {
        return Objects.hash(value);
    }

    @Override
    public String toString() {
        return "ObjectIdentity[" + value + "]";
    }
}
