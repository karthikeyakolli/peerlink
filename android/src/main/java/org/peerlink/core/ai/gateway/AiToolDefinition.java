package org.peerlink.core.ai.gateway;

import java.util.Collections;
import java.util.Map;
import java.util.Objects;

/**
 * Definition of a tool/action schema that the AI model may invoke.
 */
public final class AiToolDefinition {
    private final String name;
    private final String description;
    private final Map<String, Object> parameters;

    public AiToolDefinition(String name, String description, Map<String, Object> parameters) {
        this.name = Objects.requireNonNull(name, "name is required");
        this.description = Objects.requireNonNull(description, "description is required");
        this.parameters = parameters != null ? Collections.unmodifiableMap(parameters) : Collections.emptyMap();
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public Map<String, Object> getParameters() {
        return parameters;
    }

    @Override
    public String toString() {
        return "AiToolDefinition{name='" + name + "', description='" + description + "'}";
    }
}
