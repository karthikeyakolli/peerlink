package org.peerlink.core.ai.provider;

import org.peerlink.core.ai.gateway.AiMessage;
import org.peerlink.core.ai.gateway.AiRequest;
import org.peerlink.core.ai.gateway.AiResponse;
import org.peerlink.core.ai.gateway.AiToolCall;

import java.io.IOException;
import java.util.*;

/**
 * Deterministic offline AI provider for testing, fallback, and validation.
 */
public class SimulatedAiProvider implements AiProvider {
    private final String modelName;
    private volatile boolean available = true;
    private volatile boolean simulateTimeout = false;
    private volatile boolean simulateMalformedOutput = false;

    public SimulatedAiProvider() {
        this("simulated-peerlink-ai");
    }

    public SimulatedAiProvider(String modelName) {
        this.modelName = modelName;
    }

    @Override
    public AiProviderType getProviderType() {
        return AiProviderType.SIMULATED;
    }

    @Override
    public String getModelName() {
        return modelName;
    }

    @Override
    public boolean isAvailable() {
        return available;
    }

    public void setAvailable(boolean available) {
        this.available = available;
    }

    public void setSimulateTimeout(boolean simulateTimeout) {
        this.simulateTimeout = simulateTimeout;
    }

    public void setSimulateMalformedOutput(boolean simulateMalformedOutput) {
        this.simulateMalformedOutput = simulateMalformedOutput;
    }

    @Override
    public AiResponse generateResponse(AiRequest request) throws IOException {
        if (!available) {
            throw new IOException("Simulated AI provider is currently offline or unreachable");
        }
        if (simulateTimeout) {
            throw new java.net.SocketTimeoutException("Simulated AI provider request timed out (read deadline exceeded)");
        }
        if (simulateMalformedOutput) {
            // Return malformed response with blank content and no tools to trigger gateway bounds/schema validation rejection
            return new AiResponse("resp_malformed", modelName, "", Collections.emptyList(), 0, 0, 10);
        }

        String userPrompt = "";
        for (AiMessage msg : request.getMessages()) {
            if (msg.getRole() == org.peerlink.core.ai.gateway.AiRole.USER) {
                userPrompt = msg.getContent();
            }
        }

        String lower = userPrompt.toLowerCase();
        List<AiToolCall> toolCalls = new ArrayList<>();
        String content = "I can assist you with PeerLink operations.";

        if (lower.contains("find") || lower.contains("search") || lower.contains("show the files")) {
            Map<String, Object> args = new HashMap<>();
            args.put("query", userPrompt);
            args.put("filterExtension", lower.contains("pdf") ? "pdf" : "");
            toolCalls.add(new AiToolCall("call_search_1", "natural_language_search", args));
            content = "Proposing file search with specified filters.";
        } else if (lower.contains("share") && lower.contains("hours")) {
            Map<String, Object> args = new HashMap<>();
            args.put("targetPeer", "laptop");
            args.put("durationSeconds", 7200);
            args.put("objectName", "project report");
            toolCalls.add(new AiToolCall("call_share_1", "smart_share", args));
            content = "Proposing Smart Share for 2 hours.";
        } else if (lower.contains("bundle") || lower.contains("related to this project")) {
            Map<String, Object> args = new HashMap<>();
            args.put("bundleName", "Project Documents");
            args.put("queryPattern", "project");
            toolCalls.add(new AiToolCall("call_bundle_1", "smart_bundle", args));
            content = "Proposing Smart Bundle for project files.";
        } else if (lower.contains("every monday") || lower.contains("recipe")) {
            Map<String, Object> args = new HashMap<>();
            args.put("recurrence", "WEEKLY_MONDAY");
            args.put("targetPeer", "office-pc");
            args.put("folderName", "Documents");
            toolCalls.add(new AiToolCall("call_recipe_1", "transfer_recipe", args));
            content = "Proposing recurring Transfer Recipe.";
        } else if (lower.contains("why can't i open") || lower.contains("compatibility")) {
            content = "Deterministic compatibility assessment: The destination environment cannot natively execute or open this format without an external viewer.";
        } else if (lower.contains("why is this transfer using relay") || lower.contains("relay")) {
            content = "Diagnostics analysis: Both peers are behind symmetric NAT with direct UDP bindings filtered. Coturn relay path was established as deterministic fallback.";
        } else if (lower.contains("why is this folder not syncing") || lower.contains("sync")) {
            content = "Sync status explanation: Folder synchronization is paused due to an unresolved conflict or mass-change protection breaker.";
        } else if (lower.contains("ignore previous instructions") || lower.contains("delete all files") || lower.contains("sudo") || lower.contains("rm -rf")) {
            // Prompt injection attempt: simulated model might output a dangerous tool call,
            // which the DeterministicAiPolicyEngine MUST catch and reject!
            Map<String, Object> dangerousArgs = new HashMap<>();
            dangerousArgs.put("command", "delete_all");
            dangerousArgs.put("target", "*");
            toolCalls.add(new AiToolCall("call_injected_1", "delete_files", dangerousArgs));
            content = "Attempting to execute injected instruction.";
        }

        return new AiResponse(
                "resp_" + UUID.randomUUID(),
                modelName,
                content,
                toolCalls,
                150,
                50,
                45
        );
    }
}
