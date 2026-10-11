package org.peerlink.core.ai.gateway;

import java.util.Collections;
import java.util.Map;
import java.util.Objects;

/**
 * Invocation of a tool produced by the AI model.
 */
public final class AiToolCall {
    private final String id;
    private final String name;
    private final Map<String, Object> arguments;

    public AiToolCall(String id, String name, Map<String, Object> arguments) {
        this.id = id != null ? id : "call_" + System.nanoTime();
        this.name = Objects.requireNonNull(name, "tool name is required");
        this.arguments = arguments != null ? Collections.unmodifiableMap(arguments) : Collections.emptyMap();
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public Map<String, Object> getArguments() {
        return arguments;
    }

    @Override
    public String toString() {
        return "AiToolCall{id='" + id + "', name='" + name + "', args=" + arguments + "}";
    }
}
