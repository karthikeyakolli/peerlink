package org.peerlink.core.ai.gateway;

import java.util.Collections;
import java.util.List;
import java.util.Objects;

/**
 * Structured request sent to the AI Gateway.
 */
public final class AiRequest {
    private final String requestId;
    private final List<AiMessage> messages;
    private final List<AiToolDefinition> tools;
    private final double temperature;
    private final int maxTokens;

    public AiRequest(String requestId, List<AiMessage> messages, List<AiToolDefinition> tools, double temperature, int maxTokens) {
        this.requestId = Objects.requireNonNull(requestId, "requestId is required");
        this.messages = messages != null ? Collections.unmodifiableList(messages) : Collections.emptyList();
        this.tools = tools != null ? Collections.unmodifiableList(tools) : Collections.emptyList();
        this.temperature = temperature;
        this.maxTokens = maxTokens;
    }

    public String getRequestId() {
        return requestId;
    }

    public List<AiMessage> getMessages() {
        return messages;
    }

    public List<AiToolDefinition> getTools() {
        return tools;
    }

    public double getTemperature() {
        return temperature;
    }

    public int getMaxTokens() {
        return maxTokens;
    }
}
