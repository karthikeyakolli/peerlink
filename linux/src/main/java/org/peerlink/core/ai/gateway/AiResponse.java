package org.peerlink.core.ai.gateway;

import java.util.Collections;
import java.util.List;
import java.util.Objects;

/**
 * Structured response from the AI Gateway.
 */
public final class AiResponse {
    private final String responseId;
    private final String modelName;
    private final String content;
    private final List<AiToolCall> toolCalls;
    private final int promptTokens;
    private final int completionTokens;
    private final long latencyMs;

    public AiResponse(String responseId, String modelName, String content, List<AiToolCall> toolCalls, int promptTokens, int completionTokens, long latencyMs) {
        this.responseId = Objects.requireNonNull(responseId, "responseId is required");
        this.modelName = Objects.requireNonNull(modelName, "modelName is required");
        this.content = content != null ? content : "";
        this.toolCalls = toolCalls != null ? Collections.unmodifiableList(toolCalls) : Collections.emptyList();
        this.promptTokens = promptTokens;
        this.completionTokens = completionTokens;
        this.latencyMs = latencyMs;
    }

    public String getResponseId() {
        return responseId;
    }

    public String getModelName() {
        return modelName;
    }

    public String getContent() {
        return content;
    }

    public List<AiToolCall> getToolCalls() {
        return toolCalls;
    }

    public int getPromptTokens() {
        return promptTokens;
    }

    public int getCompletionTokens() {
        return completionTokens;
    }

    public int getTotalTokens() {
        return promptTokens + completionTokens;
    }

    public long getLatencyMs() {
        return latencyMs;
    }

    @Override
    public String toString() {
        return "AiResponse{id='" + responseId + "', model='" + modelName + "', tokens=" + getTotalTokens() + ", latency=" + latencyMs + "ms}";
    }
}
