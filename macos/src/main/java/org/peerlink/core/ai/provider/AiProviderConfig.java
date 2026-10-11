package org.peerlink.core.ai.provider;

import java.util.Objects;

/**
 * Immutable configuration for an AI Provider.
 */
public final class AiProviderConfig {
    private final AiProviderType type;
    private final String modelName;
    private final String apiKey;
    private final String endpointUrl;
    private final int timeoutSeconds;

    public AiProviderConfig(AiProviderType type, String modelName, String apiKey, String endpointUrl, int timeoutSeconds) {
        this.type = Objects.requireNonNull(type, "type is required");
        this.modelName = Objects.requireNonNull(modelName, "modelName is required");
        this.apiKey = apiKey != null ? apiKey : "";
        this.endpointUrl = endpointUrl;
        this.timeoutSeconds = timeoutSeconds > 0 ? timeoutSeconds : 30;
    }

    public AiProviderType getType() { return type; }
    public String getModelName() { return modelName; }
    public String getApiKey() { return apiKey; }
    public String getEndpointUrl() { return endpointUrl; }
    public int getTimeoutSeconds() { return timeoutSeconds; }

    public static AiProviderConfig gemini(String apiKey, String modelName) {
        return new AiProviderConfig(AiProviderType.GEMINI, modelName != null ? modelName : "gemini-1.5-pro", apiKey,
                "https://generativelanguage.googleapis.com/v1beta", 30);
    }

    public static AiProviderConfig groq(String apiKey, String modelName) {
        return new AiProviderConfig(AiProviderType.GROQ, modelName != null ? modelName : "llama-3.3-70b-versatile", apiKey,
                "https://api.groq.com/openai/v1/chat/completions", 30);
    }

    public static AiProviderConfig nvidiaNemotron(String apiKey, String modelName) {
        return new AiProviderConfig(AiProviderType.NVIDIA_NEMOTRON, modelName != null ? modelName : "nvidia/llama-3.1-nemotron-70b-instruct", apiKey,
                "https://integrate.api.nvidia.com/v1/chat/completions", 30);
    }

    public static AiProviderConfig simulated() {
        return new AiProviderConfig(AiProviderType.SIMULATED, "peerlink-deterministic-mock", "sim-key", null, 5);
    }
}
