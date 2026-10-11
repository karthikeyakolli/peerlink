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
 * Google Gemini REST provider (supports gemini-1.5-pro / gemini-1.5-flash).
 */
public class GeminiAiProvider implements AiProvider {
    private final AiProviderConfig config;

    public GeminiAiProvider(AiProviderConfig config) {
        this.config = Objects.requireNonNull(config, "config is required");
    }

    @Override
    public AiProviderType getProviderType() {
        return AiProviderType.GEMINI;
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
            throw new IOException("Gemini API key is not configured");
        }

        long start = System.currentTimeMillis();
        String targetUrl = config.getEndpointUrl() + "/models/" + config.getModelName() + ":generateContent?key=" + config.getApiKey();
        String jsonPayload = buildGeminiPayload(request);

        URL url = new URL(targetUrl);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setConnectTimeout(config.getTimeoutSeconds() * 1000);
        conn.setReadTimeout(config.getTimeoutSeconds() * 1000);
        conn.setDoOutput(true);

        try (OutputStream os = conn.getOutputStream()) {
            os.write(jsonPayload.getBytes(StandardCharsets.UTF_8));
        }

        int status = conn.getResponseCode();
        if (status != 200) {
            String err = readStream(conn.getErrorStream());
            throw new IOException("Gemini API error (HTTP " + status + "): " + err);
        }

        String responseBody = readStream(conn.getInputStream());
        long latencyMs = System.currentTimeMillis() - start;

        String content = parseGeminiText(responseBody);
        return new AiResponse(
                "gemini_" + UUID.randomUUID(),
                config.getModelName(),
                content,
                Collections.emptyList(),
                120,
                60,
                latencyMs
        );
    }

    private String buildGeminiPayload(AiRequest req) {
        StringBuilder sb = new StringBuilder("{\"contents\":[");
        for (int i = 0; i < req.getMessages().size(); i++) {
            AiMessage msg = req.getMessages().get(i);
            if (i > 0) sb.append(",");
            sb.append("{\"role\":\"").append(msg.getRole() == AiRole.ASSISTANT ? "model" : "user").append("\",");
            sb.append("\"parts\":[{\"text\":\"").append(escapeJson(msg.getContent())).append("\"}]}");
        }
        sb.append("]}");
        return sb.toString();
    }

    private String escapeJson(String raw) {
        if (raw == null) return "";
        return raw.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r");
    }

    private String parseGeminiText(String json) {
        int idx = json.indexOf("\"text\":");
        if (idx == -1) return json;
        int start = json.indexOf("\"", idx + 7);
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
