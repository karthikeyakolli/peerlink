package org.peerlink.core.ai.provider;

import org.peerlink.core.ai.gateway.*;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * OpenAI-compatible HTTP REST provider (supports Groq, NVIDIA Nemotron, and local vLLM/Ollama).
 */
public class OpenAiCompatibleAiProvider implements AiProvider {
    private final AiProviderConfig config;

    public OpenAiCompatibleAiProvider(AiProviderConfig config) {
        this.config = Objects.requireNonNull(config, "config is required");
    }

    @Override
    public AiProviderType getProviderType() {
        return config.getType();
    }

    @Override
    public String getModelName() {
        return config.getModelName();
    }

    @Override
    public boolean isAvailable() {
        return config.getApiKey() != null && !config.getApiKey().isEmpty();
    }

    @Override
    public AiResponse generateResponse(AiRequest request) throws IOException {
        if (!isAvailable()) {
            throw new IOException("Provider API key is missing or not configured: " + config.getType());
        }

        long start = System.currentTimeMillis();
        String jsonPayload = buildRequestJson(request);

        URL url = new URL(config.getEndpointUrl());
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setRequestProperty("Authorization", "Bearer " + config.getApiKey());
        conn.setConnectTimeout(config.getTimeoutSeconds() * 1000);
        conn.setReadTimeout(config.getTimeoutSeconds() * 1000);
        conn.setDoOutput(true);

        try (OutputStream os = conn.getOutputStream()) {
            os.write(jsonPayload.getBytes(StandardCharsets.UTF_8));
        }

        int status = conn.getResponseCode();
        if (status != 200) {
            String err = readStream(conn.getErrorStream());
            throw new IOException("HTTP error from " + config.getType() + " (status " + status + "): " + err);
        }

        String responseBody = readStream(conn.getInputStream());
        long latencyMs = System.currentTimeMillis() - start;

        // Parse standard chat completion
        String content = parseContent(responseBody);
        return new AiResponse(
                "resp_" + UUID.randomUUID(),
                config.getModelName(),
                content,
                Collections.emptyList(),
                100,
                50,
                latencyMs
        );
    }

    private String buildRequestJson(AiRequest req) {
        StringBuilder sb = new StringBuilder("{");
        sb.append("\"model\":\"").append(escapeJson(config.getModelName())).append("\",");
        sb.append("\"temperature\":").append(req.getTemperature()).append(",");
        sb.append("\"max_tokens\":").append(req.getMaxTokens()).append(",");
        sb.append("\"messages\":[");
        for (int i = 0; i < req.getMessages().size(); i++) {
            AiMessage msg = req.getMessages().get(i);
            if (i > 0) sb.append(",");
            sb.append("{");
            sb.append("\"role\":\"").append(msg.getRole().name().toLowerCase()).append("\",");
            sb.append("\"content\":\"").append(escapeJson(msg.getContent())).append("\"");
            sb.append("}");
        }
        sb.append("]}");
        return sb.toString();
    }

    private String escapeJson(String raw) {
        if (raw == null) return "";
        return raw.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\b", "\\b")
                .replace("\f", "\\f")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }

    private String parseContent(String json) {
        int idx = json.indexOf("\"content\":");
        if (idx == -1) return json;
        int start = json.indexOf("\"", idx + 10);
        if (start == -1) return "";
        int end = json.indexOf("\"", start + 1);
        if (end == -1) return "";
        return json.substring(start + 1, end).replace("\\n", "\n").replace("\\\"", "\"");
    }

    private String readStream(java.io.InputStream is) throws IOException {
        if (is == null) return "";
        try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line).append("\n");
            }
            return sb.toString();
        }
    }
}
